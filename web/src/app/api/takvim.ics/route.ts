import { getCurrentUser } from "@/lib/auth";
import { withUser } from "@/lib/db";
import { ASSESSMENT_KINDS, listAssessments } from "@/lib/data/assessments";
import { listCourses, listMeetings } from "@/lib/data/courses";
import { getSettings, listPlanTasks, nicosiaNow, PLAN_DAYS, TASK_KINDS } from "@/lib/data/plan";
import { buildIcs, type IcsEvent } from "@/lib/ics";
import { addDays, weekdayOf, weekStart } from "@/lib/planner";
import { fromMinutes, localParts, toMinutes } from "@/lib/schedule";

/** Ders saatleri, plan görevleri ve tarihli sınavları .ics olarak indirir (yalnızca oturum sahibi). */
export async function GET() {
  const user = await getCurrentUser();
  if (!user) return new Response("Oturum gerekli.", { status: 401 });
  const { today } = nicosiaNow();
  const events = await withUser(user.id, async (tx) => {
    const courses = await listCourses(tx);
    const code = (id: string) => courses.find((c) => c.id === id)?.code ?? "";
    const settings = await getSettings(tx, user.id);
    const out: IcsEvent[] = [];
    const monday = weekStart(today);
    for (const m of await listMeetings(tx)) {
      const c = courses.find((x) => x.id === m.course_id)!;
      out.push({
        uid: `ders-${m.id}@academicos`, title: `${c.code} ${c.name}`, description: c.instructor ?? "Öğretim elemanı belirtilmedi",
        date: addDays(monday, m.weekday - weekdayOf(monday)), start: m.start_time, end: m.end_time, weeklyUntil: settings.semesterEnd,
      });
    }
    for (const t of await listPlanTasks(tx, today, addDays(today, PLAN_DAYS - 1))) {
      if (t.status === "atlandi") continue;
      out.push({
        uid: `gorev-${t.id}@academicos`, title: `${t.status === "tamamlandi" ? "✓ " : ""}${t.title}`,
        description: `${TASK_KINDS[t.kind]} · ${code(t.course_id)}${t.detail ? `\n${t.detail}` : ""}`,
        date: t.scheduled_date, start: t.start_time, end: fromMinutes(toMinutes(t.start_time) + t.duration_min),
      });
    }
    for (const a of await listAssessments(tx)) {
      if (!a.due_at) continue; // tarihi bilinmeyen sınav takvime yazılmaz
      const p = localParts(new Date(a.due_at));
      out.push({ uid: `sinav-${a.id}@academicos`, title: `${code(a.course_id)} — ${a.title}`, description: ASSESSMENT_KINDS[a.kind], date: p.date, start: p.time, end: null });
    }
    return out;
  });
  return new Response(buildIcs(events, new Date()), {
    headers: {
      "Content-Type": "text/calendar; charset=utf-8",
      "Content-Disposition": 'attachment; filename="academicos-takvim.ics"',
      "Cache-Control": "private, no-store",
    },
  });
}
