import "server-only";
import { createHash, createPublicKey, randomBytes, randomUUID, verify as verifySignature } from "node:crypto";
import type { AIProvider, CompletionRequest, CompletionResult } from "./provider";
import { AIRequestError, AIUnavailableError, getProvider } from "./provider";
import { getAIStatus, type AIStatus } from "./config";
import { encrypt, decrypt } from "../crypto";
import { withUser } from "../db";

const AUTH = "https://auth.openai.com";
const RESOURCE = "https://api.openai.com/v1";
const SCOPES = "openid profile email offline_access resource.invoke chatgpt.tokens.use.direct";
const DEFAULT_MODEL = "gpt-6.1-sol";

type Tokens = { access_token: string; refresh_token: string; id_token: string; scope: string; expires_in: number; saved_at: number };
type Connection = { client_id: string; host_id: string; account_sub: string; account_email: string; credentials_enc: string; model: string };
type Attempt = { state: string; nonce: string; verifier_enc: string; client_id: string; host_id: string; redirect_uri: string; account_sub: string; created_at: Date };

export class ChatGPTConnectionError extends Error {}
const b64 = (s: Buffer) => s.toString("base64url");
const random = () => b64(randomBytes(32));
const challenge = (v: string) => b64(createHash("sha256").update(v).digest());
const hasPlanScope = (s: string) => s.split(/\s+/).includes("chatgpt.tokens.use.direct");

async function fetchJSON(url: string, init?: RequestInit) {
  const response = await fetch(url, { ...init, signal: AbortSignal.timeout(20000), cache: "no-store" });
  const json: unknown = await response.json().catch(() => ({}));
  if (!response.ok) throw new ChatGPTConnectionError("OpenAI bağlantı hatası (" + response.status + "). Lütfen yeniden giriş yapın.");
  return json as Record<string, unknown>;
}
const tokenValue = (obj: Record<string, unknown>, key: string) => typeof obj[key] === "string" ? obj[key] as string : "";

async function verifyIdToken(idToken: string, clientId: string, nonce: string) {
  const parts = idToken.split(".");
  if (parts.length !== 3) throw new ChatGPTConnectionError("OpenAI kimlik belirteci geçersiz.");
  const header = JSON.parse(Buffer.from(parts[0], "base64url").toString("utf8")) as { alg?: string; kid?: string };
  if (header.alg !== "RS256" || !header.kid) throw new ChatGPTConnectionError("Desteklenmeyen OpenAI kimlik imzası.");
  const jwks = await fetchJSON(AUTH + "/.well-known/jwks.json");
  const keys = Array.isArray(jwks.keys) ? jwks.keys as Record<string, unknown>[] : [];
  const jwk = keys.find(k => k.kid === header.kid && k.kty === "RSA");
  if (!jwk) throw new ChatGPTConnectionError("OpenAI kimlik doğrulama anahtarı bulunamadı.");
  const pub = createPublicKey({ key: jwk as JsonWebKey, format: "jwk" });
  const ok = verifySignature("RSA-SHA256", Buffer.from(parts[0] + "." + parts[1]), pub, Buffer.from(parts[2], "base64url"));
  if (!ok) throw new ChatGPTConnectionError("OpenAI kimlik imzası doğrulanamadı.");
  const claims = JSON.parse(Buffer.from(parts[1], "base64url").toString("utf8")) as Record<string, unknown>;
  const now = Math.floor(Date.now() / 1000);
  if (claims.iss !== AUTH || claims.aud !== clientId || claims.nonce !== nonce ||
      typeof claims.exp !== "number" || claims.exp <= now ||
      (typeof claims.nbf === "number" && claims.nbf > now) ||
      typeof claims.sub !== "string" || !claims.sub) {
    throw new ChatGPTConnectionError("OpenAI kimlik belirteci doğrulanamadı.");
  }
  return { sub: claims.sub, email: typeof claims.email === "string" ? claims.email : "" };
}
async function connection(userId: string) {
  return withUser(userId, async tx => (await tx.query<Connection>(
    "SELECT client_id, host_id, account_sub, account_email, credentials_enc, model FROM chatgpt_connections WHERE user_id=$1", [userId]
  )).rows[0] ?? null);
}

