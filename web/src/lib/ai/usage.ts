/** Yapay zekâ kullanım kaydı ve limit uygulaması (her çağrıdan önce kontrol, sonra kayıt). */
import { withUser, type Tx } from "../db";
import { checkLimits, estimateCost, getLimits, priceFor } from "./config";
import { AIRequestError, type AIProvider, type CompletionRequest, type CompletionResult } from "./provider";

export async function usageSummary(tx: Tx, provider: string | null, model: string | null) {
  const { rows } = await tx.query<{ today_requests: number; month_requests: number; month_in: string; month_out: string; month_failed: number }>(
    `SELECT
       count(*) FILTER (WHERE (created_at AT TIME ZONE 'Europe/Nicosia')::date = (now() AT TIME ZONE 'Europe/Nicosia')::date)::int AS today_requests,
       count(*) FILTER (WHERE date_trunc('month', created_at AT TIME ZONE 'Europe/Nicosia') = date_trunc('month', now() AT TIME ZONE 'Europe/Nicosia'))::int AS month_requests,
       coalesce(sum(input_tokens) FILTER (WHERE date_trunc('month', created_at AT TIME ZONE 'Europe/Nicosia') = date_trunc('month', now() AT TIME ZONE 'Europe/Nicosia')), 0) AS month_in,
       coalesce(sum(output_tokens) FILTER (WHERE date_trunc('month', created_at AT TIME ZONE 'Europe/Nicosia') = date_trunc('month', now() AT TIME ZONE 'Europe/Nicosia')), 0) AS month_out,
       count(*) FILTER (WHERE NOT ok AND date_trunc('month', created_at AT TIME ZONE 'Europe/Nicosia') = date_trunc('month', now() AT TIME ZONE 'Europe/Nicosia'))::int AS month_failed
     FROM ai_usage`,
  );
  const r = rows[0];
  const price = provider && model ? priceFor(provider, model) : null;
  return {
    todayRequests: r.today_requests,
    monthRequests: r.month_requests,
    monthFailed: r.month_failed,
    monthInputTokens: Number(r.month_in),
    monthOutputTokens: Number(r.month_out),
    monthCostUsd: estimateCost(price, Number(r.month_in), Number(r.month_out)),
    limits: getLimits(),
  };
}

/** Limitleri uygular, çağrıyı yapar ve sonucu (başarılı/başarısız) kaydeder. */
export async function callAI(userId: string, purpose: string, provider: AIProvider, req: CompletionRequest): Promise<CompletionResult> {
  const summary = await withUser(userId, (tx) => usageSummary(tx, provider.id, provider.model));
  const blocked = checkLimits(summary, summary.limits);
  if (blocked) throw new AIRequestError(blocked);
  try {
    const res = await provider.complete(req);
    await withUser(userId, (tx) =>
      tx.query("INSERT INTO ai_usage (user_id, provider, model, purpose, input_tokens, output_tokens, ok) VALUES ($1,$2,$3,$4,$5,$6,true)", [
        userId, res.provider, res.model, purpose, res.inputTokens, res.outputTokens,
      ]),
    );
    return res;
  } catch (err) {
    await withUser(userId, (tx) =>
      tx.query("INSERT INTO ai_usage (user_id, provider, model, purpose, ok) VALUES ($1,$2,$3,$4,false)", [userId, provider.id, provider.model, purpose]),
    ).catch(() => {});
    throw err;
  }
}
