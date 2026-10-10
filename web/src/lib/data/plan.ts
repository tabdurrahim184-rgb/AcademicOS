/**
 * Planlayıcının veritabanı katmanı: ayarlar, çalışma aralıkları, plan üretimi,
 * görev tamamlama / atlama / taşıma ve elle görev ekleme.
 */
import type { Tx } from "../db";
import {
  addDays, DEFAULT_WINDOWS, plan, weekdayOf, type FixedTask, type PlanSettings, type Unplaced, type Window,
} from "../planner";
import { buildDemands } from "../planner-demand";
import { localParts, toMinutes } from "../schedule";
import { advanceTopicStatus, getCourse, getTopic, isUuid, listCourses, listMeetings, listTopics } from "./courses";

export const PLAN_DAYS = 14;

export const TASK_KINDS = {
  telafi: "Telafi", guncel: "Güncel ders", tekrar: "Aralıklı tekrar", eksik: "Eksik tamamlama",
  sinav: "Sınav hazırlığı", materyal: "Materyal", serbest: "Kendi görevim",
} as const;
export type PlanTaskKind = keyof typeof TASK_KINDS;

export type PlanTask = {
  id: string;
  course_id: string;
  topic_id: string | null;
  kind: PlanTaskKind;
  title: string;
  detail: string;
  origin_key: string;
  scheduled_date: string;
  start_time: string;
  duration_min: number;
  status: "planlandi" | "tamamlandi" | "atlandi";
  locked: boolean;
  completed_at: Date | null;
};

export type StoredSettings = PlanSettings & { semesterEnd: string | null; lastGeneratedOn: string | null; lastUnplaced: Unplaced[] };

const TASK_COLS = `id, course_id, topic_id, kind, title, detail, origin_key, to_char(scheduled_date,'YYYY-MM-DD') AS scheduled_date,
  to_char(start_time,'HH24:MI') AS start_time, duration_min, status, locked, completed_at`;

export function nicosiaNow(now = new Date()) {
  const p = localParts(now);
  return { today: p.date, time: p.time };
}

export async function getSettings(tx: Tx, userId: string): Promise<StoredSettings> {
  const created = await tx.query("INSERT INTO planner_settings (user_id) VALUES ($1) ON CONFLICT DO NOTHING RETURNING user_id", [userId]);
  if (created.rowCount) {
    // İlk kullanım: varsayılan çalışma aralıkları bir kez oluşturulur (kullanıcı silerse yeniden eklenmez).
    for (const w of DEFAULT_WINDOWS) {
      await tx.query("INSERT INTO availability_windows (user_id, weekday, start_time, end_time) VALUES ($1,$2,$3,$4)", [userId, w.weekday, w.start, w.end]);
    }
  }
  const { rows } = await tx.query(
    `SELECT weekday_capacity_min, weekend_capacity_min, max_task_min, break_min, catch_up_share,
            to_char(semester_end,'YYYY-MM-DD') AS semester_end, to_char(last_generated_on,'YYYY-MM-DD') AS last_generated_on, last_unplaced
     FROM planner_settings`,
  );
  const r = rows[0];
  return {
    weekdayCapacityMin: r.weekday_capacity_min, weekendCapacityMin: r.weekend_capacity_min, maxTaskMin: r.max_task_min,
    breakMin: r.break_min, catchUpShare: r.catch_up_share, semesterEnd: r.semester_end, lastGeneratedOn: r.last_generated_on,
    lastUnplaced: r.last_unplaced,
  };
}

export async function updateSettings(tx: Tx, userId: string, s: PlanSettings & { semesterEnd: string | null }) {
  await getSettings(tx, userId);
  await tx.query(
    `UPDATE planner_settings SET weekday_capacity_min=$1, weekend_capacity_min=$2, max_task_min=$3, break_min=$4,
       catch_up_share=$5, semester_end=$6, updated_at=now(), last_generated_on=NULL`,
    [s.weekdayCapacityMin, s.weekendCapacityMin, s.maxTaskMin, s.breakMin, s.catchUpShare, s.semesterEnd],
  );
}

export async function getWindows(tx: Tx, userId: string): Promise<Array<Window & { id: string }>> {
  await getSettings(tx, userId);
  const { rows } = await tx.query<Window & { id: string }>(
    "SELECT id, weekday, to_char(start_time,'HH24:MI') AS start, to_char(end_time,'HH24:MI') AS end FROM availability_windows ORDER BY weekday, start_time",
  );
  return rows;
}

