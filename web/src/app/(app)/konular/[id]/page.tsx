import Link from "next/link";
import { notFound } from "next/navigation";
import { createObjectiveAction, createQuestionAction, deleteObjectiveAction, startSessionAction } from "@/app/actions/study";
import { ConfirmSubmit } from "@/components/ConfirmSubmit";
import { Flash } from "@/components/Flash";
import { QuestionForm } from "@/components/QuestionForm";
import { SubmitButton } from "@/components/SubmitButton";
import { getAIStatus } from "@/lib/ai/provider";
import { requireUser } from "@/lib/auth";
import { withUser } from "@/lib/db";
import { getCourse, getTopic, TOPIC_STATUSES } from "@/lib/data/courses";
import { listObjectives, loadTopicProgress } from "@/lib/data/objectives";
import { listSources } from "@/lib/data/sources";
import { listStudySessions, STUDY_MODES, type StudyMode } from "@/lib/data/study";
import { fmtDateTime } from "@/lib/format";
import { MASTERY_LABELS, type MasteryLevel } from "@/lib/mastery";

export const dynamic = "force-dynamic";
export const metadata = { title: "Konu çalışması" };

const LEVEL_CLS: Record<MasteryLevel, string> = { kanit_yok: "badge", zayif: "badge-err", gelisiyor: "badge-warn", ogrenildi: "badge-ok" };
const pct = (x: number | null) => (x == null ? "—" : `%${Math.round(x * 100)}`);