export async function connectionSummary(userId: string) {
  const c = await connection(userId);
  if (!c) return null;
  let authorized = false;
  try { authorized = hasPlanScope((JSON.parse(decrypt(c.credentials_enc)) as Tokens).scope); } catch {}
  return { email: c.account_email, model: c.model || DEFAULT_MODEL, authorized };
}

export async function beginChatGPTAuthorization(userId: string, origin: string) {
  const parsed = new URL(origin);
  if (parsed.protocol !== "http:" || parsed.hostname !== "127.0.0.1")
    throw new ChatGPTConnectionError("Bu bağlantı yalnızca yerel 127.0.0.1 adresinde desteklenir.");
  const redirectUri = origin + "/auth/callback";
  const previous = await connection(userId);
  const clientId = previous?.client_id || "dynamic_agent_client";
  const hostId = previous?.host_id || "urn:uuid:" + randomUUID();
  const state = random();
  const verifier = random();
  const nonce = random();
  await withUser(userId, async tx => {
    await tx.query(
      `INSERT INTO chatgpt_auth_attempts (user_id,state,nonce,verifier_enc,client_id,host_id,redirect_uri,account_sub)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
       ON CONFLICT (user_id) DO UPDATE SET state=EXCLUDED.state,nonce=EXCLUDED.nonce,verifier_enc=EXCLUDED.verifier_enc,
       client_id=EXCLUDED.client_id,host_id=EXCLUDED.host_id,redirect_uri=EXCLUDED.redirect_uri,
       account_sub=EXCLUDED.account_sub,created_at=now()`,
      [userId, state, nonce, encrypt(verifier), clientId, hostId, redirectUri, previous?.account_sub || ""],
    );
  });
  const url = new URL(AUTH + "/api/accounts/authorize");
  const params = new URLSearchParams({
    client_id: clientId, ext_agent_host_id: hostId,
    response_type: "code", redirect_uri: redirectUri, scope: SCOPES,
    resource: RESOURCE, state, nonce, code_challenge_method: "S256", code_challenge: challenge(verifier),
  });
  if (!previous) params.set("agent_name_hint", "AcademicOS");
  else {
    try {
      const old = JSON.parse(decrypt(previous.credentials_enc)) as Tokens;
      if (old.id_token) params.set("id_token_hint", old.id_token);
    } catch {}
  }
  url.search = params.toString();
  return url.toString();
}

