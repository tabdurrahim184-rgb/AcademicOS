import Link from "next/link";
import { explainMistakeAction } from "@/app/actions/study";
import { Flash } from "@/components/Flash";
import { SubmitButton } from "@/components/SubmitButton";
import { TeacherText } from "@/components/TeacherText";
import { getUserAIStatus } from "@/lib/ai/chatgpt";
import { requireUser } from "@/lib/auth";
import { withUser } from "@/lib/db";
import { listMistakes, type MistakeRow } from "@/lib/data/study";
import { fmtDateTime } from "@/lib/format";
import { QUESTION_TYPES } from "@/lib/grading";

export const metadata = { title: "Yanlışlar defteri" };
export const dynamic = "force-dynamic";

function resp(m: MistakeRow) {
  const r = m.response as Record<string, unknown>;
  if (typeof r?.text === "string") return r.text;
  if (typeof r?.value === "boolean") return r.value ? "Doğru" : "Yanlış";
  if (typeof r?.index === "number") return `${String.fromCharCode(65 + r.index)} seçeneği`;
  return "—";
}

export default async function MistakesPage({ searchParams }: { searchParams: Promise<Record<string, string | undefined>> }) {
  const sp = await searchParams;
  const durum = sp.durum;
  const ai = await getUserAIStatus(user.id);
  const status = durum === "cozuldu" ? "cozuldu" : durum === "hepsi" ? "hepsi" : "acik";
  const user = await requireUser();
  const mistakes = await withUser(user.id, (tx) => listMistakes(tx, status));
  return (
    <div className="mx-auto max-w-4xl space-y-6">
      <Flash sp={sp} />
      <h1>Yanlışlar defteri</h1>
      <p className="muted">Yanlış cevapların burada gerekçesiyle saklanır ve tekrar listene eklenir. Aynı soruyu sonradan doğru cevaplarsan &quot;çözüldü&quot; olarak işaretlenir.</p>
      <nav className="flex gap-2" aria-label="Filtre">
        {[["acik", "Açık"], ["cozuldu", "Çözüldü"], ["hepsi", "Hepsi"]].map(([k, v]) => (
          <Link key={k} href={`/yanlislar?durum=${k}`} className={status === k ? "btn" : "btn-secondary"} aria-current={status === k ? "page" : undefined}>{v}</Link>
        ))}
      </nav>
      {mistakes.length === 0 ? <p className="card muted">Bu listede kayıt yok.</p> : (
        <ul className="space-y-3">
          {mistakes.map((m) => (
            <li key={m.id} className="card space-y-1 text-sm">
              <p className="flex flex-wrap gap-2"><span className="badge">{m.course_code}</span><span className="badge">{QUESTION_TYPES[m.type]}</span>{m.topic_title && <span className="badge">{m.topic_title}</span>}
                <span className={m.status === "acik" ? "badge-err" : "badge-ok"}>{m.status === "acik" ? "Açık" : "Çözüldü"}</span>
                {m.misconception && <span className="badge-warn" title="Emin olunarak verilen yanlış cevap">Kavram yanılgısı olabilir</span>}</p>
              <p className="whitespace-pre-wrap font-medium">{m.prompt}</p>
              <p><span className="font-medium">Senin cevabın:</span> {resp(m)}</p>
              {m.feedback && <p className="whitespace-pre-wrap"><span className="font-medium">Değerlendirme:</span> {m.feedback}</p>}
              {m.explanation && <p className="whitespace-pre-wrap"><span className="font-medium">Açıklama:</span> {m.explanation}</p>}
              <p className="muted">Kavram: {m.concept} · {fmtDateTime(m.created_at)}</p>
              {m.ai_explanation ? (
                <div className="mt-2 rounded-lg border border-slate-200 p-3 dark:border-slate-700">
                  <p className="mb-1 text-xs font-semibold text-slate-500">Öğretmen açıklaması (yapay zekâ)</p>
                  <TeacherText text={m.ai_explanation} />
                </div>
              ) : ai.enabled ? (
                <form action={explainMistakeAction} className="mt-2">
                  <input type="hidden" name="mistakeId" value={m.id} />
                  <input type="hidden" name="returnTo" value={`/yanlislar?durum=${status}`} />
                  <SubmitButton className="btn-secondary" pendingText="Açıklama hazırlanıyor…">Neden yanlış? Öğretmene sor</SubmitButton>
                </form>
              ) : null}
            </li>
          ))}
        </ul>
      )}
      {status === "acik" && mistakes.length > 0 && (
        <p><Link href="/tekrar" className="btn">Tekrar et</Link></p>
      )}
    </div>
  );
}
