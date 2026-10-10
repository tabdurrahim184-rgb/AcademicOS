import Link from "next/link";
import { requireUser } from "@/lib/auth";
import { withUser } from "@/lib/db";
import { loadDashboard } from "@/lib/data/dashboard";
import { ASSESSMENT_KINDS } from "@/lib/data/assessments";
import { STUDY_MODES } from "@/lib/data/study";
import { getAIStatus } from "@/lib/ai/provider";
import { fmtDateTime, relativeDays } from "@/lib/format";
import { trTime, WEEKDAYS } from "@/lib/schedule";
import type { Recommendation } from "@/lib/recommend";

export const metadata = { title: "Kontrol paneli" };
export const dynamic = "force-dynamic";

function recHref(r: Recommendation) {
  switch (r.action) {
    case "devam": return `/oturum/${r.sessionId}`;
    case "calis": return `/calis?${new URLSearchParams({ ders: r.courseId, ...(r.topicId ? { konu: r.topicId } : {}), mod: r.mode })}`;
    case "materyal_yukle": return `/dersler/${r.courseId}?konu=${r.topicId}#kaynak-yukle`;
    case "konu_ekle": return r.courseId ? `/dersler/${r.courseId}#konu-ekle` : "/dersler";
  }
}
const recLabel = (r: Recommendation) =>
  r.action === "devam" ? "Kaldığın yerden devam et" : r.action === "calis" ? `Şimdi ders çalış — ${STUDY_MODES[r.mode].label}` : r.action === "materyal_yukle" ? "Materyali yükle" : "Konu ekle";

export default async function Dashboard() {
  const user = await requireUser();
  const d = await withUser(user.id, (tx) => loadDashboard(tx, new Date(), user.timezone));
  const ai = getAIStatus();
  const recCourse = d.courses.find((c) => "courseId" in d.rec && c.id === d.rec.courseId);
  const project = d.courses.find((c) => c.code === "GZT440");

  return (
    <div className="mx-auto max-w-6xl space-y-6">
      <header>
        <h1>Merhaba, {user.name.split(" ")[0]}</h1>
        <p className="muted">{WEEKDAYS[d.today.weekday]} · Kıbrıs saati {trTime(d.today.time)} · Hedef mezuniyet: Ocak 2027 (resmî tarih değil, kişisel hedef)</p>
      </header>

      <section className="card border-indigo-300 bg-indigo-50/60 dark:border-indigo-800 dark:bg-indigo-950/40" aria-labelledby="simdi">
        <h2 id="simdi">Şimdi ne çalışmalısın?</h2>
        {recCourse && <p className="mt-1 text-sm font-medium">{recCourse.code} — {recCourse.name}</p>}
        <p className="mt-1">{d.rec.reason}</p>
        <div className="mt-4 flex flex-wrap gap-2">
          <Link href={recHref(d.rec)} className="btn text-base">{recLabel(d.rec)}</Link>
          <Link href="/calis" className="btn-secondary">Başka bir hedef seç</Link>
        </div>
      </section>

      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <Stat label="Tekrar zamanı gelen" value={d.totalDue} href="/tekrar" />
        <Stat label="Açık yanlış" value={d.totalMistakes} href="/yanlislar" />
        <Stat label="Materyali eksik konu" value={d.missingMaterials} href="/telafi" />
        <Stat label="Tamamlanan konu" value={`${d.topicTotals.done} / ${d.topicTotals.total}`} href="/telafi" />
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <section className="card" aria-labelledby="bugun">
          <h2 id="bugun">Bugünkü dersler</h2>
          {d.todaysClasses.length === 0 ? (
            <p className="muted mt-2">Bugün kayıtlı yüz yüze ders yok. (Çevrimiçi derslerin saatleri tanımlı değilse burada görünmez.)</p>
          ) : (
            <ul className="mt-2 divide-y divide-slate-200 dark:divide-slate-800">
              {d.todaysClasses.map((m) => (
                <li key={m.id} className="flex items-center justify-between py-2 text-sm">
                  <Link href={`/dersler/${m.course.id}`}>{m.course.code} {m.course.name}</Link>
                  <span className="tabular-nums">{trTime(m.start_time)}–{trTime(m.end_time)}</span>
                </li>
              ))}
            </ul>
          )}
        </section>

        <section className="card" aria-labelledby="yaklasan">
          <h2 id="yaklasan">Yaklaşan sınav ve teslimler</h2>
          {d.upcoming.length === 0 ? (
            <p className="muted mt-2">Kayıtlı sınav veya ödev yok. Ders sayfasından ekleyebilirsin; bilinmeyen tarihler uydurulmaz.</p>
          ) : (
            <ul className="mt-2 divide-y divide-slate-200 dark:divide-slate-800">
              {d.upcoming.map((a) => (
                <li key={a.id} className="flex items-center justify-between gap-2 py-2 text-sm">
                  <span><span className="badge mr-2">{ASSESSMENT_KINDS[a.kind]}</span>{a.course.code} — {a.title}</span>
                  <span className={a.due_at ? "tabular-nums" : "badge-warn"}>
                    {a.due_at ? `${fmtDateTime(a.due_at)} (${relativeDays(a.due_at)})` : "Tarih bekleniyor"}
                  </span>
                </li>
              ))}
            </ul>
          )}
        </section>

        {project && (
          <section className="card" aria-labelledby="proje">
            <h2 id="proje">Bölüm Projesi (GZT440)</h2>
            <p className="muted mt-2">Proje çalışma alanı (araştırma soruları, danışman görüşmeleri, taslaklar) bir sonraki aşamada eklenecek. Şimdilik konuları, kaynakları ve teslim tarihlerini ders sayfasından takip edebilirsin.</p>
            <Link href={`/dersler/${project.id}`} className="btn-secondary mt-3">GZT440 sayfasını aç</Link>
          </section>
        )}

        <section className="card" aria-labelledby="yz">
          <h2 id="yz">Yapay zekâ öğretmeni</h2>
          {ai.enabled ? (
            <p className="mt-2 text-sm"><span className="badge-ok">Bağlı</span> Sağlayıcı: {ai.provider}, model: {ai.model}. Kullanım, sağlayıcının API fiyatlarıyla ayrıca ücretlendirilir.</p>
          ) : (
            <p className="mt-2 text-sm"><span className="badge-warn">Bağlı değil</span> {ai.reason} Kaynak okuma, not, soru çözme, yanlışlar defteri ve aralıklı tekrar yapay zekâ olmadan çalışır. Ayrıntı: <Link href="/ayarlar">Ayarlar</Link>.</p>
          )}
        </section>
      </div>
    </div>
  );
}

function Stat({ label, value, href }: { label: string; value: number | string; href: string }) {
  return (
    <Link href={href} className="card block no-underline hover:border-indigo-300 hover:no-underline">
      <span className="block text-2xl font-semibold tabular-nums text-slate-900 dark:text-slate-100">{value}</span>
      <span className="muted">{label}</span>
    </Link>
  );
}
