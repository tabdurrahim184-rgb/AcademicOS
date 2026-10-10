/**
 * Yapay zekâ öğretmeni iş akışları. Öğrencinin mesajı yapay zekâ çağrısından
 * ÖNCE ayrı bir işlemde kaydedilir; bağlantı kesilse bile kaybolmaz.
 */
import { withUser } from "../db";
import { getCourse, getTopic } from "../data/courses";
import { selectContext } from "../data/sources";
import {
  addMessage,
  createQuestion,
  finalizeAttempt,
  getQuestion,
  getStudySession,
  listMessages,
  listMistakes,
  validateQuestion,
  type QuestionInput,
} from "../data/study";
import { isObjective } from "../grading";
import type { AIProvider } from "./provider";
import {
  buildTutorSystem,
  extractCitations,
  formatContext,
  GRADING_SYSTEM,
  parseGeneratedQuestions,
  parseGrade,
  QUESTION_GEN_SYSTEM,
  toChatTurns,
} from "./prompts";

export async function saveStudentMessage(userId: string, sessionId: string, text: string) {
  const content = text.trim().slice(0, 8000);
  if (!content) throw new Error("Mesaj boş olamaz.");
  await withUser(userId, async (tx) => {
    const s = await getStudySession(tx, sessionId);
    if (!s) throw new Error("Oturum bulunamadı.");
    await addMessage(tx, userId, sessionId, { role: "ogrenci", content });
  });
}

/** Oturumdaki son öğrenci mesajına öğretmen yanıtı üretir ve kaydeder. */
export async function generateTutorReply(userId: string, sessionId: string, provider: AIProvider) {
  const prep = await withUser(userId, async (tx) => {
    const s = await getStudySession(tx, sessionId);
    if (!s) throw new Error("Oturum bulunamadı.");
    const course = (await getCourse(tx, s.course_id))!;
    const topic = s.topic_id ? await getTopic(tx, s.topic_id) : null;
    const history = await listMessages(tx, sessionId);
    const lastStudent = [...history].reverse().find((m) => m.role === "ogrenci")?.content ?? "";
    const query = [topic?.title ?? "", lastStudent].join(" ");
    const chunks = await selectContext(tx, s.source_ids, query);
    const mistakes =
      s.mode === "eksik_tamamlama"
        ? (await listMistakes(tx, "acik")).filter((m) => m.course_id === s.course_id).map((m) => `${m.prompt} → ${m.feedback || "yanlış"}`)
        : [];
    return { s, course, topic, history, chunks, mistakes };
  });
  const system = buildTutorSystem({
    mode: prep.s.mode,
    courseLabel: `${prep.course.code} ${prep.course.name}`,
    topicTitle: prep.topic?.title ?? null,
    goal: prep.s.goal,
    onlySources: prep.s.only_selected_sources,
    hasSources: prep.chunks.length > 0,
    mistakes: prep.mistakes,
  });
  const turns = toChatTurns(prep.history, formatContext(prep.chunks));
  if (!turns.length) throw new Error("Yanıtlanacak öğrenci mesajı yok.");
  const res = await provider.complete({ system, messages: turns, effort: "medium" });
  const citations = extractCitations(res.text, prep.chunks);
  await withUser(userId, (tx) =>
    addMessage(tx, userId, sessionId, { role: "ogretmen", content: res.text, citations, provider: res.provider, model: res.model }),
  );
  return { text: res.text, citations };
}

/** Seçili kaynaklardan yapay zekâ ile soru üretir; doğrulamayı geçemeyen sorular kaydedilmez. */
export async function generateQuestions(
  userId: string,
  input: { courseId: string; topicId: string | null; sourceIds: string[]; count: number },
  provider: AIProvider,
) {
  const prep = await withUser(userId, async (tx) => {
    const course = await getCourse(tx, input.courseId);
    if (!course) throw new Error("Ders bulunamadı.");
    const topic = input.topicId ? await getTopic(tx, input.topicId) : null;
    const chunks = await selectContext(tx, input.sourceIds, topic?.title ?? "", 20000);
    return { course, topic, chunks };
  });
  if (!prep.chunks.length) throw new Error("Soru üretmek için metni çıkarılmış en az bir kaynak seçin.");
  const count = Math.max(1, Math.min(10, input.count));
  const res = await provider.complete({
    system: QUESTION_GEN_SYSTEM,
    messages: [
      {
        role: "user",
        content: `${formatContext(prep.chunks)}\n\nDers: ${prep.course.code} ${prep.course.name}${prep.topic ? `, konu: ${prep.topic.title}` : ""}.\n${count} adet, farklı türlerde soru hazırla (en az biri açık uçlu olsun).`,
      },
    ],
    effort: "medium",
  });
  const generated = parseGeneratedQuestions(res.text);
  let saved = 0;
  let rejected = 0;
  await withUser(userId, async (tx) => {
    for (const g of generated) {
      const refN = g.ref ? Number(g.ref.replace(/\D/g, "")) : NaN;
      const sourceId = refN >= 1 && refN <= prep.chunks.length ? prep.chunks[refN - 1].source_id : null;
      const q: QuestionInput = {
        courseId: input.courseId,
        topicId: input.topicId,
        sourceId,
        type: g.type,
        prompt: g.prompt,
        options: g.options,
        answer: g.answer,
        rubric: g.rubric,
        explanation: g.explanation,
        concept: g.concept,
        origin: "yapay_zeka",
      };
      try {
        validateQuestion(q);
        await createQuestion(tx, userId, q);
        saved++;
      } catch {
        rejected++;
      }
    }
  });
  return { saved, rejected };
}

/** Bekleyen açık uçlu bir cevabı yapay zekâ ile değerlendirir. */
export async function gradeAttemptWithAI(userId: string, attemptId: string, provider: AIProvider) {
  const prep = await withUser(userId, async (tx) => {
    const { rows } = await tx.query<{ question_id: string; response: { text?: string }; grading_method: string }>(
      "SELECT question_id, response, grading_method FROM attempts WHERE id = $1",
      [attemptId],
    );
    const att = rows[0];
    if (!att) throw new Error("Cevap kaydı bulunamadı.");
    if (att.grading_method !== "bekliyor") throw new Error("Bu cevap zaten değerlendirilmiş.");
    const q = (await getQuestion(tx, att.question_id))!;
    if (isObjective(q.type)) throw new Error("Nesnel sorular otomatik değerlendirilir.");
    const chunks = q.source_id ? await selectContext(tx, [q.source_id], q.concept || q.prompt, 12000) : [];
    return { q, answer: String(att.response?.text ?? ""), chunks };
  });
  const res = await provider.complete({
    system: GRADING_SYSTEM,
    messages: [
      {
        role: "user",
        content: `${formatContext(prep.chunks)}\n\nSoru: ${prep.q.prompt}\nDeğerlendirme ölçütü: ${prep.q.rubric || "(belirtilmedi)"}\nÖrnek/beklenen cevap: ${prep.q.explanation || "(belirtilmedi)"}\n\nÖğrencinin cevabı:\n"""${prep.answer}"""`,
      },
    ],
    effort: "medium",
  });
  const grade = parseGrade(res.text);
  const feedback = grade.missing_concepts?.length
    ? `${grade.feedback}\n\nEksik kavramlar: ${grade.missing_concepts.join(", ")}`
    : grade.feedback;
  return withUser(userId, (tx) => finalizeAttempt(tx, userId, attemptId, { method: "yapay_zeka", score: grade.score, feedback }));
}
