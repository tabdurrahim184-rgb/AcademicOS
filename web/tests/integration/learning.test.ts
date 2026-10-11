import { readFileSync } from "node:fs";
import path from "node:path";
import { afterAll, describe, expect, it } from "vitest";
import { newUser } from "./helpers";
import { closePool, withUser } from "@/lib/db";
import { createTopic, listCourses } from "@/lib/data/courses";
import { createObjective, listObjectives, loadTopicProgress } from "@/lib/data/objectives";
import { loadSourceAudit, saveUploadedSource, updateSource } from "@/lib/data/sources";
import { createQuestion, listMistakes, submitAnswer } from "@/lib/data/study";

afterAll(closePool);
const fx = (f: string) => readFileSync(path.join(__dirname, "..", "fixtures", f));

async function setup() {
  const u = await newUser();
  const ids = await withUser(u.id, async (tx) => {
    const c = (await listCourses(tx)).find((x) => x.code === "İLF431")!;
    const topicId = await createTopic(tx, u.id, c.id, { title: "Gündem belirleme", week: 3 });
    await createObjective(tx, u.id, topicId, "Gündem belirleme kuramının kökenini açıklayabilirim.");
    const [obj] = await listObjectives(tx, { topicId });
    const q1 = await createQuestion(tx, u.id, {
      courseId: c.id, topicId, objectiveId: obj.id, type: "dogru_yanlis", prompt: "Chapel Hill araştırması 1968'dedir.",
      answer: { value: true }, concept: "Kuramın kökeni", origin: "kullanici",
    });
    const q2 = await createQuestion(tx, u.id, {
      courseId: c.id, topicId, objectiveId: obj.id, type: "kisa_cevap", prompt: "Araştırmacılar kimlerdir?",
      answer: { accepted: ["McCombs ve Shaw"] }, concept: "Kuramın kökeni", origin: "kullanici",
    });
    return { courseId: c.id, topicId, objectiveId: obj.id, q1, q2 };
  });
  return { u, ...ids };
}

const card = (userId: string, qid: string) =>
  withUser(userId, async (tx) => (await tx.query("SELECT interval_days, ease::float, repetitions FROM review_cards WHERE question_id=$1", [qid])).rows[0]);

describe("Öğrenme hedefleri ve ustalık", () => {
  it("hedef ustalığı en son cevaplardan hesaplanır; tahminle doğru 'öğrenildi' sayılmaz", async () => {
    const s = await setup();
    let p = await withUser(s.u.id, (tx) => loadTopicProgress(tx, s.topicId));
    expect(p.objectives[0]).toMatchObject({ level: "kanit_yok", total: 2, answered: 0 });
    expect(p.steps.find((x) => x.key === "hedef")!.done).toBe(true);
    expect(p.steps.find((x) => !x.done)!.key).toBe("materyal");

    await withUser(s.u.id, (tx) => submitAnswer(tx, s.u.id, { questionId: s.q1, sessionId: null, response: { value: true }, confidence: "tahmin" }));
    await withUser(s.u.id, (tx) => submitAnswer(tx, s.u.id, { questionId: s.q2, sessionId: null, response: { text: "McCombs ve Shaw" }, confidence: "emin" }));
    p = await withUser(s.u.id, (tx) => loadTopicProgress(tx, s.topicId));
    expect(p.objectives[0].level).toBe("gelisiyor");

    await withUser(s.u.id, (tx) => submitAnswer(tx, s.u.id, { questionId: s.q1, sessionId: null, response: { value: true }, confidence: "emin" }));
    p = await withUser(s.u.id, (tx) => loadTopicProgress(tx, s.topicId));
    expect(p.objectives[0].level).toBe("ogrenildi");
    expect(p.overall.accuracy).toBe(1);
    expect(p.concepts[0]).toMatchObject({ concept: "Kuramın kökeni", answered: 2, correct: 2 });
    expect(p.steps.find((x) => x.key === "dogrula")!.done).toBe(true);
  });

  it("hedef başka konuya ait soruya bağlanamaz", async () => {
    const s = await setup();
    await expect(
      withUser(s.u.id, async (tx) => {
        const other = await createTopic(tx, s.u.id, s.courseId, { title: "Çerçeveleme", week: 4 });
        await createQuestion(tx, s.u.id, { courseId: s.courseId, topicId: other, objectiveId: s.objectiveId, type: "dogru_yanlis", prompt: "x y z", answer: { value: true }, origin: "kullanici" });
      }),
    ).rejects.toThrow("hedefi seçilen konuya ait değil");
  });
});

