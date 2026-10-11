/**
 * Hassas değerler (ör. DEBİM web servis anahtarı) için AES-256-GCM şifreleme.
 * Anahtar yalnızca sunucu ortamında: APP_ENCRYPTION_KEY (32 bayt, base64).
 * Üretmek için: node -e "console.log(require('crypto').randomBytes(32).toString('base64'))"
 */
import { createCipheriv, createDecipheriv, randomBytes } from "node:crypto";

export class EncryptionUnavailableError extends Error {}

function key(): Buffer {
  const raw = process.env.APP_ENCRYPTION_KEY;
  if (!raw) throw new EncryptionUnavailableError("Sunucuda APP_ENCRYPTION_KEY tanımlı değil; bağlantı anahtarı güvenle saklanamaz.");
  const k = Buffer.from(raw, "base64");
  if (k.length !== 32) throw new EncryptionUnavailableError("APP_ENCRYPTION_KEY 32 baytlık base64 değer olmalı.");
  return k;
}

export function encryptionAvailable(): boolean {
  try {
    key();
    return true;
  } catch {
    return false;
  }
}

export function encrypt(plain: string): string {
  const iv = randomBytes(12);
  const c = createCipheriv("aes-256-gcm", key(), iv);
  const body = Buffer.concat([c.update(plain, "utf8"), c.final()]);
  return ["v1", iv.toString("base64"), c.getAuthTag().toString("base64"), body.toString("base64")].join(".");
}

export function decrypt(token: string): string {
  const [v, iv, tag, body] = token.split(".");
  if (v !== "v1" || !iv || !tag || !body) throw new Error("Şifreli değer biçimi geçersiz.");
  const d = createDecipheriv("aes-256-gcm", key(), Buffer.from(iv, "base64"));
  d.setAuthTag(Buffer.from(tag, "base64"));
  return Buffer.concat([d.update(Buffer.from(body, "base64")), d.final()]).toString("utf8");
}