export async function addWindow(tx: Tx, userId: string, w: Window) {
  if (!(w.weekday >= 1 && w.weekday <= 7) || toMinutes(w.end) <= toMinutes(w.start)) throw new Error("Geçerli bir gün ve saat aralığı girin.");
  await tx.query("INSERT INTO availability_windows (user_id, weekday, start_time, end_time) VALUES ($1,$2,$3,$4)", [userId, w.weekday, w.start, w.end]);
  await tx.query("UPDATE planner_settings SET last_generated_on = NULL");
}

export async function deleteWindow(tx: Tx, id: string) {
  await tx.query("DELETE FROM availability_windows WHERE id=$1", [id]);
  await tx.query("UPDATE planner_settings SET last_generated_on = NULL");
}

export async function listPlanTasks(tx: Tx, from: string, to: string): Promise<PlanTask[]> {
  const { rows } = await tx.query<PlanTask>(
    `SELECT ${TASK_COLS} FROM plan_tasks WHERE scheduled_date BETWEEN $1 AND $2 ORDER BY scheduled_date, start_time`,
    [from, to],
  );
  return rows;
}

export async function listOverdueTasks(tx: Tx, today: string): Promise<PlanTask[]> {
  const { rows } = await tx.query<PlanTask>(
    `SELECT ${TASK_COLS} FROM plan_tasks WHERE scheduled_date < $1 AND status='planlandi' ORDER BY scheduled_date, start_time`,
    [today],
  );
  return rows;
}

/**
 * Planı yeniden üretir:
 *  - Kullanıcının kilitlediği görevlere ve tamamlanmış görevlere dokunulmaz.
 *  - Otomatik, tamamlanmamış görevler (geçmiş dahil) silinir ve güncel durumdan yeniden planlanır;
 *    böylece yapılmayan işler kaybolmaz, sonraki uygun güne taşınır.
 */
