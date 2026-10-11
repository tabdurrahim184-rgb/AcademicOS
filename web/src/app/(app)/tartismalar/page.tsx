import Link from "next/link";
import { createDebateAction } from "@/app/actions/modules";
import { Flash } from "@/components/Flash";
import { SubmitButton } from "@/components/SubmitButton";
import { requireUser } from "@/lib/auth";
import { withUser } from "@/lib/db";
import { listCourses } from "@/lib/data/courses";
import { DEBATE_THEMES, listDebates } from "@/lib/data/debates";
import { fmtDateTime } from "@/lib/format";

export const metadata = { title: "Akademik tartışmalar" };
export const dynamic = "force-dynamic";

export default async function DebatesPage({ searchParams }: { searchParams: Promise<Record<string, string | undefined>> }) {
  const sp = await searchParams;
  const user = await requireUser();
  const { debates, courses } = await withUser(user.id, async (tx) => ({ debates: await listDebates(tx), courses: await listCourses(tx) }));
  return (
    <div className="mx-auto max-w-4xl space-y-6">
      <Flash sp={sp} />
      <header>
        <h1>Akademik tartışmalar</h1>
        <p className="muted">Derslerde tartışılan bir iddiayı akademik kavramlarla anlamak, güçlü karşı görüşleri değerlendirmek ve İslam düşüncesinin bilim, akıl, insan, ahlak, adalet, devlet, toplum, sanat ve kâinat anlayışıyla ilişkisini kaynaklarıyla hazırlamak için ayrı bir çalışma alanı. Fetva veya genel dinî soru-cevap alanı değildir; buradaki notlar diğer derslerden ayrı tutulur.</p>
      </header>
      <section className="alert-info text-sm">
        Kaynak dürüstlüğü: Ayet, hadis ve eser künyelerini sen girersin; sistem referans üretmez. Hadisleri kaynağı ve numarasıyla (ör. Buhârî, el-Câmiu&apos;s-Sahîh, kitap ve hadis no.) yaz ve asıl metinden kontrol edince &quot;doğrulandı&quot; olarak işaretle. İnanç önermeleri ile bilimsel bulgular ayrı alanlarda tutulur.
      </section>
      <form action={createDebateAction} className="card grid gap-3 sm:grid-cols-3">
        <label className="text-sm sm:col-span-3">Tartışma başlığı<input name="title" required className="input mt-1" placeholder="ör. Medya etiğinde nesnellik mümkün mü?" /></label>
        <label className="text-sm">Tema<select name="theme" className="input mt-1">{Object.entries(DEBATE_THEMES).map(([k, v]) => <option key={k} value={k}>{v}</option>)}</select></label>
        <label className="text-sm">İlgili ders (isteğe bağlı)<select name="courseId" className="input mt-1"><option value="">—</option>{courses.map((c) => <option key={c.id} value={c.id}>{c.code} {c.name}</option>)}</select></label>
        <div className="flex items-end"><SubmitButton>Tartışma oluştur</SubmitButton></div>
      </form>
      {debates.length === 0 ? <p className="card muted">Henüz tartışma yok.</p> : (
        <ul className="space-y-2">
          {debates.map((d) => (
            <li key={d.id} className="card text-sm">
              <Link href={`/tartismalar/${d.id}`} className="font-medium">{d.title}</Link>
              <p className="muted">{DEBATE_THEMES[d.theme]} · {d.sources} kaynak{d.unverified ? ` (${d.unverified} doğrulanmadı)` : ""} · {fmtDateTime(d.updated_at)}</p>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
