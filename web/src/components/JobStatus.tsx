import { cancelJobAction, resumeJobAction } from "@/app/actions/media";
import type { Job } from "@/lib/jobs";
import { AutoRefresh } from "./AutoRefresh";
import { SubmitButton } from "./SubmitButton";

const LABEL = { bekliyor: "Sırada", calisiyor: "Çalışıyor", tamamlandi: "Tamamlandı", hata: "Hata", iptal: "İptal edildi" } as const;

export function JobStatus({ job, returnTo, paid = false }: { job: Job | undefined; returnTo: string; paid?: boolean }) {
  if (!job) return null;
  const active = job.status === "bekliyor" || job.status === "calisiyor";
  const stale = active && Date.now() - new Date(job.updated_at).getTime() > 10 * 60_000;
  const pct = job.total ? Math.round((job.progress / job.total) * 100) : 0;
  return (
    <div className="rounded-lg border border-slate-200 p-3 text-sm dark:border-slate-700" data-testid="is-durumu" aria-live="polite">
      <AutoRefresh active={active && !stale} />
      <p>
        <strong>{job.kind === "ocr" ? "OCR" : "Deşifre"}:</strong> {LABEL[job.status]}
        {job.total > 0 && ` — ${job.progress}/${job.total} ${job.kind === "ocr" ? "sayfa" : "parça"} (%${pct})`}
        {job.message && ` · ${job.message}`}
      </p>
      {job.total > 0 && <div className="mt-2 h-2 rounded bg-slate-200 dark:bg-slate-700"><div className="h-2 rounded bg-indigo-600" style={{ width: `${pct}%` }} /></div>}
      <div className="mt-2 flex flex-wrap gap-2">
        {active && (
          <form action={cancelJobAction}>
            <input type="hidden" name="jobId" value={job.id} />
            <input type="hidden" name="returnTo" value={returnTo} />
            <SubmitButton className="btn-secondary">İptal et</SubmitButton>
          </form>
        )}
        {(job.status === "hata" || job.status === "iptal" || stale) && (
          <form action={resumeJobAction} className="flex flex-wrap items-center gap-2">
            <input type="hidden" name="jobId" value={job.id} />
            <input type="hidden" name="returnTo" value={returnTo} />
            {paid && <label className="flex items-center gap-1 text-xs"><input type="checkbox" name="consent" /> Kalan parçalar için ücretli işleme onay veriyorum</label>}
            <SubmitButton className="btn-secondary">Kaldığı yerden devam et</SubmitButton>
          </form>
        )}
      </div>
    </div>
  );
}
