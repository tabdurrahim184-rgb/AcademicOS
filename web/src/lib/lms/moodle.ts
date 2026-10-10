/**
 * Moodle Web Services (REST) istemcisi — DEBİM (debim.neu.edu.tr) Moodle tabanlıdır.
 *
 * Kimlik doğrulama: kullanıcının kendi oluşturduğu web servis anahtarı (Moodle'da
 * Profil → Tercihler → Güvenlik anahtarları; "Moodle mobile web service").
 * Üniversite şifresi istenmez, saklanmaz. Anahtar yalnızca sunucuda şifreli tutulur.
 * İzin verilen alan adları LMS_ALLOWED_HOSTS ile sınırlıdır (SSRF koruması).
 */
export const DEFAULT_SITE = "https://debim.neu.edu.tr";

export class MoodleError extends Error {
  constructor(message: string, readonly code?: string) {
    super(message);
  }
}

export function allowedHosts(): string[] {
  return (process.env.LMS_ALLOWED_HOSTS ?? "debim.neu.edu.tr").split(",").map((h) => h.trim().toLowerCase()).filter(Boolean);
}

/** Site adresini doğrular ve normalleştirir. Yalnızca izinli alan adları; HTTP yalnızca açıkça izinliyse (test). */
export function normalizeSiteUrl(input: string): string {
  let u: URL;
  try {
    u = new URL(input.trim());
  } catch {
    throw new MoodleError("Geçerli bir site adresi girin.");
  }
  const insecureOk = process.env.LMS_ALLOW_HTTP === "true";
  if (u.protocol !== "https:" && !(insecureOk && u.protocol === "http:")) throw new MoodleError("Site adresi https ile başlamalı.");
  if (!allowedHosts().includes(u.hostname.toLowerCase())) throw new MoodleError(`Bu alan adına bağlanılmasına izin verilmiyor: ${u.hostname}`);
  if (u.username || u.password) throw new MoodleError("Adres kullanıcı bilgisi içeremez.");
  return `${u.protocol}//${u.host}${u.pathname.replace(/\/+$/, "")}`;
}

export type SiteInfo = { sitename: string; userid: number; fullname: string; release?: string };
export type MoodleCourse = { id: number; fullname: string; shortname: string };
export type MoodleContent = {
  type: string; filename: string; filepath?: string; filesize: number; fileurl: string; timemodified: number; mimetype?: string;
};
export type MoodleModule = { id: number; name: string; modname: string; contents?: MoodleContent[] };
export type MoodleSection = { id: number; name: string; section: number; modules: MoodleModule[] };

const TIMEOUT_MS = 30_000;

export class MoodleClient {
  constructor(readonly site: string, private readonly token: string) {}

  private async call<T>(fn: string, params: Record<string, string | number> = {}): Promise<T> {
    const body = new URLSearchParams({ wstoken: this.token, wsfunction: fn, moodlewsrestformat: "json" });
    for (const [k, v] of Object.entries(params)) body.set(k, String(v));
    let res: Response;
    try {
      res = await fetch(`${this.site}/webservice/rest/server.php`, {
        method: "POST",
        body,
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        signal: AbortSignal.timeout(TIMEOUT_MS),
        redirect: "error",
      });
    } catch {
      throw new MoodleError("DEBİM'e bağlanılamadı. İnternet bağlantısını veya site adresini kontrol edin.");
    }
    if (!res.ok) throw new MoodleError(`DEBİM beklenmeyen yanıt verdi (HTTP ${res.status}).`);
    const data = (await res.json().catch(() => null)) as (T & { exception?: string; errorcode?: string; message?: string }) | null;
    if (!data) throw new MoodleError("DEBİM yanıtı okunamadı.");
    if (data.exception || data.errorcode) {
      const code = data.errorcode ?? "";
      if (code === "invalidtoken") throw new MoodleError("Güvenlik anahtarı geçersiz veya süresi dolmuş. DEBİM'de yeni anahtar oluşturun.", code);
      if (code === "accessexception") throw new MoodleError("Bu anahtarın gerekli işleme yetkisi yok (web servis erişimi kapalı olabilir).", code);
      throw new MoodleError(`DEBİM hata döndürdü: ${data.message ?? code}`, code);
    }
    return data;
  }

  siteInfo() {
    return this.call<SiteInfo>("core_webservice_get_site_info");
  }
  courses(userId: number) {
    return this.call<MoodleCourse[]>("core_enrol_get_users_courses", { userid: userId });
  }
  contents(courseId: number) {
    return this.call<MoodleSection[]>("core_course_get_contents", { courseid: courseId });
  }

  /** Dosyayı indirir; boyut sınırı aşılırsa indirmeyi keser. Anahtar URL'ye sunucu tarafında eklenir. */
  async download(fileurl: string, maxBytes: number): Promise<Buffer> {
    const u = new URL(fileurl);
    if (`${u.protocol}//${u.host}` !== new URL(this.site).origin) throw new MoodleError("Dosya adresi DEBİM dışında; indirilmedi.");
    u.searchParams.set("token", this.token);
    let res: Response;
    try {
      res = await fetch(u, { signal: AbortSignal.timeout(120_000), redirect: "error" });
    } catch {
      throw new MoodleError("Dosya indirilemedi (bağlantı hatası).");
    }
    if (!res.ok || !res.body) throw new MoodleError(`Dosya indirilemedi (HTTP ${res.status}).`);
    const ct = res.headers.get("content-type") ?? "";
    if (ct.includes("application/json")) {
      const j = (await res.json().catch(() => ({}))) as { message?: string };
      throw new MoodleError(`Dosya indirilemedi: ${j.message ?? "yetki hatası"}`);
    }
    const chunks: Buffer[] = [];
    let total = 0;
    for await (const chunk of res.body as unknown as AsyncIterable<Uint8Array>) {
      total += chunk.length;
      if (total > maxBytes) throw new MoodleError("Dosya 25 MB sınırını aşıyor; atlandı.");
      chunks.push(Buffer.from(chunk));
    }
    return Buffer.concat(chunks);
  }
}

/** Moodle bölüm adından hafta numarası çıkarır ("3. Hafta", "Week 3", "Hafta 3 - …"). */
export function weekFromName(name: string, sectionNumber?: number): number | null {
  const m = name.match(/(\d{1,2})\s*\.?\s*hafta|hafta\s*(\d{1,2})|week\s*(\d{1,2})/i);
  const n = m ? Number(m[1] ?? m[2] ?? m[3]) : null;
  if (n && n >= 1 && n <= 20) return n;
  if (sectionNumber && sectionNumber >= 1 && sectionNumber <= 20 && /^\s*$|^(konu|topic|section|bölüm)\s*\d+$/i.test(name)) return sectionNumber;
  return null;
}

export const IMPORTABLE_EXT = /\.(pdf|docx|pptx|txt|md|srt|vtt|png|jpe?g|webp)$/i;
