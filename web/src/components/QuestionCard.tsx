import { aiGradeAction, answerAction, selfGradeAction } from "@/app/actions/study";
import type { Attempt, Question } from "@/lib/data/study";
import { isObjective, QUESTION_TYPES } from "@/lib/grading";
import { SubmitButton } from "./SubmitButton";

const ORIGIN = { kullanici: "Kendi sorum", yapay_zeka: "Yapay zekâ üretimi", ogretim_elemani: "Öğretim elemanı sorusu" } as const;

function describeResponse(q: Question, r: unknown): string {
  const x = r as Record<string, unknown>;
  if (q.type === "coktan_secmeli") return q.options[Number(x.index)] ?? "—";
  if (q.type === "dogru_yanlis") return x.value ? "Doğru" : "Yanlış";
  if (q.type === "eslestirme") return ((x.pairs as number[]) ?? []).map((p, i) => `${i + 1} → ${q.options[p] ?? "?"}`).join(", ");
  return String(x.text ?? "");
}

function correctAnswer(q: Question): string | null {
  const a = q.answer as Record<string, unknown> | null;
  if (!a) return null;
  if (q.type === "coktan_secmeli") return q.options[Number(a.index)] ?? null;
  if (q.type === "dogru_yanlis") return a.value ? "Doğru" : "Yanlış";
  if (q.type === "kisa_cevap" || q.type === "bosluk_doldurma") return (a.accepted as string[]).join(" / ");
  if (q.type === "eslestirme") return (a.pairs as number[]).map((p, i) => `${i + 1} → ${q.options[p]}`).join(", ");
  return null;
}

