import { readFileSync } from "node:fs";
import path from "node:path";
import { afterAll, describe, expect, it } from "vitest";
import { newUser } from "./helpers";
import { authenticate, AuthError, createSession, registerUser, resolveSession } from "@/lib/auth-core";
import { closePool, getPool, withUser } from "@/lib/db";
import { createTopic, listCourses, listTopics, scheduleConflicts } from "@/lib/data/courses";
import { getSourceChunks, getSourceFile, listSources, saveUploadedSource, searchChunks } from "@/lib/data/sources";
import {
  createQuestion, getStudySession, listAttempts, listDueCards, listMessages, listMistakes, startStudySession, submitAnswer, finalizeAttempt,
} from "@/lib/data/study";
import { exportBackup, restoreBackup } from "@/lib/data/backup";
import { loadDashboard } from "@/lib/data/dashboard";
import { generateTutorReply, saveStudentMessage, generateQuestions, gradeAttemptWithAI } from "@/lib/ai/tutor";
import { AIRequestError, type AIProvider } from "@/lib/ai/provider";
import { UploadError } from "@/lib/extract";

const fx = (f: string) => readFileSync(path.join(__dirname, "..", "fixtures", f));
afterAll(closePool);

/** Test ikizi: gerçek sağlayıcı yerine kayıtlı yanıt döndürür (yalnızca testlerde). */
function scriptedProvider(reply: string | (() => never)): AIProvider & { calls: Array<{ system: string; messages: unknown[] }> } {
  const calls: Array<{ system: string; messages: unknown[] }> = [];
  return {
    id: "anthropic", model: "test-ikizi", calls,
    async complete(req) {
      calls.push(req);
      if (typeof reply === "function") reply();
      return { text: reply as string, provider: "test", model: "test-ikizi" };
    },
  };
}

async function setupCourseWithPdf(userId: string) {
  return withUser(userId, async (tx) => {
    const course = (await listCourses(tx)).find((c) => c.code === "İLF431")!;
    const topicId = await createTopic(tx, userId, course.id, { title: "Gündem belirleme", week: 3 });
    const src = await saveUploadedSource(tx, userId, {
      courseId: course.id, topicId, title: "", kind: "hoca", filename: "siyasal-iletisim-hafta3.pdf", data: fx("siyasal-iletisim-hafta3.pdf"),
    });
    return { courseId: course.id, topicId, sourceId: src.id };
  });
}

describe("Test A — giriş ve dokuz ders", () => {
  it("kayıt olan kullanıcı giriş yapar ve dokuz dersini görür; çakışmalar listelenir", async () => {
    const u = await newUser();
    const id = await authenticate(u.email.toUpperCase(), u.password);
    expect(id).toBe(u.id);
    const { token } = await createSession(id);
    expect((await resolveSession(token))?.id).toBe(u.id);
    const courses = await withUser(u.id, listCourses);
    expect(courses).toHaveLength(9);
    expect(courses.map((c) => c.code)).toContain("GZT440");
    expect(await withUser(u.id, scheduleConflicts)).toHaveLength(2);
  });
  it("hatalı parola reddedilir ve tekrar eden denemeler sınırlandırılır", async () => {
    const u = await newUser();
    for (let i = 0; i < 8; i++) await expect(authenticate(u.email, "yanlis-parola", "ip-x")).rejects.toThrow("hatalı");
    await expect(authenticate(u.email, u.password, "ip-x")).rejects.toThrow("Çok fazla");
    expect(await authenticate(u.email, u.password, "ip-y")).toBe(u.id);
  });
  it("aynı e-postayla ikinci hesap açılamaz", async () => {
    const u = await newUser();
    await expect(registerUser({ email: u.email, name: "X Y", password: "baskaParola123" })).rejects.toBeInstanceOf(AuthError);
  });
});

