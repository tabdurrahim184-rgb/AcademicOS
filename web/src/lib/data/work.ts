/**
 * İş Merkezi: Ahmet Özsoy ve Hasan Bey için ayrı iş akışları.
 * İşverene gönderilecek hiçbir içerik bu modülden otomatik gönderilmez; akademik notlar burada tutulmaz.
 */
import type { Tx } from "../db";
import { addDays, dateRange, weekdayOf } from "../planner";
import { fromMinutes, localParts, toMinutes } from "../schedule";
import { findWorkSlot, type Block } from "../work-schedule";
import { isUuid, listCourses, listMeetings, markPlanStale } from "./courses";
import { listPlanTasks, nicosiaNow } from "./plan";

export const WORK_KINDS = {
  haber: "Haber yazımı", reels: "Reels", video: "Video düzenleme", desifre: "Deşifre", sosyal_medya: "Sosyal medya",
  tasarim: "Tasarım", web_haberi: "Web haberi", revizyon: "Revizyon", diger: "Diğer",
} as const;
export const WORK_STATUSES = { bekliyor: "Bekliyor", yapiliyor: "Yapılıyor", revizyonda: "Revizyonda", teslim_edildi: "Teslim edildi", iptal: "İptal" } as const;
export const PRIORITIES = { dusuk: "Düşük", normal: "Normal", yuksek: "Yüksek", acil: "Acil" } as const;
export type WorkStatus = keyof typeof WORK_STATUSES;

export type WorkClient = { id: string; name: string };
export type Commitment = { id: string; client_id: string; title: string; weekday: number; start_time: string; end_time: string | null };
export type MinuteItem = { start: string; end: string; note: string };
export type WorkTask = {
  id: string; client_id: string; kind: keyof typeof WORK_KINDS; title: string; requested_by: string; description: string;
  due_at: Date | null; priority: keyof typeof PRIORITIES; estimate_min: number; status: WorkStatus;
  scheduled_date: string | null; start_time: string | null; minute_list: MinuteItem[]; created_at: Date;
};

/** Bitiş saati bilinmeyen taahhütler için planlamada varsayılan süre (arayüzde açıkça belirtilir). */
export const UNKNOWN_END_ASSUMED_MIN = 120;

/** İlk kullanımda iki işvereni ve bilinen programı oluşturur (bitiş saati bilinmediği için boş bırakılır). */
export async function ensureWorkSetup(tx: Tx, userId: string) {
  const { rows } = await tx.query<{ n: number }>("SELECT count(*)::int AS n FROM work_clients");
  if (rows[0].n > 0) return;
  const ins = async (name: string) =>
    (await tx.query<{ id: string }>("INSERT INTO work_clients (user_id, name) VALUES ($1,$2) RETURNING id", [userId, name])).rows[0].id;
  const ahmet = await ins("Ahmet Özsoy");
  await ins("Hasan Bey");
  for (const wd of [1, 2, 3]) {
    await tx.query(
      "INSERT INTO work_commitments (user_id, client_id, title, weekday, start_time, end_time) VALUES ($1,$2,'Ahmet Özsoy ile Gündem',$3,'16:30',NULL)",
      [userId, ahmet, wd],
    );
  }
}

export async function listClients(tx: Tx): Promise<WorkClient[]> {
  return (await tx.query<WorkClient>("SELECT id, name FROM work_clients ORDER BY created_at")).rows;
}

export async function listCommitments(tx: Tx): Promise<Commitment[]> {
  return (
    await tx.query<Commitment>(
      `SELECT id, client_id, title, weekday, to_char(start_time,'HH24:MI') AS start_time, to_char(end_time,'HH24:MI') AS end_time
       FROM work_commitments ORDER BY weekday, start_time`,
    )
  ).rows;
}

export async function listWorkTasks(tx: Tx, clientId?: string): Promise<WorkTask[]> {
  const { rows } = await tx.query<WorkTask>(
    `SELECT id, client_id, kind, title, requested_by, description, due_at, priority, estimate_min, status,
       to_char(scheduled_date,'YYYY-MM-DD') AS scheduled_date, to_char(start_time,'HH24:MI') AS start_time, minute_list, created_at
     FROM work_tasks ${clientId ? "WHERE client_id=$1" : ""}
     ORDER BY (status IN ('teslim_edildi','iptal')), due_at NULLS LAST, created_at`,
    clientId ? [clientId] : [],
  );
  return rows;
}

export async function taskHistory(tx: Tx, taskId: string) {
  return (await tx.query<{ event: string; note: string; created_at: Date }>(
    "SELECT event, note, created_at FROM work_task_history WHERE task_id=$1 ORDER BY created_at", [taskId],
  )).rows;
}

async function clientExists(tx: Tx, id: string) {
  return isUuid(id) && !!(await tx.query("SELECT 1 FROM work_clients WHERE id=$1", [id])).rowCount;
}

