import Link from "next/link";
import { notFound } from "next/navigation";
import { addDebateSourceAction, deleteDebateAction, deleteDebateSourceAction, updateDebateAction, verifyDebateSourceAction } from "@/app/actions/modules";
import { ConfirmSubmit } from "@/components/ConfirmSubmit";
import { Flash } from "@/components/Flash";
import { SubmitButton } from "@/components/SubmitButton";
import { requireUser } from "@/lib/auth";
import { withUser } from "@/lib/db";
import { DEBATE_SOURCE_KINDS, DEBATE_THEMES, getDebate, listDebateSources } from "@/lib/data/debates";

export const metadata = { title: "Tartışma hazırlığı" };
export const dynamic = "force-dynamic";

const FIELDS = [
  ["claim", "1. Tartışılan iddia (doğru anlaşılmış hâliyle)"],
  ["academic_context", "2. Akademik kavramlarla açıklama"],
  ["counter_arguments", "3. Karşı görüşler (en güçlü hâlleriyle)"],
  ["islamic_perspective", "4. İslam düşüncesindeki ilgili yaklaşımlar (kaynaklara atıfla)"],
  ["class_answer", "5. Sınıfta söylenebilecek doğal cevap"],
  ["weaknesses", "6. İtirazlar ve kendi görüşümün zayıf noktaları"],
  ["uncertainties", "7. Belirsizlikler / emin olmadıklarım"],
] as const;

export default async function DebatePage({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<Record<string, string | undefined>> }) {
  const { id } = await params;
  const sp = await searchParams;
  const user = await requireUser();
  const data = await withUser(user.id, async (tx) => {
    const d = await getDebate(tx, id);
    return d ? { d, sources: await listDebateSources(tx, id) } : null;
  });
  if (!data) notFound();
  const { d, sources } = data;
  const here = `/tartismalar/${id}`;
  return (
    <div className="mx-auto max-w-4xl space-y-6">
      <Flash sp={sp} />
      <Link href="/tartismalar" className="text-sm">← Akademik tartışmalar</Link>
      <form action={updateDebateAction} className="card space-y-3">
        <input type="hidden" name="debateId" value={d.id} />
        <div className="grid gap-3 sm:grid-cols-3">
          <label className="text-sm sm:col-span-2">Başlık<input name="title" defaultValue={d.title} required className="input mt-1" /></label>
          <label className="text-sm">Tema<select name="theme" defaultValue={d.theme} className="input mt-1">{Object.entries(DEBATE_THEMES).map(([k, v]) => <option key={k} value={k}>{v}</option>)}</select></label>
        </div>
        {FIELDS.map(([name, label]) => (
          <label key={name} className="block text-sm">{label}<textarea name={name} defaultValue={d[name]} className="input mt-1 min-h-24" /></label>
        ))}
        <SubmitButton>Kaydet</SubmitButton>
      </form>

      <section className="card space-y-3" aria-labelledby="kaynaklar">
        <h2 id="kaynaklar">Kaynaklar</h2>
        {sources.length === 0 && <p className="muted">Henüz kaynak yok. Uydurma riskine karşı her alıntının künyesini eksiksiz gir.</p>}
        <ul className="divide-y divide-slate-200 dark:divide-slate-800">
          {sources.map((s) => (
            <li key={s.id} className="space-y-1 py-2 text-sm" data-testid="tartisma-kaynagi">
              <p className="flex flex-wrap items-center gap-2">
                <span className="badge">{DEBATE_SOURCE_KINDS[s.kind]}</span>
                <strong>{s.reference}</strong>
                {s.verified ? <span className="badge-ok">Doğrulandı</span> : <span className="badge-warn">Doğrulanmadı</span>}
              </p>
              {s.quote && <blockquote className="border-l-4 border-slate-300 pl-3 italic dark:border-slate-600">{s.quote}</blockquote>}
              {s.note && <p className="muted">{s.note}</p>}
              <span className="flex gap-2">
                <form action={verifyDebateSourceAction}>
                  <input type="hidden" name="sourceId" value={s.id} />
                  <input type="hidden" name="verified" value={s.verified ? "0" : "1"} />
                  <input type="hidden" name="returnTo" value={here} />
                  <SubmitButton className="btn-secondary">{s.verified ? "Doğrulamayı kaldır" : "Asıl kaynaktan kontrol ettim"}</SubmitButton>
                </form>
                <form action={deleteDebateSourceAction}>
                  <input type="hidden" name="sourceId" value={s.id} />
                  <input type="hidden" name="returnTo" value={here} />
                  <ConfirmSubmit message="Kaynak silinsin mi?">Sil</ConfirmSubmit>
                </form>
              </span>
            </li>
          ))}
        </ul>
        <form action={addDebateSourceAction} className="grid gap-3 border-t border-slate-200 pt-3 dark:border-slate-800 sm:grid-cols-3">
          <input type="hidden" name="debateId" value={d.id} />
          <label className="text-sm">Tür<select name="kind" className="input mt-1">{Object.entries(DEBATE_SOURCE_KINDS).map(([k, v]) => <option key={k} value={k}>{v}</option>)}</select></label>
          <label className="text-sm sm:col-span-2">Künye<input name="reference" required className="input mt-1" placeholder="ör. Âl-i İmrân 3/190 · Buhârî, İlim 10 · Eser adı, sayfa" /></label>
          <label className="text-sm sm:col-span-3">Alıntı (asıl metinden)<textarea name="quote" className="input mt-1" /></label>
          <label className="text-sm sm:col-span-3">Not (bağlam, yorum, tartışmaya katkısı)<textarea name="note" className="input mt-1" /></label>
          <div><SubmitButton className="btn-secondary">Kaynak ekle</SubmitButton></div>
        </form>
      </section>

      <form action={deleteDebateAction}>
        <input type="hidden" name="debateId" value={d.id} />
        <ConfirmSubmit message="Tartışma ve bütün kaynakları silinsin mi?">Tartışmayı sil</ConfirmSubmit>
      </form>
    </div>
  );
}