describe("Test B / K — kaynak yükleme, kalıcılık ve Türkçe arama", () => {
  it("PDF kaydedilir, bayt bayt geri okunur, sayfa konumlarıyla aranır", async () => {
    const u = await newUser();
    const { courseId, topicId, sourceId } = await setupCourseWithPdf(u.id);
    await withUser(u.id, async (tx) => {
      const s = (await listSources(tx, { courseId }))[0];
      expect(s).toMatchObject({ id: sourceId, extraction_status: "tamam", unit_count: 2, topic_id: topicId, filename: "siyasal-iletisim-hafta3.pdf" });
      expect((await getSourceFile(tx, sourceId))!.equals(fx("siyasal-iletisim-hafta3.pdf"))).toBe(true);
      expect((await getSourceChunks(tx, sourceId)).map((c) => c.locator)).toEqual(["Sayfa 1", "Sayfa 2"]);
      const hits = await searchChunks(tx, "çerçeveleme");
      expect(hits[0]?.locator).toBe("Sayfa 2");
      expect((await searchChunks(tx, "İLETİŞİM"))[0]?.content).toContain("Siyasal İletişim");
      expect((await listTopics(tx, courseId))[0].status).toBe("materyal_alindi");
    });
  });
  it("Test L — bozuk dosya anlaşılır hatayla reddedilir veya hata durumuyla kaydedilir", async () => {
    const u = await newUser();
    const courseId = (await withUser(u.id, listCourses))[0].id;
    await expect(
      withUser(u.id, (tx) => saveUploadedSource(tx, u.id, { courseId, topicId: null, title: "", kind: "diger", filename: "sahte.docx", data: fx("sahte.docx") })),
    ).rejects.toBeInstanceOf(UploadError);
    const r = await withUser(u.id, (tx) =>
      saveUploadedSource(tx, u.id, { courseId, topicId: null, title: "", kind: "diger", filename: "bozuk.pdf", data: fx("bozuk.pdf") }),
    );
    expect(r.status).toBe("hata");
  });
});

describe("Test C / D / E / F — çalışma oturumu, cevaplar, yanlışlar, tekrar", () => {
  it("oturum ve cevaplar kalıcıdır; yanlış cevap yanlışlar defterine ve tekrar listesine girer", async () => {
    const u = await newUser();
    const { courseId, topicId, sourceId } = await setupCourseWithPdf(u.id);
    const sessionId = await withUser(u.id, (tx) =>
      startStudySession(tx, u.id, { courseId, topicId, mode: "aktif_hatirlama", goal: "Vizeye hazırlık", sourceIds: [sourceId], onlySelected: true }),
    );
    const qid = await withUser(u.id, (tx) =>
      createQuestion(tx, u.id, {
        courseId, topicId, type: "kisa_cevap", prompt: "Chapel Hill araştırmasını kimler yürütmüştür?",
        answer: { accepted: ["McCombs ve Shaw"] }, concept: "Gündem belirleme kuramının kökeni", origin: "kullanici",
      }),
    );
    const wrong = await withUser(u.id, (tx) => submitAnswer(tx, u.id, { questionId: qid, sessionId, response: { text: "Lazarsfeld" } }));
    expect(wrong).toMatchObject({ graded: true, isCorrect: false });

    // "Çıkış yapıp yeniden giriş" — yeni bağlantı ve yeni oturum belirteciyle okuma
    await closePool();
    const again = await authenticate(u.email, u.password);
    await withUser(again, async (tx) => {
      const s = await getStudySession(tx, sessionId);
      expect(s).toMatchObject({ goal: "Vizeye hazırlık", source_ids: [sourceId], status: "aktif" });
      const atts = await listAttempts(tx, { sessionId });
      expect(atts).toHaveLength(1);
      expect(atts[0]).toMatchObject({ question_id: qid, is_correct: false, response: { text: "Lazarsfeld" } });
      const mistakes = await listMistakes(tx);
      expect(mistakes.map((m) => m.concept)).toEqual(["Gündem belirleme kuramının kökeni"]);
      expect(await listDueCards(tx, new Date(Date.now() + 86400_000 + 60_000))).toHaveLength(1);
      expect(await listDueCards(tx, new Date())).toHaveLength(0);
      expect((await listTopics(tx, courseId))[0].status).toBe("tekrar_gerekiyor");
      const dash = await loadDashboard(tx, new Date(Date.now() + 3 * 86400_000));
      expect(dash.totalDue).toBe(1);
    });

    const right = await withUser(u.id, (tx) => submitAnswer(tx, u.id, { questionId: qid, sessionId, response: { text: "mccombs ve shaw" } }));
    expect(right.isCorrect).toBe(true);
    expect(await withUser(u.id, (tx) => listMistakes(tx, "acik"))).toHaveLength(0);
  });

  it("açık uçlu cevap öz değerlendirme ile sonuçlanır", async () => {
    const u = await newUser();
    const { courseId, topicId } = await setupCourseWithPdf(u.id);
    const qid = await withUser(u.id, (tx) =>
      createQuestion(tx, u.id, { courseId, topicId, type: "acik_uclu", prompt: "Gündem belirlemeyi örnekle açıklayın.", rubric: "Tanım + örnek", origin: "kullanici" }),
    );
    const a = await withUser(u.id, (tx) => submitAnswer(tx, u.id, { questionId: qid, sessionId: null, response: { text: "Medya neyi düşüneceğimizi..." } }));
    expect(a.graded).toBe(false);
    const f = await withUser(u.id, (tx) => finalizeAttempt(tx, u.id, a.attemptId, { method: "oz_degerlendirme", score: 40, feedback: "Örnek eksik" }));
    expect(f.isCorrect).toBe(false);
    await expect(withUser(u.id, (tx) => finalizeAttempt(tx, u.id, a.attemptId, { method: "oz_degerlendirme", score: 90, feedback: "" }))).rejects.toThrow("zaten");
  });
});