/** Kıbrıs yerel tarih+saatini UTC'ye çevirir. */
function nicosia(date: string, time: string): Date {
  const naive = new Date(`${date}T${time}:00Z`);
  const off = new Intl.DateTimeFormat("en-GB", { timeZone: "Europe/Nicosia", timeZoneName: "longOffset" })
    .formatToParts(naive).find((p) => p.type === "timeZoneName")?.value ?? "GMT+02:00";
  const m = off.match(/GMT([+-])(\d{2}):(\d{2})/);
  const min = m ? (m[1] === "-" ? -1 : 1) * (Number(m[2]) * 60 + Number(m[3])) : 120;
  return new Date(naive.getTime() - min * 60_000);
}

export async function createWorkTask(
  tx: Tx, userId: string,
  t: { clientId: string; kind: string; title: string; requestedBy: string; description: string; dueDate: string | null; dueTime: string; priority: string; estimateMin: number },
): Promise<string> {
  if (!(await clientExists(tx, t.clientId))) throw new Error("İşveren bulunamadı.");
  if (!(t.kind in WORK_KINDS)) throw new Error("Geçersiz görev türü.");
  if (!(t.priority in PRIORITIES)) throw new Error("Geçersiz öncelik.");
  if (t.title.trim().length < 2) throw new Error("Görev başlığı girin.");
  if (!(t.estimateMin >= 5 && t.estimateMin <= 1440)) throw new Error("Süre tahmini 5–1440 dakika olmalı.");
  const due = t.dueDate && /^\d{4}-\d{2}-\d{2}$/.test(t.dueDate) ? nicosia(t.dueDate, /^\d{2}:\d{2}$/.test(t.dueTime) ? t.dueTime : "18:00") : null;
  const { rows } = await tx.query<{ id: string }>(
    `INSERT INTO work_tasks (user_id, client_id, kind, title, requested_by, description, due_at, priority, estimate_min)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING id`,
    [userId, t.clientId, t.kind, t.title.trim().slice(0, 300), t.requestedBy.slice(0, 200), t.description.slice(0, 10000), due, t.priority, t.estimateMin],
  );
  await tx.query("INSERT INTO work_task_history (user_id, task_id, event) VALUES ($1,$2,'Oluşturuldu')", [userId, rows[0].id]);
  return rows[0].id;
}

export async function setWorkStatus(tx: Tx, userId: string, id: string, status: WorkStatus) {
  const { rowCount } = await tx.query("UPDATE work_tasks SET status=$2, updated_at=now() WHERE id=$1", [id, status]);
  if (!rowCount) throw new Error("Görev bulunamadı.");
  await tx.query("INSERT INTO work_task_history (user_id, task_id, event) VALUES ($1,$2,$3)", [userId, id, `Durum: ${WORK_STATUSES[status]}`]);
}

export async function addRevision(tx: Tx, userId: string, id: string, note: string) {
  if (!note.trim()) throw new Error("Revizyon notu girin.");
  const { rowCount } = await tx.query("UPDATE work_tasks SET status='revizyonda', updated_at=now() WHERE id=$1", [id]);
  if (!rowCount) throw new Error("Görev bulunamadı.");
  await tx.query("INSERT INTO work_task_history (user_id, task_id, event, note) VALUES ($1,$2,'Revizyon istendi',$3)", [userId, id, note.slice(0, 5000)]);
}

export async function deleteWorkTask(tx: Tx, id: string) {
  if (isUuid(id)) await tx.query("DELETE FROM work_tasks WHERE id=$1", [id]);
}

/** "00:12-00:45 Açılış sahnesi" biçimindeki satırları dakika listesine çevirir. */
export function parseMinuteList(text: string): MinuteItem[] {
  const out: MinuteItem[] = [];
  for (const line of text.split(/\r?\n/)) {
    const m = line.trim().match(/^(\d{1,2}:\d{2}(?::\d{2})?)\s*[-–]\s*(\d{1,2}:\d{2}(?::\d{2})?)\s*(.*)$/);
    if (m) out.push({ start: m[1], end: m[2], note: m[3].trim().slice(0, 500) });
    else if (line.trim()) throw new Error(`Satır anlaşılamadı: "${line.trim().slice(0, 40)}" (biçim: 00:12-00:45 açıklama)`);
  }
  return out.slice(0, 200);
}

export async function updateMinuteList(tx: Tx, id: string, text: string) {
  const list = parseMinuteList(text);
  const { rowCount } = await tx.query("UPDATE work_tasks SET minute_list=$2, updated_at=now() WHERE id=$1", [id, JSON.stringify(list)]);
  if (!rowCount) throw new Error("Görev bulunamadı.");
}

