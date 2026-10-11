import Link from "next/link";
import { notFound } from "next/navigation";
import { deleteRecordingAction, startTranscriptionAction, updateSegmentAction } from "@/app/actions/media";
import { ConfirmSubmit } from "@/components/ConfirmSubmit";
import { Flash } from "@/components/Flash";
import { JobStatus } from "@/components/JobStatus";
import { SubmitButton } from "@/components/SubmitButton";
import { requireUser } from "@/lib/auth";
import { withUser } from "@/lib/db";
import { getRecording, listSegments } from "@/lib/data/recordings";
import { formatTs } from "@/lib/extract";
import { listJobs } from "@/lib/jobs";
import { getTranscriptionStatus, UNIT_SEC } from "@/lib/transcription";

export const metadata = { title: "Kayıt" };
export const dynamic = "force-dynamic";

export default async function RecordingPage({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<Record<string, string | undefined>> }) {
  const { id } = await params;
  const sp = await searchParams;
  const user = await requireUser();
  const data = await withUser(user.id, async (tx) => {
    const r = await getRecording(tx, id);
    return r ? { r, segs: await listSegments(tx, id), job: (await listJobs(tx, id))[0] } : null;
  });
  if (!data) notFound();
  const { r, segs, job } = data;
  const t = getTranscriptionStatus();
  const minutes = r.duration_sec ? Number(r.duration_sec) / 60 : null;
  const here = `/kayitlar/${id}`;
  const busy = job && (job.status === "bekliyor" || job.status === "calisiyor");
  return (
    <div className="mx-auto max-w-4xl space-y-6">
      <Flash sp={sp} />
      <Link href={`/kayitlar?arsiv=${r.archive}`} className="text-sm">← Kayıtlar</Link>
      <h1>{r.title}</h1>
      <p className="muted">{r.filename} · süre {r.duration_sec ? formatTs(Number(r.duration_sec)) : "?"} · {r.archive === "ders" ? "Ders arşivi" : "İş arşivi"}</p>
      {r.mime.startsWith("video/") ? (
        <video controls preload="metadata" src={`/api/kayitlar/${id}/medya`} className="w-full rounded-lg" />
      ) : (
        <audio controls preload="metadata" src={`/api/kayitlar/${id}/medya`} className="w-full" />
      )}
      <JobStatus job={job} returnTo={here} paid />

      {!busy && segs.length === 0 && (
        t.enabled ? (
          <form action={startTranscriptionAction} className="card space-y-2">
            <input type="hidden" name="recordingId" value={id} />
            <p className="text-sm">Kayıt {minutes ? `${minutes.toFixed(1)} dakika` : "?"}; {Math.max(1, Math.ceil(Number(r.duration_sec ?? 0) / UNIT_SEC))} parça hâlinde OpenAI ({t.model}) ile deşifre edilecek.
              {t.pricePerMin != null && minutes != null ? ` Tahmini maliyet: ${(t.pricePerMin * minutes).toFixed(3)} $.` : " Fiyat bilgisi tanımlı değil (TRANSCRIPTION_PRICE_PER_MIN)."}</p>
            <label className="flex items-start gap-2 text-sm"><input type="checkbox" name="consent" className="mt-1" /> Bu ses kaydının OpenAI&apos;ye gönderilmesini ve ücretlendirilmesini onaylıyorum.</label>
            <SubmitButton>Deşifre et</SubmitButton>
          </form>
        ) : <p className="alert-info">Otomatik deşifre kapalı: {t.reason}</p>
      )}

      {segs.length > 0 && (
        <section className="card space-y-3" aria-labelledby="desifre">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <h2 id="desifre">Deşifre ({segs.length} bölüm)</h2>
            <span className="flex flex-wrap gap-2 text-sm">
              {["txt", "srt", "vtt", "docx"].map((f) => <a key={f} href={`/api/kayitlar/${id}/disa?bicim=${f}`} className="btn-secondary" download>{f.toUpperCase()}</a>)}
            </span>
          </div>
          <p className="muted">Anlaşılmayan sözler sağlayıcının çıktısında nasıl geldiyse öyle kalır; uydurma tamamlanmaz. Düzelttiğin metin ayrıca saklanır, ham çıktı korunur.</p>
          <ol className="space-y-3">
            {segs.map((s) => (
              <li key={s.id} id={`seg-${s.id}`} className="rounded-lg border border-slate-200 p-2 dark:border-slate-800">
                <form action={updateSegmentAction} className="space-y-1">
                  <input type="hidden" name="segmentId" value={s.id} />
                  <input type="hidden" name="recordingId" value={id} />
                  <p className="flex flex-wrap items-center gap-2 text-xs">
                    <span className="badge tabular-nums">{formatTs(Number(s.start_sec))}–{formatTs(Number(s.end_sec))}</span>
                    <input name="speaker" defaultValue={s.speaker ?? ""} placeholder="Konuşmacı" aria-label="Konuşmacı" className="input w-36 py-1" />
                    {s.text !== s.raw_text && <span className="badge-warn">Düzeltildi</span>}
                  </p>
                  <textarea name="text" defaultValue={s.text} className="input min-h-16" aria-label="Metin" />
                  <SubmitButton className="btn-secondary">Kaydet</SubmitButton>
                </form>
              </li>
            ))}
          </ol>
        </section>
      )}
      <form action={deleteRecordingAction}>
        <input type="hidden" name="recordingId" value={id} />
        <ConfirmSubmit message="Kayıt ve deşifresi kalıcı olarak silinsin mi?">Kaydı sil</ConfirmSubmit>
      </form>
    </div>
  );
}
