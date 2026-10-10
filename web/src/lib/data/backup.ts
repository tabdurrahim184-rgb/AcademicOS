/**
 * Kullanıcı verisinin tam yedeği (JSON) ve geri yüklenmesi.
 * Yedek; dersler, konular, kaynak dosyaları (base64), notlar, oturumlar,
 * sorular, cevaplar, yanlışlar ve tekrar kartlarını içerir.
 * Geri yüklemede bütün kimlikler yeniden üretilir; böylece yedek başka bir
 * hesaba da güvenle yüklenebilir.
 */
import { randomUUID } from "node:crypto";
import type { Tx } from "../db";

export const BACKUP_FORMAT = "academicos-yedek";
export const BACKUP_VERSION = 3;
const SUPPORTED_VERSIONS = [1, 2, 3];

type TableSpec = {
  table: string;
  cols: string[];
  pk?: string; // yeniden üretilecek birincil anahtar
  fks?: Record<string, string>; // kolon → referans verdiği tablo
  bytea?: string[];
  singleton?: boolean; // kullanıcı başına tek satır (birincil anahtar user_id)
};

const TIME_COLS = new Set(["start_time", "end_time"]);
const DATE_COLS = new Set(["scheduled_date", "semester_end", "last_generated_on", "event_date", "due_date"]);

