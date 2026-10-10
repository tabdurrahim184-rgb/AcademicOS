// Gerçek sağlayıcı sınıflarını (resmî SDK'lar) yerel test sunucularına karşı çalıştırır.
// Doğrulanan: gönderilen istek biçimi, yanıt ve token ayrıştırma, hata çevirisi.
// DOĞRULANMAYAN: gerçek OpenAI/Anthropic API'lerinin bu istekleri kabul ettiği.
import http from "node:http";
import type { AddressInfo } from "node:net";
import { afterAll, beforeAll, describe, expect, it } from "vitest";

type Captured = { path: string; headers: http.IncomingHttpHeaders; body: Record<string, unknown> };
let server: http.Server;
let base = "";
const captured: Captured[] = [];
let mode: "ok" | "401" | "refusal" = "ok";

beforeAll(async () => {
  server = http.createServer((req, res) => {
    let b = "";
    req.on("data", (c) => (b += c));
    req.on("end", () => {
      const body = JSON.parse(b || "{}");
      captured.push({ path: req.url!, headers: req.headers, body });
      if (mode === "401") {
        res.writeHead(401, { "content-type": "application/json" });
        return res.end(JSON.stringify({ error: { type: "authentication_error", message: "bad key" } }));
      }
      res.writeHead(200, { "content-type": "application/json" });
      if (req.url!.startsWith("/v1/responses")) {
        return res.end(JSON.stringify({
          id: "resp_1", object: "response", created_at: 1, status: "completed", model: body.model,
          output: [{ type: "message", id: "m1", role: "assistant", status: "completed", content: [{ type: "output_text", text: "Merhaba [K1]", annotations: [] }] }],
          usage: { input_tokens: 120, output_tokens: 8, total_tokens: 128, input_tokens_details: { cached_tokens: 0 }, output_tokens_details: { reasoning_tokens: 0 } },
        }));
      }
      return res.end(JSON.stringify({
        id: "msg_1", type: "message", role: "assistant", model: body.model,
        content: mode === "refusal" ? [] : [{ type: "text", text: "Selam [K1]" }],
        stop_reason: mode === "refusal" ? "refusal" : "end_turn", stop_sequence: null,
        usage: { input_tokens: 50, output_tokens: 5, cache_read_input_tokens: 30, cache_creation_input_tokens: 0 },
      }));
    });
  });
  await new Promise<void>((r) => server.listen(0, "127.0.0.1", r));
  base = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
});
afterAll(() => new Promise<void>((r) => server.close(() => r())));

async function freshProvider(env: Record<string, string>) {
  for (const k of ["AI_PROVIDER", "AI_MODEL", "OPENAI_API_KEY", "ANTHROPIC_API_KEY", "OPENAI_BASE_URL", "ANTHROPIC_BASE_URL"]) delete process.env[k];
  Object.assign(process.env, env);
  const mod = await import("@/lib/ai/provider");
  return mod;
}

describe("OpenAI sağlayıcısı (Responses API)", () => {
  it("doğru istek gövdesini gönderir: model, yönergeler, store:false; metni ve token sayısını okur", async () => {
    mode = "ok";
    const { getProvider } = await freshProvider({ AI_PROVIDER: "openai", AI_MODEL: "test-openai-model", OPENAI_API_KEY: "sk-test", OPENAI_BASE_URL: `${base}/v1` });
    const r = await getProvider().complete({ system: "Sen öğretmensin.", messages: [{ role: "user", content: "Anlat" }] });
    expect(r).toMatchObject({ text: "Merhaba [K1]", provider: "openai", model: "test-openai-model", inputTokens: 120, outputTokens: 8 });
    const req = captured.at(-1)!;
    expect(req.path).toBe("/v1/responses");
    expect(req.headers.authorization).toBe("Bearer sk-test");
    expect(req.body).toMatchObject({ model: "test-openai-model", instructions: "Sen öğretmensin.", store: false, input: [{ role: "user", content: "Anlat" }] });
  });
  it("yetki hatasını Türkçe ve anahtarı sızdırmadan bildirir", async () => {
    mode = "401";
    const { getProvider } = await freshProvider({ AI_PROVIDER: "openai", AI_MODEL: "m2", OPENAI_API_KEY: "sk-gizli", OPENAI_BASE_URL: `${base}/v1` });
    const err = (await getProvider().complete({ system: "s", messages: [{ role: "user", content: "x" }] }).catch((e) => e)) as Error;
    expect(err.message).toBe("API anahtarı geçersiz veya yetkisiz.");
    expect(err.message).not.toContain("sk-gizli");
  });
});

describe("Anthropic sağlayıcısı (Messages API)", () => {
  it("uyarlanabilir düşünme, düşük efor, önbellek ve yedek yönlendirmeyi gönderir; önbellek tokenlarını sayar", async () => {
    mode = "ok";
    const { getProvider } = await freshProvider({ AI_PROVIDER: "anthropic", AI_MODEL: "claude-sonnet-5-5", ANTHROPIC_API_KEY: "k", ANTHROPIC_BASE_URL: base });
    const r = await getProvider().complete({ system: "s", messages: [{ role: "user", content: "x" }] });
    expect(r).toMatchObject({ text: "Selam [K1]", inputTokens: 80, outputTokens: 5 });
    const req = captured.at(-1)!;
    expect(req.body).toMatchObject({ model: "claude-sonnet-5-5", thinking: { type: "adaptive" }, output_config: { effort: "low" }, cache_control: { type: "ephemeral" }, fallbacks: "default" });
    expect(String(req.headers["anthropic-beta"])).toContain("server-side-fallback-2026-07-01");
  });
  it("Haiku 5.5'te yedek yönlendirme parametresi gönderilmez; reddetme Türkçe hataya çevrilir", async () => {
    mode = "refusal";
    const { getProvider } = await freshProvider({ AI_PROVIDER: "anthropic", AI_MODEL: "claude-haiku-5-5", ANTHROPIC_API_KEY: "k", ANTHROPIC_BASE_URL: base });
    await expect(getProvider().complete({ system: "s", messages: [{ role: "user", content: "x" }] })).rejects.toThrow("reddetti");
    expect(captured.at(-1)!.body.fallbacks).toBeUndefined();
  });
});
