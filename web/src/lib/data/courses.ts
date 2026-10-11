import type { Tx } from "../db";
import { findConflicts, type Meeting } from "../schedule";

export type Course = {
  id: string;
  code: string;
  name: string;
  instructor: string | null;
  delivery: "yuz_yuze" | "cevrimici";
  notes: string;
};
export type CourseMeeting = { id: string; course_id: string; weekday: number; start_time: string; end_time: string };

export const TOPIC_STATUSES = {
  materyal_eksik: "Materyal eksik",
  materyal_alindi: "Materyal alındı",
  okundu: "Okundu / dinlendi",
  not_cikarildi: "Not çıkarıldı",
  soru_calisildi: "Soru çalışıldı",
  tekrar_gerekiyor: "Tekrar gerekiyor",
  tamamlandi: "Tamamlandı",
} as const;
export type TopicStatus = keyof typeof TOPIC_STATUSES;

export type Topic = {
  id: string;
  course_id: string;
  title: string;
  week: number | null;
  description: string;
  status: TopicStatus;
  is_catch_up: boolean;
};

export async function listCourses(tx: Tx): Promise<Course[]> {
  const { rows } = await tx.query<Course>(
    "SELECT id, code, name, instructor, delivery, notes FROM courses ORDER BY created_at, code",
  );
  return rows;
}

export async function getCourse(tx: Tx, id: string): Promise<Course | null> {
  if (!isUuid(id)) return null;
  const { rows } = await tx.query<Course>("SELECT id, code, name, instructor, delivery, notes FROM courses WHERE id = $1", [id]);
  return rows[0] ?? null;
}

export async function listMeetings(tx: Tx, courseId?: string): Promise<CourseMeeting[]> {
  const { rows } = await tx.query<CourseMeeting>(
    `SELECT id, course_id, weekday, to_char(start_time,'HH24:MI') AS start_time, to_char(end_time,'HH24:MI') AS end_time
     FROM course_meetings ${courseId ? "WHERE course_id = $1" : ""} ORDER BY weekday, start_time`,
    courseId ? [courseId] : [],
  );
  return rows;
}

export async function scheduleConflicts(tx: Tx) {
  const courses = await listCourses(tx);
  const label = new Map(courses.map((c) => [c.id, `${c.code} ${c.name}`]));
  const meetings: Meeting[] = (await listMeetings(tx)).map((m) => ({
    id: m.id,
    courseId: m.course_id,
    courseLabel: label.get(m.course_id) ?? "",
    weekday: m.weekday,
    start: m.start_time,
    end: m.end_time,
  }));
  return findConflicts(meetings);
}

export async function updateCourse(
  tx: Tx,
  id: string,
  data: { code: string; name: string; instructor: string | null; delivery: "yuz_yuze" | "cevrimici"; notes: string },
) {
  const { rowCount } = await tx.query(
    "UPDATE courses SET code=$2, name=$3, instructor=$4, delivery=$5, notes=$6 WHERE id=$1",
    [id, data.code, data.name, data.instructor, data.delivery, data.notes],
  );
  if (!rowCount) throw new Error("Ders bulunamadı.");
}

export async function addMeeting(tx: Tx, userId: string, courseId: string, weekday: number, start: string, end: string) {
  if (!(await getCourse(tx, courseId))) throw new Error("Ders bulunamadı.");
  await tx.query(
    "INSERT INTO course_meetings (user_id, course_id, weekday, start_time, end_time) VALUES ($1,$2,$3,$4,$5)",
    [userId, courseId, weekday, start, end],
  );
  await markPlanStale(tx);
}

export async function deleteMeeting(tx: Tx, id: string) {
  await tx.query("DELETE FROM course_meetings WHERE id = $1", [id]);
  await markPlanStale(tx);
}

export async function listTopics(tx: Tx, courseId?: string): Promise<Topic[]> {
  const { rows } = await tx.query<Topic>(
    `SELECT id, course_id, title, week, description, status, is_catch_up FROM topics
     ${courseId ? "WHERE course_id = $1" : ""} ORDER BY week NULLS LAST, created_at`,
    courseId ? [courseId] : [],
  );
  return rows;
}

export async function getTopic(tx: Tx, id: string): Promise<Topic | null> {
  if (!isUuid(id)) return null;
  const { rows } = await tx.query<Topic>("SELECT id, course_id, title, week, description, status, is_catch_up FROM topics WHERE id=$1", [id]);
  return rows[0] ?? null;
}

export async function createTopic(
  tx: Tx,
  userId: string,
  courseId: string,
  data: { title: string; week: number | null; description?: string; isCatchUp?: boolean },
): Promise<string> {
  if (!(await getCourse(tx, courseId))) throw new Error("Ders bulunamadı.");
  const { rows } = await tx.query<{ id: string }>(
    "INSERT INTO topics (user_id, course_id, title, week, description, is_catch_up) VALUES ($1,$2,$3,$4,$5,$6) RETURNING id",
    [userId, courseId, data.title, data.week, data.description ?? "", data.isCatchUp ?? false],
  );
  await markPlanStale(tx);
  return rows[0].id;
}

/** Akademik durum değiştiğinde çalışma planı bir sonraki açılışta yeniden üretilir. */
export async function markPlanStale(tx: Tx) {
  await tx.query("UPDATE planner_settings SET last_generated_on = NULL");
}

export async function setTopicCatchUp(tx: Tx, id: string, value: boolean) {
  await tx.query("UPDATE topics SET is_catch_up=$2, updated_at=now() WHERE id=$1", [id, value]);
  await markPlanStale(tx);
}

export async function setTopicStatus(tx: Tx, id: string, status: TopicStatus) {
  if (!(status in TOPIC_STATUSES)) throw new Error("Geçersiz durum.");
  await tx.query("UPDATE topics SET status=$2, updated_at=now() WHERE id=$1", [id, status]);
  await markPlanStale(tx);
}

/**
 * Durumu yalnızca ileri taşır (ör. materyal yüklenince "materyal_eksik" → "materyal_alindi").
 * Kullanıcının elle belirlediği daha ileri bir durumu geriye almaz.
 */
export async function advanceTopicStatus(tx: Tx, id: string, to: TopicStatus) {
  const order = Object.keys(TOPIC_STATUSES);
  const topic = await getTopic(tx, id);
  if (!topic) return;
  if (topic.status === "tekrar_gerekiyor" && to !== "tamamlandi") return;
  if (order.indexOf(to) > order.indexOf(topic.status)) await setTopicStatus(tx, id, to);
}

export const isUuid = (s: string) => /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(s);
