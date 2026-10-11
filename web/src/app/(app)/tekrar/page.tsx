import Link from "next/link";
import { Flash } from "@/components/Flash";
import { QuestionCard } from "@/components/QuestionCard";
import { getAIStatus } from "@/lib/ai/provider";
import { requireUser } from "@/lib/auth";
import { withUser } from "@/lib/db";
import { isUuid } from "@/lib/data/courses";
import { getQuestion, listDueCards, type Attempt } from "@/lib/data/study";
import { fmtDateTime } from "@/lib/format";

export const metadata = { title: "Tekrar" };
export const dynamic = "force-dynamic";

/** Aralıklı tekrar: zamanı gelen sorular teker teker sorulur (SM-2). */
export default async function ReviewPage({ searchParams }: { searchParams: Promise<Record<string, string | undefined>> }) {
  const sp = await searchParams;
  const user = await requireUser();
  const ai = getAIStatus();
  const data = await withUser(user.id, async (tx) => {
    const due = await listDueCards(tx);
    let result: { attempt: Attempt; q: Awaited<ReturnType<typeof getQuestion>> } | null = null;
    if (sp.sonuc && isUuid(sp.sonuc)) {
      const { rows } = await tx.query<Attempt>("SELECT * FROM attempts WHERE id = $1", [sp.sonuc]);
      if (rows[0]) result = { attempt: rows[0], q: await getQuestion(tx, rows[0].question_id) };
    }
    const current = due[0] ? await getQuestion(tx, due[0].question_id) : null;
    const { rows: next } = await tx.query<{ due_at: Date }>("SELECT due_at FROM review_cards WHERE due_at > now() ORDER BY due_at LIMIT 1");
    return { due, result, current, nextDue: next[0]?.due_at ?? null };
  });

  return (
    <div className="mx-auto max-w-3xl space-y-6">
      <Flash sp={sp} />
      <h1>Aralıklı tekrar</h1>
      <p className="muted">Yanlış cevapladığın veya daha önce çözdüğün sorular SM-2 algoritmasıyla planlanır: doğru cevaplarda aralık uzar, yanlışlarda soru ertesi gün yeniden gelir.</p>
      {data.result?.q && (
        <div>
          <h2 className="mb-2 text-base">Son cevabın</h2>
          <QuestionCard q={data.result.q} attempt={data.result.attempt} returnTo="/tekrar" aiEnabled={ai.enabled} />
        </div>
      )}
      {data.current && data.current.id !== data.result?.q?.id ? (
        <div>
          <h2 className="mb-2 text-base">Sıradaki soru <span className="muted font-normal">({data.due.length} soru bekliyor · {data.due[0].course_code})</span></h2>
          <QuestionCard q={data.current} returnTo="/tekrar" aiEnabled={ai.enabled} />
        </div>
      ) : data.due.length > 1 ? (
        <Link href="/tekrar" className="btn">Sonraki soru</Link>
      ) : !data.current ? (
        <p className="alert-ok">Şu anda tekrar zamanı gelen soru yok.{data.nextDue && ` Bir sonraki tekrar: ${fmtDateTime(data.nextDue)}.`}</p>
      ) : null}
    </div>
  );
}
