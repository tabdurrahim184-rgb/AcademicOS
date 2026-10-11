import Link from "next/link";
import { createTopicAction, setTopicStatusAction } from "@/app/actions/academic";
import { setCatchUpAction } from "@/app/actions/plan";
import { Flash } from "@/components/Flash";
import { SubmitButton } from "@/components/SubmitButton";
import { requireUser } from "@/lib/auth";
import { withUser } from "@/lib/db";
import { loadCatchUp } from "@/lib/data/catchup";
import { TOPIC_STATUSES } from "@/lib/data/courses";

export const metadata = { title: "Telafi" };
export const dynamic = "force-dynamic";

export default async function CatchUpPage({ searchParams }: { searchParams: Promise<Record<string, string | undefined>> }) {
  const sp = await searchParams;
  const user = await requireUser();
  const data = await withUser(user.id, (tx) => loadCatchUp(tx));
  const all = data.flatMap((d) => d.topics);
  const catchUp = all.filter((t) => t.is_catch_up);
  const here = "/telafi";

  return (
    <div className="mx-auto max-w-5xl space-y-6">
      <Flash sp={sp} />
      <header className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h1>Telafi ve ilerleme</h1>
          <p className="muted">
            Kaçırdığın haftaların konularını <strong>telafi</strong> olarak işaretle; çalışma planı bunları güncel derslerini ihmal etmeden, günlük kapasitene göre 14 güne yayar.
            Gerçek eksikler, konuları ve materyalleri girdikçe netleşir — sistem eksik hafta uydurmaz.
          </p>
        </div>
        <Link href="/plan" className="btn">14 günlük plana git</Link>
      </header>

      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <Stat label="Telafi konusu" value={`${catchUp.filter((t) => t.status === "tamamlandi").length} / ${catchUp.length} tamam`} />
        <Stat label="Materyali eksik" value={all.filter((t) => t.status === "materyal_eksik").length} />
        <Stat label="Açık yanlış" value={data.reduce((n, d) => n + d.openMistakes, 0)} />
        <Stat label="Tekrar zamanı gelen" value={data.reduce((n, d) => n + d.dueReviews, 0)} />
      </div>

      {data.map((d) => (
        <section key={d.course.id} className="card space-y-3" aria-labelledby={`c-${d.course.id}`} data-testid="telafi-dersi">
          <div className="flex flex-wrap items-baseline justify-between gap-2">
            <h2 id={`c-${d.course.id}`} className="text-base"><Link href={`/dersler/${d.course.id}`}>{d.course.code} {d.course.name}</Link></h2>
            <span className="muted">{d.completed.length}/{d.topics.length} konu tamamlandı</span>
          </div>

          {d.topics.length === 0 ? (
            <p className="muted">Bu ders için henüz hafta/konu girilmedi. İzlencedeki haftaları ekleyerek gerçek eksikleri görünür kıl.</p>
          ) : (
            <dl className="grid gap-2 text-sm sm:grid-cols-2">
              <Row label="Materyali eksik" value={d.missingMaterial.length ? d.missingMaterial.map((t) => t.title).join(", ") : "Yok"} warn={d.missingMaterial.length > 0} />
              <Row label="Çalışılmamış haftalar" value={d.unstudiedWeeks.length ? d.unstudiedWeeks.map((w) => `${w}.`).join(", ") + " hafta" : "Yok"} warn={d.unstudiedWeeks.length > 0} />
              <Row label="Konu girilmemiş haftalar" value={d.weeksWithoutTopics.length ? d.weeksWithoutTopics.map((w) => `${w}.`).join(", ") + " hafta" : "Yok"} warn={d.weeksWithoutTopics.length > 0} />
              <Row label="Açık yanlış" value={`${d.openMistakes}${d.misconceptions ? ` (${d.misconceptions} tanesi emin olunarak yapılmış — kavram yanılgısı olabilir)` : ""}`} warn={d.openMistakes > 0} />
              <Row label="Tekrar gereken kavramlar" value={d.weakConcepts.length ? d.weakConcepts.map((c) => `${c.concept} (${c.open})`).join(", ") : "Yok"} warn={d.weakConcepts.length > 0} />
              <Row label="Tekrar zamanı gelen soru" value={String(d.dueReviews)} warn={d.dueReviews > 0} />
            </dl>
          )}

          {d.topics.length > 0 && (
            <ul className="divide-y divide-slate-200 dark:divide-slate-800">
              {d.topics.map((t) => (
                <li key={t.id} className="flex flex-wrap items-center justify-between gap-2 py-2 text-sm">
                  <span>
                    {t.week ? `${t.week}. hafta — ` : ""}<Link href={`/konular/${t.id}`}>{t.title}</Link>{" "}
                    {t.is_catch_up && <span className="badge-warn">Telafi</span>}{" "}
                    <span className="muted">{t.sourceCount} kaynak{t.openMistakes ? ` · ${t.openMistakes} yanlış` : ""}</span>
                  </span>
                  <span className="flex flex-wrap items-center gap-2">
                    <form action={setCatchUpAction}>
                      <input type="hidden" name="topicId" value={t.id} />
                      <input type="hidden" name="value" value={t.is_catch_up ? "0" : "1"} />
                      <input type="hidden" name="returnTo" value={here} />
                      <SubmitButton className="btn-secondary" pendingText="…">{t.is_catch_up ? "Telafiden çıkar" : "Telafi olarak işaretle"}</SubmitButton>
                    </form>
                    <form action={setTopicStatusAction} className="flex items-center gap-2">
                      <input type="hidden" name="topicId" value={t.id} />
                      <input type="hidden" name="returnTo" value={here} />
                      <select name="status" defaultValue={t.status} className="input w-auto" aria-label={`${t.title} durumu`}>
                        {Object.entries(TOPIC_STATUSES).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
                      </select>
                      <SubmitButton className="btn-secondary">Kaydet</SubmitButton>
                    </form>
                  </span>
                </li>
              ))}
            </ul>
          )}

          <details>
            <summary className="cursor-pointer text-sm font-medium">Kaçırdığın bir haftayı ekle</summary>
            <form action={createTopicAction} className="mt-3 grid gap-3 sm:grid-cols-[6rem_1fr_auto] sm:items-end">
              <input type="hidden" name="courseId" value={d.course.id} />
              <input type="hidden" name="returnTo" value={here} />
              <input type="hidden" name="isCatchUp" value="on" />
              <label className="text-sm">Hafta<input name="week" type="number" min={1} max={20} className="input mt-1" /></label>
              <label className="text-sm">Konu başlığı<input name="title" required className="input mt-1" /></label>
              <SubmitButton>Telafi konusu ekle</SubmitButton>
            </form>
          </details>
        </section>
      ))}
    </div>
  );
}

function Stat({ label, value }: { label: string; value: number | string }) {
  return (
    <div className="card">
      <span className="block text-xl font-semibold tabular-nums">{value}</span>
      <span className="muted">{label}</span>
    </div>
  );
}

function Row({ label, value, warn }: { label: string; value: string; warn: boolean }) {
  return (
    <div>
      <dt className="muted">{label}</dt>
      <dd className={warn ? "font-medium text-amber-800 dark:text-amber-300" : ""}>{value}</dd>
    </div>
  );
}
