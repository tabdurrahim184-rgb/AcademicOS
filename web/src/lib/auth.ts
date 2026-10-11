import "server-only";
import { cookies, headers } from "next/headers";
import { redirect } from "next/navigation";
import { cache } from "react";
import { createSession, deleteSession, resolveSession, type SessionUser } from "./auth-core";

export const SESSION_COOKIE = "aos_oturum";

export const getCurrentUser = cache(async (): Promise<SessionUser | null> => {
  const store = await cookies();
  return resolveSession(store.get(SESSION_COOKIE)?.value);
});

export async function requireUser(): Promise<SessionUser> {
  const user = await getCurrentUser();
  if (!user) redirect("/giris");
  return user;
}

export async function startSession(userId: string) {
  const { token, expiresAt } = await createSession(userId);
  const store = await cookies();
  store.set(SESSION_COOKIE, token, {
    httpOnly: true,
    sameSite: "lax",
    // Yerel HTTP (127.0.0.1) kurulumunda COOKIE_SECURE=false; HTTPS arkasında true (varsayılan: üretimde true).
    secure: process.env.COOKIE_SECURE ? process.env.COOKIE_SECURE === "true" : process.env.NODE_ENV === "production",
    path: "/",
    expires: expiresAt,
  });
}

export async function endSession() {
  const store = await cookies();
  const token = store.get(SESSION_COOKIE)?.value;
  if (token) await deleteSession(token);
  store.delete(SESSION_COOKIE);
}

/**
 * Hız sınırı anahtarı için istemci adresi. X-Forwarded-For istemci tarafından
 * sahte gönderilebileceğinden yalnızca güvenilir bir ters vekil arkasında
 * (TRUST_PROXY=true) kullanılır; aksi halde sınır yalnızca e-posta başınadır.
 */
export async function clientKey(): Promise<string> {
  if (process.env.TRUST_PROXY !== "true") return "yerel";
  const h = await headers();
  const parts = (h.get("x-forwarded-for") ?? "").split(",").map((s) => s.trim()).filter(Boolean);
  // Vekilin eklediği son adres güvenilirdir; öncekiler istemciden gelebilir.
  return parts[parts.length - 1] ?? "yerel";
}