export async function finishChatGPTAuthorization(userId: string, callback: URL) {
  const receivedState = callback.searchParams.get("state");
  const attempt = await withUser(userId, async tx => {
    const { rows } = await tx.query<Attempt>("SELECT * FROM chatgpt_auth_attempts WHERE user_id=$1 FOR UPDATE", [userId]);
    const a = rows[0];
    if (!a || !receivedState || receivedState !== a.state || Date.now() - new Date(a.created_at).getTime() > 10 * 60_000)
      throw new ChatGPTConnectionError("ChatGPT giriş doğrulaması süresi doldu veya geçersiz. Yeniden deneyin.");
    await tx.query("DELETE FROM chatgpt_auth_attempts WHERE user_id=$1", [userId]);
    return a;
  });
  if (callback.searchParams.get("error"))
    throw new ChatGPTConnectionError("ChatGPT bağlantısına izin verilmedi. İstersen yeniden deneyebilirsin.");
  const code = callback.searchParams.get("code");
  if (!code) throw new ChatGPTConnectionError("ChatGPT giriş kodu bulunamadı.");
  const issuedClientId = callback.searchParams.get("client_id");
  const clientId = attempt.client_id === "dynamic_agent_client" ? issuedClientId : attempt.client_id;
  if (!clientId || clientId === "dynamic_agent_client" ||
      (issuedClientId && attempt.client_id !== "dynamic_agent_client" && issuedClientId !== clientId)) {
    throw new ChatGPTConnectionError("OpenAI uygulama kimliği doğrulanamadı.");
  }
  const token = await fetchJSON(AUTH + "/api/accounts/oauth/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "authorization_code", client_id: clientId,
      code, code_verifier: decrypt(attempt.verifier_enc), redirect_uri: attempt.redirect_uri, resource: RESOURCE }),
  });
  const claims = await verifyIdToken(tokenValue(token, "id_token"), clientId, attempt.nonce);
  if (attempt.account_sub && claims.sub !== attempt.account_sub)
    throw new ChatGPTConnectionError("Farklı ChatGPT hesabı seçildi. Mevcut bağlantı değiştirilmedi.");
  const scope = tokenValue(token, "scope");
  if (!hasPlanScope(scope)) throw new ChatGPTConnectionError("Bu hesap ChatGPT planıyla AI kullanımı izni vermedi.");
  const tokens: Tokens = {
    access_token: tokenValue(token, "access_token"), refresh_token: tokenValue(token, "refresh_token"),
    id_token: tokenValue(token, "id_token"), scope, expires_in: Number(token.expires_in || 3600), saved_at: Date.now(),
  };
  if (!tokens.access_token || !tokens.refresh_token) throw new ChatGPTConnectionError("OpenAI erişim bilgileri eksik.");
  await withUser(userId, tx => tx.query(
    `INSERT INTO chatgpt_connections (user_id,client_id,host_id,account_sub,account_email,credentials_enc,model)
     VALUES ($1,$2,$3,$4,$5,$6,$7)
     ON CONFLICT (user_id) DO UPDATE SET client_id=EXCLUDED.client_id,host_id=EXCLUDED.host_id,
       account_sub=EXCLUDED.account_sub,account_email=EXCLUDED.account_email,credentials_enc=EXCLUDED.credentials_enc,updated_at=now()`,
    [userId, clientId, attempt.host_id, claims.sub, claims.email, encrypt(JSON.stringify(tokens)), DEFAULT_MODEL]
  ));
}

export async function disconnectChatGPT(userId: string) {
  const c = await connection(userId);
  if (c) {
    const t = JSON.parse(decrypt(c.credentials_enc)) as Tokens;
    if (t.refresh_token) {
      try {
        await fetch(AUTH + "/api/accounts/oauth/revoke", {
          method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" },
          body: new URLSearchParams({ token: t.refresh_token, token_type_hint: "refresh_token", client_id: c.client_id }),
          signal: AbortSignal.timeout(8000),
        });
      } catch { /* local disconnect still proceeds */ }
    }
  }
  await withUser(userId, tx => tx.query("DELETE FROM chatgpt_connections WHERE user_id=$1", [userId]));
}
export async function chooseChatGPTModel(userId: string, model: string) {
  if (!/^[a-zA-Z0-9._-]{3,100}$/.test(model)) throw new ChatGPTConnectionError("Model kimliği geçersiz.");
  await withUser(userId, tx => tx.query("UPDATE chatgpt_connections SET model=$2,updated_at=now() WHERE user_id=$1", [userId, model]));
}