const TABLES: TableSpec[] = [
  { table: "courses", pk: "id", cols: ["id", "code", "name", "instructor", "delivery", "notes", "created_at"] },
  { table: "course_meetings", pk: "id", cols: ["id", "course_id", "weekday", "start_time", "end_time"], fks: { course_id: "courses" } },
  { table: "topics", pk: "id", cols: ["id", "course_id", "title", "week", "description", "status", "is_catch_up", "created_at", "updated_at"], fks: { course_id: "courses" } },
  { table: "learning_objectives", pk: "id", cols: ["id", "topic_id", "text", "ord", "created_at"], fks: { topic_id: "topics" } },
  {
    table: "sources", pk: "id",
    cols: ["id", "course_id", "topic_id", "title", "kind", "filename", "mime", "size_bytes", "sha256", "file_type", "extraction_status", "extraction_note", "unit_count", "created_at"],
    fks: { course_id: "courses", topic_id: "topics" },
  },
  { table: "source_files", cols: ["source_id", "content"], fks: { source_id: "sources" }, bytea: ["content"] },
  { table: "source_chunks", pk: "id", cols: ["id", "source_id", "ord", "locator_type", "locator", "content", "raw_ocr"], fks: { source_id: "sources" } },
  { table: "notes", pk: "id", cols: ["id", "course_id", "topic_id", "title", "body", "origin", "created_at", "updated_at"], fks: { course_id: "courses", topic_id: "topics" } },
  { table: "assessments", pk: "id", cols: ["id", "course_id", "kind", "title", "due_at", "weight", "score", "notes", "created_at"], fks: { course_id: "courses" } },
  {
    table: "study_sessions", pk: "id",
    cols: ["id", "course_id", "topic_id", "mode", "goal", "source_ids", "only_selected_sources", "status", "started_at", "last_activity_at", "ended_at"],
    fks: { course_id: "courses", topic_id: "topics" },
  },
  { table: "session_messages", pk: "id", cols: ["id", "session_id", "role", "content", "citations", "provider", "model", "created_at"], fks: { session_id: "study_sessions" } },
  {
    table: "questions", pk: "id",
    cols: ["id", "course_id", "topic_id", "source_id", "objective_id", "type", "prompt", "options", "answer", "rubric", "explanation", "concept", "origin", "created_at"],
    fks: { course_id: "courses", topic_id: "topics", source_id: "sources", objective_id: "learning_objectives" },
  },
  {
    table: "attempts", pk: "id",
    cols: ["id", "question_id", "session_id", "response", "is_correct", "score", "grading_method", "feedback", "confidence", "created_at"],
    fks: { question_id: "questions", session_id: "study_sessions" },
  },
  { table: "mistakes", pk: "id", cols: ["id", "question_id", "attempt_id", "concept", "status", "misconception", "ai_explanation", "created_at", "resolved_at"], fks: { question_id: "questions", attempt_id: "attempts" } },
  {
    table: "review_cards", pk: "id",
    cols: ["id", "question_id", "ease", "interval_days", "repetitions", "lapses", "due_at", "last_reviewed_at"],
    fks: { question_id: "questions" },
  },
  { table: "review_log", pk: "id", cols: ["id", "card_id", "quality", "interval_days", "ease", "reviewed_at"], fks: { card_id: "review_cards" } },
  {
    table: "planner_settings", singleton: true,
    cols: ["weekday_capacity_min", "weekend_capacity_min", "max_task_min", "break_min", "catch_up_share", "semester_end"],
  },
  { table: "availability_windows", pk: "id", cols: ["id", "weekday", "start_time", "end_time"] },
  {
    table: "plan_tasks", pk: "id",
    cols: ["id", "course_id", "topic_id", "kind", "title", "detail", "origin_key", "scheduled_date", "start_time", "duration_min", "status", "locked", "completed_at", "created_at"],
    fks: { course_id: "courses", topic_id: "topics" },
  },
  // ---- sürüm 3: Bölüm Projesi, tartışmalar, iş merkezi, kayıtlar
  { table: "project_profiles", singleton: true, cols: ["title", "aim", "research_questions", "method", "format", "advisor"] },
  {
    table: "project_entries", pk: "id",
    cols: ["id", "kind", "title", "body", "event_date", "due_date", "status", "source_id", "created_at"], fks: { source_id: "sources" },
  },
  {
    table: "debates", pk: "id",
    cols: ["id", "course_id", "theme", "title", "claim", "academic_context", "counter_arguments", "islamic_perspective", "class_answer", "weaknesses", "uncertainties", "created_at"],
    fks: { course_id: "courses" },
  },
  { table: "debate_sources", pk: "id", cols: ["id", "debate_id", "kind", "reference", "quote", "note", "verified", "created_at"], fks: { debate_id: "debates" } },
  { table: "work_clients", pk: "id", cols: ["id", "name", "note", "created_at"] },
  { table: "work_commitments", pk: "id", cols: ["id", "client_id", "title", "weekday", "start_time", "end_time"], fks: { client_id: "work_clients" } },
  {
    table: "work_tasks", pk: "id",
    cols: ["id", "client_id", "kind", "title", "requested_by", "description", "due_at", "priority", "estimate_min", "status", "scheduled_date", "start_time", "minute_list", "created_at"],
    fks: { client_id: "work_clients" },
  },
  { table: "work_task_history", cols: ["task_id", "event", "note", "created_at"], fks: { task_id: "work_tasks" } },
  {
    table: "recordings", pk: "id",
    cols: ["id", "archive", "course_id", "client_id", "title", "filename", "mime", "size_bytes", "duration_sec", "status", "created_at"],
    fks: { course_id: "courses", client_id: "work_clients" },
  },
  { table: "recording_files", cols: ["recording_id", "content"], fks: { recording_id: "recordings" }, bytea: ["content"] },
  {
    table: "transcript_segments", pk: "id",
    cols: ["id", "recording_id", "ord", "start_sec", "end_sec", "raw_text", "text", "speaker"], fks: { recording_id: "recordings" },
  },
];

const JSON_COLS = new Set(["citations", "options", "answer", "response", "minute_list"]);

export type Backup = { format: string; version: number; created_at: string; data: Record<string, Record<string, unknown>[]> };