export default async function TopicPage({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<Record<string, string | undefined>> }) {
  const { id } = await params;
  const sp = await searchParams;
  const user = await requireUser();
  const data = await withUser(user.id, async (tx) => {
    const topic = await getTopic(tx, id);
    if (!topic) return null;
    return {
      course: (await getCourse(tx, topic.course_id))!,
      progress: await loadTopicProgress(tx, id),
      sources: await listSources(tx, { topicId: id }),
      courseSources: await listSources(tx, { courseId: topic.course_id }),
      sessions: (await listStudySessions(tx, 50, topic.course_id)).filter((s) => s.topic_id === id).slice(0, 8),
      objectives: await listObjectives(tx, { topicId: id }),
    };
  });
  if (!data) notFound();
  const { course, progress: p, sources, courseSources, sessions } = data;
  const t = p.topic;
  const ai = getAIStatus();
  const here = `/konular/${id}`;
  const textSources = (sources.some((s) => s.extraction_status === "tamam") ? sources : courseSources).filter((s) => s.extraction_status === "tamam");
  const current = p.steps.find((s) => !s.done);

  const startForm = (mode: StudyMode, label: string, starter?: string, primary = false) => (
    <form action={startSessionAction}>
      <input type="hidden" name="courseId" value={course.id} />
      <input type="hidden" name="topicId" value={t.id} />
      <input type="hidden" name="mode" value={mode} />
      <input type="hidden" name="onlySelected" value="on" />
      {textSources.map((s) => <input key={s.id} type="hidden" name="sourceIds" value={s.id} />)}
      {starter && <input type="hidden" name="starter" value={starter} />}
      <SubmitButton className={primary ? "btn" : "btn-secondary"} pendingText="Açılıyor…">{label}</SubmitButton>
    </form>
  );

  const stepAction = (key: string) => {
    switch (key) {
      case "materyal": return <Link className="btn-secondary" href={`/dersler/${course.id}?konu=${t.id}#kaynak-yukle`}>Materyal yükle</Link>;
      case "hedef": return <a className="btn-secondary" href="#hedefler">Hedef yaz</a>;
      case "oku": return ai.enabled ? startForm("konu_anlatimi", "Bana bu konuyu öğret", `"${t.title}" konusunu bana öğret.`) : startForm("okuma", "Kaynakla çalış");
      case "not": return startForm("okuma", "Okuyup not çıkar");
      case "soru": return startForm("aktif_hatirlama", "Soruları çöz");
      case "yanlis": return ai.enabled ? startForm("eksik_tamamlama", "Eksiklerimi tamamla", "Yanlış yaptığım noktaları bana farklı bir yoldan yeniden anlat.") : <Link className="btn-secondary" href="/yanlislar">Yanlışlarımı gözden geçir</Link>;
      case "dogrula": return startForm("aktif_hatirlama", "Hedefleri sına");
      default: return null;
    }
  };

  return (
    <div className="mx-auto max-w-5xl space-y-6">
      <Flash sp={sp} />
      <header>
        <Link href={`/dersler/${course.id}`} className="text-sm">← {course.code} {course.name}</Link>
        <h1 className="mt-1">{t.week ? `${t.week}. hafta — ` : ""}{t.title}</h1>
        <p className="mt-1 flex flex-wrap gap-2 text-sm">
          <span className="badge">{TOPIC_STATUSES[t.status]}</span>
          {t.is_catch_up && <span className="badge-warn">Telafi</span>}
          <span className={LEVEL_CLS[p.overall.level]}>Ustalık: {MASTERY_LABELS[p.overall.level]}</span>
        </p>
      </header>

      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <Stat label="Doğruluk (son cevaplar)" value={pct(p.overall.accuracy)} />
        <Stat label="Cevaplanan soru" value={`${p.overall.answered} / ${p.overall.total}`} />
        <Stat label="Açık yanlış" value={`${p.counts.open_mistakes}${p.counts.misconceptions ? ` (${p.counts.misconceptions} yanılgı)` : ""}`} />
        <Stat label="Tekrar zamanı gelen" value={p.counts.due} />
      </div>

      <section className="card" aria-labelledby="adimlar">
        <h2 id="adimlar">Çalışma adımları</h2>
        <p className="muted">Her adımın durumu gerçek verinden belirlenir (yüklenen kaynak, oturum, not, cevap ve yanlışlar). Sıradaki adım vurgulanmıştır.</p>
        <ol className="mt-3 space-y-2">
          {p.steps.map((s, i) => (
            <li key={s.key} className={`flex flex-wrap items-center justify-between gap-2 rounded-lg border p-3 ${s.key === current?.key ? "border-indigo-400 bg-indigo-50/60 dark:border-indigo-700 dark:bg-indigo-950/40" : "border-slate-200 dark:border-slate-800"}`}
              data-testid="calisma-adimi" aria-current={s.key === current?.key ? "step" : undefined}>
              <div>
                <p className="font-medium">{s.done ? "✓" : `${i + 1}.`} {s.title} {s.done && <span className="badge-ok ml-1">Tamam</span>}</p>
                {!s.done && <p className="muted">{s.hint}</p>}
              </div>
              {!s.done && stepAction(s.key)}
            </li>
          ))}
        </ol>
      </section>

      <section id="hedefler" className="card space-y-3" aria-labelledby="hedef-baslik">
        <h2 id="hedef-baslik">Öğrenme hedefleri</h2>
        <p className="muted">Hedeflere soru bağladıkça ustalık, bu soruların en son cevaplarından hesaplanır. Tahminle verilen doğru cevap hedefi &quot;öğrenildi&quot; yapmaz.</p>
        {p.objectives.length === 0 ? <p className="muted">Henüz hedef yok. Ör. &quot;Gündem belirleme kuramını bir haber örneğiyle açıklayabilirim.&quot;</p> : (
          <ul className="divide-y divide-slate-200 dark:divide-slate-800">
            {p.objectives.map((o) => (
              <li key={o.id} className="flex flex-wrap items-center justify-between gap-2 py-2 text-sm">
                <span>{o.text}</span>
                <span className="flex items-center gap-2">
                  <span className={LEVEL_CLS[o.level]}>{MASTERY_LABELS[o.level]}</span>
                  <span className="muted">{o.answered}/{o.total} soru</span>
                  <form action={deleteObjectiveAction}>
                    <input type="hidden" name="objectiveId" value={o.id} />
                    <input type="hidden" name="returnTo" value={here} />
                    <ConfirmSubmit message="Bu hedef silinsin mi? Bağlı sorular silinmez.">Sil</ConfirmSubmit>
                  </form>
                </span>
              </li>
            ))}
          </ul>
        )}
        <form action={createObjectiveAction} className="flex flex-wrap gap-2">
          <input type="hidden" name="topicId" value={t.id} />
          <input type="hidden" name="returnTo" value={here} />
          <label htmlFor="hedef-metni" className="sr-only">Yeni hedef</label>
          <input id="hedef-metni" name="text" required minLength={3} className="input flex-1" placeholder="Bu konunun sonunda … yapabilmeliyim" />
          <SubmitButton className="btn-secondary">Hedef ekle</SubmitButton>
        </form>
      </section>

      <section className="card space-y-2" aria-labelledby="kavramlar">
        <h2 id="kavramlar">Kavram bazında durum</h2>
        {p.concepts.length === 0 ? <p className="muted">Kavramı belirtilmiş ve cevaplanmış soru yok. Soru eklerken &quot;Ölçülen kavram&quot; alanını doldur.</p> : (
          <table className="w-full text-left text-sm">
            <thead><tr className="muted"><th className="py-1 font-medium">Kavram</th><th className="font-medium">Doğruluk</th><th className="font-medium">Durum</th></tr></thead>
            <tbody>
              {p.concepts.map((c) => (
                <tr key={c.concept} className="border-t border-slate-200 dark:border-slate-800">
                  <td className="py-1">{c.concept}</td><td className="tabular-nums">{pct(c.accuracy)} ({c.correct}/{c.answered})</td>
                  <td><span className={LEVEL_CLS[c.level]}>{MASTERY_LABELS[c.level]}</span></td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </section>

      <section className="card space-y-2" aria-labelledby="kaynaklar">
        <h2 id="kaynaklar">Bu konunun kaynakları</h2>
        {sources.length === 0 ? <p className="muted">Bu konuya bağlı kaynak yok.</p> : (
          <ul className="space-y-1 text-sm">{sources.map((s) => <li key={s.id}><Link href={`/kaynaklar/${s.id}`}>{s.title}</Link> <span className="muted">{s.extraction_status === "tamam" ? `${s.unit_count} bölüm` : "metin yok"}</span></li>)}</ul>
        )}
      </section>

      <section className="card space-y-2" aria-labelledby="gecmis">
        <h2 id="gecmis">Çalışma geçmişi</h2>
        {sessions.length === 0 ? <p className="muted">Bu konuda henüz oturum yok.</p> : (
          <ul className="space-y-1 text-sm">
            {sessions.map((s) => <li key={s.id}><Link href={`/oturum/${s.id}`}>{STUDY_MODES[s.mode].label}</Link> <span className="muted">{fmtDateTime(s.started_at)} · {s.status === "aktif" ? "devam ediyor" : "tamamlandı"}</span></li>)}
          </ul>
        )}
      </section>

      <section className="card" aria-labelledby="soru-ekle">
        <h2 id="soru-ekle">Bu konuya soru ekle</h2>
        <QuestionForm action={createQuestionAction} courseId={course.id} topics={[{ id: t.id, title: t.title }]} returnTo={here} defaultTopicId={t.id} objectives={data.objectives} />
      </section>
    </div>
  );
}

function Stat({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="card">
      <span className="block text-xl font-semibold tabular-nums">{value}</span>
      <span className="muted">{label}</span>
    </div>
  );
}
