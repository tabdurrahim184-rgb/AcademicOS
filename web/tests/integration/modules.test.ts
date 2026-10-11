import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import http from "node:http";
import type { AddressInfo } from "node:net";
import os from "node:os";
import path from "node:path";
import JSZip from "jszip";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { newUser } from "./helpers";
import { closePool, withUser } from "@/lib/db";
import { listCourses, listTopics } from "@/lib/data/courses";
import { importOne, parseZip } from "@/lib/data/bulk-import";
import { getSourceChunks, getSource, listSources, saveUploadedSource } from "@/lib/data/sources";
import { createEntry, getProfile, listEntries, saveProfile, setEntryStatus } from "@/lib/data/project";
import { addDebateSource, createDebate, listDebateSources, listDebates, setSourceVerified, updateDebate } from "@/lib/data/debates";
import {
  addCommitment, analyzeWorkTask, commitmentConflicts, createWorkTask, ensureWorkSetup, listClients, listCommitments, listWorkTasks,
  parseMinuteList, scheduleWorkTask, setWorkStatus, taskHistory, updateMinuteList,
} from "@/lib/data/work";
import { listPlanTasks, regeneratePlan } from "@/lib/data/plan";
import { loadWeek } from "@/lib/data/calendar";
import { createJob, getJob, runJob, cancelJob } from "@/lib/jobs";
import { listSegments, saveRecording, updateOcrChunk, updateSegment } from "@/lib/data/recordings";
import { exportBackup, restoreBackup } from "@/lib/data/backup";
import { toDocx, toSrt, toVtt } from "@/lib/transcription";
import { toMinutes } from "@/lib/schedule";
import { weekdayOf } from "@/lib/planner";

const fx = (f: string) => readFileSync(path.join(__dirname, "..", "fixtures", f));
const MONDAY = new Date("2026-10-12T04:00:00Z"); // Pazartesi 07:00 Kıbrıs

let audio: Buffer;
let mockOpenAI: http.Server;
const transcribeCalls: string[] = [];
beforeAll(async () => {
  // 3 saniyelik gerçek ses dosyası (ffmpeg ile)
  const f = path.join(os.tmpdir(), `aos-test-${process.pid}.mp3`);
  execFileSync("ffmpeg", ["-hide_banner", "-loglevel", "error", "-f", "lavfi", "-i", "sine=frequency=440:duration=3", "-y", f]);
  audio = readFileSync(f);
  // TEST İKİZİ: OpenAI ses deşifre uç noktası (gerçek sağlayıcı doğrulanmaz)
  mockOpenAI = http.createServer((req, res) => {
    let size = 0;
    req.on("data", (c) => (size += c.length));
    req.on("end", () => {
      transcribeCalls.push(`${req.url} ${size}`);
      res.writeHead(200, { "content-type": "application/json" });
      res.end(JSON.stringify({ text: "Merhaba, bugün çerçeveleme kuramını işleyeceğiz.", duration: 3, language: "turkish",
        segments: [{ id: 0, start: 0, end: 1.5, text: " Merhaba," }, { id: 1, start: 1.5, end: 3, text: " bugün çerçeveleme kuramını işleyeceğiz." }] }));
    });
  });
  await new Promise<void>((r) => mockOpenAI.listen(0, "127.0.0.1", r));
  Object.assign(process.env, {
    TRANSCRIPTION_PROVIDER: "openai", TRANSCRIPTION_MODEL: "whisper-1", OPENAI_API_KEY: "sk-test",
    OPENAI_BASE_URL: `http://127.0.0.1:${(mockOpenAI.address() as AddressInfo).port}/v1`,
  });
});
afterAll(async () => {
  await new Promise<void>((r) => mockOpenAI.close(() => r()));
  for (const k of ["TRANSCRIPTION_PROVIDER", "TRANSCRIPTION_MODEL", "OPENAI_API_KEY", "OPENAI_BASE_URL"]) delete process.env[k];
  await closePool();
});

