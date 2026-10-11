import Link from "next/link";
import { requireUser } from "@/lib/auth";
import { withUser } from "@/lib/db";
import { listCourses, listMeetings, listTopics, scheduleConflicts } from "@/lib/data/courses";
import { trTime, WEEKDAYS } from "@/lib/schedule";

export const metadata = { title: "Derslerim" };
export const dynamic = "force-dynamic";

export default async function CoursesPage() {
  const user = await requireUser();
  const { courses, meetings, conflicts, topics } = await withUser(user.id, async (tx) => ({
    courses: await listCourses(tx),
    meetings: await listMeetings(tx),
    conflicts: await scheduleConflicts(tx),
    topics: await listTopics(tx),
  }));
  return (
    <div className="mx-auto max-w-6xl space-y-6">
      <h1>Derslerim <span className="muted font-normal">({courses.length})</span></h1>
      {conflicts.length > 0 && (
        <section className="alert-info" aria-labelledby="cakisma">
          <h2 id="cakisma" className="text-base">Ders saati çakışmaları</h2>
          <p className="mt-1">Aşağıdaki saatler kayıtlı programa göre çakışıyor. Sistem dersleri senin onayın olmadan değiştirmez; doğrulamak için ders sayfasından saatleri düzenleyebilirsin.</p>
          <ul className="mt-2 list-disc pl-5">
            {conflicts.map((c, i) => (
              <li key={i}>{WEEKDAYS[c.weekday]} {trTime(c.overlapStart)}–{trTime(c.overlapEnd)}: {c.a.courseLabel} ↔ {c.b.courseLabel}</li>
            ))}
          </ul>
        </section>
      )}
      <ul className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
        {courses.map((c) => {
          const ms = meetings.filter((m) => m.course_id === c.id);
          const ts = topics.filter((t) => t.course_id === c.id);
          return (
            <li key={c.id}>
              <Link href={`/dersler/${c.id}`} className="card block h-full no-underline hover:border-indigo-300 hover:no-underline" data-testid="ders-karti">
                <span className="badge">{c.code}</span>
                <span className="mt-2 block font-semibold text-slate-900 dark:text-slate-100">{c.name}</span>
                <span className="muted block">{c.instructor ?? "Öğretim elemanı belirtilmedi"}</span>
                <span className="mt-2 block text-sm text-slate-700 dark:text-slate-300">
                  {ms.length ? ms.map((m) => `${WEEKDAYS[m.weekday]} ${trTime(m.start_time)}–${trTime(m.end_time)}`).join("; ") : c.delivery === "cevrimici" ? "Çevrimiçi" : "Saat girilmedi"}
                </span>
                <span className="muted mt-2 block">{ts.length} konu · {ts.filter((t) => t.status === "tamamlandi").length} tamamlandı</span>
              </Link>
            </li>
          );
        })}
      </ul>
    </div>
  );
}
