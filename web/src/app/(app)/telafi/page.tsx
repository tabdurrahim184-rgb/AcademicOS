import Link from "next/link";
import { setTopicStatusAction } from "@/app/actions/academic";
import { SubmitButton } from "@/components/SubmitButton";
import { requireUser } from "@/lib/auth";
import { withUser } from "@/lib/db";
import { listCourses, listTopics, TOPIC_STATUSES } from "@/lib/data/courses";

export const metadata = { title: "Telafi planı" };
export const dynamic = "force-dynamic";

export default async function CatchUpPage() {
  const user = await requireUser();
  const { courses, topics } = await withUser(user.id, async (tx) => ({ courses: await listCourses(tx), topics: await listTopics(tx) }));
  const open = topics.filter((t) => t.status !== "tamamlandi");
  return (
    <div className="mx-auto max-w-5xl space-y-6">
      <h1>Telafi ve ilerleme durumu</h1>
      <p className="muted">
        Başlangıçta iki haftalık açık olduğu kaydedildi; gerçek eksikler her dersin haftalarını ve konularını girdikçe belirlenir. Her konunun durumunu buradan güncelleyebilirsin.
        Zaman kapasitesine göre otomatik 14 günlük plan üretimi sonraki aşamadadır; şu an öneriler kontrol panelindeki &quot;Şimdi ne çalışmalısın?&quot; kartından gelir.
      </p>
      <p className="text-sm">{topics.length} konu · {open.length} açık · {topics.filter((t) => t.status === "materyal_eksik").length} konunun materyali eksik</p>
      {courses.map((c) => {
        const ts = topics.filter((t) => t.course_id === c.id);
        return (
          <section key={c.id} className="card" aria-labelledby={`c-${c.id}`}>
            <h2 id={`c-${c.id}`} className="text-base"><Link href={`/dersler/${c.id}`}>{c.code} {c.name}</Link></h2>
            {ts.length === 0 ? (
              <p className="muted mt-1">Konu girilmedi. <Link href={`/dersler/${c.id}#konu-ekle`}>Hafta / konu ekle</Link></p>
            ) : (
              <ul className="mt-2 divide-y divide-slate-200 dark:divide-slate-800">
                {ts.map((t) => (
                  <li key={t.id} className="flex flex-wrap items-center justify-between gap-2 py-2 text-sm">
                    <span>{t.week ? `${t.week}. hafta — ` : ""}{t.title}</span>
                    <form action={setTopicStatusAction} className="flex items-center gap-2">
                      <input type="hidden" name="topicId" value={t.id} />
                      <input type="hidden" name="returnTo" value="/telafi" />
                      <select name="status" defaultValue={t.status} className="input w-auto" aria-label={`${t.title} durumu`}>
                        {Object.entries(TOPIC_STATUSES).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
                      </select>
                      <SubmitButton className="btn-secondary">Kaydet</SubmitButton>
                    </form>
                  </li>
                ))}
              </ul>
            )}
          </section>
        );
      })}
    </div>
  );
}