describe("Eminlik bilgisi tekrar aralığını kişiselleştirir", () => {
  it("emin doğru > kısmen doğru > tahmin doğru; emin yanlış kavram yanılgısı olarak işaretlenir", async () => {
    const results: Record<string, number> = {};
    for (const conf of ["emin", "kismen", "tahmin"] as const) {
      const s = await setup();
      await withUser(s.u.id, (tx) => submitAnswer(tx, s.u.id, { questionId: s.q1, sessionId: null, response: { value: true }, confidence: conf }));
      await withUser(s.u.id, (tx) => submitAnswer(tx, s.u.id, { questionId: s.q1, sessionId: null, response: { value: true }, confidence: conf }));
      await withUser(s.u.id, (tx) => submitAnswer(tx, s.u.id, { questionId: s.q1, sessionId: null, response: { value: true }, confidence: conf }));
      results[conf] = (await card(s.u.id, s.q1)).interval_days;
    }
    expect(results.emin).toBeGreaterThan(results.kismen);
    expect(results.kismen).toBeGreaterThan(results.tahmin);

    const s = await setup();
    await withUser(s.u.id, (tx) => submitAnswer(tx, s.u.id, { questionId: s.q1, sessionId: null, response: { value: false }, confidence: "emin" }));
    const m = await withUser(s.u.id, (tx) => listMistakes(tx));
    expect(m[0].misconception).toBe(true);
    expect((await card(s.u.id, s.q1)).ease).toBeCloseTo(1.7, 5); // kalite 0: 2.5 → 1.7
    await withUser(s.u.id, (tx) => submitAnswer(tx, s.u.id, { questionId: s.q2, sessionId: null, response: { text: "bilmiyorum" }, confidence: "tahmin" }));
    expect((await withUser(s.u.id, (tx) => listMistakes(tx))).find((x) => x.question_id === s.q2)!.misconception).toBe(false);
  });
});

describe("Kaynak denetimi ve düzeltme", () => {
  it("yinelenen ve konuyla ilgisiz görünen kaynakları raporlar; konu düzeltilebilir", async () => {
    const s = await setup();
    const { other, a, b } = await withUser(s.u.id, async (tx) => {
      const other = await createTopic(tx, s.u.id, s.courseId, { title: "Futbol yayıncılığı", week: 5 });
      const a = await saveUploadedSource(tx, s.u.id, { courseId: s.courseId, topicId: s.topicId, title: "Hafta 3", kind: "hoca", filename: "siyasal-iletisim-hafta3.pdf", data: fx("siyasal-iletisim-hafta3.pdf") });
      const b = await saveUploadedSource(tx, s.u.id, { courseId: s.courseId, topicId: other, title: "Yanlış yere", kind: "hoca", filename: "kopya.pdf", data: fx("siyasal-iletisim-hafta3.pdf") });
      return { other, a, b };
    });
    let issues = await withUser(s.u.id, (tx) => loadSourceAudit(tx, s.courseId));
    expect(issues.filter((i) => i.message.includes("Aynı dosya"))).toHaveLength(2);
    expect(issues.find((i) => i.sourceId === b.id && i.message.includes("hiç geçmiyor"))).toBeDefined();
    expect(issues.find((i) => i.sourceId === a.id && i.message.includes("hiç geçmiyor"))).toBeUndefined();

    await withUser(s.u.id, (tx) => updateSource(tx, b.id, { title: "Hafta 3 (kopya)", kind: "arkadas", topicId: s.topicId }));
    issues = await withUser(s.u.id, (tx) => loadSourceAudit(tx, s.courseId));
    expect(issues.find((i) => i.sourceId === b.id && i.message.includes("hiç geçmiyor"))).toBeUndefined();
    void other;

    // Başka dersin konusuna bağlanamaz
    const foreignTopic = await withUser(s.u.id, async (tx) => {
      const c413 = (await listCourses(tx)).find((x) => x.code === "İLF413")!;
      return createTopic(tx, s.u.id, c413.id, { title: "Etik", week: 1 });
    });
    await expect(withUser(s.u.id, (tx) => updateSource(tx, b.id, { title: "x", kind: "hoca", topicId: foreignTopic }))).rejects.toThrow("dersine ait değil");
  });
});
