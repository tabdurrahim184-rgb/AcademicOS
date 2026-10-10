import { createHash, randomBytes } from "node:crypto";
import { sysQuery, withUser } from "./db";
import { hashPassword, verifyPassword } from "./passwords";
import { seedInitialCourses } from "./data/seed";

export const SESSION_TTL_DAYS = 30;
const MAX_FAILED_PER_15MIN = 8;

export type SessionUser = { id: string; email: string; name: string; timezone: string };

export class AuthError extends Error {}

const sha256 = (s: string) => createHash("sha256").update(s).digest("hex");

export function validateRegistration(input: { email: string; name: string; password: string }) {
  const email = input.email.trim();
  const name = input.name.trim();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw new AuthError("Geçerli bir e-posta adresi girin.");
  if (name.length < 2 || name.length > 100) throw new AuthError("Ad en az 2, en fazla 100 karakter olmalıdır.");
  if (input.password.length < 10) throw new AuthError("Parola en az 10 karakter olmalıdır.");
  if (input.password.length > 200) throw new AuthError("Parola çok uzun.");
  return { email, name, password: input.password };
}

/** Yeni hesap oluşturur ve başlangıç derslerini ekler. */
export async function registerUser(input: { email: string; name: string; password: string; seedCourses?: boolean }) {
  const { email, name, password } = validateRegistration(input);
  const existing = await sysQuery("SELECT 1 FROM users WHERE lower(email) = lower($1)", [email]);
  if (existing.rowCount) throw new AuthError("Bu e-posta adresiyle kayıtlı bir hesap zaten var.");
  const hash = await hashPassword(password);
  const { rows } = await sysQuery<{ id: string }>(
    "INSERT INTO users (email, name, password_hash) VALUES ($1, $2, $3) RETURNING id",
    [email, name, hash],
  );
  const userId = rows[0].id;
  if (input.seedCourses !== false) {
    await withUser(userId, (tx) => seedInitialCourses(tx, userId));
  }
  return userId;
}

/** E-posta + parola doğrulaması; hız sınırlaması uygular. */
export async function authenticate(emailRaw: string, password: string, clientKey = "yerel"): Promise<string> {
  const email = emailRaw.trim().toLowerCase();
  const key = `${email}|${clientKey}`;
  const { rows: rl } = await sysQuery<{ n: string }>(
    "SELECT count(*) AS n FROM login_attempts WHERE key = $1 AND success = false AND created_at > now() - interval '15 minutes'",
    [key],
  );
  if (Number(rl[0].n) >= MAX_FAILED_PER_15MIN) {
    throw new AuthError("Çok fazla başarısız deneme yapıldı. Lütfen 15 dakika sonra tekrar deneyin.");
  }
  const { rows } = await sysQuery<{ id: string; password_hash: string }>(
    "SELECT id, password_hash FROM users WHERE lower(email) = $1",
    [email],
  );
  const ok = rows.length > 0 && (await verifyPassword(password, rows[0].password_hash));
  await sysQuery("INSERT INTO login_attempts (key, success) VALUES ($1, $2)", [key, ok]);
  if (!ok) throw new AuthError("E-posta veya parola hatalı.");
  return rows[0].id;
}

export async function createSession(userId: string): Promise<{ token: string; expiresAt: Date }> {
  const token = randomBytes(32).toString("base64url");
  const expiresAt = new Date(Date.now() + SESSION_TTL_DAYS * 86400_000);
  await sysQuery("INSERT INTO auth_sessions (id, user_id, expires_at) VALUES ($1, $2, $3)", [sha256(token), userId, expiresAt]);
  return { token, expiresAt };
}

export async function resolveSession(token: string | undefined | null): Promise<SessionUser | null> {
  if (!token || token.length > 200) return null;
  const { rows } = await sysQuery<SessionUser>(
    `SELECT u.id, u.email, u.name, u.timezone FROM auth_sessions s JOIN users u ON u.id = s.user_id
     WHERE s.id = $1 AND s.expires_at > now()`,
    [sha256(token)],
  );
  return rows[0] ?? null;
}

export async function deleteSession(token: string) {
  await sysQuery("DELETE FROM auth_sessions WHERE id = $1", [sha256(token)]);
}