/** Soru gösterimi + cevap formu + (varsa) son denemenin sonucu. */
export function QuestionCard({
  q,
  attempt,
  sessionId,
  returnTo,
  aiEnabled,
  index,
}: {
  q: Question;
  attempt?: Attempt | null;
  sessionId?: string | null;
  returnTo: string;
  aiEnabled: boolean;
  index?: number;
}) {
  const ca = correctAnswer(q);
  return (
    <article className="card space-y-3" aria-labelledby={`q-${q.id}`}>
      <div className="flex flex-wrap items-center gap-2">
        {index != null && <span className="badge">Soru {index}</span>}
        <span className="badge">{QUESTION_TYPES[q.type]}</span>
        <span className={q.origin === "yapay_zeka" ? "badge-warn" : "badge"}>{ORIGIN[q.origin]}</span>
        {q.concept && <span className="muted">Kavram: {q.concept}</span>}
      </div>
      <p id={`q-${q.id}`} className="whitespace-pre-wrap font-medium">{q.prompt}</p>

      {attempt ? (
        <div className="space-y-2">
          <p className="text-sm"><span className="font-medium">Cevabın:</span> {describeResponse(q, attempt.response)}</p>
          {attempt.grading_method === "bekliyor" ? (
            <div className="alert-info space-y-3">
              <p>Bu açık uçlu bir soru; otomatik puanlanamaz. Değerlendirme ölçütüyle karşılaştır ve kendini puanla{aiEnabled ? " ya da yapay zekâ değerlendirmesi iste" : ""}.</p>
              {q.rubric && <p><span className="font-medium">Ölçüt:</span> {q.rubric}</p>}
              {q.explanation && <p><span className="font-medium">Örnek cevap / açıklama:</span> {q.explanation}</p>}
              <form action={selfGradeAction} className="flex flex-wrap items-end gap-2">
                <input type="hidden" name="attemptId" value={attempt.id} />
                <input type="hidden" name="returnTo" value={returnTo} />
                <label className="text-sm">Öz değerlendirme
                  <select name="score" className="input mt-1 w-auto" defaultValue="70">
                    <option value="100">Tam ve gerekçeli (100)</option>
                    <option value="75">Büyük ölçüde doğru (75)</option>
                    <option value="50">Kısmen doğru (50)</option>
                    <option value="20">Büyük ölçüde eksik (20)</option>
                    <option value="0">Yanlış / boş (0)</option>
                  </select>
                </label>
                <SubmitButton className="btn-secondary">Puanımı kaydet</SubmitButton>
              </form>
              {aiEnabled && (
                <form action={aiGradeAction}>
                  <input type="hidden" name="attemptId" value={attempt.id} />
                  <input type="hidden" name="returnTo" value={returnTo} />
                  <SubmitButton className="btn-secondary" pendingText="Değerlendiriliyor…">Yapay zekâ ile değerlendir</SubmitButton>
                </form>
              )}
            </div>
          ) : (
            <div className={attempt.is_correct ? "alert-ok" : "alert-err"} role="status">
              <p className="font-semibold">
                {attempt.is_correct ? "Doğru" : "Yanlış"}
                {attempt.score != null && ` — ${Number(attempt.score)} / 100`}
                <span className="ml-2 text-xs font-normal">
                  ({attempt.grading_method === "otomatik" ? "otomatik değerlendirme" : attempt.grading_method === "yapay_zeka" ? "yapay zekâ değerlendirmesi" : "öz değerlendirme"})
                </span>
              </p>
              {attempt.feedback && <p className="mt-1 whitespace-pre-wrap">{attempt.feedback}</p>}
              {!attempt.is_correct && ca && <p className="mt-1"><span className="font-medium">Doğru cevap:</span> {ca}</p>}
              {q.explanation && <p className="mt-1"><span className="font-medium">Açıklama:</span> {q.explanation}</p>}
              {!attempt.is_correct && <p className="mt-1 text-xs">Bu soru yanlışlar defterine eklendi ve tekrar listene alındı.</p>}
            </div>
          )}
        </div>
      ) : (
        <form action={answerAction} className="space-y-3">
          <input type="hidden" name="questionId" value={q.id} />
          <input type="hidden" name="type" value={q.type} />
          <input type="hidden" name="sessionId" value={sessionId ?? ""} />
          <input type="hidden" name="returnTo" value={returnTo} />
          {q.type === "coktan_secmeli" && (
            <fieldset className="space-y-2">
              <legend className="sr-only">Seçenekler</legend>
              {q.options.map((o, i) => (
                <label key={i} className="flex items-start gap-2 text-sm">
                  <input type="radio" name="choice" value={i} className="mt-1" /> <span>{String.fromCharCode(65 + i)}) {o}</span>
                </label>
              ))}
            </fieldset>
          )}
          {q.type === "dogru_yanlis" && (
            <fieldset className="flex gap-4 text-sm">
              <legend className="sr-only">Doğru mu yanlış mı?</legend>
              <label className="flex items-center gap-2"><input type="radio" name="choice" value="dogru" /> Doğru</label>
              <label className="flex items-center gap-2"><input type="radio" name="choice" value="yanlis" /> Yanlış</label>
            </fieldset>
          )}
          {q.type === "eslestirme" && (
            <div className="space-y-2">
              {q.options.map((_, i) => (
                <label key={i} className="flex items-center gap-2 text-sm">
                  <span className="w-6">{i + 1}.</span>
                  <select name="pair" className="input w-auto" required defaultValue="">
                    <option value="" disabled>Seç…</option>
                    {q.options.map((o, j) => <option key={j} value={j}>{o}</option>)}
                  </select>
                </label>
              ))}
            </div>
          )}
          {(q.type === "kisa_cevap" || q.type === "bosluk_doldurma") && (
            <input name="text" className="input" placeholder="Cevabın" aria-label="Cevabın" autoComplete="off" />
          )}
          {!isObjective(q.type) && (
            <textarea name="text" className="input min-h-32" placeholder="Cevabını kendi cümlelerinle yaz…" aria-label="Cevabın" />
          )}
          <SubmitButton pendingText="Gönderiliyor…">Cevabı gönder</SubmitButton>
        </form>
      )}
    </article>
  );
}
