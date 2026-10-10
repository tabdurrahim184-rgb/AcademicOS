import type { Tx } from "../db";
import { gradeObjective, isObjective, type QuestionType, QUESTION_TYPES } from "../grading";
import { NEW_CARD, nextDueDate, qualityFromResult, sm2 } from "../sm2";
import { advanceTopicStatus, getCourse, getTopic, isUuid, markPlanStale, setTopicStatus } from "./courses";

export const STUDY_MODES = {
  konu_anlatimi: { label: "Konu anlatımı", ai: true, hint: "Kavramlar, tanımlar, neden-sonuç ilişkileri ve örneklerle anlatım." },
  sokratik: { label: "Sokratik öğrenme", ai: true, hint: "Düşündürücü sorularla adım adım ilerleme." },
  sinav_hazirligi: { label: "Sınav hazırlığı", ai: true, hint: "Konuya uygun farklı türde sorular." },
  aktif_hatirlama: { label: "Aktif hatırlama", ai: false, hint: "Notlara bakmadan soruları cevapla." },
  derinlemesine: { label: "Derinlemesine öğrenme", ai: true, hint: "Tarihsel, toplumsal, felsefi ve mesleki bağlam." },
  gazetecilik: { label: "Gazetecilik uygulaması", ai: true, hint: "Teoriyi haber yazımı ve medya örnekleriyle ilişkilendirme." },
  tartisma: { label: "Tartışma provası", ai: true, hint: "Akademik tartışma ve akıl yürütme hatalarının tespiti." },
  eksik_tamamlama: { label: "Eksik tamamlama", ai: true, hint: "Önceki yanlışlara göre konuyu yeniden öğrenme." },
  hizli_tekrar: { label: "Hızlı tekrar", ai: false, hint: "Zamanı gelen kartlarla kısa hatırlama oturumu." },
  okuma: { label: "Kaynak okuma", ai: false, hint: "Seçili kaynakları oku, not çıkar, soru hazırla." },
} as const;
export type StudyMode = keyof typeof STUDY_MODES;

export type StudySession = {
  id: string;
  course_id: string;
  topic_id: string | null;
  mode: StudyMode;
  goal: string;
  source_ids: string[];
  only_selected_sources: boolean;
  status: "aktif" | "tamamlandi";
  started_at: Date;
  last_activity_at: Date;
  ended_at: Date | null;
};

export type SessionMessage = {
  id: string;
  role: "ogrenci" | "ogretmen" | "sistem";
  content: string;
  citations: Array<{ ref: string; sourceId: string; title: string; locator: string }>;
  provider: string | null;
  model: string | null;
  created_at: Date;
};

const SESSION_COLS = "id, course_id, topic_id, mode, goal, source_ids, only_selected_sources, status, started_at, last_activity_at, ended_at";

export async function startStudySession(
  tx: Tx,
  userId: string,
  input: { courseId: string; topicId: string | null; mode: StudyMode; goal: string; sourceIds: string[]; onlySelected: boolean },
): Promise<string> {
  if (!(input.mode in STUDY_MODES)) throw new Error("Geçersiz çalışma modu.");
  if (!(await getCourse(tx, input.courseId))) throw new Error("Ders bulunamadı.");
  if (input.topicId) {
    const t = await getTopic(tx, input.topicId);
    if (!t || t.course_id !== input.courseId) throw new Error("Konu bu derse ait değil.");
  }
  const ids = input.sourceIds.filter(isUuid);
  const { rows: valid } = await tx.query<{ id: string }>(
    "SELECT id FROM sources WHERE id = ANY($1::uuid[]) AND course_id = $2",
    [ids, input.courseId],
  );
  const { rows } = await tx.query<{ id: string }>(
    `INSERT INTO study_sessions (user_id, course_id, topic_id, mode, goal, source_ids, only_selected_sources)
     VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING id`,
    [userId, input.courseId, input.topicId, input.mode, input.goal.slice(0, 500), valid.map((v) => v.id), input.onlySelected],
  );
  return rows[0].id;
}

