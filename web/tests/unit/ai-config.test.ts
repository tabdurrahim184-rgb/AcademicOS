import { describe, expect, it } from "vitest";
import { checkLimits, estimateCost, getAIStatus, getLimits, priceFor } from "@/lib/ai/config";

describe("Yapay zekâ yapılandırması", () => {
  it("varsayılan olarak kapalıdır ve model seçilmeden açılmaz", () => {
    expect(getAIStatus({}).enabled).toBe(false);
    const s = getAIStatus({ AI_PROVIDER: "anthropic", ANTHROPIC_API_KEY: "k" });
    expect(s).toMatchObject({ enabled: false });
    expect(!s.enabled && s.reason).toContain("AI_MODEL");
  });
  it("desteklenmeyen Anthropic modelini reddeder", () => {
    expect(getAIStatus({ AI_PROVIDER: "anthropic", ANTHROPIC_API_KEY: "k", AI_MODEL: "claude-haiku-4-5" }).enabled).toBe(false);
    expect(getAIStatus({ AI_PROVIDER: "anthropic", ANTHROPIC_API_KEY: "k", AI_MODEL: "claude-haiku-5-5" })).toEqual({ enabled: true, provider: "anthropic", model: "claude-haiku-5-5" });
  });
  it("OpenAI için anahtar ve model ister", () => {
    expect(getAIStatus({ AI_PROVIDER: "openai", AI_MODEL: "m" }).enabled).toBe(false);
    expect(getAIStatus({ AI_PROVIDER: "openai", OPENAI_API_KEY: "k", AI_MODEL: "m" }).enabled).toBe(true);
  });
  it("fiyat ve maliyet tahmini", () => {
    expect(priceFor("anthropic", "claude-sonnet-5-5", {})).toEqual({ input: 2, output: 10 });
    expect(priceFor("openai", "x", {})).toBeNull();
    expect(priceFor("openai", "x", { AI_PRICE_INPUT_PER_MTOK: "0.1", AI_PRICE_OUTPUT_PER_MTOK: "0.5" })).toEqual({ input: 0.1, output: 0.5 });
    expect(estimateCost({ input: 2, output: 10 }, 1_000_000, 100_000)).toBeCloseTo(3);
    expect(estimateCost(null, 1, 1)).toBeNull();
  });
  it("günlük istek ve aylık bütçe sınırları", () => {
    const l = getLimits({ AI_DAILY_REQUEST_LIMIT: "10", AI_MONTHLY_BUDGET_USD: "5" });
    expect(l).toEqual({ dailyRequests: 10, monthlyBudgetUsd: 5 });
    expect(getLimits({}).dailyRequests).toBe(50);
    expect(checkLimits({ todayRequests: 10, monthCostUsd: 0 }, l)).toContain("Günlük");
    expect(checkLimits({ todayRequests: 1, monthCostUsd: 5.01 }, l)).toContain("bütçe");
    expect(checkLimits({ todayRequests: 1, monthCostUsd: null }, l)).toContain("fiyatı bilinmiyor");
    expect(checkLimits({ todayRequests: 1, monthCostUsd: 1 }, l)).toBeNull();
  });
});