const refreshLocks = new Map<string, Promise<string>>();
async function accessToken(userId: string): Promise<string> {
  const active = refreshLocks.get(userId);
  if (active) return active;
  const p = (async () => {
    const c = await connection(userId);
    if (!c) throw new ChatGPTConnectionError("ChatGPT bağlantısı bulunamadı.");
    const tokens = JSON.parse(decrypt(c.credentials_enc)) as Tokens;
    if (!hasPlanScope(tokens.scope)) throw new ChatGPTConnectionError("ChatGPT plan kullanımı için izin yok.");
    if (tokens.saved_at + tokens.expires_in * 1000 - Date.now() > 90_000) return tokens.access_token;
    const refreshed = await fetchJSON(AUTH + "/api/accounts/oauth/token", {
      method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({ grant_type: "refresh_token", client_id: c.client_id,
        refresh_token: tokens.refresh_token, resource: RESOURCE }),
    });
    const next: Tokens = {
      access_token: tokenValue(refreshed, "access_token"), refresh_token: tokenValue(refreshed, "refresh_token"),
      id_token: tokenValue(refreshed, "id_token") || tokens.id_token,
      scope: tokenValue(refreshed, "scope") || tokens.scope,
      expires_in: Number(refreshed.expires_in || 3600), saved_at: Date.now(),
    };
    if (!next.access_token || !next.refresh_token || !hasPlanScope(next.scope))
      throw new ChatGPTConnectionError("ChatGPT oturumu yenilenemedi. Yeniden giriş yap.");
    await withUser(userId, tx => tx.query("UPDATE chatgpt_connections SET credentials_enc=$2,updated_at=now() WHERE user_id=$1",
      [userId, encrypt(JSON.stringify(next))]));
    return next.access_token;
  })();
  refreshLocks.set(userId, p);
  try { return await p; } finally { refreshLocks.delete(userId); }
}
class ChatGPTPlanProvider implements AIProvider {
  readonly id = "chatgpt" as const;
  constructor(private readonly userId: string, readonly model: string) {}
  async complete(req: CompletionRequest): Promise<CompletionResult> {
    try {
      const token = await accessToken(this.userId);
      const response = await fetch(RESOURCE + "/responses", {
        method: "POST", headers: { Authorization: "Bearer " + token, "Content-Type": "application/json" },
        body: JSON.stringify({
          model: this.model, instructions: req.system,
          input: req.messages.map(m => ({ role: m.role, content: m.content })),
          store: false, stream: true,
        }),
        signal: AbortSignal.timeout(180000),
      });
      if (!response.ok || !response.body) throw new ChatGPTConnectionError("ChatGPT yanıt hizmeti hata döndürdü (" + response.status + ").");
      let output = ""; let done = false; let inputTokens = 0; let outputTokens = 0;
      const reader = response.body.getReader();
      const decoder = new TextDecoder();
      let buffer = "";
      let eventParts: string[] = [];
      const handle = (raw: string) => {
        if (!raw.startsWith("data:")) return;
        const data = raw.slice(5).trim();
        if (!data || data === "[DONE]") return;
        let obj: Record<string, unknown>;
        try { obj = JSON.parse(data) as Record<string, unknown>; } catch { return; }
        if (obj.type === "response.output_text.delta" && typeof obj.delta === "string") output += obj.delta;
        if (obj.type === "response.completed") {
          done = true;
          const res = obj.response as { usage?: { input_tokens?: number; output_tokens?: number } } | undefined;
          inputTokens = res?.usage?.input_tokens ?? 0;
          outputTokens = res?.usage?.output_tokens ?? 0;
        }
        if (obj.type === "response.failed" || obj.type === "response.incomplete" || obj.type === "error")
          throw new ChatGPTConnectionError("ChatGPT yanıtı tamamlanamadı. Hesap kullanım sınırını veya seçilen modeli kontrol et.");
      };
      while (true) {
        const { value, done: ended } = await reader.read();
        if (ended) break;
        buffer += decoder.decode(value, { stream: true }).replace(/\r\n/g, "\n");
        let i: number;
        while ((i = buffer.indexOf("\n")) !== -1) {
          const line = buffer.slice(0, i); buffer = buffer.slice(i + 1);
          if (!line.trim()) { for (const e of eventParts) handle(e); eventParts = []; }
          else if (line.startsWith("data:")) eventParts.push(line);
        }
      }
      for (const e of eventParts) handle(e);
      if (!done) throw new ChatGPTConnectionError("ChatGPT bağlantısı yanıt tamamlanmadan kesildi.");
      if (!output.trim()) throw new ChatGPTConnectionError("ChatGPT boş yanıt döndürdü.");
      return { text: output.trim(), provider: "chatgpt", model: this.model, inputTokens, outputTokens };
    } catch (e) {
      if (e instanceof ChatGPTConnectionError) throw new AIRequestError(e.message);
      throw new AIRequestError("ChatGPT isteği başarısız oldu. Ağ ve bağlantı durumunu kontrol edin.");
    }
  }
}
export async function getUserAIStatus(userId: string): Promise<AIStatus> {
  const c = await connection(userId);
  if (c) return { enabled: true, provider: "chatgpt", model: c.model || DEFAULT_MODEL };
  return getAIStatus();
}
export async function getUserProvider(userId: string): Promise<AIProvider> {
  const c = await connection(userId);
  if (c) return new ChatGPTPlanProvider(userId, c.model || DEFAULT_MODEL);
  return getProvider();
}
