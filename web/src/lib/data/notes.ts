import type { Tx } from "../db";
import { getCourse, getTopic } from "./courses";

export type Note = { id: string; course_id: string; topic_id: string | null; title: string; body: string; origin: "kullanici" | "yapay_zeka"; created_at: Date; updated_at: Date };

export async function listNotes(tx: Tx, courseId?: string): Promise<Note[]> {
  const { rows } = await tx.query<Note>(
    `SELECT id, course_id, topic_id, title, body, origin, created_at, updated_at FROM notes ${courseId ? "WHERE course_id=$1" : ""} ORDER BY updated_at DESC`,
    courseId ? [courseId] : [],
  );
  return rows;
}

export async function createNote(
  tx: Tx,
  userId: string,
  n: { courseId: string; topicId: string | null; title: string; body: string; origin: Note["origin"] },
) {
  if (!n.body.trim()) throw new Error("Not boş olamaz.");
  if (!(await getCourse(tx, n.courseId))) throw new Error("Ders bulunamadı.");
  if (n.topicId) {
    const t = await getTopic(tx, n.topicId);
    if (!t || t.course_id !== n.courseId) throw new Error("Konu bu derse ait değil.");
  }
  const { rows } = await tx.query<{ id: string }>(
    "INSERT INTO notes (user_id, course_id, topic_id, title, body, origin) VALUES ($1,$2,$3,$4,$5,$6) RETURNING id",
    [userId, n.courseId, n.topicId, n.title.trim() || "Adsız not", n.body.slice(0, 50000), n.origin],
  );
  return rows[0].id;
}

export async function deleteNote(tx: Tx, id: string) {
  await tx.query("DELETE FROM notes WHERE id=$1", [id]);
}
