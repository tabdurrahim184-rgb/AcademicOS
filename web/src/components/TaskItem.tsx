import Link from "next/link";
import { completeTaskAction, moveTaskAction, postponeTaskAction, releaseTaskAction, reopenTaskAction } from "@/app/actions/plan";
import { modeForTask, TASK_KINDS, type PlanTask } from "@/lib/data/plan";
import { fromMinutes, toMinutes, trTime } from "@/lib/schedule";
import { SubmitButton } from "./SubmitButton";

const KIND_STYLE: Record<string, string> = {
  telafi: "badge-warn", eksik: "badge-err", sinav: "badge-err", tekrar: "badge-ok", guncel: "badge", materyal: "badge", serbest: "badge",
};

export function TaskItem({ t, returnTo, courseCode }: { t: PlanTask; returnTo: string; courseCode: string }) {
  const end = fromMinutes(toMinutes(t.start_time) + t.duration_min);
  const studyHref = `/calis?${new URLSearchParams({ ders: t.course_id, ...(t.topic_id ? { konu: t.topic_id } : {}), mod: modeForTask(t) })}`;
  const done = t.status === "tamamlandi";
  return (
    <li className={`flex flex-wrap items-start justify-between gap-2 py-3 ${done ? "opacity-70" : ""}`} data-testid="plan-gorevi">
      <div className="min-w-0">
        <p className="text-sm">
          <span className="tabular-nums font-medium">{trTime(t.start_time)}–{trTime(end)}</span>{" "}
          <span className={KIND_STYLE[t.kind]}>{TASK_KINDS[t.kind]}</span>{" "}
          {t.locked && <span className="badge" title="Sizin yerleştirdiğiniz görev; planlayıcı taşımaz">Sabit</span>}{" "}
          {done && <span className="badge-ok">Tamamlandı</span>}
        </p>
        <p className={`mt-1 font-medium ${done ? "line-through" : ""}`}>{t.title}</p>
        {t.detail && <p className="muted">{t.detail}</p>}
        <p className="muted text-xs">{courseCode} · {t.duration_min} dk</p>
      </div>
      <div className="flex flex-wrap items-center gap-2">
        {!done && t.kind !== "materyal" && <Link href={studyHref} className="btn-secondary">Başla</Link>}
        {t.kind === "materyal" && !done && <Link href={`/dersler/${t.course_id}${t.topic_id ? `?konu=${t.topic_id}` : ""}#kaynak-yukle`} className="btn-secondary">Yükle</Link>}
        <form action={done ? reopenTaskAction : completeTaskAction}>
          <input type="hidden" name="taskId" value={t.id} />
          <input type="hidden" name="returnTo" value={returnTo} />
          <SubmitButton className={done ? "btn-secondary" : "btn"} pendingText="…">{done ? "Geri al" : "Tamamlandı"}</SubmitButton>
        </form>
        {!done && (
          <details className="relative">
            <summary className="btn-secondary cursor-pointer list-none">Diğer</summary>
            <div className="absolute right-0 z-10 mt-1 w-64 space-y-2 rounded-lg border border-slate-200 bg-white p-3 shadow-lg dark:border-slate-700 dark:bg-slate-900">
              <form action={postponeTaskAction}>
                <input type="hidden" name="taskId" value={t.id} />
                <input type="hidden" name="returnTo" value={returnTo} />
                <SubmitButton className="btn-secondary w-full">Ertele</SubmitButton>
              </form>
              <form action={moveTaskAction} className="space-y-1">
                <input type="hidden" name="taskId" value={t.id} />
                <input type="hidden" name="returnTo" value={returnTo} />
                <label className="block text-xs">Tarih<input type="date" name="date" defaultValue={t.scheduled_date} required className="input mt-1" /></label>
                <label className="block text-xs">Saat<input type="time" name="start" defaultValue={t.start_time} required className="input mt-1" /></label>
                <SubmitButton className="btn-secondary w-full">Taşı ve sabitle</SubmitButton>
              </form>
              {t.locked && t.kind !== "serbest" && (
                <form action={releaseTaskAction}>
                  <input type="hidden" name="taskId" value={t.id} />
                  <input type="hidden" name="returnTo" value={returnTo} />
                  <SubmitButton className="btn-secondary w-full">Otomatik planlamaya bırak</SubmitButton>
                </form>
              )}
            </div>
          </details>
        )}
      </div>
    </li>
  );
}
