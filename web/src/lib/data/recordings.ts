import type { Tx } from "../db";
import { getCourse, isUuid } from "./courses";
import { MAX_MEDIA_BYTES, MEDIA_EXT } from "../transcription";

export type Recording = {
  id: string; archive: "ders" | "is"; course_id: string | null; client_id: string | null; title: string; filename: string;
  mime: string; size_bytes: string; duration_sec: string | null; status: string; created_at: Date;
};
export type Segment = { id: string; ord: number; start_sec: string; end_sec: string; raw_text: string; text: string; speaker: string | null };

const COLS = "id, archive, course_id, client_id, title, filename, mime, size_bytes, duration_sec, status, created_at";

const MIME: Record<string, string> = {
  mp3: "audio/mpeg", m4a: "audio/mp4", wav: "audio/wav", ogg: "audio/ogg", oga: "audio/ogg", webm: "video/webm", mp4: "video/mp4",
  mov: "video/quicktime", mkv: "video/x-matroska", aac: "audio/aac", flac: "audio/flac",
};

export async function saveRecording(
  tx: Tx, userId: string,
  r: { archive: "ders" | "is"; courseId: string | null; clientId: string | null; title: string; filename: string; data: Buffer; durationSec: number },
): Promise<string> {
  if (!MEDIA_EXT.test(r.filename)) throw new Error("Desteklenmeyen ses/video türü (mp3, m4a, wav, ogg, webm, mp4, mov, mkv, aac, flac).");
  if (r.data.length === 0) throw new Error("Dosya boş.");
  if (r.data.length > MAX_MEDIA_BYTES) throw new Error("Dosya 100 MB sınırını aşıyor.");
  if (r.archive === "ders" && r.courseId && !(await getCourse(tx, r.courseId))) throw new Error("Ders bulunamadı.");
  if (r.archive === "is" && r.clientId && !(await tx.query("SELECT 1 FROM work_clients WHERE id=$1", [r.clientId])).rowCount) throw new Error("İşveren bulunamadı.");
  const ext = r.filename.toLowerCase().split(".").pop()!;
  const filename = r.filename.normalize("NFC").replace(/[\\/\u0000-\u001f]/g, "_").slice(0, 200);
  const { rows } = await tx.query<{ id: string }>(
    `INSERT INTO recordings (user_id, archive, course_id, client_id, title, filename, mime, size_bytes, duration_sec)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING id`,
    [userId, r.archive, r.archive === "ders" ? r.courseId : null, r.archive === "is" ? r.clientId : null,
      (r.title.trim() || filename.replace(/\.[^.]+$/, "")).slice(0, 200), filename, MIME[ext] ?? "application/octet-stream", r.data.length, r.durationSec.toFixed(2)],
  );
  await tx.query("INSERT INTO recording_files (recording_id, user_id, content) VALUES ($1,$2,$3)", [rows[0].id, userId, r.data]);
  return rows[0].id;
}

export async function listRecordings(tx: Tx, archive?: "ders" | "is"): Promise<Recording[]> {
  return (await tx.query<Recording>(`SELECT ${COLS} FROM recordings ${archive ? "WHERE archive=$1" : ""} ORDER BY created_at DESC`, archive ? [archive] : [])).rows;
}

export async function getRecording(tx: Tx, id: string): Promise<Recording | null> {
  if (!isUuid(id)) return null;
  return (await tx.query<Recording>(`SELECT ${COLS} FROM recordings WHERE id=$1`, [id])).rows[0] ?? null;
}

export async function getRecordingFile(tx: Tx, id: string): Promise<Buffer | null> {
  if (!isUuid(id)) return null;
  return (await tx.query<{ content: Buffer }>("SELECT content FROM recording_files WHERE recording_id=$1", [id])).rows[0]?.content ?? null;
}

export async function listSegments(tx: Tx, recId: string): Promise<Segment[]> {
  return (await tx.query<Segment>(
    "SELECT id, ord, start_sec, end_sec, raw_text, text, speaker FROM transcript_segments WHERE recording_id=$1 ORDER BY ord", [recId],
  )).rows;
}

export async function updateSegment(tx: Tx, id: string, text: string, speaker: string | null) {
  if (!isUuid(id)) throw new Error("Segment bulunamadı.");
  const { rowCount } = await tx.query("UPDATE transcript_segments SET text=$2, speaker=$3 WHERE id=$1", [id, text.slice(0, 10000), speaker?.slice(0, 100) || null]);
  if (!rowCount) throw new Error("Segment bulunamadı.");
}

export async function deleteRecording(tx: Tx, id: string) {
  if (isUuid(id)) await tx.query("DELETE FROM recordings WHERE id=$1", [id]);
}

/** OCR ile elde edilmiş bir metin bölümünü düzeltir (ham OCR korunur; özgün kaynak metni düzenlenemez). */
export async function updateOcrChunk(tx: Tx, chunkId: string, content: string) {
  if (!isUuid(chunkId)) throw new Error("Bölüm bulunamadı.");
  const { rowCount } = await tx.query("UPDATE source_chunks SET content=$2 WHERE id=$1 AND raw_ocr IS NOT NULL", [chunkId, content.normalize("NFC").slice(0, 50000)]);
  if (!rowCount) throw new Error("Yalnızca OCR ile çıkarılmış metin düzenlenebilir.");
}