export async function regeneratePlan(tx: Tx, userId: string, now = new Date()) {
  const { today, time } = nicosiaNow(now);
  const settings = await getSettings(tx, userId);
  const windows = await getWindows(tx, userId);
  const last = addDays(today, PLAN_DAYS - 1);

  await tx.query("DELETE FROM plan_tasks WHERE status='planlandi' AND locked=false");

  const courses = await listCourses(tx);
  const topics = await listTopics(tx);
  const meetings = await listMeetings(tx);
  const { rows: mistakes } = await tx.query<{ topic_id: string; n: string }>(
    `SELECT q.topic_id, count(*) AS n FROM mistakes m JOIN questions q ON q.id=m.question_id
     WHERE m.status='acik' AND q.topic_id IS NOT NULL GROUP BY q.topic_id`,
  );
  const { rows: due } = await tx.query<{ course_id: string; date: string; count: string }>(
    `SELECT q.course_id, to_char((r.due_at AT TIME ZONE 'Europe/Nicosia')::date,'YYYY-MM-DD') AS date, count(*) AS count
     FROM review_cards r JOIN questions q ON q.id = r.question_id
     WHERE (r.due_at AT TIME ZONE 'Europe/Nicosia')::date <= $1::date GROUP BY 1, 2`,
    [last],
  );
  // Geçmiş vadeli kartlar bugüne toplanır
  const dueMap = new Map<string, number>();
  for (const d of due) {
    const date = d.date < today ? today : d.date;
    const k = `${d.course_id}|${date}`;
    dueMap.set(k, (dueMap.get(k) ?? 0) + Number(d.count));
  }
  const { rows: assess } = await tx.query<{ id: string; course_id: string; title: string; due_date: string | null }>(
    `SELECT id, course_id, title, to_char((due_at AT TIME ZONE 'Europe/Nicosia')::date,'YYYY-MM-DD') AS due_date
     FROM assessments WHERE score IS NULL`,
  );
  const { rows: done } = await tx.query<{ origin_key: string }>("SELECT origin_key FROM plan_tasks WHERE status = 'tamamlandi'");
  // "Ertele" ile atlanan görevler bugün yeniden planlanmaz, yarından itibaren planlanır.
  const { rows: postponed } = await tx.query<{ origin_key: string }>(
    "SELECT DISTINCT origin_key FROM plan_tasks WHERE status = 'atlandi' AND scheduled_date >= $1",
    [today],
  );
  const postponedKeys = new Set(postponed.map((p) => p.origin_key.replace(/#\d+$/, "")));
  const { rows: kept } = await tx.query<PlanTask & { catch_up: boolean }>(
    `SELECT ${TASK_COLS}, (kind IN ('telafi')) AS catch_up FROM plan_tasks WHERE scheduled_date BETWEEN $1 AND $2 AND status <> 'atlandi'`,
    [today, last],
  );
  const mistakeMap = new Map(mistakes.map((m) => [m.topic_id, Number(m.n)]));
  const keptKeys = new Set(kept.map((k) => k.origin_key));

  const demands = buildDemands({
    today,
    days: PLAN_DAYS,
    courses,
    topics: topics.map((t) => ({ ...t, openMistakes: mistakeMap.get(t.id) ?? 0 })),
    meetings: meetings.map((m) => ({ course_id: m.course_id, weekday: m.weekday, end_time: m.end_time })),
    dueByCourseDate: [...dueMap.entries()].map(([k, count]) => ({ course_id: k.split("|")[0], date: k.split("|")[1], count })),
    assessments: assess,
    completedKeys: new Set(done.map((d) => d.origin_key)),
  })
    .filter((d) => !keptKeys.has(d.key) && ![...keptKeys].some((k) => k.startsWith(`${d.key}#`)))
    .map((d) => (postponedKeys.has(d.key) && d.earliest <= today ? { ...d, earliest: addDays(today, 1), earliestTime: undefined } : d));

  const fixed: FixedTask[] = kept.map((k) => ({
    date: k.scheduled_date, start: k.start_time, minutes: k.duration_min, courseId: k.course_id, topicId: k.topic_id, catchUp: k.catch_up,
  }));
  const result = plan({
    startDate: today, days: PLAN_DAYS, nowTime: time, settings,
    windows: windows.map(({ weekday, start, end }) => ({ weekday, start, end })),
    meetings: meetings.map((m) => ({ weekday: m.weekday, start: m.start_time, end: m.end_time })),
    fixed, demands,
  });
  for (const p of result.placed) {
    await tx.query(
      `INSERT INTO plan_tasks (user_id, course_id, topic_id, kind, title, detail, origin_key, scheduled_date, start_time, duration_min)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)`,
      [userId, p.courseId, p.topicId, p.kind, p.title, p.detail, p.key, p.date, p.start, p.minutes],
    );
  }
  await tx.query("UPDATE planner_settings SET last_generated_on=$1, last_unplaced=$2", [today, JSON.stringify(result.unplaced)]);
  return { placed: result.placed.length, unplaced: result.unplaced };
}

/** Plan bugün üretilmediyse (gün döndüyse, ayar değiştiyse) yeniden üretir. */
export async function ensureFreshPlan(tx: Tx, userId: string, now = new Date()) {
  const s = await getSettings(tx, userId);
  if (s.lastGeneratedOn !== nicosiaNow(now).today) await regeneratePlan(tx, userId, now);
}

async function getTask(tx: Tx, id: string): Promise<PlanTask | null> {
  if (!isUuid(id)) return null;
  const { rows } = await tx.query<PlanTask>(`SELECT ${TASK_COLS} FROM plan_tasks WHERE id=$1`, [id]);
  return rows[0] ?? null;
}

/** Görevi tamamlar; konu görevlerinde konunun ilerleme durumunu ileri taşır. */
export async function completeTask(tx: Tx, id: string) {
  const t = await getTask(tx, id);
  if (!t) throw new Error("Görev bulunamadı.");
  if (t.status === "tamamlandi") return;
  await tx.query("UPDATE plan_tasks SET status='tamamlandi', completed_at=now() WHERE id=$1", [id]);
  if (t.topic_id) {
    const key = t.origin_key.replace(/#\d+$/, "");
    const isLastPart = !/#\d+$/.test(t.origin_key) || !(await tx.query(
      "SELECT 1 FROM plan_tasks WHERE origin_key LIKE $1 AND status='planlandi'", [`${key}#%`],
    )).rowCount;
    if (isLastPart && key.startsWith("calis:")) await advanceTopicStatus(tx, t.topic_id, "okundu");
    if (isLastPart && key.startsWith("hatirla:")) await advanceTopicStatus(tx, t.topic_id, "soru_calisildi");
  }
}

/** Görevi erteler: bugün yeniden planlanmaz; gerekiyorsa sonraki günlere yerleşir. */
export async function postponeTask(tx: Tx, id: string) {
  await tx.query("UPDATE plan_tasks SET status='atlandi', locked=false WHERE id=$1 AND status='planlandi'", [id]);
  await markPlanStale(tx);
}

export async function reopenTask(tx: Tx, id: string) {
  await tx.query("UPDATE plan_tasks SET status='planlandi', completed_at=NULL WHERE id=$1", [id]);
}

/** Kilidi kaldırır; görev bir sonraki üretimde otomatik olarak yeniden planlanır. */
export async function releaseTask(tx: Tx, id: string) {
  await tx.query("UPDATE plan_tasks SET locked=false WHERE id=$1 AND kind <> 'serbest'", [id]);
  await markPlanStale(tx);
}

async function assertSlotFree(tx: Tx, date: string, start: string, minutes: number, exceptId: string | null) {
  const s = toMinutes(start);
  const e = s + minutes;
  if (e > 24 * 60) throw new Error("Görev gece yarısını geçemez.");
  const meetings = await listMeetings(tx);
  for (const m of meetings.filter((m) => m.weekday === weekdayOf(date))) {
    if (s < toMinutes(m.end_time) && toMinutes(m.start_time) < e) throw new Error("Bu saat bir ders saatiyle çakışıyor.");
  }
  const { rows } = await tx.query<{ start_time: string; duration_min: number; title: string }>(
    `SELECT to_char(start_time,'HH24:MI') AS start_time, duration_min, title FROM plan_tasks
     WHERE scheduled_date=$1 AND status <> 'atlandi' AND (locked OR status = 'tamamlandi') AND ($2::uuid IS NULL OR id <> $2)`,
    [date, exceptId],
  );
  for (const r of rows) {
    const rs = toMinutes(r.start_time);
    if (s < rs + r.duration_min && rs < e) throw new Error(`Bu saat "${r.title}" göreviyle çakışıyor.`);
  }
}

/** Görevi başka gün/saate taşır ve kilitler (planlayıcı artık taşımaz). */
export async function moveTask(tx: Tx, id: string, date: string, start: string) {
  const t = await getTask(tx, id);
  if (!t) throw new Error("Görev bulunamadı.");
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date) || !/^\d{2}:\d{2}$/.test(start)) throw new Error("Geçerli tarih ve saat girin.");
  await assertSlotFree(tx, date, start, t.duration_min, id);
  await tx.query("UPDATE plan_tasks SET scheduled_date=$2, start_time=$3, locked=true WHERE id=$1", [id, date, start]);
  await markPlanStale(tx);
}

