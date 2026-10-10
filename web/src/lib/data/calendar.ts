import type { Tx } from "../db";
import { addDays, dateRange, weekdayOf } from "../planner";
import { findConflicts, fromMinutes, localParts, toMinutes, type Meeting } from "../schedule";
import { ASSESSMENT_KINDS, listAssessments } from "./assessments";
import { listCourses, listMeetings } from "./courses";
import { listPlanTasks, TASK_KINDS } from "./plan";
import { STUDY_MODES } from "./study";

export type CalEvent = {
  type: "ders" | "gorev" | "sinav" | "oturum";
  date: string;
  start: string | null; // null = gün boyu / saat yok
  end: string | null;
  title: string;
  subtitle: string;
  href: string;
  conflict?: string;
  done?: boolean;
};

export async function loadWeek(tx: Tx, weekStartDate: string) {
  const days = dateRange(weekStartDate, 7);
  const last = days[6];
  const courses = await listCourses(tx);
  const code = (id: string) => courses.find((c) => c.id === id)?.code ?? "";
  const meetings = await listMeetings(tx);
  const conflicts = findConflicts(
    meetings.map<Meeting>((m) => ({ id: m.id, courseId: m.course_id, courseLabel: code(m.course_id), weekday: m.weekday, start: m.start_time, end: m.end_time })),
  );
  const events: CalEvent[] = [];

  for (const date of days) {
    for (const m of meetings.filter((m) => m.weekday === weekdayOf(date))) {
      const c = conflicts.find((x) => x.a.id === m.id || x.b.id === m.id);
      const other = c ? (c.a.id === m.id ? c.b : c.a).courseLabel : null;
      const course = courses.find((x) => x.id === m.course_id)!;
      events.push({
        type: "ders", date, start: m.start_time, end: m.end_time, title: `${course.code} ${course.name}`,
        subtitle: course.instructor ?? "Öğretim elemanı belirtilmedi", href: `/dersler/${course.id}`,
        conflict: other ? `${other} ile çakışıyor` : undefined,
      });
    }
  }
  for (const t of await listPlanTasks(tx, weekStartDate, last)) {
    if (t.status === "atlandi") continue;
    events.push({
      type: "gorev", date: t.scheduled_date, start: t.start_time, end: fromMinutes(toMinutes(t.start_time) + t.duration_min),
      title: t.title, subtitle: `${TASK_KINDS[t.kind]} · ${t.duration_min} dk`, href: "/plan", done: t.status === "tamamlandi",
    });
  }
  const assessments = await listAssessments(tx);
  for (const a of assessments) {
    if (!a.due_at) continue;
    const p = localParts(new Date(a.due_at));
    if (p.date < weekStartDate || p.date > last) continue;
    events.push({
      type: "sinav", date: p.date, start: p.time, end: null, title: `${code(a.course_id)} — ${a.title}`,
      subtitle: ASSESSMENT_KINDS[a.kind], href: `/dersler/${a.course_id}#sinavlar`,
    });
  }
  const { rows: sessions } = await tx.query<{ id: string; course_id: string; mode: keyof typeof STUDY_MODES; started_at: Date; last_activity_at: Date }>(
    `SELECT id, course_id, mode, started_at, last_activity_at FROM study_sessions
     WHERE started_at >= ($1::date - 1) AND started_at < ($2::date + 2)`,
    [weekStartDate, last],
  );
  for (const s of sessions) {
    const a = localParts(new Date(s.started_at));
    if (a.date < weekStartDate || a.date > last) continue;
    const b = localParts(new Date(s.last_activity_at));
    events.push({
      type: "oturum", date: a.date, start: a.time, end: b.date === a.date && b.time > a.time ? b.time : null,
      title: `${code(s.course_id)} — ${STUDY_MODES[s.mode].label}`, subtitle: "Gerçekleşen çalışma oturumu", href: `/oturum/${s.id}`,
    });
  }
  events.sort((x, y) => x.date.localeCompare(y.date) || (x.start ?? "").localeCompare(y.start ?? ""));
  const undated = assessments.filter((a) => !a.due_at && a.score == null).map((a) => ({ ...a, code: code(a.course_id) }));
  return { days, events, undated, prev: addDays(weekStartDate, -7), next: addDays(weekStartDate, 7) };
}
