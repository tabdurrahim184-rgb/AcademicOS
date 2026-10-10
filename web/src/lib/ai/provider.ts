import "server-only";
import Anthropic from "@anthropic-ai/sdk";
import OpenAI from "openai";
import { getAIStatus, type AIStatus } from "./config";

export { getAIStatus, type AIStatus };

/**
 * Sağlayıcıdan bağımsız yapay zekâ katmanı.
 *
 * Önemli: ChatGPT/Claude abonelikleri API erişimi içermez. Bu katman yalnızca
 * resmî, ayrı faturalanan API anahtarlarıyla çalışır. Anahtar veya model seçimi
 * yoksa yapay zekâ özellikleri kapalıdır; sahte cevap üretilmez.
 */
export type ChatTurn = { role: "user" | "assistant"; content: string };
export type CompletionRequest = { system: string; messages: ChatTurn[]; maxTokens?: number; effort?: "low" | "medium" | "high" };
export type CompletionResult = { text: string; provider: string; model: string; inputTokens: number; outputTokens: number };

export interface AIProvider {
  readonly id: "anthropic" | "openai";
  readonly model: string;
  complete(req: CompletionRequest): Promise<CompletionResult>;
}

export class AIUnavailableError extends Error {}
export class AIRequestError extends Error {}

// Sunucu tarafı reddetme yedeğini destekleyen modeller (yalnızca bunlarda gönderilir).
const FALLBACK_CAPABLE = new Set(["claude-fable-5-1", "claude-opus-5-5", "claude-opus-5", "claude-sonnet-5-5"]);

class AnthropicProvider implements AIProvider {
  readonly id = "anthropic" as const;
  private client: Anthropic;
  constructor(readonly model: string) {
    this.client = new Anthropic({ timeout: 180_000, maxRetries: 2 });
  }
  async complete(req: CompletionRequest): Promise<CompletionResult> {
    try {
      const useFallback = FALLBACK_CAPABLE.has(this.model);
      const res = await this.client.beta.messages.create({
        model: this.model,
        max_tokens: req.maxTokens ?? 8000,
        system: req.system,
        messages: req.messages,
        thinking: { type: "adaptive" },
        output_config: { effort: req.effort ?? "low" },
        // Aynı oturumdaki tekrar eden kaynak bağlamı önbelleğe alınır (girdi maliyetini düşürür).
        cache_control: { type: "ephemeral" },
        ...(useFallback ? { betas: ["server-side-fallback-2026-07-01"], fallbacks: "default" as const } : {}),
      });
      if (res.stop_reason === "refusal") {
        throw new AIRequestError("Yapay zekâ bu isteği yanıtlamayı reddetti. Soruyu farklı ifade etmeyi deneyin.");
      }
      const text = res.content.flatMap((b) => (b.type === "text" ? [b.text] : [])).join("\n").trim();
      if (!text) throw new AIRequestError("Yapay zekâ boş yanıt döndürdü.");
      const usage = {
        inputTokens: (res.usage.input_tokens ?? 0) + (res.usage.cache_read_input_tokens ?? 0) + (res.usage.cache_creation_input_tokens ?? 0),
        outputTokens: res.usage.output_tokens ?? 0,
      };
      const suffix = res.stop_reason === "max_tokens" ? "\n\n[Yanıt uzunluk sınırında kesildi.]" : "";
      return { text: text + suffix, provider: this.id, model: res.model, ...usage };
    } catch (err) {
      throw translateError(err);
    }
  }
}

class OpenAIProvider implements AIProvider {
  readonly id = "openai" as const;
  private client: OpenAI;
  constructor(readonly model: string) {
    this.client = new OpenAI({ timeout: 180_000, maxRetries: 2 });
  }
  async complete(req: CompletionRequest): Promise<CompletionResult> {
    try {
      const res = await this.client.responses.create({
        model: this.model,
        instructions: req.system,
        input: req.messages.map((m) => ({ role: m.role, content: m.content })),
        max_output_tokens: req.maxTokens ?? 8000,
        // Öğrencinin ders içeriği OpenAI tarafında yanıt geçmişi olarak saklanmasın.
        store: false,
      });
      const text = (res.output_text ?? "").trim();
      if (!text) throw new AIRequestError("Yapay zekâ boş yanıt döndürdü.");
      return {
        text, provider: this.id, model: res.model ?? this.model,
        inputTokens: res.usage?.input_tokens ?? 0, outputTokens: res.usage?.output_tokens ?? 0,
      };
    } catch (err) {
      throw translateError(err);
    }
  }
}

function translateError(err: unknown): Error {
  if (err instanceof AIRequestError) return err;
  if (err instanceof Anthropic.AuthenticationError || err instanceof OpenAI.AuthenticationError)
    return new AIRequestError("API anahtarı geçersiz veya yetkisiz.");
  if (err instanceof Anthropic.RateLimitError || err instanceof OpenAI.RateLimitError)
    return new AIRequestError("Yapay zekâ hizmeti istek sınırına ulaştı. Biraz sonra tekrar deneyin.");
  if (err instanceof Anthropic.APIConnectionError || err instanceof OpenAI.APIConnectionError)
    return new AIRequestError("Yapay zekâ hizmetine bağlanılamadı. İnternet bağlantısını kontrol edin.");
  if (err instanceof Anthropic.NotFoundError || err instanceof OpenAI.NotFoundError)
    return new AIRequestError("Seçilen model bulunamadı. AI_MODEL değerini sağlayıcının model listesinden kontrol edin.");
  if (err instanceof Anthropic.APIError || err instanceof OpenAI.APIError)
    return new AIRequestError(`Yapay zekâ hizmeti hata döndürdü (${(err as { status?: number }).status ?? "?"}).`);
  return new AIRequestError("Yapay zekâ isteği başarısız oldu.");
}

let cached: { key: string; provider: AIProvider } | null = null;

export function getProvider(): AIProvider {
  const status = getAIStatus();
  if (!status.enabled) throw new AIUnavailableError(status.reason);
  const key = `${status.provider}:${status.model}`;
  if (cached?.key !== key) {
    cached = { key, provider: status.provider === "anthropic" ? new AnthropicProvider(status.model) : new OpenAIProvider(status.model) };
  }
  return cached.provider;
}
