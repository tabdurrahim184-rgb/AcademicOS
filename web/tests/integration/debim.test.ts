import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { newUser } from "./helpers";
import { startMockMoodle, MOCK_TOKEN } from "./mock-moodle";
import { closePool, withUser } from "@/lib/db";
import { listCourses, listTopics } from "@/lib/data/courses";
import { listSources } from "@/lib/data/sources";
import { connect, disconnect, getConnection, importCourseMaterials, linkCourse, remoteCourses } from "@/lib/lms/debim";

let mock: Awaited<ReturnType<typeof startMockMoodle>>;
beforeAll(async () => {
  mock = await startMockMoodle();
  process.env.APP_ENCRYPTION_KEY = Buffer.alloc(32, 3).toString("base64");
  process.env.LMS_ALLOWED_HOSTS = "127.0.0.1";
  process.env.LMS_ALLOW_HTTP = "true";
});
afterAll(async () => {
  await mock.close();
  await closePool();
});

describe("DEBİM (Moodle web servisleri) — test ikizine karşı", () => {
  it("geçersiz anahtar reddedilir ve hiçbir şey saklanmaz", async () => {
    const u = await newUser();
    await expect(connect(u.id, mock.url, "0".repeat(32))).rejects.toThrow("Güvenlik anahtarı geçersiz");
    expect(await withUser(u.id, getConnection)).toBeNull();
  });

  it("bağlanır, anahtarı şifreli saklar, dersi eşleştirir, materyalleri konu/haftaya aktarır ve tekrarları atlar", async () => {
    const u = await newUser();
    const info = await connect(u.id, mock.url, MOCK_TOKEN);
    expect(info.fullname).toBe("Abdurrahim Türkmenoğlu");
    const raw = await withUser(u.id, async (tx) => (await tx.query("SELECT token_enc FROM lms_connections")).rows[0].token_enc as string);
    expect(raw).not.toContain(MOCK_TOKEN);

    const remote = await remoteCourses(u.id);
    expect(remote.map((r) => r.id)).toEqual([1204, 1300]);
    const c431 = (await withUser(u.id, listCourses)).find((c) => c.code === "İLF431")!;
    await expect(importCourseMaterials(u.id, 1204)).rejects.toThrow("eşleştirilmedi");
    await withUser(u.id, (tx) => linkCourse(tx, u.id, 1204, "İLF431 Siyasal İletişim", c431.id));

    const r1 = await importCourseMaterials(u.id, 1204);
    expect(r1.summary).toEqual({ eklendi: 2, yinelenen: 1, atlandi: 1, hata: 0 }); // kopya.pdf aynı içerik; .exe atlandı
    await withUser(u.id, async (tx) => {
      const topics = await listTopics(tx, c431.id);
      expect(topics.map((t) => [t.title, t.week])).toEqual([["3. Hafta: Gündem belirleme", 3], ["Hafta 4", 4]]);
      const sources = await listSources(tx, { courseId: c431.id });
      expect(sources.map((s) => s.filename).sort()).toEqual(["hafta3.pdf", "sunum.pptx"]);
      expect(sources.every((s) => s.kind === "hoca" && s.extraction_status === "tamam")).toBe(true);
    });

    // İkinci aktarım: değişmemiş dosyalar indirilmez
    const downloadsBefore = mock.requests.filter((r) => r.startsWith("indir:")).length;
    const r2 = await importCourseMaterials(u.id, 1204);
    expect(r2.summary.eklendi).toBe(0);
    expect(mock.requests.filter((r) => r.startsWith("indir:")).length).toBe(downloadsBefore); // hiçbir dosya yeniden indirilmedi
    expect(r2.summary.yinelenen).toBe(3);

    // Bağlantı kaldırılınca anahtar silinir, materyaller kalır
    await withUser(u.id, (tx) => disconnect(tx));
    expect(await withUser(u.id, getConnection)).toBeNull();
    expect(await withUser(u.id, (tx) => listSources(tx, { courseId: c431.id }))).toHaveLength(2);
  });

  it("başka kullanıcının bağlantısı ve eşleştirmeleri görünmez", async () => {
    const a = await newUser();
    await connect(a.id, mock.url, MOCK_TOKEN);
    const b = await newUser();
    expect(await withUser(b.id, getConnection)).toBeNull();
    await expect(remoteCourses(b.id)).rejects.toThrow("Önce DEBİM");
  });
});
