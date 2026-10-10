import Link from "next/link";
import { startSessionAction } from "@/app/actions/study";
import { Flash } from "@/components/Flash";
import { SubmitButton } from "@/components/SubmitButton";
import { getUserAIStatus } from "@/lib/ai/chatgpt";
import { requireUser } from "@/lib/auth";
import { withUser } from "@/lib/db";
import { isUuid, listCourses, listTopics, TOPIC_STATUSES } from "@/lib/data/courses";
import { listSources } from "@/lib/data/sources";
import { listStudySessions, STUDY_MODES, type StudyMode } from "@/lib/data/study";
import { fmtDateTime } from "@/lib/format";

export const metadata = { title: "Ders çalış" };
export const dynamic = "force-dynamic";

export default async function StudyStart({ searchParams }: { searchParams: Promise<Record<string, string | undefined>> }) {
  const sp = await searchParams;
  const user = await requireUser();
  const courseId = sp.ders && isUuid(sp.ders) ? sp.ders : null;
  const data = await withUser(user.id, async (tx) => ({
    courses: await listCourses(tx),
    topics: courseId ? await listTopics(tx, courseId) : [],
    sources: courseId ? await listSources(tx, { courseId }) : [],
    recent: await listStudySessions(tx, 8),
  }));
  const ai = await getUserAIStatus(user.id);
  const course = data.courses.find((c) => c.id === courseId);
  const mode = (sp.mod && sp.mod in STUDY_MODES ? sp.mod : ai.enabled ? "konu_anlatimi" : "okuma") as StudyMode;
  const topicId = sp.konu ?? "";
  const topicSources = data.sources.filter((s) => s.topic_id === topicId && s.extraction_status === "tamam");
  const courseLabel = (id: string) => data.courses.find((c) => c.id === id)?.code ?? "";

  return (
    <div className="mx-auto max-w-4xl space-y-6">
      <Flash sp={sp} />
      <h1>Ders çalış</h1>
      {!ai.enabled && (
        <p className="alert-info">Yapay zekâ öğretmeni bağlı değil ({ai.reason}). Kaynak okuma, aktif hatırlama, hızlı tekrar ve soru çözme modları çalışır; yapay zekâ gerektiren modlar devre dışıdır.</p>
      )}

      <section className="card" aria-labelledby="ders-sec">
        <h2 id="ders-sec">1. Ders seç</h2>
        <ul className="mt-3 flex flex-wrap gap-2">
          {data.courses.map((c) => (
            <li key={c.id}>
              <Link href={`/calis?ders=${c.id}${sp.mod ? `&mod=${sp.mod}` : ""}`} aria-current={c.id === courseId ? "true" : undefined}
                className={c.id === courseId ? "btn" : "btn-secondary"}>{c.code}</Link>
            </li>
          ))}
        </ul>
      </section>

      {course && (
        <form action={startSessionAction} className="card space-y-4" aria-labelledby="hedef">
          <h2 id="hedef">2. {course.code} {course.name} — çalışma hedefi</h2>
          <input type="hidden" name="courseId" value={course.id} />
          <div className="grid gap-4 sm:grid-cols-2">
            <label className="text-sm">Konu
              <select name="topicId" className="input mt-1" defaultValue={topicId}>
                <option value="">Belirli bir konu yok</option>
                {data.topics.map((t) => <option key={t.id} value={t.id}>{t.week ? `${t.week}. hafta — ` : ""}{t.title} ({TOPIC_STATUSES[t.status]})</option>)}
              </select>
            </label>
            <label className="text-sm">Çalışma modu
              <select name="mode" className="input mt-1" defaultValue={mode}>
                {Object.entries(STUDY_MODES).map(([k, v]) => (
                  <option key={k} value={k} disabled={v.ai && !ai.enabled}>{v.label}{v.ai && !ai.enabled ? " (yapay zekâ gerekir)" : ""}</option>
                ))}
              </select>
            </label>
          </div>
          <label className="block text-sm">Hedefin (isteğe bağlı)
            <input name="goal" className="input mt-1" placeholder="ör. Vize için gündem belirleme kuramını anlamak" />
          </label>
          <fieldset>
            <legend className="label">Kaynaklar</legend>
            {data.sources.length === 0 && <p className="muted">Bu derse kaynak yüklenmemiş. <Link href={`/dersler/${course.id}#kaynak-yukle`}>Kaynak yükle</Link></p>}
            <div className="space-y-1">
              {data.sources.map((s) => (
                <label key={s.id} className="flex items-center gap-2 text-sm">
                  <input type="checkbox" name="sourceIds" value={s.id} disabled={s.extraction_status !== "tamam"}
                    defaultChecked={s.extraction_status === "tamam" && (topicSources.length ? s.topic_id === topicId : true)} />
                  {s.title} {s.extraction_status !== "tamam" && <span className="badge-warn">metin yok</span>}
                </label>
              ))}
            </div>
            <label className="mt-3 flex items-center gap-2 text-sm">
              <input type="checkbox" name="onlySelected" defaultChecked /> Yalnızca seçili kaynaklara göre cevap ver
            </label>
          </fieldset>
          {ai.enabled && (
            <label className="block text-sm">Öğretmene ilk mesajın (boş bırakırsan oturum mesajsız açılır)
              <input name="starter" className="input mt-1" defaultValue={mode === "konu_anlatimi" ? "Bu konuyu bana öğret." : ""} />
            </label>
          )}
          <SubmitButton pendingText="Oturum başlatılıyor…">Çalışma oturumunu başlat</SubmitButton>
        </form>
      )}

      <section className="card" aria-labelledby="son">
        <h2 id="son">Son çalışma oturumların</h2>
        {data.recent.length === 0 ? <p className="muted mt-2">Henüz oturum yok.</p> : (
          <ul className="mt-2 divide-y divide-slate-200 dark:divide-slate-800">
            {data.recent.map((s) => (
              <li key={s.id} className="flex flex-wrap items-center justify-between gap-2 py-2 text-sm">
                <Link href={`/oturum/${s.id}`}>{courseLabel(s.course_id)} — {STUDY_MODES[s.mode].label}{s.goal ? `: ${s.goal}` : ""}</Link>
                <span className="muted">{s.status === "aktif" ? "Devam ediyor" : "Tamamlandı"} · {fmtDateTime(s.last_activity_at)}</span>
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}