const course = async (userId: string, code: string) => (await withUser(userId, listCourses)).find((c) => c.code.startsWith(code))!;

describe("Toplu ve ZIP içe aktarma", () => {
  it("ZIP klasörlerini konulara eşler, aynı dosyayı ikinci kez eklemez, bozuk dosyada diğerlerini kaydeder", async () => {
    const u = await newUser();
    const c = await course(u.id, "İLF431");
    const z = new JSZip();
    z.file("Ders/3. Hafta - Gündem/ders.pdf", fx("siyasal-iletisim-hafta3.pdf"));
    z.file("Ders/3. Hafta - Gündem/ayni-dosya.pdf", fx("siyasal-iletisim-hafta3.pdf"));
    z.file("Ders/Okumalar/bozuk.pdf", fx("bozuk.pdf"));
    z.file("Ders/Okumalar/sahte.docx", fx("sahte.docx"));
    const { items } = await parseZip(await z.generateAsync({ type: "nodebuffer" }));
    const out = await withUser(u.id, async (tx) => {
      const res = [];
      for (const it of items) res.push(await importOne(tx, u.id, c.id, it));
      return res;
    });
    expect(out.map((o) => o.status)).toEqual(["eklendi", "yinelenen", "eklendi", "hata"]);
    await withUser(u.id, async (tx) => {
      expect((await listTopics(tx, c.id)).map((t) => [t.title, t.week])).toEqual([["3. Hafta - Gündem", 3], ["Okumalar", null]]);
      expect(await listSources(tx, { courseId: c.id })).toHaveLength(2);
    });
  });
});

describe("OCR işi (gerçek Tesseract)", () => {
  it("taranmış PDF'i okur, kaynağı aranabilir yapar; OCR metni düzeltilebilir, ham çıktı korunur", async () => {
    const u = await newUser();
    const c = await course(u.id, "İLF431");
    const src = await withUser(u.id, (tx) =>
      saveUploadedSource(tx, u.id, { courseId: c.id, topicId: null, title: "Tarama", kind: "hoca", filename: "taranmis.pdf", data: fx("taranmis.pdf") }),
    );
    expect(src.status).toBe("metin_yok");
    const jobId = await withUser(u.id, (tx) => createJob(tx, u.id, "ocr", src.id));
    await expect(withUser(u.id, (tx) => createJob(tx, u.id, "ocr", src.id))).rejects.toThrow("zaten devam eden");
    await runJob(u.id, jobId);
    await withUser(u.id, async (tx) => {
      expect(await getJob(tx, jobId)).toMatchObject({ status: "tamamlandi", progress: 1, total: 1 });
      expect((await getSource(tx, src.id))!.extraction_status).toBe("tamam");
      const [chunk] = await getSourceChunks(tx, src.id);
      expect(chunk.content).toMatch(/Çerçeveleme/);
      await updateOcrChunk(tx, chunk.id, "Düzeltilmiş metin");
      const [after] = await getSourceChunks(tx, src.id);
      expect(after.content).toBe("Düzeltilmiş metin");
      expect(after.raw_ocr).toMatch(/Çerçeveleme/);
    });
  }, 120_000);
});