/** Kullanıcı değişikliğinden sonra otomatik görevler bir sonraki açılışta yeniden yerleştirilir. */
async function markPlanStale(tx: Tx) {
  await tx.query("UPDATE planner_settings SET last_generated_on = NULL");
}

export async function addManualTask(
  tx: Tx,
  userId: string,
  input: { courseId: string; topicId: string | null; title: string; date: string; start: string; minutes: number },
) {
  if (!(await getCourse(tx, input.courseId))) throw new Error("Ders bulunamadı.");
  if (input.topicId) {
    const t = await getTopic(tx, input.topicId);
    if (!t || t.course_id !== input.courseId) throw new Error("Konu bu derse ait değil.");
  }
  if (input.title.trim().length < 2) throw new Error("Görev başlığı girin.");
  if (!(input.minutes >= 5 && input.minutes <= 240)) throw new Error("Süre 5–240 dakika olmalı.");
  if (!/^\d{4}-\d{2}-\d{2}$/.test(input.date) || !/^\d{2}:\d{2}$/.test(input.start)) throw new Error("Geçerli tarih ve saat girin.");
  await assertSlotFree(tx, input.date, input.start, input.minutes, null);
  await tx.query(
    `INSERT INTO plan_tasks (user_id, course_id, topic_id, kind, title, origin_key, scheduled_date, start_time, duration_min, locked)
     VALUES ($1,$2,$3,'serbest',$4,$5,$6,$7,$8,true)`,
    [userId, input.courseId, input.topicId, input.title.trim(), `serbest:${Date.now()}`, input.date, input.start, input.minutes],
  );
  await markPlanStale(tx);
}

/** Görevin çalışma oturumunu başlatmak için uygun mod */
export function modeForTask(t: Pick<PlanTask, "kind" | "origin_key">) {
  if (t.kind === "tekrar") return "hizli_tekrar";
  if (t.kind === "sinav") return "sinav_hazirligi";
  if (t.kind === "eksik") return "eksik_tamamlama";
  if (t.origin_key.startsWith("hatirla:")) return "aktif_hatirlama";
  return "okuma";
}
