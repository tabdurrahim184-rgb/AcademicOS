import Link from "next/link";
import {
  addCommitmentAction, addRevisionAction, createWorkTaskAction, deleteCommitmentAction, deleteWorkTaskAction, saveMinuteListAction,
  scheduleWorkTaskAction, setWorkStatusAction,
} from "@/app/actions/modules";
import { ConfirmSubmit } from "@/components/ConfirmSubmit";
import { Flash } from "@/components/Flash";
import { SubmitButton } from "@/components/SubmitButton";
import { requireUser } from "@/lib/auth";
import { withUser } from "@/lib/db";
import { isUuid } from "@/lib/data/courses";
import {
  analyzeWorkTask, commitmentConflicts, ensureWorkSetup, listClients, listCommitments, listWorkTasks, PRIORITIES, taskHistory,
  UNKNOWN_END_ASSUMED_MIN, WORK_KINDS, WORK_STATUSES,
} from "@/lib/data/work";
import { fmtDate, fmtDateTime } from "@/lib/format";
import { trTime, WEEKDAYS } from "@/lib/schedule";

export const metadata = { title: "İş merkezi" };
export const dynamic = "force-dynamic";

export default async function WorkPage({ searchParams }: { searchParams: Promise<Record<string, string | undefined>> }) {
  const sp = await searchParams;
  const user = await requireUser();
  const analyzeId = sp.analiz && isUuid(sp.analiz) ? sp.analiz : null;
  const data = await withUser(user.id, async (tx) => {
    await ensureWorkSetup(tx, user.id);
    const tasks = await listWorkTasks(tx);
    return {
      clients: await listClients(tx),
      commitments: await listCommitments(tx),
      conflicts: await commitmentConflicts(tx),
      tasks,
      histories: Object.fromEntries(await Promise.all(tasks.slice(0, 50).map(async (t) => [t.id, await taskHistory(tx, t.id)] as const))),
      analysis: analyzeId ? await analyzeWorkTask(tx, analyzeId) : null,
    };
  });
  const activeClient = data.clients.find((c) => c.id === sp.isveren) ?? data.clients[0];
  const tasks = data.tasks.filter((t) => t.client_id === activeClient?.id);

  return (
    <div className="mx-auto max-w-5xl space-y-6">
      <Flash sp={sp} />
      <header>
        <h1>İş merkezi</h1>
        <p className="muted">İşlerin akademik hayatını ezmemesi için: iş görevleri hafta içi 08.30–18.00 akademik zamanına <strong>otomatik olarak asla</strong> konmaz; ders araları iş için müsait sayılmaz. Bu sayfadan işverene hiçbir mesaj gönderilmez.</p>
      </header>

      <nav className="flex flex-wrap gap-2" aria-label="İşveren">
        {data.clients.map((c) => (
          <Link key={c.id} href={`/is?isveren=${c.id}`} className={c.id === activeClient?.id ? "btn" : "btn-secondary"} aria-current={c.id === activeClient?.id ? "page" : undefined}>
            {c.name} ({data.tasks.filter((t) => t.client_id === c.id && !["teslim_edildi", "iptal"].includes(t.status)).length})
          </Link>
        ))}
      </nav>

      {data.analysis && (
        <section className="card space-y-2" aria-labelledby="analiz" data-testid="is-analizi">
          <h2 id="analiz">Bu işi alırsam ne etkilenir?</h2>
          {!data.analysis.ok ? <p className="alert-err">{data.analysis.reason}</p> : (
            <>
              <p className="text-sm">Akademik zamanı koruyarak en erken uygun zaman: <strong>{fmtDate(data.analysis.date)} {trTime(data.analysis.start)}</strong>.</p>
              {data.analysis.affected.length === 0 ? (
                <p className="alert-ok">Hiçbir ders çalışma görevin etkilenmiyor.</p>
              ) : (
                <div className="alert-err text-sm">
                  <p>Teslim tarihine yetişmesi için şu ders çalışmalarının zamanı kullanılacak (planlarsan bu görevler başka güne taşınır):</p>
                  <ul className="mt-1 list-disc pl-5">{data.analysis.affected.map((a, i) => <li key={i}>{trTime(a.start)} — {a.label} ({a.minutes} dk)</li>)}</ul>
                </div>
              )}
              <form action={scheduleWorkTaskAction}>
                <input type="hidden" name="taskId" value={analyzeId!} />
                <input type="hidden" name="returnTo" value={`/is?isveren=${activeClient?.id}`} />
                <SubmitButton>Bu zamana planla</SubmitButton>
              </form>
            </>
          )}
        </section>
      )}

      {activeClient && (
        <>
          <section className="card space-y-3" aria-labelledby="yeni-is">
            <h2 id="yeni-is">{activeClient.name} için yeni görev</h2>
            <form action={createWorkTaskAction} className="grid gap-3 sm:grid-cols-3">
              <input type="hidden" name="clientId" value={activeClient.id} />
              <input type="hidden" name="returnTo" value={`/is?isveren=${activeClient.id}`} />
              <label className="text-sm">Tür<select name="kind" className="input mt-1">{Object.entries(WORK_KINDS).map(([k, v]) => <option key={k} value={k}>{v}</option>)}</select></label>
              <label className="text-sm sm:col-span-2">Başlık<input name="title" required className="input mt-1" /></label>
              <label className="text-sm">Talep eden<input name="requestedBy" defaultValue={activeClient.name} className="input mt-1" /></label>
              <label className="text-sm">Öncelik<select name="priority" defaultValue="normal" className="input mt-1">{Object.entries(PRIORITIES).map(([k, v]) => <option key={k} value={k}>{v}</option>)}</select></label>
              <label className="text-sm">Süre tahmini (dk)<input name="estimateMin" type="number" min={5} max={1440} defaultValue={60} className="input mt-1" /></label>
              <label className="text-sm">Teslim tarihi<input name="dueDate" type="date" className="input mt-1" /></label>
              <label className="text-sm">Teslim saati<input name="dueTime" type="time" defaultValue="18:00" className="input mt-1" /></label>
              <label className="text-sm sm:col-span-3">Açıklama<textarea name="description" className="input mt-1" /></label>
              <div><SubmitButton>Görev ekle</SubmitButton></div>
            </form>
          </section>

          <section className="space-y-3" aria-labelledby="gorevler">
            <h2 id="gorevler">Görevler</h2>
            {tasks.length === 0 && <p className="card muted">Bu işveren için görev yok.</p>}
            {tasks.map((t) => (
              <article key={t.id} className={`card space-y-2 text-sm ${["teslim_edildi", "iptal"].includes(t.status) ? "opacity-70" : ""}`} data-testid="is-gorevi">
                <div className="flex flex-wrap items-start justify-between gap-2">
                  <div>
                    <p className="font-medium">{t.title}</p>
                    <p className="muted">
                      {WORK_KINDS[t.kind]} · {PRIORITIES[t.priority]} öncelik · {t.estimate_min} dk · {t.requested_by && `Talep: ${t.requested_by} · `}
                      Teslim: {t.due_at ? fmtDateTime(t.due_at) : "belirtilmedi"}
                    </p>
                    <p>
                      <span className="badge">{WORK_STATUSES[t.status]}</span>{" "}
                      {t.scheduled_date && t.start_time ? <span className="badge-ok">Planlandı: {fmtDate(t.scheduled_date)} {trTime(t.start_time)}</span> : <span className="badge-warn">Zamanı belirlenmedi</span>}
                    </p>
                  </div>
                  <div className="flex flex-wrap gap-2">
                    {!["teslim_edildi", "iptal"].includes(t.status) && <Link className="btn-secondary" href={`/is?isveren=${activeClient.id}&analiz=${t.id}#analiz`}>Etki analizi / planla</Link>}
                    <form action={setWorkStatusAction} className="flex gap-1">
                      <input type="hidden" name="taskId" value={t.id} />
                      <input type="hidden" name="returnTo" value={`/is?isveren=${activeClient.id}`} />
                      <select name="status" defaultValue={t.status} className="input w-auto" aria-label="Durum">{Object.entries(WORK_STATUSES).map(([k, v]) => <option key={k} value={k}>{v}</option>)}</select>
                      <SubmitButton className="btn-secondary">Kaydet</SubmitButton>
                    </form>
                  </div>
                </div>
                {t.description && <p className="whitespace-pre-wrap">{t.description}</p>}
                <details>
                  <summary className="cursor-pointer text-xs">Revizyon, dakika listesi ve geçmiş</summary>
                  <div className="mt-2 grid gap-3 sm:grid-cols-2">
                    <form action={addRevisionAction} className="space-y-1">
                      <input type="hidden" name="taskId" value={t.id} />
                      <input type="hidden" name="returnTo" value={`/is?isveren=${activeClient.id}`} />
                      <label className="block text-xs">Revizyon notu<textarea name="note" required className="input mt-1" /></label>
                      <SubmitButton className="btn-secondary">Revizyon kaydet</SubmitButton>
                    </form>
                    <form action={saveMinuteListAction} className="space-y-1">
                      <input type="hidden" name="taskId" value={t.id} />
                      <input type="hidden" name="returnTo" value={`/is?isveren=${activeClient.id}`} />
                      <label className="block text-xs">Dakika listesi (her satır: 00:12-00:45 açıklama)
                        <textarea name="minutes" defaultValue={t.minute_list.map((m) => `${m.start}-${m.end} ${m.note}`).join("\n")} className="input mt-1 font-mono" />
                      </label>
                      <SubmitButton className="btn-secondary">Listeyi kaydet</SubmitButton>
                    </form>
                  </div>
                  <ul className="mt-2 space-y-1 text-xs">
                    {(data.histories[t.id] ?? []).map((h, i) => <li key={i}><span className="muted">{fmtDateTime(h.created_at)}</span> · {h.event}{h.note && `: ${h.note}`}</li>)}
                  </ul>
                  <form action={deleteWorkTaskAction} className="mt-2">
                    <input type="hidden" name="taskId" value={t.id} />
                    <input type="hidden" name="returnTo" value={`/is?isveren=${activeClient.id}`} />
                    <ConfirmSubmit message="Görev ve geçmişi silinsin mi?">Görevi sil</ConfirmSubmit>
                  </form>
                </details>
              </article>
            ))}
          </section>
        </>
      )}

      <section className="card space-y-2" aria-labelledby="sabit">
        <h2 id="sabit">Sabit iş saatleri</h2>
        <ul className="space-y-1 text-sm">
          {data.commitments.map((c) => (
            <li key={c.id} className="flex flex-wrap items-center justify-between gap-2">
              <span>{WEEKDAYS[c.weekday]} {trTime(c.start_time)}{c.end_time ? `–${trTime(c.end_time)}` : " (bitiş saati belirsiz)"} · {c.title} · {data.clients.find((x) => x.id === c.client_id)?.name}</span>
              <form action={deleteCommitmentAction}><input type="hidden" name="commitmentId" value={c.id} /><ConfirmSubmit message="Sabit iş saati silinsin mi?">Sil</ConfirmSubmit></form>
            </li>
          ))}
        </ul>
        {data.commitments.some((c) => !c.end_time) && <p className="muted">Bitiş saati belirsiz olanlar planlamada {UNKNOWN_END_ASSUMED_MIN} dakika sürüyor kabul edilir; gerçek bitiş saatini öğrendiğinde yeniden ekle.</p>}
        {data.conflicts.length > 0 && (
          <div className="alert-err text-sm">
            <p>Çakışmalar (bilgilendirme — sistem saatleri değiştirmez):</p>
            <ul className="list-disc pl-5">{data.conflicts.map((c, i) => <li key={i}>{WEEKDAYS[c.weekday]}: {c.commitment} ↔ {c.with}</li>)}</ul>
          </div>
        )}
        <form action={addCommitmentAction} className="flex flex-wrap items-end gap-2">
          <label className="text-sm">İşveren<select name="clientId" className="input mt-1 w-auto">{data.clients.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}</select></label>
          <label className="text-sm">Başlık<input name="title" className="input mt-1 w-auto" /></label>
          <label className="text-sm">Gün<select name="weekday" className="input mt-1 w-auto">{WEEKDAYS.slice(1).map((d, i) => <option key={d} value={i + 1}>{d}</option>)}</select></label>
          <label className="text-sm">Başlangıç<input name="start" type="time" required className="input mt-1 w-auto" /></label>
          <label className="text-sm">Bitiş (biliniyorsa)<input name="end" type="time" className="input mt-1 w-auto" /></label>
          <SubmitButton className="btn-secondary">Ekle</SubmitButton>
        </form>
      </section>
    </div>
  );
}