export async function getStudySession(tx: Tx, id: string): Promise<StudySession | null> {
  if (!isUuid(id)) return null;
  const { rows } = await tx.query<StudySession>(`SELECT ${SESSION_COLS} FROM study_sessions WHERE id = $1`, [id]);
  return rows[0] ?? null;
}

export async function listStudySessions(tx: Tx, limit = 20, courseId?: string): Promise<StudySession[]> {
  const { rows } = await tx.query<StudySession>(
    `SELECT ${SESSION_COLS} FROM study_sessions ${courseId ? "WHERE course_id = $2" : ""}
     ORDER BY last_activity_at DESC LIMIT $1`,
    courseId ? [limit, courseId] : [limit],
  );
  return rows;
}

export async function updateSessionSources(tx: Tx, sessionId: string, sourceIds: string[], onlySelected: boolean) {
  const s = await getStudySession(tx, sessionId);
  if (!s) throw new Error("Oturum bulunamadı.");
  const { rows: valid } = await tx.query<{ id: string }>(
    "SELECT id FROM sources WHERE id = ANY($1::uuid[]) AND course_id = $2",
    [sourceIds.filter(isUuid), s.course_id],
  );
  await tx.query(
    "UPDATE study_sessions SET source_ids=$2, only_selected_sources=$3, last_activity_at=now() WHERE id=$1",
    [sessionId, valid.map((v) => v.id), onlySelected],
  );
}

export async function endStudySession(tx: Tx, id: string) {
  await tx.query("UPDATE study_sessions SET status='tamamlandi', ended_at=now(), last_activity_at=now() WHERE id=$1", [id]);
}

export async function addMessage(
  tx: Tx,
  userId: string,
  sessionId: string,
  msg: { role: SessionMessage["role"]; content: string; citations?: SessionMessage["citations"]; provider?: string; model?: string },
) {
  await tx.query(
    `INSERT INTO session_messages (user_id, session_id, role, content, citations, provider, model)
     VALUES ($1,$2,$3,$4,$5,$6,$7)`,
    [userId, sessionId, msg.role, msg.content, JSON.stringify(msg.citations ?? []), msg.provider ?? null, msg.model ?? null],
  );
  await tx.query("UPDATE study_sessions SET last_activity_at = now() WHERE id = $1", [sessionId]);
}

export async function listMessages(tx: Tx, sessionId: string): Promise<SessionMessage[]> {
  const { rows } = await tx.query<SessionMessage>(
    "SELECT id, role, content, citations, provider, model, created_at FROM session_messages WHERE session_id = $1 ORDER BY created_at, id",
    [sessionId],
  );
  return rows;
}

// ---------------------------------------------------------------- Sorular

export type Question = {
  id: string;
  course_id: string;
  topic_id: string | null;
  source_id: string | null;
  type: QuestionType;
  prompt: string;
  options: string[];
  answer: unknown;
  rubric: string;
  explanation: string;
  concept: string;
  origin: "kullanici" | "yapay_zeka" | "ogretim_elemani";
  created_at: Date;
};
const Q_COLS = "id, course_id, topic_id, source_id, type, prompt, options, answer, rubric, explanation, concept, origin, created_at";

export type QuestionInput = {
  courseId: string;
  topicId: string | null;
  sourceId?: string | null;
  type: QuestionType;
  prompt: string;
  options?: string[];
  answer?: unknown;
  rubric?: string;
  explanation?: string;
  concept?: string;
  origin: Question["origin"];
};

