import Link from "next/link";
import { notFound } from "next/navigation";
import { createNoteAction, endSessionAction, updateSessionSourcesAction } from "@/app/actions/study";
import { ChatBox } from "@/components/ChatBox";
import { Flash } from "@/components/Flash";
import { QuestionCard } from "@/components/QuestionCard";
import { SubmitButton } from "@/components/SubmitButton";
import { getAIStatus } from "@/lib/ai/provider";
import { requireUser } from "@/lib/auth";
import { withUser } from "@/lib/db";
import { getCourse, getTopic } from "@/lib/data/courses";
import { getSourceChunks, listSources } from "@/lib/data/sources";
import { getStudySession, listAttempts, listDueCards, listMessages, listQuestions, STUDY_MODES } from "@/lib/data/study";
import { fmtDateTime } from "@/lib/format";

export const dynamic = "force-dynamic";
export const metadata = { title: "Çalışma oturumu" };

export default async function SessionPage({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<Record<string, string | undefined>> }) {
  const { id } = await params;
  const sp = await searchParams;
  const user = await requireUser();
  const data = await withUser(user.id, async (tx) => {
    const s = await getStudySession(tx, id);
    if (!s) return null;
    const course = (await getCourse(tx, s.course_id))!;
    const topic = s.topic_id ? await getTopic(tx, s.topic_id) : null;
    const allSources = await listSources(tx, { courseId: s.course_id });
    const selected = allSources.filter((x) => s.source_ids.includes(x.id));
    let questions = await listQuestions(tx, { courseId: s.course_id, topicId: s.topic_id });
    if (s.mode === "hizli_tekrar") {
      const due = new Set((await listDueCards(tx)).map((d) => d.question_id));
      questions = (await listQuestions(tx, { courseId: s.course_id })).filter((q) => due.has(q.id));
    }
    const readingChunks = s.mode === "okuma" || s.mode === "aktif_hatirlama"
      ? (await Promise.all(selected.map(async (src) => ({ src, chunks: await getSourceChunks(tx, src.id) })))) : [];
    return {
      s, course, topic, allSources, selected, questions, readingChunks,
      messages: await listMessages(tx, id),
      attempts: await listAttempts(tx, { sessionId: id }),
    };
  });
  if (!data) notFound();
  const { s, course, topic, allSources, selected, questions, messages, attempts, readingChunks } = data;
  const ai = getAIStatus();
  const here = `/oturum/${id}`;
  const lastAttempt = (qid: string) => [...attempts].reverse().find((a) => a.question_id === qid) ?? null;
  const answered = questions.filter((q) => lastAttempt(q.id)).length;

  return (
    <div className="mx-auto max-w-5xl space-y-6">
      <Flash sp={sp} />
      <header className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <Link href={`/dersler/${course.id}`} className="text-sm">← {course.code} {course.name}</Link>
          <h1 className="mt-1">{STUDY_MODES[s.mode].label}{topic ? `: ${topic.title}` : ""}</h1>
          <p className="muted">
            {s.goal && `Hedef: ${s.goal} · `}Başlangıç: {fmtDateTime(s.started_at)} · Son etkinlik: {fmtDateTime(s.last_activity_at)} ·{" "}
            {s.status === "aktif" ? <span className="badge-ok">Devam ediyor</span> : <span className="badge">Tamamlandı</span>}
          </p>
        </div>
        {s.status === "aktif" && (
          <form action={endSessionAction}>
            <input type="hidden" name="sessionId" value={s.id} />
            <SubmitButton className="btn-secondary">Oturumu bitir</SubmitButton>
          </form>
        )}
      </header>

      <section className="card space-y-2" aria-labelledby="kaynak-baslik">
        <h2 id="kaynak-baslik" className="text-base">Kaynaklar {s.only_selected_sources && <span className="badge ml-1">Yalnızca seçili kaynaklar</span>}</h2>
        {selected.length === 0 ? (
          <p className="muted">Bu oturumda seçili kaynak yok.{ai.enabled && " Öğretmen genel bilgiyle anlatır ve bunu belirtir."}</p>
        ) : (
          <ul className="flex flex-wrap gap-2 text-sm">{selected.map((x) => <li key={x.id}><Link href={`/kaynaklar/${x.id}`} className="badge">{x.title}</Link></li>)}</ul>
        )}
        <details>
          <summary className="cursor-pointer text-sm">Kaynak seçimini değiştir</summary>
          <form action={updateSessionSourcesAction} className="mt-2 space-y-1">
            <input type="hidden" name="sessionId" value={s.id} />
            {allSources.map((x) => (
              <label key={x.id} className="flex items-center gap-2 text-sm">
                <input type="checkbox" name="sourceIds" value={x.id} defaultChecked={s.source_ids.includes(x.id)} disabled={x.extraction_status !== "tamam"} /> {x.title}
              </label>
            ))}
            <label className="flex items-center gap-2 text-sm"><input type="checkbox" name="onlySelected" defaultChecked={s.only_selected_sources} /> Yalnızca seçili kaynaklara göre cevap ver</label>
            <SubmitButton className="btn-secondary">Güncelle</SubmitButton>
          </form>
        </details>
      </section>

      {readingChunks.length > 0 && (
        <section className="card space-y-3" aria-labelledby="okuma">
          <h2 id="okuma">{s.mode === "aktif_hatirlama" ? "Önce oku, sonra kapatıp soruları cevapla" : "Kaynak metni"}</h2>
          <details open={s.mode === "okuma"}>
            <summary className="cursor-pointer text-sm">Metni göster / gizle</summary>
            <div className="mt-3 max-h-[32rem] space-y-4 overflow-y-auto pr-2">
              {readingChunks.map(({ src, chunks }) => (
                <div key={src.id}>
                  <h3 className="font-semibold">{src.title}</h3>
                  {chunks.map((c) => (
                    <p key={c.id} className="mt-2 whitespace-pre-wrap text-sm leading-relaxed"><span className="badge mr-2">{c.locator}</span>{c.content}</p>
                  ))}
                </div>
              ))}
            </div>
          </details>
        </section>
      )}

      {(ai.enabled || messages.length > 0) && (
        <section className="card space-y-4" aria-labelledby="ogretmen">
          <h2 id="ogretmen">Öğretmen</h2>
          {!ai.enabled && <p className="alert-info">Yapay zekâ bağlantısı şu anda yok. Önceki konuşma aşağıda saklı; yeni yanıt alınamaz.</p>}
          <ol className="space-y-3" aria-live="polite">
            {messages.map((m) => (
              <li key={m.id} className={m.role === "ogrenci" ? "ml-8 rounded-lg bg-indigo-50 p-3 dark:bg-indigo-950/50" : "mr-4 rounded-lg border border-slate-200 p-3 dark:border-slate-800"}>
                <p className="mb-1 text-xs font-semibold text-slate-500">{m.role === "ogrenci" ? "Sen" : `Öğretmen (yapay zekâ${m.model ? ` · ${m.model}` : ""})`}</p>
                <p className="whitespace-pre-wrap text-sm leading-relaxed">{m.content}</p>
                {m.role === "ogretmen" && m.citations.length > 0 && (
                  <p className="mt-2 text-xs">
                    Kaynaklar:{" "}
                    {m.citations.map((c) => (
                      <Link key={c.ref} href={`/kaynaklar/${c.sourceId}`} className="mr-2">[{c.ref}] {c.title} — {c.locator}</Link>
                    ))}
                  </p>
                )}
                {m.role === "ogretmen" && m.citations.length === 0 && selected.length > 0 && (
                  <p className="mt-2 text-xs text-amber-700 dark:text-amber-300">Bu yanıtta kaynak atfı yok; bilgileri kaynakla karşılaştır.</p>
                )}
                {m.role === "ogretmen" && (
                  <form action={createNoteAction} className="mt-2">
                    <input type="hidden" name="courseId" value={course.id} />
                    <input type="hidden" name="topicId" value={topic?.id ?? ""} />
                    <input type="hidden" name="returnTo" value={here} />
                    <input type="hidden" name="origin" value="yapay_zeka" />
                    <input type="hidden" name="title" value={`Öğretmen açıklaması${topic ? ` — ${topic.title}` : ""}`} />
                    <input type="hidden" name="body" value={m.content} />
                    <button className="text-xs text-indigo-700 underline dark:text-indigo-300">Notlarıma kaydet</button>
                  </form>
                )}
              </li>
            ))}
          </ol>
          {ai.enabled && s.status === "aktif" && <ChatBox sessionId={s.id} />}
        </section>
      )}

      <section className="space-y-3" aria-labelledby="sorular">
        <div className="flex flex-wrap items-baseline justify-between gap-2">
          <h2 id="sorular">{s.mode === "hizli_tekrar" ? "Tekrar zamanı gelen sorular" : "Sorular"} <span className="muted font-normal">({answered}/{questions.length} cevaplandı)</span></h2>
          <Link href={`/dersler/${course.id}#sorular`} className="text-sm">Soru ekle / üret</Link>
        </div>
        {questions.length === 0 && (
          <p className="card muted">Bu {topic ? "konu" : "ders"} için soru yok. Ders sayfasından kendi sorularını ekleyebilir{ai.enabled ? " veya kaynaklardan yapay zekâ ile üretebilir" : ""}sin.</p>
        )}
        {questions.map((q, i) => (
          <QuestionCard key={q.id} q={q} index={i + 1} attempt={lastAttempt(q.id)} sessionId={s.id} returnTo={here} aiEnabled={ai.enabled} />
        ))}
      </section>

      <section className="card" aria-labelledby="hizli-not">
        <h2 id="hizli-not" className="text-base">Not al</h2>
        <form action={createNoteAction} className="mt-2 space-y-2">
          <input type="hidden" name="courseId" value={course.id} />
          <input type="hidden" name="topicId" value={topic?.id ?? ""} />
          <input type="hidden" name="returnTo" value={here} />
          <input name="title" className="input" placeholder="Başlık" aria-label="Not başlığı" defaultValue={topic ? `${topic.title} notu` : ""} />
          <textarea name="body" required className="input min-h-24" placeholder="Kendi cümlelerinle özetle…" aria-label="Not metni" />
          <SubmitButton className="btn-secondary">Notu kaydet</SubmitButton>
        </form>
      </section>
    </div>
  );
}