describe("Deşifre işi (OpenAI test ikizi + gerçek ffmpeg)", () => {
  it("kaydı parçalar, segmentleri zaman damgalarıyla kaydeder, düzenleme ham metni korur, dışa aktarır", async () => {
    const u = await newUser();
    const c = await course(u.id, "İLF431");
    const recId = await withUser(u.id, (tx) => saveRecording(tx, u.id, { archive: "ders", courseId: c.id, clientId: null, title: "Ders kaydı", filename: "kayit.mp3", data: audio, durationSec: 3 }));
    const jobId = await withUser(u.id, (tx) => createJob(tx, u.id, "transkripsiyon", recId));
    await runJob(u.id, jobId);
    expect(transcribeCalls.at(-1)).toMatch(/^\/v1\/audio\/transcriptions \d+/);
    const segs = await withUser(u.id, (tx) => listSegments(tx, recId));
    expect(segs.map((s) => [Number(s.start_sec), Number(s.end_sec), s.text])).toEqual([[0, 1.5, "Merhaba,"], [1.5, 3, "bugün çerçeveleme kuramını işleyeceğiz."]]);
    await withUser(u.id, (tx) => updateSegment(tx, segs[0].id, "Merhaba arkadaşlar,", "Hoca"));
    const after = await withUser(u.id, (tx) => listSegments(tx, recId));
    expect(after[0]).toMatchObject({ text: "Merhaba arkadaşlar,", raw_text: "Merhaba,", speaker: "Hoca" });
    expect(toSrt(after)).toContain("00:00:01,500 --> 00:00:03,000");
    expect(toVtt(after)).toMatch(/^WEBVTT\n\n00:00:00\.000 --> 00:00:01\.500/);
    const docx = await JSZip.loadAsync(await toDocx("Ders kaydı", after));
    expect(await docx.file("word/document.xml")!.async("string")).toContain("Hoca: Merhaba arkadaşlar,");
    expect(await withUser(u.id, (tx) => getJob(tx, jobId))).toMatchObject({ status: "tamamlandi" });
  }, 60_000);

  it("iptal edilen iş çalışmaz; başka kullanıcı kaydı göremez", async () => {
    const u = await newUser();
    const recId = await withUser(u.id, (tx) => saveRecording(tx, u.id, { archive: "is", courseId: null, clientId: null, title: "İş", filename: "a.mp3", data: audio, durationSec: 3 }));
    const jobId = await withUser(u.id, (tx) => createJob(tx, u.id, "transkripsiyon", recId));
    await withUser(u.id, (tx) => cancelJob(tx, jobId));
    const before = transcribeCalls.length;
    await runJob(u.id, jobId);
    expect(transcribeCalls.length).toBe(before);
    const b = await newUser();
    expect(await withUser(b.id, (tx) => listSegments(tx, recId))).toHaveLength(0);
    await expect(withUser(b.id, (tx) => saveRecording(tx, b.id, { archive: "ders", courseId: null, clientId: null, title: "x", filename: "x.exe", data: audio, durationSec: 1 }))).rejects.toThrow("Desteklenmeyen");
  });
});

