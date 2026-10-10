import { expect, test } from "@playwright/test";
import { addTopic, fixture, login, openCourse, register, uploadPdf } from "./helpers";

test.describe("İlk kullanılabilir sürüm kabul akışı (yapay zekâ kapalı)", () => {
  test("giriş → 9 ders → PDF yükle → çalış → soru çöz → yanlış → çıkış/giriş → kaldığın yerden devam", async ({ page, context }) => {
    // 1–3: Uygulamayı aç, hesap oluştur / giriş yap, dokuz dersi gör
    const { email, password } = await register(page);
    await page.goto("/dersler");
    await expect(page.getByTestId("ders-karti")).toHaveCount(9);
    await expect(page.getByText("Ders saati çakışmaları")).toBeVisible();
    await expect(page.getByRole("listitem").filter({ hasText: /Cuma 15\.30–16\.30: .*İLF413.*İLF267|Cuma 15\.30–16\.30: .*İLF267.*İLF413/ })).toBeVisible();

    // 4: Siyasal İletişim
    await openCourse(page, "İLF431");
    await expect(page.getByRole("heading", { name: "Siyasal İletişim" })).toBeVisible();
    await addTopic(page, "3", "Gündem belirleme");

    // 5–7: Gerçek PDF yükle, derse kaydedilsin, içerik okunup konuyla ilişkilendirilsin
    await uploadPdf(page, "Gündem belirleme");
    await expect(page.getByText(/Dosya kaydedildi\. 2 metin bölümü çıkarıldı/)).toBeVisible();
    await expect(page.getByText("Sayfa 1", { exact: true })).toBeVisible();
    await expect(page.getByText(/Gündem belirleme kuramı, medyanın/)).toBeVisible();
    await expect(page.getByText("Konu: Gündem belirleme")).toBeVisible();
    // Özgün dosya bayt bayt geri alınabilir
    const fileUrl = await page.getByRole("link", { name: "Özgün dosyayı aç" }).getAttribute("href");
    const res = await page.request.get(fileUrl!);
    expect(res.status()).toBe(200);
    expect(res.headers()["content-type"]).toBe("application/pdf");
    const fs = await import("node:fs");
    expect(Buffer.from(await res.body()).equals(fs.readFileSync(fixture("siyasal-iletisim-hafta3.pdf")))).toBe(true);

    // 8–9: Yapay zekâ kapalı → dürüst durum, kaynakla çalışma (okuma) oturumu
    await page.getByRole("button", { name: "Bu kaynakla çalış" }).click();
    await expect(page.getByRole("heading", { name: /Kaynak okuma: Gündem belirleme/ })).toBeVisible();
    await expect(page.getByText(/McCombs ve Shaw/)).toBeVisible();
    const sessionUrl = page.url();

    // Soru ekle (ders sayfasında)
    await openCourse(page, "İLF431");
    await page.getByText("Soru ekle", { exact: true }).click();
    await page.locator('select[name="type"]').selectOption("kisa_cevap");
    await page.locator("form", { has: page.locator('select[name="type"]') }).locator('select[name="topicId"]').selectOption({ label: "Gündem belirleme" });
    await page.getByLabel(/Soru metni/).fill("Chapel Hill araştırmasını kimler yürütmüştür?");
    await page.getByLabel(/Kabul edilen cevaplar/).fill("McCombs ve Shaw|McCombs and Shaw");
    await page.getByLabel("Ölçülen kavram").fill("Gündem belirlemenin kökeni");
    await page.getByRole("button", { name: "Soruyu kaydet" }).click();
    await expect(page.getByText("Soru kaydedildi.")).toBeVisible();

    // 10–13: Soru çöz, cevap kaydedilsin, değerlendirme görünsün, yanlış tekrar listesine girsin
    await page.goto(sessionUrl);
    await page.getByLabel("Cevabın").fill("Lazarsfeld");
    await page.getByRole("button", { name: "Cevabı gönder" }).click();
    await expect(page.getByText(/^Yanlış — 0 \/ 100/)).toBeVisible();
    await expect(page.getByText(/Kabul edilen cevap: McCombs ve Shaw/)).toBeVisible();
    await expect(page.getByText(/yanlışlar defterine eklendi/)).toBeVisible();
    await page.goto("/yanlislar");
    await expect(page.getByText("Chapel Hill araştırmasını kimler yürütmüştür?")).toBeVisible();
    await expect(page.getByText("Lazarsfeld")).toBeVisible();

    // 14–16: Çıkış yap, yeniden giriş yap, kaldığın yerden devam et
    await page.goto("/");
    await page.getByRole("button", { name: "Çıkış yap" }).click();
    await expect(page).toHaveURL(/\/giris/);
    await page.goto(sessionUrl);
    await expect(page).toHaveURL(/\/giris/);
    await context.clearCookies();
    await login(page, email, password);
    await expect(page.getByText(/yarım kalan çalışma oturumun var/)).toBeVisible();
    await page.getByRole("link", { name: "Kaldığın yerden devam et" }).click();
    await expect(page).toHaveURL(sessionUrl);
    await expect(page.getByText("(1/1 cevaplandı)")).toBeVisible();
    await expect(page.getByText(/Cevabın:.*Lazarsfeld/)).toBeVisible();
  });

  test("Test G — başka kullanıcı özel oturum, kaynak ve dosyaya erişemez", async ({ page, browser }) => {
    await register(page);
    await openCourse(page, "İLF431");
    await addTopic(page, "3", "Gündem belirleme");
    await uploadPdf(page, "Gündem belirleme");
    await expect(page.getByText(/Dosya kaydedildi/)).toBeVisible();
    const sourceUrl = new URL(page.url()).pathname;
    const fileUrl = (await page.getByRole("link", { name: "Özgün dosyayı aç" }).getAttribute("href"))!;

    const other = await browser.newContext({ baseURL: "http://localhost:3100" });
    const p2 = await other.newPage();
    await register(p2, "Başka Kullanıcı");
    const r1 = await p2.goto(sourceUrl);
    expect(r1?.status()).toBe(404);
    const r2 = await p2.request.get(fileUrl);
    expect(r2.status()).toBe(404);
    await p2.goto("/ara?q=çerçeveleme");
    await expect(p2.getByText("0 sonuç")).toBeVisible();
    // Oturumsuz erişim
    const anon = await browser.newContext({ baseURL: "http://localhost:3100" });
    expect((await anon.request.get(fileUrl)).status()).toBe(401);
    expect((await anon.request.get("/api/yedek")).status()).toBe(401);
    await other.close();
    await anon.close();
  });

  test("Test K / L — Türkçe arama ve bozuk dosya hatası", async ({ page }) => {
    await register(page);
    await openCourse(page, "İLF431");
    await addTopic(page, "3", "Çerçeveleme");
    await uploadPdf(page, "Çerçeveleme");
    await expect(page.getByText(/Dosya kaydedildi/)).toBeVisible();
    await page.goto("/ara?q=ÇERÇEVELEME");
    await expect(page.getByText(/sonuç/)).not.toHaveText(/^0 sonuç/);
    await expect(page.locator("mark").first()).toHaveText(/çerçeveleme/i);

    await openCourse(page, "İLF431");
    await page.locator("#kaynak-yukle").getByLabel(/Dosya/).setInputFiles(fixture("sahte.docx"));
    await page.locator("#kaynak-yukle").getByRole("button", { name: "Yükle" }).click();
    await expect(page.locator("p[role=alert]")).toHaveText(/geçerli bir DOCX değil/);

    await page.locator("#kaynak-yukle").getByLabel(/Dosya/).setInputFiles(fixture("metinsiz.pdf"));
    await page.locator("#kaynak-yukle").getByRole("button", { name: "Yükle" }).click();
    await expect(page.getByText(/seçilebilir metin bulunamadı/).first()).toBeVisible();
  });

  test("Test J — yedek indirilir ve geri yüklenir", async ({ page }) => {
    await register(page);
    await openCourse(page, "İLF413");
    await addTopic(page, "1", "Etik kuramlar");
    await page.goto("/ayarlar");
    const download = page.waitForEvent("download");
    await page.getByRole("link", { name: "Yedeği indir" }).click();
    const file = await (await download).path();
    const json = JSON.parse((await import("node:fs")).readFileSync(file!, "utf8"));
    expect(json.data.courses).toHaveLength(9);
    expect(json.data.topics[0].title).toBe("Etik kuramlar");

    await page.locator('input[name="file"]').setInputFiles(file!);
    await page.getByLabel(/Onaylamak için/).fill("yanlış");
    await page.getByRole("button", { name: "Geri yükle" }).click();
    await expect(page.locator("p[role=alert]")).toHaveText(/GERİ YÜKLE yazın/);

    await page.locator('input[name="file"]').setInputFiles(file!);
    await page.getByLabel(/Onaylamak için/).fill("GERİ YÜKLE");
    page.on("dialog", (d) => d.accept());
    await page.getByRole("button", { name: "Geri yükle" }).click();
    await expect(page.getByText(/Geri yükleme tamamlandı: 9 ders/)).toBeVisible();
    await page.goto("/telafi");
    await expect(page.getByText("1. hafta — Etik kuramlar")).toBeVisible();
  });
});
