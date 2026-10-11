import Link from "next/link";
import { notFound } from "next/navigation";
import { startSessionAction } from "@/app/actions/study";
import { updateSourceAction } from "@/app/actions/academic";
import { startOcrAction, updateOcrChunkAction } from "@/app/actions/media";
import { JobStatus } from "@/components/JobStatus";
import { listJobs } from "@/lib/jobs";
import { Flash } from "@/components/Flash";
import { SubmitButton } from "@/components/SubmitButton";
import { getAIStatus } from "@/lib/ai/provider";
import { requireUser } from "@/lib/auth";
import { withUser } from "@/lib/db";
import { getCourse, getTopic, listTopics } from "@/lib/data/courses";
import { EXTRACTION_LABELS, getSource, getSourceChunks, SOURCE_KINDS } from "@/lib/data/sources";
import { fmtBytes, fmtDateTime } from "@/lib/format";

export const dynamic = "force-dynamic";
export const metadata = { title: "Kaynak" };

export default async function SourcePage({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<Record<string, string | undefined>> }) {
  const { id } = await params;
  const sp = await searchParams;
  const user = await requireUser();
  const data = await withUser(user.id, async (tx) => {
    const s = await getSource(tx, id);
    if (!s) return null;
    return {
      s, chunks: await getSourceChunks(tx, id), course: (await getCourse(tx, s.course_id))!,
      topic: s.topic_id ? await getTopic(tx, s.topic_id) : null, topics: await listTopics(tx, s.course_id),
      job: (await listJobs(tx, id))[0],
    };
  });
  if (!data) notFound();
  const { s, chunks, course, topic, topics, job } = data;
  const ocrBusy = job && (job.status === "bekliyor" || job.status === "calisiyor");
  const ai = getAIStatus();
  return (
    <div className="mx-auto max-w-4xl space-y-6">
      <Flash sp={sp} />
      {sp.yuklendi && (
        <p role="status" className={s.extraction_status === "tamam" ? "alert-ok" : "alert-info"}>
          Dosya kaydedildi. {s.extraction_status === "tamam" ? `${chunks.length} metin bölümü çıkarıldı ve aranabilir.` : s.extraction_note}
        </p>
      )}
      <header>
        <Link href={`/dersler/${course.id}`} className="text-sm">← {course.code} {course.name}</Link>
        <h1 className="mt-1">{s.title}</h1>
        <p className="muted">
          {SOURCE_KINDS[s.kind]} · {s.filename} · {fmtBytes(s.size_bytes)} · {fmtDateTime(s.created_at)}
          {topic && ` · Konu: ${topic.title}`}
        </p>
        <p className="mt-2 text-sm">
          <span className={s.extraction_status === "tamam" ? "badge-ok" : "badge-warn"}>{EXTRACTION_LABELS[s.extraction_status]}</span>{" "}
          {s.extraction_note}
        </p>
        <div className="mt-3 flex flex-wrap gap-2">
          <a href={`/api/kaynaklar/${s.id}/dosya`} className="btn-secondary" target="_blank" rel="noopener">Özgün dosyayı aç</a>
          {s.extraction_status === "tamam" && (
            <form action={startSessionAction} className="flex gap-2">
              <input type="hidden" name="courseId" value={course.id} />
              <input type="hidden" name="topicId" value={topic?.id ?? ""} />
              <input type="hidden" name="sourceIds" value={s.id} />
              <input type="hidden" name="onlySelected" value="on" />
              {ai.enabled ? (
                <>
                  <input type="hidden" name="mode" value="konu_anlatimi" />
                  <input type="hidden" name="starter" value={`"${s.title}" kaynağındaki konuyu bana öğret.`} />
                  <SubmitButton pendingText="Öğretmen hazırlanıyor…">Bana bu konuyu öğret</SubmitButton>
                </>
              ) : (
                <>
                  <input type="hidden" name="mode" value="okuma" />
                  <SubmitButton pendingText="Açılıyor…">Bu kaynakla çalış</SubmitButton>
                </>
              )}
            </form>
          )}
        </div>
      </header>
      <JobStatus job={job} returnTo={`/kaynaklar/${s.id}`} />
      {!ocrBusy && s.extraction_status !== "tamam" && ["pdf", "image"].includes(s.file_type) && (
        <form action={startOcrAction} className="card space-y-2">
          <input type="hidden" name="sourceId" value={s.id} />
          <p className="text-sm">Bu dosyada seçilebilir metin yok (taranmış sayfa veya görsel). OCR ile metin çıkarılabilir: işlem sunucuda, Türkçe dil modeliyle yapılır; dosya dışarı gönderilmez. PDF&apos;lerde en fazla 40 sayfa işlenir. Tanıma hataları olabilir; sonuçları düzenleyebilirsin.</p>
          <SubmitButton>OCR ile metni çıkar</SubmitButton>
        </form>
      )}
      <details className="card">
        <summary className="cursor-pointer text-sm font-medium">Kaynak bilgilerini düzelt (başlık, tür, konu)</summary>
        <form action={updateSourceAction} className="mt-3 grid gap-3 sm:grid-cols-3">
          <input type="hidden" name="sourceId" value={s.id} />
          <label className="text-sm">Başlık<input name="title" defaultValue={s.title} required className="input mt-1" /></label>
          <label className="text-sm">Tür
            <select name="kind" defaultValue={s.kind} className="input mt-1">{Object.entries(SOURCE_KINDS).map(([k, v]) => <option key={k} value={k}>{v}</option>)}</select>
          </label>
          <label className="text-sm">Konu
            <select name="topicId" defaultValue={s.topic_id ?? ""} className="input mt-1">
              <option value="">Konu seçilmedi</option>
              {topics.map((t) => <option key={t.id} value={t.id}>{t.week ? `${t.week}. hafta — ` : ""}{t.title}</option>)}
            </select>
          </label>
          <div className="sm:col-span-3"><SubmitButton className="btn-secondary">Kaydet</SubmitButton></div>
        </form>
      </details>
      {chunks.length > 0 && (
        <section aria-labelledby="metin" className="space-y-3">
          <h2 id="metin">Çıkarılan metin <span className="muted font-normal">(özgün içerik korunur)</span></h2>
          {chunks.map((c) => (
            <article key={c.id} id={`parca-${c.ord}`} className="card">
              <p className="badge mb-2">{c.locator}{c.raw_ocr != null && " · OCR"}</p>
              <p className="whitespace-pre-wrap text-sm leading-relaxed">{c.content}</p>
              {c.raw_ocr != null && (
                <details className="mt-2">
                  <summary className="cursor-pointer text-xs">OCR metnini düzelt</summary>
                  <form action={updateOcrChunkAction} className="mt-2 space-y-2">
                    <input type="hidden" name="sourceId" value={s.id} />
                    <input type="hidden" name="chunkId" value={c.id} />
                    <textarea name="content" defaultValue={c.content} className="input min-h-40 text-sm" aria-label="OCR metni" />
                    <SubmitButton className="btn-secondary">Düzeltmeyi kaydet</SubmitButton>
                  </form>
                </details>
              )}
            </article>
          ))}
        </section>
      )}
    </div>
  );
}