export async function addCommitment(tx: Tx, userId: string, c: { clientId: string; title: string; weekday: number; start: string; end: string | null }) {
  if (!(await clientExists(tx, c.clientId))) throw new Error("İşveren bulunamadı.");
  if (!(c.weekday >= 1 && c.weekday <= 7) || !/^\d{2}:\d{2}$/.test(c.start)) throw new Error("Geçerli gün ve saat girin.");
  if (c.end && toMinutes(c.end) <= toMinutes(c.start)) throw new Error("Bitiş başlangıçtan sonra olmalı.");
  await tx.query(
    "INSERT INTO work_commitments (user_id, client_id, title, weekday, start_time, end_time) VALUES ($1,$2,$3,$4,$5,$6)",
    [userId, c.clientId, c.title.trim() || "Sabit iş", c.weekday, c.start, c.end],
  );
  await markPlanStale(tx);
}

export async function deleteCommitment(tx: Tx, id: string) {
  if (isUuid(id)) await tx.query("DELETE FROM work_commitments WHERE id=$1", [id]);
  await markPlanStale(tx);
}

/** Ders saatleri, sabit iş taahhütleri, planlı iş görevleri ve ders çalışma planı → zaman blokları. */
export async function busyBlocks(tx: Tx, from: string, days: number, exceptTaskId?: string): Promise<Block[]> {
  const dates = dateRange(from, days);
  const courses = await listCourses(tx);
  const meetings = await listMeetings(tx);
  const commitments = await listCommitments(tx);
  const blocks: Block[] = [];
  for (const date of dates) {
    const wd = weekdayOf(date);
    for (const m of meetings.filter((x) => x.weekday === wd)) {
      blocks.push({ date, start: m.start_time, minutes: toMinutes(m.end_time) - toMinutes(m.start_time), label: courses.find((c) => c.id === m.course_id)?.code ?? "Ders", kind: "ders" });
    }
    for (const c of commitments.filter((x) => x.weekday === wd)) {
      const minutes = c.end_time ? toMinutes(c.end_time) - toMinutes(c.start_time) : UNKNOWN_END_ASSUMED_MIN;
      blocks.push({ date, start: c.start_time, minutes, label: c.title, kind: "taahhut" });
    }
  }
  for (const t of await listPlanTasks(tx, from, addDays(from, days - 1))) {
    if (t.status === "planlandi") blocks.push({ date: t.scheduled_date, start: t.start_time, minutes: t.duration_min, label: t.title, kind: "calisma" });
  }
  for (const w of await listWorkTasks(tx)) {
    if (w.id === exceptTaskId || !w.scheduled_date || !w.start_time || ["teslim_edildi", "iptal"].includes(w.status)) continue;
    blocks.push({ date: w.scheduled_date, start: w.start_time, minutes: w.estimate_min, label: w.title, kind: "is" });
  }
  return blocks;
}

/** "Bu işi alırsam hangi ders çalışmam etkilenir?" — gerçek takvim verisiyle analiz ve (istenirse) planlama. */
export async function analyzeWorkTask(tx: Tx, id: string, now = new Date()) {
  const { rows } = await tx.query<{ estimate_min: number; due_at: Date | null }>("SELECT estimate_min, due_at FROM work_tasks WHERE id=$1", [id]);
  if (!rows[0]) throw new Error("Görev bulunamadı.");
  const { today, time } = nicosiaNow(now);
  const due = rows[0].due_at ? localParts(new Date(rows[0].due_at)).date : null;
  const blocks = await busyBlocks(tx, today, 21, id);
  return findWorkSlot({ fromDate: today, fromTime: time, dueDate: due, minutes: rows[0].estimate_min, blocks });
}

export async function scheduleWorkTask(tx: Tx, _userId: string, id: string, now = new Date()) {
  const r = await analyzeWorkTask(tx, id, now);
  if (!r.ok) throw new Error(r.reason);
  await tx.query("UPDATE work_tasks SET scheduled_date=$2, start_time=$3, updated_at=now() WHERE id=$1", [id, r.date, r.start]);
  await markPlanStale(tx); // etkilenen otomatik çalışma görevleri yeniden yerleştirilir
  return r;
}

/** Sabit taahhütlerin ders saatleri ve akademik zamanla çakışmaları (bilgilendirme). */
export async function commitmentConflicts(tx: Tx) {
  const courses = await listCourses(tx);
  const meetings = await listMeetings(tx);
  const out: Array<{ commitment: string; weekday: number; with: string }> = [];
  for (const c of await listCommitments(tx)) {
    const s = toMinutes(c.start_time);
    const e = c.end_time ? toMinutes(c.end_time) : s + UNKNOWN_END_ASSUMED_MIN;
    for (const m of meetings.filter((x) => x.weekday === c.weekday)) {
      if (s < toMinutes(m.end_time) && toMinutes(m.start_time) < e) {
        out.push({ commitment: c.title, weekday: c.weekday, with: `${courses.find((x) => x.id === m.course_id)?.code ?? "ders"} (${m.start_time}–${m.end_time})` });
      }
    }
    if (c.weekday <= 5 && s < toMinutes("18:00")) out.push({ commitment: c.title, weekday: c.weekday, with: `akademik zaman (08.30–18.00), ${fromMinutes(s)} başlangıç` });
  }
  return out;
}
