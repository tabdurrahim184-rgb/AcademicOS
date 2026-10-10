import Link from "next/link";
import { notFound } from "next/navigation";
import {
  addMeetingAction, createAssessmentAction, createTopicAction, deleteAssessmentAction, deleteMeetingAction, deleteSourceAction,
  updateAssessmentScoreAction, updateCourseAction, uploadSourceAction,
} from "@/app/actions/academic";
import { createNoteAction, createQuestionAction, deleteNoteAction, deleteQuestionAction, generateQuestionsAction, startSessionAction } from "@/app/actions/study";
import { ConfirmSubmit } from "@/components/ConfirmSubmit";
import { Flash } from "@/components/Flash";
import { QuestionForm } from "@/components/QuestionForm";
import { SubmitButton } from "@/components/SubmitButton";
import { getAIStatus } from "@/lib/ai/provider";
import { requireUser } from "@/lib/auth";
import { withUser } from "@/lib/db";
import { ASSESSMENT_KINDS, listAssessments, requiredRemainingAverage } from "@/lib/data/assessments";
import { getCourse, listMeetings, listTopics, TOPIC_STATUSES } from "@/lib/data/courses";
import { listNotes } from "@/lib/data/notes";
import { listObjectives } from "@/lib/data/objectives";
import { EXTRACTION_LABELS, listSources, loadSourceAudit, SOURCE_KINDS } from "@/lib/data/sources";
import { listQuestions } from "@/lib/data/study";
import { fmtBytes, fmtDate, fmtDateTime } from "@/lib/format";
import { QUESTION_TYPES } from "@/lib/grading";
import { trTime, WEEKDAYS } from "@/lib/schedule";

export const dynamic = "force-dynamic";

type Props = { params: Promise<{ id: string }>; searchParams: Promise<Record<string, string | string[] | undefined>> };

export async function generateMetadata({ params }: Props) {
  const { id } = await params;
  const user = await requireUser();
  const c = await withUser(user.id, (tx) => getCourse(tx, id));
  return { title: c ? `${c.code} ${c.name}` : "Ders" };
}