/** Soru girişini doğrular; hatalı cevap anahtarlarını kaydetmez. */
export function validateQuestion(q: QuestionInput) {
  if (!(q.type in QUESTION_TYPES)) throw new Error("Geçersiz soru türü.");
  if (q.prompt.trim().length < 3) throw new Error("Soru metni çok kısa.");
  const a = (q.answer ?? null) as Record<string, unknown> | null;
  switch (q.type) {
    case "coktan_secmeli": {
      const opts = (q.options ?? []).filter((o) => o.trim());
      if (opts.length < 2) throw new Error("Çoktan seçmeli soruda en az iki seçenek olmalı.");
      if (!a || !Number.isInteger(a.index) || (a.index as number) < 0 || (a.index as number) >= opts.length)
        throw new Error("Doğru seçenek belirtilmeli.");
      break;
    }
    case "dogru_yanlis":
      if (!a || typeof a.value !== "boolean") throw new Error("Doğru/yanlış cevabı belirtilmeli.");
      break;
    case "kisa_cevap":
    case "bosluk_doldurma":
      if (!a || !Array.isArray(a.accepted) || !(a.accepted as string[]).some((s) => s.trim()))
        throw new Error("En az bir kabul edilen cevap girilmeli.");
      break;
    case "eslestirme": {
      const pairs = a?.pairs as number[] | undefined;
      if (!pairs || pairs.length < 2 || (q.options ?? []).length !== pairs.length)
        throw new Error("Eşleştirme sorusunda sol ve sağ sütun aynı sayıda olmalı.");
      break;
    }
    default:
      if (!q.rubric?.trim() && !q.explanation?.trim())
        throw new Error("Açık uçlu sorular için değerlendirme ölçütü veya örnek cevap girilmeli.");
  }
}

export async function createQuestion(tx: Tx, userId: string, q: QuestionInput): Promise<string> {
  validateQuestion(q);
  if (!(await getCourse(tx, q.courseId))) throw new Error("Ders bulunamadı.");
  if (q.topicId) {
    const t = await getTopic(tx, q.topicId);
    if (!t || t.course_id !== q.courseId) throw new Error("Konu bu derse ait değil.");
  }
  const { rows } = await tx.query<{ id: string }>(
    `INSERT INTO questions (user_id, course_id, topic_id, source_id, type, prompt, options, answer, rubric, explanation, concept, origin)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12) RETURNING id`,
    [userId, q.courseId, q.topicId, q.sourceId ?? null, q.type, q.prompt.trim(), JSON.stringify(q.options ?? []),
      JSON.stringify(q.answer ?? null), q.rubric ?? "", q.explanation ?? "", q.concept ?? "", q.origin],
  );
  return rows[0].id;
}

export async function getQuestion(tx: Tx, id: string): Promise<Question | null> {
  if (!isUuid(id)) return null;
  const { rows } = await tx.query<Question>(`SELECT ${Q_COLS} FROM questions WHERE id = $1`, [id]);
  return rows[0] ?? null;
}

export async function listQuestions(tx: Tx, filter: { courseId?: string; topicId?: string | null } = {}): Promise<Question[]> {
  const where: string[] = [];
  const params: unknown[] = [];
  if (filter.courseId) where.push(`course_id = $${params.push(filter.courseId)}`);
  if (filter.topicId) where.push(`topic_id = $${params.push(filter.topicId)}`);
  const { rows } = await tx.query<Question>(
    `SELECT ${Q_COLS} FROM questions ${where.length ? "WHERE " + where.join(" AND ") : ""} ORDER BY created_at`,
    params,
  );
  return rows;
}

export async function deleteQuestion(tx: Tx, id: string) {
  await tx.query("DELETE FROM questions WHERE id = $1", [id]);
}

// ---------------------------------------------------------------- Denemeler

export type Attempt = {
  id: string;
  question_id: string;
  session_id: string | null;
  response: unknown;
  is_correct: boolean | null;
  score: string | null;
  grading_method: "otomatik" | "yapay_zeka" | "oz_degerlendirme" | "bekliyor";
  feedback: string;
  created_at: Date;
};

/**
 * Bir cevabı kaydeder. Nesnel türler hemen değerlendirilir; açık uçlu türler
 * "bekliyor" olarak kaydedilir ve sonra yapay zekâ veya öz değerlendirmeyle sonuçlanır.
 */
