import type { Tx } from "../db";
import { conceptStats, latestGraded, mastery, studySteps, type AttemptLite } from "../mastery";
import { getTopic, isUuid } from "./courses";

export type Objective = { id: string; topic_id: string; text: string; ord: number };

export async function listObjectives(tx: Tx, filter: { topicId?: string; courseId?: string } = {}): Promise<Objective[]> {
  if (filter.topicId) {
    const { rows } = await tx.query<Objective>("SELECT id, topic_id, text, ord FROM learning_objectives WHERE topic_id=$1 ORDER BY ord, created_at", [filter.topicId]);
    return rows;
  }
  const { rows } = await tx.query<Objective>(
    `SELECT o.id, o.topic_id, o.text, o.ord FROM learning_objectives o JOIN topics t ON t.id = o.topic_id
     ${filter.courseId ? "WHERE t.course_id = $1" : ""} ORDER BY o.ord, o.created_at`,
    filter.courseId ? [filter.courseId] : [],
  );
  return rows;
}

export async function createObjective(tx: Tx, userId: string, topicId: string, text: string) {
  const t = text.trim();
  if (t.length < 3 || t.length > 500) throw new Error("Hedef 3–500 karakter olmalı.");
  if (!(await getTopic(tx, topicId))) throw new Error("Konu bulunamadı.");
  const { rows } = await tx.query<{ n: number }>("SELECT count(*)::int AS n FROM learning_objectives WHERE topic_id=$1", [topicId]);
  await tx.query("INSERT INTO learning_objectives (user_id, topic_id, text, ord) VALUES ($1,$2,$3,$4)", [userId, topicId, t, rows[0].n]);
}

export async function deleteObjective(tx: Tx, id: string) {
  if (isUuid(id)) await tx.query("DELETE FROM learning_objectives WHERE id=$1", [id]);
}

/** Konu çalışma merkezi için bütün göstergeler (gerçek veriden). */
export async function loadTopicProgress(tx: Tx, topicId: string) {
  const objectives = await listObjectives(tx, { topicId });
  const { rows: questions } = await tx.query<{ id: string; concept: string; objective_id: string | null }>(
    "SELECT id, concept, objective_id FROM questions WHERE topic_id=$1",
    [topicId],
  );
  const { rows: attempts } = await tx.query<AttemptLite>(
    `SELECT a.question_id, a.is_correct, a.created_at, a.confidence FROM attempts a JOIN questions q ON q.id = a.question_id WHERE q.topic_id=$1`,
    [topicId],
  );
  const counts = (
    await tx.query<{ sources: number; text_sources: number; sessions: number; reading: number; notes: number; open_mistakes: number; misconceptions: number; due: number }>(
      `SELECT
         (SELECT count(*)::int FROM sources WHERE topic_id=$1) AS sources,
         (SELECT count(*)::int FROM sources WHERE topic_id=$1 AND extraction_status='tamam') AS text_sources,
         (SELECT count(*)::int FROM study_sessions WHERE topic_id=$1) AS sessions,
         (SELECT count(*)::int FROM study_sessions WHERE topic_id=$1 AND mode IN ('okuma','konu_anlatimi','derinlemesine')) AS reading,
         (SELECT count(*)::int FROM notes WHERE topic_id=$1) AS notes,
         (SELECT count(*)::int FROM mistakes m JOIN questions q ON q.id=m.question_id WHERE q.topic_id=$1 AND m.status='acik') AS open_mistakes,
         (SELECT count(*)::int FROM mistakes m JOIN questions q ON q.id=m.question_id WHERE q.topic_id=$1 AND m.status='acik' AND m.misconception) AS misconceptions,
         (SELECT count(*)::int FROM review_cards r JOIN questions q ON q.id=r.question_id WHERE q.topic_id=$1 AND r.due_at <= now()) AS due`,
      [topicId],
    )
  ).rows[0];
  const latest = latestGraded(attempts);
  const overall = mastery(questions.map((q) => q.id), latest);
  const objectiveMastery = objectives.map((o) => ({ ...o, ...mastery(questions.filter((q) => q.objective_id === o.id).map((q) => q.id), latest) }));
  const topic = (await getTopic(tx, topicId))!;
  const steps = studySteps({
    sourcesWithText: counts.text_sources, status: topic.status, readingSessions: counts.reading, notes: counts.notes,
    questions: questions.length, answered: overall.answered, openMistakes: counts.open_mistakes,
    objectives: objectives.length, objectivesLearned: objectiveMastery.filter((o) => o.level === "ogrenildi").length,
  });
  return { topic, counts, overall, objectives: objectiveMastery, concepts: conceptStats(questions, latest), steps };
}
