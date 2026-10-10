/**
 * Yapay zekâ yapılandırması, fiyat tablosu ve limitler — saf, birim testlenebilir.
 *
 * Varsayılan model YOKTUR: kullanıcı maliyeti bilerek AI_MODEL seçmelidir.
 * Fiyatlar: Anthropic resmî fiyat sayfası (platform.claude.com/docs/en/about-claude/pricing),
 * 10 Ekim 2026'da doğrulandı. OpenAI fiyatları bu ortamdan doğrulanamadığı için tabloda yoktur;
 * AI_PRICE_INPUT_PER_MTOK / AI_PRICE_OUTPUT_PER_MTOK ile girilebilir.
 */
type Env = Record<string, string | undefined>;

export type AIStatus =
  | { enabled: true; provider: "anthropic" | "openai" | "chatgpt"; model: string }
  | { enabled: false; reason: string };

/** Uyarlanabilir düşünme (adaptive thinking) destekleyen, önerilen güncel Anthropic modelleri. */
export const ANTHROPIC_MODELS = {
  "claude-haiku-5-5": { label: "Claude Haiku 5.5", input: 0.1, output: 0.5, note: "En düşük maliyet; 100K token üzerindeki istemlerde 0,50 $ / 2,50 $." },
  "claude-sonnet-5-5": { label: "Claude Sonnet 5.5", input: 2, output: 10, note: "Maliyet/kalite dengesi." },
  "claude-opus-5-5": { label: "Claude Opus 5.5", input: 4, output: 20, note: "En yüksek kalite, en pahalı." },
} as const;

export function getAIStatus(env: Env = process.env): AIStatus {
  const provider = (env.AI_PROVIDER ?? "").trim().toLowerCase();
  const model = (env.AI_MODEL ?? "").trim();
  if (!provider) return { enabled: false, reason: "Yapay zekâ sağlayıcısı yapılandırılmamış (AI_PROVIDER boş)." };
  if (provider !== "anthropic" && provider !== "openai") return { enabled: false, reason: `Bilinmeyen sağlayıcı: ${provider}` };
  const key = provider === "anthropic" ? env.ANTHROPIC_API_KEY : env.OPENAI_API_KEY;
  if (!key) return { enabled: false, reason: `${provider === "anthropic" ? "ANTHROPIC_API_KEY" : "OPENAI_API_KEY"} tanımlı değil.` };
  if (!model) return { enabled: false, reason: "Model seçilmedi (AI_MODEL boş). Maliyeti bilerek bir model seçin; varsayılan model kullanılmaz." };
  if (provider === "anthropic" && !(model in ANTHROPIC_MODELS)) {
    return { enabled: false, reason: `"${model}" bu uygulamada desteklenmiyor. Desteklenenler: ${Object.keys(ANTHROPIC_MODELS).join(", ")}.` };
  }
  return { enabled: true, provider, model };
}

export type Price = { input: number; output: number } | null;

export function priceFor(provider: string, model: string, env: Env = process.env): Price {
  if (provider === "chatgpt") return { input: 0, output: 0 };
  const i = Number(env.AI_PRICE_INPUT_PER_MTOK);
  const o = Number(env.AI_PRICE_OUTPUT_PER_MTOK);
  if (env.AI_PRICE_INPUT_PER_MTOK && env.AI_PRICE_OUTPUT_PER_MTOK && i >= 0 && o >= 0) return { input: i, output: o };
  if (provider === "anthropic" && model in ANTHROPIC_MODELS) {
    const m = ANTHROPIC_MODELS[model as keyof typeof ANTHROPIC_MODELS];
    return { input: m.input, output: m.output };
  }
  return null;
}

/** Tahmini maliyet (USD). Önbellek indirimi hesaba katılmaz; gerçek tutar daha düşük olabilir. */
export function estimateCost(price: Price, inputTokens: number, outputTokens: number): number | null {
  if (!price) return null;
  return (inputTokens * price.input + outputTokens * price.output) / 1_000_000;
}

export type Limits = { dailyRequests: number; monthlyBudgetUsd: number | null };

export function getLimits(env: Env = process.env): Limits {
  const d = Number(env.AI_DAILY_REQUEST_LIMIT);
  const b = Number(env.AI_MONTHLY_BUDGET_USD);
  return {
    dailyRequests: Number.isFinite(d) && d >= 0 && env.AI_DAILY_REQUEST_LIMIT ? Math.floor(d) : 50,
    monthlyBudgetUsd: env.AI_MONTHLY_BUDGET_USD && Number.isFinite(b) && b >= 0 ? b : null,
  };
}

/** İstek yapılmadan önce limit kontrolü; aşılmışsa Türkçe gerekçe döndürür. */
export function checkLimits(usage: { todayRequests: number; monthCostUsd: number | null }, limits: Limits): string | null {
  if (usage.todayRequests >= limits.dailyRequests) {
    return `Günlük yapay zekâ istek sınırına ulaşıldı (${limits.dailyRequests}). Sınır AI_DAILY_REQUEST_LIMIT ile değiştirilebilir.`;
  }
  if (limits.monthlyBudgetUsd != null) {
    if (usage.monthCostUsd == null) return "Aylık bütçe tanımlı ancak seçilen modelin fiyatı bilinmiyor; AI_PRICE_INPUT_PER_MTOK ve AI_PRICE_OUTPUT_PER_MTOK girin.";
    if (usage.monthCostUsd >= limits.monthlyBudgetUsd) {
      return `Bu ayın tahmini yapay zekâ harcaması bütçeye ulaştı (${usage.monthCostUsd.toFixed(2)} $ / ${limits.monthlyBudgetUsd} $).`;
    }
  }
  return null;
}
