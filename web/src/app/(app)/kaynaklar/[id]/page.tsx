import Link from "next/link";
import { notFound } from "next/navigation";
import { startSessionAction } from "@/app/actions/study";
import { Flash } from "@/components/Flash";
import { SubmitButton } from "@/components/SubmitButton";
import { getAIStatus } from "@/lib/ai/provider";
import { requireUser } from "@/lib/auth";
import { withUser } from "@/lib/db";
import { getCourse, getTopic } from "@/lib/data/courses";
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
    return { s, chunks: await getSourceChunks(tx, id), course: (await getCourse(tx, s.course_id))!, topic: s.topic_id ? await getTopic(tx, s.topic_id) : null };
  });
  if (!data) notFound();
  const { s, chunks, course, topic } = data;
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
      {chunks.length > 0 && (
        <section aria-labelledby="metin" className="space-y-3">
          <h2 id="metin">Çıkarılan metin <span className="muted font-normal">(özgün içerik korunur)</span></h2>
          {chunks.map((c) => (
            <article key={c.id} id={`parca-${c.ord}`} className="card">
              <p className="badge mb-2">{c.locator}</p>
              <p className="whitespace-pre-wrap text-sm leading-relaxed">{c.content}</p>
            </article>
          ))}
        </section>
      )}
    </div>
  );
}