describe("Test G — kullanıcılar arası veri izolasyonu (RLS)", () => {
  it("başka kullanıcı özel verileri göremez, değiştiremez, silemez", async () => {
    const a = await newUser("Kullanıcı A");
    const b = await newUser("Kullanıcı B");
    const { courseId, sourceId } = await setupCourseWithPdf(a.id);
    await withUser(b.id, async (tx) => {
      expect((await listCourses(tx)).some((c) => c.id === courseId)).toBe(false);
      expect(await getSourceFile(tx, sourceId)).toBeNull();
      expect(await searchChunks(tx, "çerçeveleme")).toHaveLength(0);
      const upd = await tx.query("UPDATE courses SET name='ele geçirildi' WHERE id=$1", [courseId]);
      expect(upd.rowCount).toBe(0);
      const del = await tx.query("DELETE FROM sources WHERE id=$1", [sourceId]);
      expect(del.rowCount).toBe(0);
      await expect(createTopic(tx, b.id, courseId, { title: "x", week: 1 })).rejects.toThrow("Ders bulunamadı");
    });
    // Başka kullanıcı adına satır eklenemez (WITH CHECK)
    await expect(
      withUser(b.id, (tx) => tx.query("INSERT INTO courses (user_id, code, name) VALUES ($1,'X','Y')", [a.id])),
    ).rejects.toThrow(/row-level security/);
    // Kullanıcı bağlamı olmadan hiçbir satır görünmez
    const { rows } = await getPool().query("SELECT count(*)::int AS n FROM courses");
    expect(rows[0].n).toBe(0);
    expect((await withUser(a.id, (tx) => listCourses(tx))).find((c) => c.id === courseId)!.name).toBe("Siyasal İletişim");
  });
  it("uygulama rolü RLS'yi atlayamaz", async () => {
    const { rows } = await getPool().query("SELECT rolsuper, rolbypassrls FROM pg_roles WHERE rolname = current_user");
    expect(rows[0]).toEqual({ rolsuper: false, rolbypassrls: false });
  });
});

describe("Test H — yapay zekâ bağlantısı kesilince veri kaybı olmaz", () => {
  it("öğrenci mesajı kaydedilir, hata yanıtı uydurulmaz", async () => {
    const u = await newUser();
    const { courseId, topicId, sourceId } = await setupCourseWithPdf(u.id);
    const sid = await withUser(u.id, (tx) =>
      startStudySession(tx, u.id, { courseId, topicId, mode: "konu_anlatimi", goal: "", sourceIds: [sourceId], onlySelected: true }),
    );
    await saveStudentMessage(u.id, sid, "Bana gündem belirlemeyi öğret.");
    const down = scriptedProvider(() => { throw new AIRequestError("Yapay zekâ hizmetine bağlanılamadı."); });
    await expect(generateTutorReply(u.id, sid, down)).rejects.toThrow("bağlanılamadı");
    const msgs = await withUser(u.id, (tx) => listMessages(tx, sid));
    expect(msgs.map((m) => m.role)).toEqual(["ogrenci"]);
    expect(msgs[0].content).toBe("Bana gündem belirlemeyi öğret.");
  });
  it("bağlantı varken yanıt, kaynak bağlamı ve doğrulanmış atıflarla kaydedilir", async () => {
    const u = await newUser();
    const { courseId, topicId, sourceId } = await setupCourseWithPdf(u.id);
    const sid = await withUser(u.id, (tx) =>
      startStudySession(tx, u.id, { courseId, topicId, mode: "konu_anlatimi", goal: "", sourceIds: [sourceId], onlySelected: true }),
    );
    await saveStudentMessage(u.id, sid, "Çerçeveleme nedir?");
    const p = scriptedProvider("Çerçeveleme, öne çıkarılan yönlerin seçimidir [K2]. Uydurma atıf [K7].");
    const r = await generateTutorReply(u.id, sid, p);
    expect(p.calls[0].system).toContain("YALNIZCA verilen kaynaklara dayan");
    expect(JSON.stringify(p.calls[0].messages)).toContain('konum=\\"Sayfa 2\\"');
    expect(r.citations.map((c) => c.locator)).toEqual(["Sayfa 2"]);
    const msgs = await withUser(u.id, (tx) => listMessages(tx, sid));
    expect(msgs.map((m) => m.role)).toEqual(["ogrenci", "ogretmen"]);
    expect(msgs[1].citations[0]).toMatchObject({ sourceId, locator: "Sayfa 2" });
  });
  it("üretilen sorular doğrulanır; geçersiz cevap anahtarlı sorular kaydedilmez", async () => {
    const u = await newUser();
    const { courseId, topicId, sourceId } = await setupCourseWithPdf(u.id);
    const p = scriptedProvider(JSON.stringify([
      { type: "coktan_secmeli", prompt: "Chapel Hill hangi yıl?", options: ["1968", "1972"], answer: { index: 0 }, ref: "K1" },
      { type: "coktan_secmeli", prompt: "Geçersiz anahtar", options: ["a", "b"], answer: { index: 5 } },
      { type: "acik_uclu", prompt: "Çerçevelemeyi tartışın.", rubric: "Tanım ve örnek" },
    ]));
    expect(await generateQuestions(u.id, { courseId, topicId, sourceIds: [sourceId], count: 3 }, p)).toEqual({ saved: 2, rejected: 1 });
    const qs = await withUser(u.id, (tx) => tx.query("SELECT origin, source_id FROM questions ORDER BY created_at"));
    expect(qs.rows.every((r) => r.origin === "yapay_zeka")).toBe(true);
    expect(qs.rows[0].source_id).toBe(sourceId);
  });
  it("açık uçlu cevap yapay zekâ ile puanlanır", async () => {
    const u = await newUser();
    const { courseId, topicId } = await setupCourseWithPdf(u.id);
    const qid = await withUser(u.id, (tx) =>
      createQuestion(tx, u.id, { courseId, topicId, type: "acik_uclu", prompt: "Çerçeveleme nedir?", rubric: "Tanım", origin: "kullanici" }),
    );
    const a = await withUser(u.id, (tx) => submitAnswer(tx, u.id, { questionId: qid, sessionId: null, response: { text: "Seçme" } }));
    const res = await gradeAttemptWithAI(u.id, a.attemptId, scriptedProvider('{"score": 45, "feedback": "Tanım eksik.", "missing_concepts": ["öne çıkarma"]}'));
    expect(res).toEqual({ isCorrect: false, score: 45 });
    const m = await withUser(u.id, (tx) => listMistakes(tx));
    expect(m).toHaveLength(1);
  });
});

