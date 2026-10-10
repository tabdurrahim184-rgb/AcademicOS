import type { Tx } from "../db";
import { listCourses, listTopics, type Course, type Topic } from "./courses";

export type CourseCatchUp = {
  course: Course;
  topics: Array<Topic & { sourceCount: number; openMistakes: number }>;
  missingMaterial: Topic[];
  unstudiedWeeks: number[]; // konusu var ama çalışılmamış haftalar
  weeksWithoutTopics: number[]; // 1..en büyük hafta arasında hiç konu girilmemiş haftalar
  completed: Topic[];
  openMistakes: number;
  misconceptions: number;
  weakConcepts: Array<{ concept: string; open: number }>;
  dueReviews: number;
};

const UNSTUDIED: Topic["status"][] = ["materyal_eksik", "materyal_alindi"];

export async function loadCatchUp(tx: Tx, now = new Date()): Promise<CourseCatchUp[]> {
  const courses = await listCourses(tx);
  const topics = await listTopics(tx);
  const { rows: src } = await tx.query<{ topic_id: string; n: string }>("SELECT topic_id, count(*) AS n FROM sources WHERE topic_id IS NOT NULL GROUP BY 1");
  const { rows: mist } = await tx.query<{ course_id: string; topic_id: string | null; concept: string; misconception: boolean }>(
    `SELECT q.course_id, q.topic_id, m.concept, m.misconception FROM mistakes m JOIN questions q ON q.id = m.question_id WHERE m.status = 'acik'`,
  );
  const { rows: due } = await tx.query<{ course_id: string; n: string }>(
    "SELECT q.course_id, count(*) AS n FROM review_cards r JOIN questions q ON q.id = r.question_id WHERE r.due_at <= $1 GROUP BY 1",
    [now],
  );
  const srcMap = new Map(src.map((r) => [r.topic_id, Number(r.n)]));
  return courses.map((course) => {
    const ts = topics
      .filter((t) => t.course_id === course.id)
      .map((t) => ({ ...t, sourceCount: srcMap.get(t.id) ?? 0, openMistakes: mist.filter((m) => m.topic_id === t.id).length }));
    const weeks = ts.map((t) => t.week).filter((w): w is number => w != null);
    const maxWeek = weeks.length ? Math.max(...weeks) : 0;
    const cm = mist.filter((m) => m.course_id === course.id);
    const conceptCounts = new Map<string, number>();
    for (const m of cm) conceptCounts.set(m.concept, (conceptCounts.get(m.concept) ?? 0) + 1);
    return {
      course,
      topics: ts,
      missingMaterial: ts.filter((t) => t.status === "materyal_eksik"),
      unstudiedWeeks: [...new Set(ts.filter((t) => t.week != null && UNSTUDIED.includes(t.status)).map((t) => t.week!))].sort((a, b) => a - b),
      weeksWithoutTopics: Array.from({ length: maxWeek }, (_, i) => i + 1).filter((w) => !weeks.includes(w)),
      completed: ts.filter((t) => t.status === "tamamlandi"),
      openMistakes: cm.length,
      misconceptions: cm.filter((m) => m.misconception).length,
      weakConcepts: [...conceptCounts.entries()].map(([concept, open]) => ({ concept, open })).sort((a, b) => b.open - a.open).slice(0, 8),
      dueReviews: Number(due.find((d) => d.course_id === course.id)?.n ?? 0),
    };
  });
}