export async function submitAnswer(
  tx: Tx,
  userId: string,
  input: { questionId: string; sessionId: string | null; response: unknown },
): Promise<{ attemptId: string; graded: boolean; isCorrect: boolean | null; feedback: string }> {
  const q = await getQuestion(tx, input.questionId);
  if (!q) throw new Error("Soru bulunamadı.");
  if (input.sessionId) {
    const s = await getStudySession(tx, input.sessionId);
    if (!s) throw new Error("Oturum bulunamadı.");
  }
  if (isObjective(q.type)) {
    const g = gradeObjective(q.type, q.answer, input.response);
    const { rows } = await tx.query<{ id: string }>(
      `INSERT INTO attempts (user_id, question_id, session_id, response, is_correct, score, grading_method, feedback)
       VALUES ($1,$2,$3,$4,$5,$6,'otomatik',$7) RETURNING id`,
      [userId, q.id, input.sessionId, JSON.stringify(input.response), g.isCorrect, g.score, g.feedback],
    );
    await afterGrading(tx, userId, q, rows[0].id, g.isCorrect, g.score);
    if (input.sessionId) await tx.query("UPDATE study_sessions SET last_activity_at=now() WHERE id=$1", [input.sessionId]);
    return { attemptId: rows[0].id, graded: true, isCorrect: g.isCorrect, feedback: g.feedback };
  }
  const { rows } = await tx.query<{ id: string }>(
    `INSERT INTO attempts (user_id, question_id, session_id, response, grading_method)
     VALUES ($1,$2,$3,$4,'bekliyor') RETURNING id`,
    [userId, q.id, input.sessionId, JSON.stringify(input.response)],
  );
  if (input.sessionId) await tx.query("UPDATE study_sessions SET last_activity_at=now() WHERE id=$1", [input.sessionId]);
  return { attemptId: rows[0].id, graded: false, isCorrect: null, feedback: "" };
}

/** Bekleyen açık uçlu denemeyi sonuçlandırır (yapay zekâ veya öğrencinin öz değerlendirmesi). */
export async function finalizeAttempt(
  tx: Tx,
  userId: string,
  attemptId: string,
  result: { method: "yapay_zeka" | "oz_degerlendirme"; score: number; feedback: string },
) {
  const { rows } = await tx.query<Attempt>("SELECT * FROM attempts WHERE id = $1", [attemptId]);
  const att = rows[0];
  if (!att) throw new Error("Cevap kaydı bulunamadı.");
  if (att.grading_method !== "bekliyor") throw new Error("Bu cevap zaten değerlendirilmiş.");
  const score = Math.max(0, Math.min(100, Math.round(result.score)));
  const isCorrect = score >= 60;
  await tx.query("UPDATE attempts SET is_correct=$2, score=$3, grading_method=$4, feedback=$5 WHERE id=$1", [
    attemptId, isCorrect, score, result.method, result.feedback.slice(0, 5000),
  ]);
  const q = (await getQuestion(tx, att.question_id))!;
  await afterGrading(tx, userId, q, attemptId, isCorrect, score);
  return { isCorrect, score };
}

