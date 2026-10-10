import { readFileSync } from "node:fs";
import path from "node:path";
import JSZip from "jszip";
import { afterEach, describe, expect, it } from "vitest";
import { decrypt, encrypt } from "@/lib/crypto";
import { parseZip } from "@/lib/data/bulk-import";
import { normalizeSiteUrl, weekFromName } from "@/lib/lms/moodle";

const KEY = Buffer.alloc(32, 7).toString("base64");
afterEach(() => {
  delete process.env.APP_ENCRYPTION_KEY;
  delete process.env.LMS_ALLOWED_HOSTS;
});

describe("Anahtar şifreleme", () => {
  it("şifreler, çözer; değiştirilmiş veriyi reddeder; anahtarsız çalışmaz", () => {
    process.env.APP_ENCRYPTION_KEY = KEY;
    const enc = encrypt("abc123token");
    expect(enc).not.toContain("abc123token");
    expect(decrypt(enc)).toBe("abc123token");
    const parts = enc.split(".");
    parts[3] = Buffer.from("başka").toString("base64");
    expect(() => decrypt(parts.join("."))).toThrow();
    delete process.env.APP_ENCRYPTION_KEY;
    expect(() => encrypt("x")).toThrow("APP_ENCRYPTION_KEY");
  });
});

describe("DEBİM adres doğrulama (SSRF koruması)", () => {
  it("yalnızca izinli alan adları ve https", () => {
    expect(normalizeSiteUrl("https://debim.neu.edu.tr/")).toBe("https://debim.neu.edu.tr");
    expect(() => normalizeSiteUrl("http://debim.neu.edu.tr")).toThrow("https");
    expect(() => normalizeSiteUrl("https://169.254.169.254")).toThrow("izin verilmiyor");
    expect(() => normalizeSiteUrl("https://user:pw@debim.neu.edu.tr")).toThrow();
    expect(() => normalizeSiteUrl("dosya")).toThrow();
  });
});

describe("Hafta numarası çıkarımı", () => {
  it("Türkçe ve İngilizce bölüm adları", () => {
    expect(weekFromName("3. Hafta: Gündem belirleme")).toBe(3);
    expect(weekFromName("Hafta 12 - Final")).toBe(12);
    expect(weekFromName("Week 4")).toBe(4);
    expect(weekFromName("Genel", 0)).toBeNull();
    expect(weekFromName("", 5)).toBe(5);
    expect(weekFromName("Ders Notları")).toBeNull();
  });
});

describe("ZIP içe aktarma ayrıştırması", () => {
  it("ortak üst klasörü atlar, klasörü konuya ve haftaya çevirir, desteklenmeyenleri raporlar", async () => {
    const pdf = readFileSync(path.join(__dirname, "..", "fixtures", "siyasal-iletisim-hafta3.pdf"));
    const z = new JSZip();
    z.file("İLF431 Siyasal İletişim/3. Hafta - Gündem/ders.pdf", pdf);
    z.file("İLF431 Siyasal İletişim/Okumalar/makale.txt", "Çerçeveleme metni");
    z.file("İLF431 Siyasal İletişim/program.exe", "MZ");
    z.file("__MACOSX/._ders.pdf", "x");
    const { items, skipped } = await parseZip(await z.generateAsync({ type: "nodebuffer" }));
    expect(items.map((i) => [i.filename, i.topicTitle, i.week])).toEqual([
      ["ders.pdf", "3. Hafta - Gündem", 3],
      ["makale.txt", "Okumalar", null],
    ]);
    expect(skipped.map((s) => s.filename)).toEqual(["program.exe"]);
  });
  it("bozuk ZIP'i reddeder", async () => {
    await expect(parseZip(Buffer.from("PK bozuk"))).rejects.toThrow("ZIP");
  });
});
