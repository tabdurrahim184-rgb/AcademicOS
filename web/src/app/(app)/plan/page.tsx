import Link from "next/link";
import { addTaskAction, regenerateAction } from "@/app/actions/plan";
import { Flash } from "@/components/Flash";
import { SubmitButton } from "@/components/SubmitButton";
import { TaskItem } from "@/components/TaskItem";
import { requireUser } from "@/lib/auth";
import { withUser } from "@/lib/db";
import { listCourses } from "@/lib/data/courses";
import { ensureFreshPlan, getSettings, listOverdueTasks, listPlanTasks, nicosiaNow, PLAN_DAYS } from "@/lib/data/plan";
import { addDays, capacityFor, dateRange } from "@/lib/planner";

export const metadata = { title: "Çalışma planı" };
export const dynamic = "force-dynamic";

const fmtDay = (date: string) =>
  new Intl.DateTimeFormat("tr-TR", { weekday: "long", day: "numeric", month: "long", timeZone: "UTC" }).format(new Date(`${date}T00:00:00Z`));

export default async function PlanPage({ searchParams }: { searchParams: Promise<Record<string, string | undefined>> }) {
  const sp = await searchParams;
  const user = await requireUser();
  const { today } = nicosiaNow();
  const last = addDays(today, PLAN_DAYS - 1);
  const data = await withUser(user.id, async (tx) => {
    await ensureFreshPlan(tx, user.id);
    return {
      settings: await getSettings(tx, user.id),
      tasks: await listPlanTasks(tx, today, last),
      overdue: await listOverdueTasks(tx, today),
      courses: await listCourses(tx),
    };
  });
  const code = (id: string) => data.courses.find((c) => c.id === id)?.code ?? "";
  const days = dateRange(today, PLAN_DAYS);
  const totalPlanned = data.tasks.filter((t) => t.status !== "atlandi").reduce((n, t) => n + t.duration_min, 0);
  const totalDone = data.tasks.filter((t) => t.status === "tamamlandi").reduce((n, t) => n + t.duration_min, 0);

  return (
    <div className="mx-auto max-w-5xl space-y-6">
      <Flash sp={sp} />
      <header className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h1>14 günlük çalışma planı</h1>
          <p className="muted">
            {fmtDay(today)} – {fmtDay(last)} · Planlanan {Math.round(totalPlanned / 60 * 10) / 10} saat · Tamamlanan {Math.round(totalDone / 60 * 10) / 10} saat
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          <form action={regenerateAction}><input type="hidden" name="returnTo" value="/plan" /><SubmitButton className="btn-secondary" pendingText="Planlanıyor…">Planı yeniden oluştur</SubmitButton></form>
          <Link href="/plan/ayarlar" className="btn-secondary">Kapasite ve saatler</Link>
        </div>
      </header>

      <p className="alert-info">
        Plan; konu durumlarından, yanlışlarından, tekrar kartlarından, ders saatlerinden ve tarihi bilinen sınavlardan otomatik oluşturulur ve her gün yeniden düzenlenir.
        Yapılmayan görevler kaybolmaz, sonraki uygun güne taşınır. Ders saatlerine ve günlük kapasitenin ({data.settings.weekdayCapacityMin} dk hafta içi, {data.settings.weekendCapacityMin} dk hafta sonu) üstüne görev konmaz.
        Telafi görevleri bir günün kapasitesinin en fazla %{data.settings.catchUpShare}&apos;ini kullanır.
      </p>

      {data.overdue.length > 0 && (
        <section className="card" aria-labelledby="geciken">
          <h2 id="geciken">Geciken sabit görevler</h2>
          <p className="muted">Bu görevleri sen yerleştirdiğin için planlayıcı taşımadı. Tamamla, yeni bir zamana taşı veya otomatik planlamaya bırak.</p>
          <ul className="divide-y divide-slate-200 dark:divide-slate-800">
            {data.overdue.map((t) => <TaskItem key={t.id} t={t} returnTo="/plan" courseCode={code(t.course_id)} />)}
          </ul>
        </section>
      )}

      {days.map((date) => {
        const list = data.tasks.filter((t) => t.scheduled_date === date && t.status !== "atlandi");
        const minutes = list.reduce((n, t) => n + t.duration_min, 0);
        const cap = capacityFor(date, data.settings);
        return (
          <section key={date} className="card" aria-labelledby={`gun-${date}`} data-testid="plan-gunu">
            <div className="flex flex-wrap items-baseline justify-between gap-2">
              <h2 id={`gun-${date}`} className="text-base">{date === today ? "Bugün — " : ""}{fmtDay(date)}</h2>
              <span className="muted tabular-nums" data-testid="gun-toplami">{minutes} / {cap} dk</span>
            </div>
            {list.length === 0 ? <p className="muted mt-1">Planlanmış görev yok.</p> : (
              <ul className="divide-y divide-slate-200 dark:divide-slate-800">
                {list.map((t) => <TaskItem key={t.id} t={t} returnTo="/plan" courseCode={code(t.course_id)} />)}
              </ul>
            )}
          </section>
        );
      })}

      {data.settings.lastUnplaced.length > 0 && (
        <section className="card" aria-labelledby="sigmayan">
          <h2 id="sigmayan">Plana sığmayan çalışmalar ({data.settings.lastUnplaced.length})</h2>
          <p className="muted">Bunlar gerçek kapasitene sığmadığı için planlanmadı. Günlük kapasiteyi veya çalışma aralıklarını gerçekçi biçimde artırabilir, ya da telafi payını değiştirebilirsin.</p>
          <ul className="mt-2 list-disc space-y-1 pl-5 text-sm">
            {data.settings.lastUnplaced.slice(0, 30).map((u) => <li key={u.key}>{u.title} <span className="muted">— {u.reason}</span></li>)}
          </ul>
        </section>
      )}

      <section className="card" aria-labelledby="ekle">
        <h2 id="ekle">Kendi görevini ekle</h2>
        <form action={addTaskAction} className="mt-3 grid gap-3 sm:grid-cols-3">
          <input type="hidden" name="returnTo" value="/plan" />
          <label className="text-sm">Ders<select name="courseId" className="input mt-1" required>{data.courses.map((c) => <option key={c.id} value={c.id}>{c.code} {c.name}</option>)}</select></label>
          <label className="text-sm sm:col-span-2">Başlık<input name="title" required className="input mt-1" placeholder="ör. Makale okuması" /></label>
          <label className="text-sm">Tarih<input name="date" type="date" required defaultValue={today} className="input mt-1" /></label>
          <label className="text-sm">Saat<input name="start" type="time" required className="input mt-1" /></label>
          <label className="text-sm">Süre (dk)<input name="minutes" type="number" min={5} max={240} defaultValue={45} required className="input mt-1" /></label>
          <div className="sm:col-span-3"><SubmitButton>Ekle</SubmitButton></div>
        </form>
      </section>
    </div>
  );
}