describe("Bölüm Projesi ve akademik tartışmalar", () => {
  it("proje bilgisi, kayıtlar, teslimin takvime ve plana yansıması", async () => {
    const u = await newUser();
    await withUser(u.id, async (tx) => {
      expect(await getProfile(tx)).toMatchObject({ title: "" }); // uydurma yok
      await saveProfile(tx, u.id, { title: "Kıbrıs'ta yerel gazetecilik", aim: "", research_questions: "1) …", method: "Derinlemesine görüşme", format: "", advisor: "İbrahim Özejder" });
      await createEntry(tx, u.id, { kind: "gorusme", title: "1. danışman görüşmesi", body: "Konu daraltılacak.", eventDate: "2026-10-08" });
      await createEntry(tx, u.id, { kind: "teslim", title: "Ara teslim", body: "", dueDate: "2026-10-20" });
      expect((await getProfile(tx)).advisor).toBe("İbrahim Özejder");
      expect((await listEntries(tx)).map((e) => e.kind)).toEqual(["gorusme", "teslim"]);
      await regeneratePlan(tx, u.id, MONDAY);
      const tasks = await listPlanTasks(tx, "2026-10-12", "2026-10-25");
      const proj = tasks.filter((t) => t.origin_key.startsWith("proje:"));
      expect(proj).toHaveLength(2);
      expect(proj.every((t) => t.scheduled_date <= "2026-10-20")).toBe(true);
      expect((await loadWeek(tx, "2026-10-19")).events.some((e) => e.title === "Bölüm Projesi — Ara teslim")).toBe(true);
      const teslim = (await listEntries(tx, "teslim"))[0];
      await setEntryStatus(tx, teslim.id, "tamamlandi");
      await regeneratePlan(tx, u.id, MONDAY);
      expect((await listPlanTasks(tx, "2026-10-12", "2026-10-25")).some((t) => t.origin_key.startsWith("proje:"))).toBe(false);
    });
  });

  it("tartışma alanları ve kaynak doğrulama durumu kalıcıdır", async () => {
    const u = await newUser();
    await withUser(u.id, async (tx) => {
      const id = await createDebate(tx, u.id, { theme: "adalet", title: "Haberde tarafsızlık ve adalet", courseId: null });
      await updateDebate(tx, id, {
        title: "Haberde tarafsızlık ve adalet", theme: "adalet", claim: "Gazeteci her zaman tarafsız olmalıdır.", academic_context: "Nesnellik normu",
        counter_arguments: "Hak odaklı habercilik…", islamic_perspective: "Adalet kavramı…", class_answer: "…", weaknesses: "…", uncertainties: "",
      });
      await addDebateSource(tx, u.id, id, { kind: "kuran", reference: "Nisâ 4/135", quote: "", note: "Adaletin şahitliği" });
      await expect(addDebateSource(tx, u.id, id, { kind: "hadis", reference: "", quote: "", note: "" })).rejects.toThrow("künyesini");
      const [s] = await listDebateSources(tx, id);
      expect(s.verified).toBe(false);
      await setSourceVerified(tx, s.id, true);
      expect((await listDebates(tx))[0]).toMatchObject({ sources: 1, unverified: 0, claim: "Gazeteci her zaman tarafsız olmalıdır." });
    });
  });
});

describe("İş Merkezi — gerçek veritabanı", () => {
  it("iki işveren ve bilinen program oluşturulur; program çakışmaları bildirilir; iş görevleri akademik zamana konmaz", async () => {
    const u = await newUser();
    await withUser(u.id, async (tx) => {
      await ensureWorkSetup(tx, u.id);
      await ensureWorkSetup(tx, u.id); // tekrar çağrılması güvenli
      const clients = await listClients(tx);
      expect(clients.map((c) => c.name)).toEqual(["Ahmet Özsoy", "Hasan Bey"]);
      const commits = await listCommitments(tx);
      expect(commits.map((c) => [c.weekday, c.start_time, c.end_time])).toEqual([[1, "16:30", null], [2, "16:30", null], [3, "16:30", null]]);
      const conflicts = await commitmentConflicts(tx);
      expect(conflicts.some((c) => c.weekday === 2 && c.with.startsWith("İLF413"))).toBe(true); // Salı İletişim Etiği 15.30–17.30
      expect(conflicts.some((c) => c.with.startsWith("akademik zaman"))).toBe(true);

      const hasan = clients[1];
      const id = await createWorkTask(tx, u.id, { clientId: hasan.id, kind: "reels", title: "Seçim Reels'i", requestedBy: "Hasan Bey", description: "", dueDate: "2026-10-13", dueTime: "12:00", priority: "yuksek", estimateMin: 90 });
      await regeneratePlan(tx, u.id, MONDAY);
      const r = await analyzeWorkTask(tx, id, MONDAY);
      expect(r.ok).toBe(true);
      if (r.ok) {
        expect(r.date).toBe("2026-10-12");
        expect(toMinutes(r.start)).toBeGreaterThanOrEqual(toMinutes("18:30")); // Pazartesi taahhüdü 16.30 + 120 dk varsayımı sonrası
      }
      const s = await scheduleWorkTask(tx, u.id, id, MONDAY);
      expect(s.ok && weekdayOf(s.date) <= 5 && toMinutes(s.start) >= toMinutes("18:00")).toBe(true);
      // Plan yeniden üretilince çalışma görevleri planlanan işle çakışmaz
      await regeneratePlan(tx, u.id, MONDAY);
      const w = (await listWorkTasks(tx))[0];
      for (const p of (await listPlanTasks(tx, w.scheduled_date!, w.scheduled_date!))) {
        const ps = toMinutes(p.start_time), ws = toMinutes(w.start_time!);
        expect(ps < ws + w.estimate_min && ws < ps + p.duration_min).toBe(false);
      }
      await setWorkStatus(tx, u.id, id, "teslim_edildi");
      expect((await taskHistory(tx, id)).map((h) => h.event)).toEqual(["Oluşturuldu", "Durum: Teslim edildi"]);
      await updateMinuteList(tx, id, "00:00-00:15 Açılış\n00:15-00:45 Röportaj");
      expect((await listWorkTasks(tx))[0].minute_list).toEqual([{ start: "00:00", end: "00:15", note: "Açılış" }, { start: "00:15", end: "00:45", note: "Röportaj" }]);
      await expect(addCommitment(tx, u.id, { clientId: hasan.id, title: "x", weekday: 4, start: "20:00", end: "19:00" })).rejects.toThrow("Bitiş");
    });
    expect(() => parseMinuteList("rastgele satır")).toThrow("anlaşılamadı");
    const other = await newUser();
    expect(await withUser(other.id, listWorkTasks)).toHaveLength(0);
  });
});