export async function exportBackup(tx: Tx): Promise<Backup> {
  const data: Backup["data"] = {};
  for (const spec of TABLES) {
    const sel = spec.cols
      .map((c) => (TIME_COLS.has(c) ? `to_char(${c},'HH24:MI') AS ${c}` : DATE_COLS.has(c) ? `to_char(${c},'YYYY-MM-DD') AS ${c}` : c))
      .join(", ");
    const { rows } = await tx.query(`SELECT ${sel} FROM ${spec.table}`);
    data[spec.table] = rows.map((r) => {
      const o: Record<string, unknown> = { ...r };
      for (const b of spec.bytea ?? []) o[b] = (r[b] as Buffer).toString("base64");
      return o;
    });
  }
  return { format: BACKUP_FORMAT, version: BACKUP_VERSION, created_at: new Date().toISOString(), data };
}

export function validateBackup(b: unknown): asserts b is Backup {
  const x = b as Backup;
  if (!x || x.format !== BACKUP_FORMAT) throw new Error("Bu dosya bir AcademicOS yedeği değil.");
  if (!SUPPORTED_VERSIONS.includes(x.version)) throw new Error(`Desteklenmeyen yedek sürümü: ${x.version}`);
  if (!x.data || typeof x.data !== "object") throw new Error("Yedek verisi eksik.");
  for (const spec of TABLES) {
    if (x.data[spec.table] !== undefined && !Array.isArray(x.data[spec.table])) throw new Error(`Yedekte ${spec.table} bozuk.`);
  }
}

/**
 * Geri yükleme: kullanıcının mevcut akademik verisini SİLER ve yedektekini yükler.
 * Tek işlem içinde çalışır; herhangi bir hata olursa hiçbir değişiklik kalmaz.
 */
export async function restoreBackup(tx: Tx, userId: string, backup: unknown) {
  validateBackup(backup);
  await tx.query("DELETE FROM courses"); // RLS: yalnızca bu kullanıcının dersleri; derse bağlı tablolar CASCADE ile silinir
  for (const t of ["availability_windows", "planner_settings", "project_entries", "project_profiles", "debates", "recordings", "work_clients"]) {
    await tx.query(`DELETE FROM ${t}`); // RLS: yalnızca bu kullanıcının satırları
  }
  const idMap = new Map<string, Map<string, string>>();
  const mapOf = (t: string) => idMap.get(t) ?? idMap.set(t, new Map()).get(t)!;
  const remap = (table: string, old: unknown) => {
    if (old == null) return null;
    const v = mapOf(table).get(String(old));
    if (!v) throw new Error(`Yedekte tutarsız referans (${table}).`);
    return v;
  };
  const counts: Record<string, number> = {};
  for (const spec of TABLES) {
    const rows = backup.data[spec.table] ?? [];
    for (const row of rows) {
      const values: unknown[] = [];
      const usedCols: string[] = [];
      for (const c of spec.cols) {
        let v = row[c];
        // Eski sürüm yedeğinde olmayan kolon: veritabanı varsayılanı kullanılır
        if (v === undefined && c !== spec.pk) continue;
        if (c === spec.pk) {
          const nid = randomUUID();
          mapOf(spec.table).set(String(v), nid);
          v = nid;
        } else if (spec.fks?.[c]) {
          v = remap(spec.fks[c], v);
        } else if (c === "source_ids") {
          v = ((v as string[]) ?? []).map((s) => mapOf("sources").get(s)).filter(Boolean);
        } else if (c === "citations") {
          v = ((v as Array<Record<string, unknown>>) ?? []).map((ct) => ({ ...ct, sourceId: mapOf("sources").get(String(ct.sourceId)) ?? null }));
        }
        if (spec.bytea?.includes(c)) v = Buffer.from(String(v), "base64");
        if (JSON_COLS.has(c)) v = JSON.stringify(v ?? null);
        values.push(v);
        usedCols.push(c);
      }
      const cols = ["user_id", ...usedCols];
      const ph = cols.map((_, i) => `$${i + 1}`).join(", ");
      await tx.query(`INSERT INTO ${spec.table} (${cols.join(", ")}) VALUES (${ph})`, [userId, ...values]);
    }
    counts[spec.table] = rows.length;
  }
  return counts;
}
