import type { Tx } from "../db";
import { recommend, type Recommendation } from "../recommend";
import { localParts } from "../schedule";
import { listAssessments } from "./assessments";
import { listCourses, listMeetings, listTopics } from "./courses";

export async function loadDashboard(tx: Tx, now = new Date(), timeZone = "Europe/Nicosia") {
  const courses = await listCourses(tx);
  const topics = await listTopics(tx);
  const meetings = await listMeetings(tx);
  const assessments = await listAssessments(tx);
  const { rows: srcCounts } = await tx.query<{ topic_id: string; n: string }>(
    "SELECT topic_id, count(*) AS n FROM sources WHERE topic_id IS NOT NULL GROUP BY topic_id",
  );
  const { rows: due } = await tx.query<{ course_id: string; n: string }>(
    `SELECT q.course_id, count(*) AS n FROM review_cards r JOIN questions q ON q.id = r.question_id
     WHERE r.due_at <= $1 GROUP BY q.course_id`,
    [now],
  );
  const { rows: mist } = await tx.query<{ course_id: string; n: string }>(
    `SELECT q.course_id, count(*) AS n FROM mistakes m JOIN questions q ON q.id = m.question_id
     WHERE m.status = 'acik' GROUP BY q.course_id`,
  );
  const { rows: active } = await tx.query<{ id: string; course_id: string; last_activity_at: Date }>(
    "SELECT id, course_id, last_activity_at FROM study_sessions WHERE status='aktif' ORDER BY last_activity_at DESC LIMIT 1",
  );
  const sc = Object.fromEntries(srcCounts.map((r) => [r.topic_id, Number(r.n)]));
  const dueByCourse = Object.fromEntries(due.map((r) => [r.course_id, Number(r.n)]));
  const mistakesByCourse = Object.fromEntries(mist.map((r) => [r.course_id, Number(r.n)]));

  const rec: Recommendation = recommend({
    now,
    courses,
    topics: topics.map((t) => ({ ...t, sourceCount: sc[t.id] ?? 0 })),
    dueCardsByCourse: dueByCourse,
    openMistakesByCourse: mistakesByCourse,
    assessments: assessments.filter((a) => a.score == null),
    activeSession: active[0] ?? null,
  });

  const today = localParts(now, timeZone);
  const courseById = new Map(courses.map((c) => [c.id, c]));
  const todaysClasses = meetings
    .filter((m) => m.weekday === today.weekday)
    .map((m) => ({ ...m, course: courseById.get(m.course_id)! }));

  const upcoming = assessments
    .filter((a) => a.score == null && (a.due_at == null || a.due_at.getTime() >= now.getTime() - 86400_000))
    .slice(0, 8)
    .map((a) => ({ ...a, course: courseById.get(a.course_id)! }));

  const missingMaterials = topics.filter((t) => t.status === "materyal_eksik").length;
  const topicTotals = { total: topics.length, done: topics.filter((t) => t.status === "tamamlandi").length };
  const totalDue = Object.values(dueByCourse).reduce((a, b) => a + b, 0);
  const totalMistakes = Object.values(mistakesByCourse).reduce((a, b) => a + b, 0);

  return { courses, rec, todaysClasses, upcoming, missingMaterials, topicTotals, totalDue, totalMistakes, today };
}