describe("Yedek sürüm 3", () => {
  it("proje, tartışma, iş ve kayıt verisini başka hesaba geri yükler", async () => {
    const a = await newUser();
    await withUser(a.id, async (tx) => {
      await saveProfile(tx, a.id, { title: "Proje", aim: "", research_questions: "", method: "", format: "", advisor: "" });
      await createEntry(tx, a.id, { kind: "taslak", title: "Taslak 1", body: "metin", dueDate: "2026-11-01" });
      const d = await createDebate(tx, a.id, { theme: "sanat", title: "Sanat ve ahlak", courseId: null });
      await addDebateSource(tx, a.id, d, { kind: "akademik", reference: "Makale, s. 12", quote: "", note: "" });
      await ensureWorkSetup(tx, a.id);
      const [c] = await listClients(tx);
      const t = await createWorkTask(tx, a.id, { clientId: c.id, kind: "haber", title: "Haber", requestedBy: "", description: "", dueDate: null, dueTime: "", priority: "normal", estimateMin: 30 });
      await updateMinuteList(tx, t, "00:00-00:10 Giriş");
      await saveRecording(tx, a.id, { archive: "is", courseId: null, clientId: c.id, title: "Ses", filename: "s.mp3", data: audio, durationSec: 3 });
    });
    const backup = JSON.parse(JSON.stringify(await withUser(a.id, exportBackup)));
    expect(backup.version).toBe(3);
    const b = await newUser();
    await withUser(b.id, async (tx) => {
      await ensureWorkSetup(tx, b.id); // hedef hesapta önceden oluşmuş iş verisi silinip yedekle değiştirilir
      await restoreBackup(tx, b.id, backup);
      expect((await getProfile(tx)).title).toBe("Proje");
      expect((await listEntries(tx))[0]).toMatchObject({ title: "Taslak 1", due_date: "2026-11-01" });
      expect(await listDebateSources(tx, (await listDebates(tx))[0].id)).toHaveLength(1);
      expect((await listClients(tx)).map((c) => c.name)).toEqual(["Ahmet Özsoy", "Hasan Bey"]);
      expect((await listWorkTasks(tx))[0].minute_list).toEqual([{ start: "00:00", end: "00:10", note: "Giriş" }]);
      const recs = await tx.query("SELECT r.title, length(f.content) AS n FROM recordings r JOIN recording_files f ON f.recording_id=r.id");
      expect(recs.rows[0]).toMatchObject({ title: "Ses", n: audio.length });
    });
  });
});