describe("Test J — yedekleme ve geri yükleme", () => {
  it("yedek başka hesaba eksiksiz geri yüklenir; dosyalar ve ilişkiler korunur", async () => {
    const a = await newUser();
    const { courseId, topicId, sourceId } = await setupCourseWithPdf(a.id);
    const sid = await withUser(a.id, (tx) =>
      startStudySession(tx, a.id, { courseId, topicId, mode: "okuma", goal: "", sourceIds: [sourceId], onlySelected: true }),
    );
    const qid = await withUser(a.id, (tx) =>
      createQuestion(tx, a.id, { courseId, topicId, type: "dogru_yanlis", prompt: "Çerçeveleme bir seçimdir.", answer: { value: true }, origin: "kullanici" }),
    );
    await withUser(a.id, (tx) => submitAnswer(tx, a.id, { questionId: qid, sessionId: sid, response: { value: false } }));
    const backup = JSON.parse(JSON.stringify(await withUser(a.id, exportBackup)));

    const b = await newUser();
    const counts = await withUser(b.id, (tx) => restoreBackup(tx, b.id, backup));
    expect(counts).toMatchObject({ courses: 9, sources: 1, source_files: 1, attempts: 1, mistakes: 1, review_cards: 1 });
    await withUser(b.id, async (tx) => {
      const src = (await listSources(tx))[0];
      expect(src.id).not.toBe(sourceId);
      expect((await getSourceFile(tx, src.id))!.equals(fx("siyasal-iletisim-hafta3.pdf"))).toBe(true);
      const s = (await tx.query("SELECT source_ids FROM study_sessions")).rows[0];
      expect(s.source_ids).toEqual([src.id]);
      expect((await searchChunks(tx, "çerçeveleme")).length).toBeGreaterThan(0);
      expect((await listMistakes(tx))[0].prompt).toBe("Çerçeveleme bir seçimdir.");
    });
    // A'nın verisi etkilenmez
    expect(await withUser(a.id, (tx) => listSources(tx))).toHaveLength(1);
  });
  it("bozuk yedek reddedilir ve mevcut veri korunur", async () => {
    const u = await newUser();
    await expect(withUser(u.id, (tx) => restoreBackup(tx, u.id, { format: "academicos-yedek", version: 1, data: { courses: [{ id: "x", code: "A", name: "B", delivery: "yuz_yuze", notes: "", created_at: new Date().toISOString() }], course_meetings: [{ id: "m", course_id: "olmayan", weekday: 1, start_time: "08:00", end_time: "09:00" }] } }))).rejects.toThrow("tutarsız");
    expect(await withUser(u.id, listCourses)).toHaveLength(9);
  });
});
