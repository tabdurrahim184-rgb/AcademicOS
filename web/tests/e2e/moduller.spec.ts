import { execFileSync } from "node:child_process";
import { mkdtempSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import JSZip from "jszip";
import { expect, test } from "@playwright/test";
import { fixture, openCourse, register } from "./helpers";

test.describe("DEBİM ve içe aktarma", () => {
  test("Moodle test ikizine bağlan → dersi eşleştir → materyalleri aktar → bağlantıyı kaldır", async ({ page }) => {
    await register(page);
    await page.goto("/debim");
    await page.getByLabel("Site adresi").fill("http://127.0.0.1:3198");
    await page.getByLabel("Güvenlik anahtarı (token)").fill("yanlisanahtar0000000000000000000");
    await page.getByRole("button", { name: "DEBİM'e bağlan" }).click();
    await expect(page.locator("p[role=alert]")).toHaveText(/Güvenlik anahtarı geçersiz/);

    await page.getByLabel("Site adresi").fill("http://127.0.0.1:3198");
    await page.getByLabel("Güvenlik anahtarı (token)").fill("e2etoken1234567890abcdef12345678");
    await page.getByRole("button", { name: "DEBİM'e bağlan" }).click();
    await expect(page.getByText(/DEBİM'e bağlanıldı \(Abdurrahim Türkmenoğlu\)/)).toBeVisible();
    await expect(page.getByText("İLF431 Siyasal İletişim", { exact: false }).first()).toBeVisible();

    await page.getByLabel("AcademicOS dersi").selectOption({ label: "İLF431 Siyasal İletişim" });
    await page.getByRole("button", { name: "Eşleştir" }).click();
    await expect(page.getByText("Ders eşleştirildi.")).toBeVisible();
    await page.getByRole("button", { name: "Ders materyallerimi aktar" }).click();
    await expect(page.getByTestId("aktarim-raporu")).toContainText("2 dosya eklendi");
    await page.getByRole("button", { name: "Ders materyallerimi aktar" }).click();
    await expect(page.getByTestId("aktarim-raporu")).toContainText("0 dosya eklendi · 2 zaten vardı");

    await openCourse(page, "İLF431");
    await expect(page.getByRole("link", { name: "3. hafta — 3. Hafta: Gündem belirleme" })).toBeVisible();
    await expect(page.getByRole("link", { name: "hafta3" })).toBeVisible();

    await page.goto("/debim");
    page.on("dialog", (d) => d.accept());
    await page.getByRole("button", { name: "Bağlantıyı kaldır" }).click();
    await expect(page.getByText(/bağlantısı kaldırıldı ve anahtar silindi/)).toBeVisible();
  });

  test("ZIP içe aktarma: klasörler konu olur, tekrarlanan dosya eklenmez", async ({ page }) => {
    await register(page);
    const z = new JSZip();
    const fs = await import("node:fs");
    z.file("Ders/2. Hafta - Çerçeveleme/notlar.pdf", fs.readFileSync(fixture("siyasal-iletisim-hafta3.pdf")));
    z.file("Ders/2. Hafta - Çerçeveleme/kopya.pdf", fs.readFileSync(fixture("siyasal-iletisim-hafta3.pdf")));
    const dir = mkdtempSync(path.join(os.tmpdir(), "aos-e2e-"));
    const zipPath = path.join(dir, "ders.zip");
    writeFileSync(zipPath, await z.generateAsync({ type: "nodebuffer" }));
    await page.goto("/debim");
    await page.locator('select[name="courseId"]').selectOption({ label: "İLF431 Siyasal İletişim" });
    await page.getByLabel("Dosyalar veya ZIP").setInputFiles(zipPath);
    await page.getByRole("button", { name: "İçe aktar" }).click();
    await expect(page.getByTestId("aktarim-raporu")).toContainText("1 dosya eklendi · 1 zaten vardı");
    await page.goto("/telafi");
    await expect(page.getByText("2. Hafta - Çerçeveleme").first()).toBeVisible();
  });
});

test("OCR: taranmış görselden metin çıkarılır ve düzeltilebilir", async ({ page }) => {
  test.setTimeout(120_000);
  await register(page);
  await openCourse(page, "İLF431");
  await page.locator("#kaynak-yukle").getByLabel(/Dosya/).setInputFiles(fixture("taranmis.png"));
  await page.locator("#kaynak-yukle").getByRole("button", { name: "Yükle" }).click();
  await expect(page.getByText(/OCR\) henüz desteklenmiyor|metin okuma/).first()).toBeVisible();
  await page.getByRole("button", { name: "OCR ile metni çıkar" }).click();
  await expect(page.getByText(/OCR başlatıldı/)).toBeVisible();
  await expect(page.getByText(/haberin hangi yönünün/).first()).toBeVisible({ timeout: 90_000 });
  await page.getByText("OCR metnini düzelt").click();
  await page.getByLabel("OCR metni").fill("Çerçeveleme, haberin hangi yönünün öne çıkacağını seçer. (düzeltildi)");
  await page.getByRole("button", { name: "Düzeltmeyi kaydet" }).click();
  await expect(page.getByText("OCR metni düzeltildi.")).toBeVisible();
  await page.goto("/ara?q=düzeltildi");
  await expect(page.getByText(/1 sonuç/)).toBeVisible();
});

test("Kayıt yükleme: ses oynatılır, deşifre sağlayıcısı yokken dürüstçe kapalı görünür", async ({ page }) => {
  await register(page);
  const dir = mkdtempSync(path.join(os.tmpdir(), "aos-e2e-"));
  const mp3 = path.join(dir, "ders-kaydi.mp3");
  execFileSync("ffmpeg", ["-hide_banner", "-loglevel", "error", "-f", "lavfi", "-i", "sine=frequency=440:duration=2", "-y", mp3]);
  await page.goto("/kayitlar");
  await expect(page.getByText(/Otomatik deşifre kapalı/)).toBeVisible();
  await page.getByLabel(/Ses \/ video dosyası/).setInputFiles(mp3);
  await page.getByLabel("Başlık").fill("Siyasal iletişim 3. hafta kaydı");
  await page.getByRole("button", { name: "Yükle" }).click();
  await expect(page.getByRole("heading", { name: "Siyasal iletişim 3. hafta kaydı" })).toBeVisible();
  await expect(page.getByText(/süre 00:00:02/)).toBeVisible();
  const src = await page.locator("audio").getAttribute("src");
  const res = await page.request.get(src!, { headers: { Range: "bytes=0-99" } });
  expect(res.status()).toBe(206);
  expect((await res.body()).length).toBe(100);
  await expect(page.getByText(/Otomatik deşifre kapalı/)).toBeVisible();
  await expect(page.getByRole("button", { name: "Deşifre et" })).toHaveCount(0);
});

test("Bölüm Projesi, akademik tartışma ve iş merkezi", async ({ page }) => {
  await register(page);
  // Proje
  await page.goto("/proje");
  await page.getByLabel("Proje konusu / başlığı").fill("Kıbrıs'ta yerel gazetecilik");
  await page.getByLabel("Danışman", { exact: true }).fill("İbrahim Özejder");
  await page.getByRole("button", { name: "Kaydet" }).first().click();
  await expect(page.getByText("Proje bilgileri kaydedildi.")).toBeVisible();
  await page.getByLabel("Tür").selectOption("teslim");
  await page.getByLabel("Başlık", { exact: true }).fill("Ara teslim");
  const due = new Date(Date.now() + 5 * 86400_000).toLocaleDateString("sv-SE", { timeZone: "Europe/Nicosia" });
  await page.getByLabel("Son tarih (varsa)").fill(due);
  await page.getByRole("button", { name: "Ekle" }).click();
  await expect(page.getByText(/Ara \/ son teslim eklendi/)).toBeVisible();
  await expect(page.getByText("Yaklaşan teslimler ve görevler")).toBeVisible();
  await page.goto("/plan");
  await expect(page.getByText(/Bölüm Projesi 1\/2: Ara teslim/).first()).toBeVisible();

  // Tartışma
  await page.goto("/tartismalar");
  await page.getByLabel("Tartışma başlığı").fill("Haberde tarafsızlık ve adalet");
  await page.getByLabel("Tema").selectOption("adalet");
  await page.getByRole("button", { name: "Tartışma oluştur" }).click();
  await page.getByLabel(/1\. Tartışılan iddia/).fill("Gazeteci her koşulda tarafsız olmalıdır.");
  await page.getByRole("button", { name: "Kaydet" }).first().click();
  await expect(page.getByText("Tartışma kaydedildi.")).toBeVisible();
  await page.getByLabel("Künye").fill("Nisâ 4/135");
  await page.getByRole("button", { name: "Kaynak ekle" }).click();
  await expect(page.getByTestId("tartisma-kaynagi")).toContainText("Doğrulanmadı");
  await page.getByRole("button", { name: "Asıl kaynaktan kontrol ettim" }).click();
  await expect(page.getByTestId("tartisma-kaynagi")).toContainText("Doğrulandı");

  // İş merkezi
  await page.goto("/is");
  await expect(page.getByRole("link", { name: /Ahmet Özsoy/ })).toBeVisible();
  await expect(page.getByText(/Ahmet Özsoy ile Gündem/).first()).toBeVisible();
  await expect(page.getByText(/akademik zaman \(08\.30–18\.00\)/).first()).toBeVisible();
  await page.getByRole("link", { name: /Hasan Bey/ }).click();
  const taskForm = page.locator("form", { has: page.getByRole("button", { name: "Görev ekle" }) });
  await taskForm.getByLabel("Başlık").fill("Seçim Reels'i");
  await taskForm.getByLabel("Süre tahmini (dk)").fill("60");
  await page.getByRole("button", { name: "Görev ekle" }).click();
  await expect(page.getByText("İş görevi eklendi.")).toBeVisible();
  await page.getByRole("link", { name: "Etki analizi / planla" }).click();
  await expect(page.getByTestId("is-analizi")).toContainText("Akademik zamanı koruyarak en erken uygun zaman");
  await page.getByRole("button", { name: "Bu zamana planla" }).click();
  await expect(page.getByText(/akademik zamanın dışına planlandı/)).toBeVisible();
  const planned = await page.getByTestId("is-gorevi").getByText(/Planlandı:/).textContent();
  const m = planned!.match(/(\d{1,2}) (\S+) (\d{4}) (\d{2})\.(\d{2})/)!;
  const months = ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"];
  const day = new Date(Date.UTC(Number(m[3]), months.indexOf(m[2]), Number(m[1]))).getUTCDay();
  const minutes = Number(m[4]) * 60 + Number(m[5]);
  if (day >= 1 && day <= 5) expect(minutes).toBeGreaterThanOrEqual(18 * 60 + 30); // hafta içi akademik zaman korunur
});