/** Yanlışlar defteri + aralıklı tekrar kartı + konu durumu güncellemesi. */
async function afterGrading(tx: Tx, userId: string, q: Question, attemptId: string, isCorrect: boolean, score: number) {
  if (!isCorrect) {
    await tx.query(
      "INSERT INTO mistakes (user_id, question_id, attempt_id, concept) VALUES ($1,$2,$3,$4)",
      [userId, q.id, attemptId, q.concept || q.prompt.slice(0, 120)],
    );
  } else {
    await tx.query("UPDATE mistakes SET status='cozuldu', resolved_at=now() WHERE question_id=$1 AND status='acik'", [q.id]);
  }
  // Kartın SM-2 durumunu güncelle (yoksa oluştur).
  const { rows } = await tx.query<{ id: string; ease: string; interval_days: number; repetitions: number; lapses: number }>(
    "SELECT id, ease, interval_days, repetitions, lapses FROM review_cards WHERE question_id = $1",
    [q.id],
  );
  const prev = rows[0]
    ? { ease: Number(rows[0].ease), intervalDays: rows[0].interval_days, repetitions: rows[0].repetitions, lapses: rows[0].lapses }
    : NEW_CARD;
  const quality = qualityFromResult(isCorrect, score);
  const next = sm2(prev, quality);
  const now = new Date();
  const due = nextDueDate(now, next.intervalDays);
  let cardId: string;
  if (rows[0]) {
    cardId = rows[0].id;
    await tx.query(
      "UPDATE review_cards SET ease=$2, interval_days=$3, repetitions=$4, lapses=$5, due_at=$6, last_reviewed_at=$7 WHERE id=$1",
      [cardId, next.ease, next.intervalDays, next.repetitions, next.lapses, due, now],
    );
  } else {
    const ins = await tx.query<{ id: string }>(
      `INSERT INTO review_cards (user_id, question_id, ease, interval_days, repetitions, lapses, due_at, last_reviewed_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING id`,
      [userId, q.id, next.ease, next.intervalDays, next.repetitions, next.lapses, due, now],
    );
    cardId = ins.rows[0].id;
  }
  await markPlanStale(tx);
  await tx.query("INSERT INTO review_log (user_id, card_id, quality, interval_days, ease) VALUES ($1,$2,$3,$4,$5)", [
    userId, cardId, quality, next.intervalDays, next.ease,
  ]);
  if (q.topic_id) {
    if (!isCorrect) await setTopicStatus(tx, q.topic_id, "tekrar_gerekiyor");
    else await advanceTopicStatus(tx, q.topic_id, "soru_calisildi");
  }
}

export async function listAttempts(tx: Tx, filter: { sessionId?: string; questionId?: string }): Promise<Attempt[]> {
  const where: string[] = [];
  const params: unknown[] = [];
  if (filter.sessionId) where.push(`session_id = $${params.push(filter.sessionId)}`);
  if (filter.questionId) where.push(`question_id = $${params.push(filter.questionId)}`);
  const { rows } = await tx.query<Attempt>(
    `SELECT id, question_id, session_id, response, is_correct, score, grading_method, feedback, created_at FROM attempts
     ${where.length ? "WHERE " + where.join(" AND ") : ""} ORDER BY created_at`,
    params,
  );
  return rows;
}

export type MistakeRow = {
  id: string;
  question_id: string;
  concept: string;
  status: "acik" | "cozuldu";
  created_at: Date;
  prompt: string;
  type: QuestionType;
  course_id: string;
  course_code: string;
  topic_title: string | null;
  response: unknown;
  feedback: string;
  explanation: string;
};

export async function listMistakes(tx: Tx, status: "acik" | "cozuldu" | "hepsi" = "acik"): Promise<MistakeRow[]> {
  const { rows } = await tx.query<MistakeRow>(
    `SELECT m.id, m.question_id, m.concept, m.status, m.created_at, q.prompt, q.type, q.course_id, c.code AS course_code,
            t.title AS topic_title, a.response, a.feedback, q.explanation
     FROM mistakes m JOIN questions q ON q.id = m.question_id JOIN courses c ON c.id = q.course_id
     JOIN attempts a ON a.id = m.attempt_id LEFT JOIN topics t ON t.id = q.topic_id
     ${status === "hepsi" ? "" : "WHERE m.status = $1"} ORDER BY m.created_at DESC`,
    status === "hepsi" ? [] : [status],
  );
  return rows;
}

export type DueCard = { card_id: string; question_id: string; due_at: Date; course_code: string; prompt: string };

export async function listDueCards(tx: Tx, at = new Date(), limit = 50): Promise<DueCard[]> {
  const { rows } = await tx.query<DueCard>(
    `SELECT r.id AS card_id, r.question_id, r.due_at, c.code AS course_code, q.prompt
     FROM review_cards r JOIN questions q ON q.id = r.question_id JOIN courses c ON c.id = q.course_id
     WHERE r.due_at <= $1 ORDER BY r.due_at LIMIT $2`,
    [at, limit],
  );
  return rows;
}
