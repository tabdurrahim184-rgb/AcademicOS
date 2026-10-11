/** Bölüm Projesi (GZT440) çalışma alanı. Bilinmeyen proje bilgileri boş bırakılır, uydurulmaz. */
import type { Tx } from "../db";
import { isUuid, markPlanStale } from "./courses";

export const ENTRY_KINDS = {
  kaynak: "Literatür / kaynakça",
  gorusme: "Danışman görüşmesi",
  geribildirim: "Geri bildirim",
  taslak: "Taslak",
  revizyon: "Revizyon",
  cekim: "Araştırma / görüşme / çekim planı",
  teslim: "Ara / son teslim",
  gorev: "Görev",
} as const;
export type EntryKind = keyof typeof ENTRY_KINDS;

export type ProjectProfile = { title: string; aim: string; research_questions: string; method: string; format: string; advisor: string };
export type ProjectEntry = {
  id: string; kind: EntryKind; title: string; body: string; event_date: string | null; due_date: string | null;
  status: "acik" | "tamamlandi"; source_id: string | null; created_at: Date;
};

const EMPTY: ProjectProfile = { title: "", aim: "", research_questions: "", method: "", format: "", advisor: "" };
const ENTRY_COLS = `id, kind, title, body, to_char(event_date,'YYYY-MM-DD') AS event_date, to_char(due_date,'YYYY-MM-DD') AS due_date, status, source_id, created_at`;
const dateOrNull = (s: string | null | undefined) => (s && /^\d{4}-\d{2}-\d{2}$/.test(s) ? s : null);

export async function getProfile(tx: Tx): Promise<ProjectProfile> {
  const { rows } = await tx.query<ProjectProfile>("SELECT title, aim, research_questions, method, format, advisor FROM project_profiles");
  return rows[0] ?? EMPTY;
}

export async function saveProfile(tx: Tx, userId: string, p: ProjectProfile) {
  const v = Object.fromEntries(Object.entries(p).map(([k, x]) => [k, String(x ?? "").slice(0, 10000)])) as ProjectProfile;
  await tx.query(
    `INSERT INTO project_profiles (user_id, title, aim, research_questions, method, format, advisor) VALUES ($1,$2,$3,$4,$5,$6,$7)
     ON CONFLICT (user_id) DO UPDATE SET title=EXCLUDED.title, aim=EXCLUDED.aim, research_questions=EXCLUDED.research_questions,
       method=EXCLUDED.method, format=EXCLUDED.format, advisor=EXCLUDED.advisor, updated_at=now()`,
    [userId, v.title, v.aim, v.research_questions, v.method, v.format, v.advisor],
  );
}

export async function listEntries(tx: Tx, kind?: EntryKind): Promise<ProjectEntry[]> {
  const { rows } = await tx.query<ProjectEntry>(
    `SELECT ${ENTRY_COLS} FROM project_entries ${kind ? "WHERE kind=$1" : ""} ORDER BY coalesce(due_date, event_date) NULLS LAST, created_at`,
    kind ? [kind] : [],
  );
  return rows;
}

export async function createEntry(
  tx: Tx, userId: string,
  e: { kind: EntryKind; title: string; body: string; eventDate?: string | null; dueDate?: string | null; sourceId?: string | null },
) {
  if (!(e.kind in ENTRY_KINDS)) throw new Error("Geçersiz kayıt türü.");
  if (!e.title.trim()) throw new Error("Başlık girin.");
  if (e.sourceId) {
    const { rowCount } = await tx.query("SELECT 1 FROM sources WHERE id=$1", [e.sourceId]);
    if (!rowCount) throw new Error("Kaynak bulunamadı.");
  }
  await tx.query(
    "INSERT INTO project_entries (user_id, kind, title, body, event_date, due_date, source_id) VALUES ($1,$2,$3,$4,$5,$6,$7)",
    [userId, e.kind, e.title.trim().slice(0, 300), e.body.slice(0, 20000), dateOrNull(e.eventDate), dateOrNull(e.dueDate), e.sourceId ?? null],
  );
  if (e.dueDate) await markPlanStale(tx);
}

export async function updateEntry(tx: Tx, id: string, e: { title: string; body: string; eventDate: string | null; dueDate: string | null }) {
  if (!isUuid(id)) throw new Error("Kayıt bulunamadı.");
  if (!e.title.trim()) throw new Error("Başlık girin.");
  const { rowCount } = await tx.query(
    "UPDATE project_entries SET title=$2, body=$3, event_date=$4, due_date=$5, updated_at=now() WHERE id=$1",
    [id, e.title.trim().slice(0, 300), e.body.slice(0, 20000), dateOrNull(e.eventDate), dateOrNull(e.dueDate)],
  );
  if (!rowCount) throw new Error("Kayıt bulunamadı.");
  await markPlanStale(tx);
}

export async function setEntryStatus(tx: Tx, id: string, status: "acik" | "tamamlandi") {
  if (isUuid(id)) await tx.query("UPDATE project_entries SET status=$2, updated_at=now() WHERE id=$1", [id, status]);
  await markPlanStale(tx);
}

export async function deleteEntry(tx: Tx, id: string) {
  if (isUuid(id)) await tx.query("DELETE FROM project_entries WHERE id=$1", [id]);
  await markPlanStale(tx);
}

/** Planlayıcı ve takvim için: tarihli, açık proje teslimleri. */
export async function projectDeadlines(tx: Tx) {
  const { rows } = await tx.query<{ id: string; kind: EntryKind; title: string; due_date: string }>(
    `SELECT id, kind, title, to_char(due_date,'YYYY-MM-DD') AS due_date FROM project_entries
     WHERE status='acik' AND due_date IS NOT NULL AND kind IN ('teslim','taslak','revizyon','gorev','cekim')`,
  );
  return rows;
}