export default async function CoursePage({ params, searchParams }: Props) {
  const { id } = await params;
  const sp = await searchParams;
  const user = await requireUser();
  const data = await withUser(user.id, async (tx) => {
    const course = await getCourse(tx, id);
    if (!course) return null;
    return {
      course,
      meetings: await listMeetings(tx, id),
      topics: await listTopics(tx, id),
      sources: await listSources(tx, { courseId: id }),
      questions: await listQuestions(tx, { courseId: id }),
      notes: await listNotes(tx, id),
      objectives: await listObjectives(tx, { courseId: id }),
      audit: await loadSourceAudit(tx, id),
      assessments: await listAssessments(tx, id),
    };
  });
  if (!data) notFound();
  const { course, meetings, topics, sources, questions, notes, assessments, objectives, audit } = data;
  const ai = getAIStatus();
  const here = `/dersler/${id}`;
  const preTopic = typeof sp.konu === "string" ? sp.konu : "";
  const textSources = sources.filter((s) => s.extraction_status === "tamam");
  const calc = requiredRemainingAverage(assessments.map((a) => ({ weight: a.weight == null ? null : Number(a.weight), score: a.score == null ? null : Number(a.score) })), 60);

  return (
    <div className="mx-auto max-w-5xl space-y-6">
      <Flash sp={sp} />
      <header className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <span className="badge">{course.code}</span>
          <h1 className="mt-1">{course.name}</h1>
          <p className="muted">
            {course.instructor ?? "Öğretim elemanı belirtilmedi"} ·{" "}
            {meetings.length ? meetings.map((m) => `${WEEKDAYS[m.weekday]} ${trTime(m.start_time)}–${trTime(m.end_time)}`).join("; ") : course.delivery === "cevrimici" ? "Çevrimiçi" : "Saat girilmedi"}
          </p>
        </div>
        <Link href={`/calis?ders=${course.id}`} className="btn">Bu dersi çalış</Link>
      </header>

      {/* ------------------------------------------------------------- Konular */}
      <section className="card space-y-3" aria-labelledby="konular">
        <h2 id="konular">Haftalar ve konular</h2>
        {topics.length === 0 && <p className="muted">Henüz konu yok. Ders izlencesindeki haftaları ekleyerek başla.</p>}
        <ul className="divide-y divide-slate-200 dark:divide-slate-800">
          {topics.map((t) => {
            const tSources = sources.filter((s) => s.topic_id === t.id && s.extraction_status === "tamam");
            return (
              <li key={t.id} className="flex flex-wrap items-center justify-between gap-2 py-3">
                <div>
                  <p className="font-medium"><Link href={`/konular/${t.id}`}>{t.week ? `${t.week}. hafta — ` : ""}{t.title}</Link>{t.is_catch_up && <span className="badge-warn ml-2">Telafi</span>}</p>
                  <p className="muted">{TOPIC_STATUSES[t.status]} · {sources.filter((s) => s.topic_id === t.id).length} kaynak</p>
                </div>
                <form action={startSessionAction} className="flex flex-wrap gap-2">
                  <input type="hidden" name="courseId" value={course.id} />
                  <input type="hidden" name="topicId" value={t.id} />
                  <input type="hidden" name="onlySelected" value="on" />
                  {(tSources.length ? tSources : textSources).map((s) => <input key={s.id} type="hidden" name="sourceIds" value={s.id} />)}
                  {ai.enabled ? (
                    <>
                      <input type="hidden" name="mode" value="konu_anlatimi" />
                      <input type="hidden" name="starter" value={`"${t.title}" konusunu bana öğret.`} />
                      <SubmitButton pendingText="Öğretmen hazırlanıyor…" className="btn">Bana bu konuyu öğret</SubmitButton>
                    </>
                  ) : (
                    <>
                      <input type="hidden" name="mode" value="okuma" />
                      <SubmitButton pendingText="Açılıyor…" className="btn-secondary">Kaynakla çalış</SubmitButton>
                    </>
                  )}
                </form>
              </li>
            );
          })}
        </ul>
        <details id="konu-ekle" open={topics.length === 0}>
          <summary className="cursor-pointer text-sm font-medium">Konu ekle</summary>
          <form action={createTopicAction} className="mt-3 grid gap-3 sm:grid-cols-[6rem_1fr_auto] sm:items-end">
            <input type="hidden" name="courseId" value={course.id} />
            <div><label className="label" htmlFor="week">Hafta</label><input id="week" name="week" type="number" min={1} max={20} className="input" /></div>
            <div><label className="label" htmlFor="title">Konu başlığı</label><input id="title" name="title" required className="input" placeholder="ör. Gündem belirleme kuramı" /></div>
            <SubmitButton>Ekle</SubmitButton>
          </form>
        </details>
      </section>

      {/* ------------------------------------------------------------- Kaynaklar */}
      <section className="card space-y-3" aria-labelledby="kaynaklar">
        <h2 id="kaynaklar">Kaynaklar</h2>
        {sources.length === 0 && <p className="muted">Henüz kaynak yüklenmedi.</p>}
        <ul className="divide-y divide-slate-200 dark:divide-slate-800">
          {sources.map((s) => (
            <li key={s.id} className="flex flex-wrap items-center justify-between gap-2 py-2">
              <div className="min-w-0">
                <Link href={`/kaynaklar/${s.id}`} className="font-medium">{s.title}</Link>
                <p className="muted">
                  {SOURCE_KINDS[s.kind]} · {s.file_type.toUpperCase()} · {fmtBytes(s.size_bytes)} ·{" "}
                  <span className={s.extraction_status === "tamam" ? "" : "text-amber-700 dark:text-amber-300"}>{EXTRACTION_LABELS[s.extraction_status]}</span>
                  {s.topic_id && ` · ${topics.find((t) => t.id === s.topic_id)?.title ?? ""}`}
                </p>
              </div>
              {audit.filter((i) => i.sourceId === s.id).map((i, n) => (
                <p key={n} className={`w-full text-xs ${i.level === "uyari" ? "text-amber-800 dark:text-amber-300" : "text-slate-500"}`} data-testid="kaynak-denetimi">
                  {i.level === "uyari" ? "Kontrol et: " : "Not: "}{i.message}
                </p>
              ))}
              <form action={deleteSourceAction}>
                <input type="hidden" name="sourceId" value={s.id} />
                <input type="hidden" name="courseId" value={course.id} />
                <ConfirmSubmit message={`"${s.title}" kaynağı ve çıkarılan metni kalıcı olarak silinsin mi?`}>Sil</ConfirmSubmit>
              </form>
            </li>
          ))}
        </ul>
        <form id="kaynak-yukle" action={uploadSourceAction} className="grid gap-3 rounded-lg border border-dashed border-slate-300 p-3 dark:border-slate-700 sm:grid-cols-2">
          <input type="hidden" name="courseId" value={course.id} />
          <div className="sm:col-span-2">
            <label className="label" htmlFor="file">Dosya (PDF, DOCX, PPTX, TXT, MD, SRT, VTT, görsel — en fazla 25 MB)</label>
            <input id="file" name="file" type="file" required className="input" accept=".pdf,.docx,.pptx,.txt,.md,.srt,.vtt,.png,.jpg,.jpeg,.webp" />
          </div>
          <div><label className="label" htmlFor="stitle">Başlık (isteğe bağlı)</label><input id="stitle" name="title" className="input" /></div>
          <div>
            <label className="label" htmlFor="kind">Kaynak türü</label>
            <select id="kind" name="kind" className="input" defaultValue="hoca">
              {Object.entries(SOURCE_KINDS).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
            </select>
          </div>
          <div>
            <label className="label" htmlFor="topicId">Konu</label>
            <select id="topicId" name="topicId" className="input" defaultValue={preTopic}>
              <option value="">Konu seçilmedi</option>
              {topics.map((t) => <option key={t.id} value={t.id}>{t.week ? `${t.week}. hafta — ` : ""}{t.title}</option>)}
            </select>
          </div>
          <div className="flex items-end"><SubmitButton pendingText="Yükleniyor ve okunuyor…">Yükle</SubmitButton></div>
          <p className="muted sm:col-span-2">Dosyalar yalnızca senin hesabına bağlı özel veritabanında saklanır. Görsellerden ve taranmış PDF&apos;lerden metin okuma (OCR) henüz yok.</p>
        </form>
      </section>

      {/* ------------------------------------------------------------- Sorular */}
      <section className="card space-y-3" aria-labelledby="sorular">
        <h2 id="sorular">Soru bankası <span className="muted font-normal">({questions.length})</span></h2>
        <p className="muted">Soruları çalışma oturumunda veya tekrar ekranında çözersin. Yapay zekâ üretimi sorular ayrıca işaretlenir.</p>
        <ul className="divide-y divide-slate-200 dark:divide-slate-800">
          {questions.map((q) => (
            <li key={q.id} className="flex items-start justify-between gap-2 py-2 text-sm">
              <span><span className="badge mr-2">{QUESTION_TYPES[q.type]}</span>{q.origin === "yapay_zeka" && <span className="badge-warn mr-2">Yapay zekâ</span>}{q.origin === "ogretim_elemani" && <span className="badge-ok mr-2">Öğretim elemanı</span>}<span className="whitespace-pre-wrap">{q.prompt}</span></span>
              <form action={deleteQuestionAction}>
                <input type="hidden" name="questionId" value={q.id} />
                <input type="hidden" name="returnTo" value={here} />
                <ConfirmSubmit message="Soru ve bu soruya verilen bütün cevaplar silinsin mi?">Sil</ConfirmSubmit>
              </form>
            </li>
          ))}
        </ul>
        <details>
          <summary className="cursor-pointer text-sm font-medium">Soru ekle</summary>
          <QuestionForm action={createQuestionAction} courseId={course.id} topics={topics.map((t) => ({ id: t.id, title: t.title }))} returnTo={here} objectives={objectives} />
        </details>
        {ai.enabled ? (
          <details>
            <summary className="cursor-pointer text-sm font-medium">Kaynaklardan yapay zekâ ile soru üret</summary>
            <form action={generateQuestionsAction} className="mt-3 space-y-3">
              <input type="hidden" name="courseId" value={course.id} />
              <input type="hidden" name="returnTo" value={here} />
              <fieldset><legend className="label">Kaynaklar</legend>
                {textSources.length === 0 && <p className="muted">Metni çıkarılmış kaynak yok.</p>}
                {textSources.map((s) => <label key={s.id} className="flex items-center gap-2 text-sm"><input type="checkbox" name="sourceIds" value={s.id} defaultChecked /> {s.title}</label>)}
              </fieldset>
              <div className="flex flex-wrap items-end gap-3">
                <label className="text-sm">Konu
                  <select name="topicId" className="input mt-1 w-auto"><option value="">—</option>{topics.map((t) => <option key={t.id} value={t.id}>{t.title}</option>)}</select>
                </label>
                <label className="text-sm">Soru sayısı<input name="count" type="number" min={1} max={10} defaultValue={5} className="input mt-1 w-20" /></label>
                <SubmitButton pendingText="Sorular üretiliyor…">Üret</SubmitButton>
              </div>
            </form>
          </details>
        ) : (
          <p className="muted">Yapay zekâ ile soru üretimi için bir API sağlayıcısı yapılandırılmalı (Ayarlar).</p>
        )}
      </section>

      {/* ------------------------------------------------------------- Notlar */}
      <section className="card space-y-3" aria-labelledby="notlar">
        <h2 id="notlar">Notlarım</h2>
        <ul className="space-y-3">
          {notes.map((n) => (
            <li key={n.id} className="rounded-lg border border-slate-200 p-3 dark:border-slate-800">
              <div className="flex items-start justify-between gap-2">
                <p className="font-medium">{n.title} {n.origin === "yapay_zeka" && <span className="badge-warn ml-1">Yapay zekâ çıktısı</span>}</p>
                <form action={deleteNoteAction}>
                  <input type="hidden" name="noteId" value={n.id} />
                  <input type="hidden" name="returnTo" value={here} />
                  <ConfirmSubmit message="Not silinsin mi?">Sil</ConfirmSubmit>
                </form>
              </div>
              <p className="mt-1 whitespace-pre-wrap text-sm">{n.body}</p>
              <p className="muted mt-1 text-xs">{fmtDateTime(n.updated_at)}</p>
            </li>
          ))}
        </ul>
        <details>
          <summary className="cursor-pointer text-sm font-medium">Not ekle</summary>
          <form action={createNoteAction} className="mt-3 space-y-3">
            <input type="hidden" name="courseId" value={course.id} />
            <input type="hidden" name="returnTo" value={here} />
            <input name="title" className="input" placeholder="Başlık" aria-label="Not başlığı" />
            <select name="topicId" className="input" aria-label="Konu"><option value="">Konu seçilmedi</option>{topics.map((t) => <option key={t.id} value={t.id}>{t.title}</option>)}</select>
            <textarea name="body" required className="input min-h-32" placeholder="Notun…" aria-label="Not metni" />
            <SubmitButton>Notu kaydet</SubmitButton>
          </form>
        </details>
      </section>

      {/* ------------------------------------------------------------- Değerlendirmeler */}
      <section className="card space-y-3" aria-labelledby="sinavlar">
        <h2 id="sinavlar">Sınavlar, ödevler ve notlar</h2>
        {assessments.length === 0 && <p className="muted">Kayıt yok. Tarihi bilinmeyen sınavı tarihsiz ekleyebilirsin; &quot;Tarih bekleniyor&quot; olarak görünür.</p>}
        <ul className="divide-y divide-slate-200 dark:divide-slate-800">
          {assessments.map((a) => (
            <li key={a.id} className="flex flex-wrap items-center justify-between gap-2 py-2 text-sm">
              <span>
                <span className="badge mr-2">{ASSESSMENT_KINDS[a.kind]}</span>{a.title} ·{" "}
                <span className={a.due_at ? "" : "badge-warn"}>{fmtDate(a.due_at)}</span>
                {a.weight != null && ` · ağırlık %${Number(a.weight)}`}
              </span>
              <span className="flex items-center gap-2">
                <form action={updateAssessmentScoreAction} className="flex items-center gap-1">
                  <input type="hidden" name="assessmentId" value={a.id} />
                  <input type="hidden" name="courseId" value={course.id} />
                  <input name="score" type="number" min={0} max={100} step="0.01" defaultValue={a.score == null ? "" : Number(a.score)} className="input w-20" aria-label="Alınan not" placeholder="Not" />
                  <SubmitButton className="btn-secondary">Kaydet</SubmitButton>
                </form>
                <form action={deleteAssessmentAction}>
                  <input type="hidden" name="assessmentId" value={a.id} />
                  <input type="hidden" name="courseId" value={course.id} />
                  <ConfirmSubmit message="Bu kayıt silinsin mi?">Sil</ConfirmSubmit>
                </form>
              </span>
            </li>
          ))}
        </ul>
        {assessments.length > 0 && (
          <p className="text-sm">
            {calc.ok
              ? calc.required == null
                ? `Dönem notu (girilen notlara göre): ${calc.current}. ${calc.assumptions}`
                : `Dönem sonu ${60} hedefi için kalan değerlendirmelerden gereken ortalama: ${calc.required}. Şu ana kadar toplanan: ${calc.current}. Varsayım: ${calc.assumptions}`
              : `Gereken not hesaplanamıyor: ${calc.reason}`}
          </p>
        )}
        <details>
          <summary className="cursor-pointer text-sm font-medium">Sınav / ödev ekle</summary>
          <form action={createAssessmentAction} className="mt-3 grid gap-3 sm:grid-cols-3">
            <input type="hidden" name="courseId" value={course.id} />
            <label className="text-sm">Tür<select name="kind" className="input mt-1">{Object.entries(ASSESSMENT_KINDS).map(([k, v]) => <option key={k} value={k}>{v}</option>)}</select></label>
            <label className="text-sm sm:col-span-2">Başlık<input name="title" className="input mt-1" placeholder="ör. Vize sınavı" /></label>
            <label className="text-sm">Tarih (boş = Tarih bekleniyor)<input name="dueDate" type="date" className="input mt-1" /></label>
            <label className="text-sm">Saat (Kıbrıs)<input name="dueTime" type="time" className="input mt-1" /></label>
            <label className="text-sm">Ağırlık % (doğrulanmışsa)<input name="weight" type="number" min={0} max={100} className="input mt-1" /></label>
            <div className="sm:col-span-3"><SubmitButton>Ekle</SubmitButton></div>
          </form>
        </details>
      </section>

      {/* ------------------------------------------------------------- Ders bilgisi */}
      <section className="card space-y-3" aria-labelledby="bilgi">
        <h2 id="bilgi">Ders bilgileri ve saatleri</h2>
        <details>
          <summary className="cursor-pointer text-sm font-medium">Düzenle</summary>
          <form action={updateCourseAction} className="mt-3 grid gap-3 sm:grid-cols-2">
            <input type="hidden" name="courseId" value={course.id} />
            <label className="text-sm">Kod<input name="code" defaultValue={course.code} required className="input mt-1" /></label>
            <label className="text-sm">Ad<input name="name" defaultValue={course.name} required className="input mt-1" /></label>
            <label className="text-sm">Öğretim elemanı<input name="instructor" defaultValue={course.instructor ?? ""} className="input mt-1" placeholder="Belirtilmedi" /></label>
            <label className="text-sm">Biçim
              <select name="delivery" defaultValue={course.delivery} className="input mt-1"><option value="yuz_yuze">Yüz yüze</option><option value="cevrimici">Çevrimiçi</option></select>
            </label>
            <label className="text-sm sm:col-span-2">Notlar<textarea name="notes" defaultValue={course.notes} className="input mt-1" /></label>
            <div><SubmitButton>Kaydet</SubmitButton></div>
          </form>
          <h3 className="mt-4 text-sm font-semibold">Haftalık saatler</h3>
          <ul className="mt-2 space-y-1 text-sm">
            {meetings.map((m) => (
              <li key={m.id} className="flex items-center gap-2">
                {WEEKDAYS[m.weekday]} {trTime(m.start_time)}–{trTime(m.end_time)}
                <form action={deleteMeetingAction}>
                  <input type="hidden" name="meetingId" value={m.id} />
                  <input type="hidden" name="courseId" value={course.id} />
                  <ConfirmSubmit message="Bu ders saati silinsin mi?">Sil</ConfirmSubmit>
                </form>
              </li>
            ))}
          </ul>
          <form action={addMeetingAction} className="mt-3 flex flex-wrap items-end gap-2">
            <input type="hidden" name="courseId" value={course.id} />
            <label className="text-sm">Gün<select name="weekday" className="input mt-1 w-auto">{WEEKDAYS.slice(1).map((d, i) => <option key={d} value={i + 1}>{d}</option>)}</select></label>
            <label className="text-sm">Başlangıç<input name="start" type="time" required className="input mt-1 w-auto" /></label>
            <label className="text-sm">Bitiş<input name="end" type="time" required className="input mt-1 w-auto" /></label>
            <SubmitButton className="btn-secondary">Saat ekle</SubmitButton>
          </form>
        </details>
      </section>
    </div>
  );
}
