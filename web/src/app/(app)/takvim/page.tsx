import Link from "next/link";
import { requireUser } from "@/lib/auth";
import { withUser } from "@/lib/db";
import { loadWeek, type CalEvent } from "@/lib/data/calendar";
import { nicosiaNow } from "@/lib/data/plan";
import { weekStart } from "@/lib/planner";
import { trTime } from "@/lib/schedule";

export const metadata = { title: "Takvim" };
export const dynamic = "force-dynamic";

const TYPE: Record<CalEvent["type"], { label: string; cls: string }> = {
  ders: { label: "Ders", cls: "border-l-indigo-500" },
  gorev: { label: "Çalışma", cls: "border-l-emerald-500" },
  sinav: { label: "Sınav / teslim", cls: "border-l-red-500" },
  oturum: { label: "Yapılan çalışma", cls: "border-l-slate-400" },
};

const fmtDay = (date: string, opts: Intl.DateTimeFormatOptions) => new Intl.DateTimeFormat("tr-TR", { ...opts, timeZone: "UTC" }).format(new Date(`${date}T00:00:00Z`));

export default async function CalendarPage({ searchParams }: { searchParams: Promise<{ hafta?: string }> }) {
  const { hafta } = await searchParams;
  const user = await requireUser();
  const { today } = nicosiaNow();
  const start = weekStart(hafta && /^\d{4}-\d{2}-\d{2}$/.test(hafta) ? hafta : today);
  const w = await withUser(user.id, (tx) => loadWeek(tx, start));

  return (
    <div className="mx-auto max-w-7xl space-y-4">
      <header className="flex flex-wrap items-center justify-between gap-3">
        <h1>Takvim <span className="muted font-normal">{fmtDay(w.days[0], { day: "numeric", month: "long" })} – {fmtDay(w.days[6], { day: "numeric", month: "long", year: "numeric" })}</span></h1>
        <nav className="flex flex-wrap gap-2" aria-label="Hafta">
          <Link href={`/takvim?hafta=${w.prev}`} className="btn-secondary">← Önceki</Link>
          <Link href="/takvim" className="btn-secondary">Bu hafta</Link>
          <Link href={`/takvim?hafta=${w.next}`} className="btn-secondary">Sonraki →</Link>
          <a href="/api/takvim.ics" className="btn-secondary" download>Takvime aktar (.ics)</a>
        </nav>
      </header>
      <p className="muted flex flex-wrap gap-3 text-xs">
        {Object.values(TYPE).map((t) => <span key={t.label} className={`border-l-4 pl-2 ${t.cls}`}>{t.label}</span>)}
        <span>Saatler Kıbrıs yerel saatidir (yaz/kış saati otomatik).</span>
      </p>
      {w.undated.length > 0 && (
        <p className="alert-info text-sm">Tarih bekleniyor: {w.undated.map((a) => `${a.code} — ${a.title}`).join("; ")}. Tarih öğrenilince ders sayfasından ekleyebilirsin; takvime tahmini tarih yazılmaz.</p>
      )}
      <div className="grid gap-3 lg:grid-cols-7">
        {w.days.map((date) => {
          const list = w.events.filter((e) => e.date === date);
          return (
            <section key={date} className={`card p-3 ${date === today ? "ring-2 ring-indigo-400" : ""}`} aria-labelledby={`d-${date}`} data-testid="takvim-gunu">
              <h2 id={`d-${date}`} className="text-sm">{fmtDay(date, { weekday: "long" })} <span className="muted font-normal">{fmtDay(date, { day: "numeric", month: "short" })}</span></h2>
              {list.length === 0 ? <p className="muted mt-2 text-xs">Boş</p> : (
                <ul className="mt-2 space-y-2">
                  {list.map((e, i) => (
                    <li key={i} className={`rounded border-l-4 bg-slate-50 px-2 py-1 text-xs dark:bg-slate-800/60 ${TYPE[e.type].cls} ${e.done ? "opacity-60" : ""}`}>
                      <Link href={e.href} className="block text-slate-900 no-underline hover:underline dark:text-slate-100">
                        <span className="tabular-nums font-semibold">{e.start ? trTime(e.start) : "Gün boyu"}{e.end ? `–${trTime(e.end)}` : ""}</span>{" "}
                        <span className={e.done ? "line-through" : ""}>{e.title}</span>
                      </Link>
                      <span className="muted block text-xs">{e.subtitle}</span>
                      {e.conflict && <span className="badge-warn mt-1">Çakışma: {e.conflict}</span>}
                    </li>
                  ))}
                </ul>
              )}
            </section>
          );
        })}
      </div>
    </div>
  );
}
