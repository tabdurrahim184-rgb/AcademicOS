import { expect, test } from "@playwright/test";
import { addTopic, openCourse, register, uploadPdf } from "./helpers";

// Not: Bu testler yerel bir Anthropic API test ikiziyle çalışır (tests/e2e/mock-anthropic.mjs).
// Uygulamanın yapay zekâ akışını (kayıt, kaynak bağlamı, atıf doğrulama, soru üretimi,
// değerlendirme) doğrular; gerçek bir modelin cevap kalitesini DOĞRULAMAZ.
test("Bana bu konuyu öğret → kaynaklı yanıt → soru üret → açık uçlu değerlendirme", async ({ page }) => {
  await register(page);
  await openCourse(page, "İLF431");
  await addTopic(page, "3", "Gündem belirleme");
  await uploadPdf(page, "Gündem belirleme");
  await expect(page.getByText(/Dosya kaydedildi/)).toBeVisible();

  await page.getByRole("button", { name: "Bana bu konuyu öğret" }).click();
  await expect(page.getByRole("heading", { name: /Konu anlatımı: Gündem belirleme/ })).toBeVisible();
  await expect(page.getByText(/konusunu bana öğret|kaynağındaki konuyu bana öğret/)).toBeVisible();
  await expect(page.getByText(/medya, kamuoyunun hangi konular hakkında düşüneceğini/)).toBeVisible();
  await expect(page.getByRole("link", { name: /\[K1\] .* — Sayfa 1/ })).toBeVisible();

  await page.getByLabel("Mesajın").fill("Hayır, aynı şey değil; neyi düşüneceğimizi belirler.");
  await page.getByRole("button", { name: "Gönder" }).click();
  await expect(page.getByText("Hayır, aynı şey değil; neyi düşüneceğimizi belirler.")).toBeVisible();
  await expect(page.getByText(/Öğretmen \(yapay zekâ/)).toHaveCount(2);

  await openCourse(page, "İLF431");
  await page.getByText("Kaynaklardan yapay zekâ ile soru üret").click();
  await page.locator("form", { has: page.getByRole("button", { name: "Üret" }) }).locator('select[name="topicId"]').selectOption({ label: "Gündem belirleme" });
  await page.getByRole("button", { name: "Üret" }).click();
  await expect(page.getByText(/2 soru üretildi ve kaydedildi/)).toBeVisible();
  await expect(page.getByText("Yapay zekâ", { exact: true }).first()).toBeVisible();

  await page.goto("/calis");
  await page.getByRole("link", { name: /Konu anlatımı/ }).first().click();
  await page.getByLabel("Cevabın").last().fill("Çerçeveleme bir olayın bazı yönlerini öne çıkarmaktır.");
  await page.getByRole("button", { name: "Cevabı gönder" }).last().click();
  await expect(page.getByText(/otomatik puanlanamaz/)).toBeVisible();
  await page.getByRole("button", { name: "Yapay zekâ ile değerlendir" }).click();
  await expect(page.getByText(/Tanım var ama örnek eksik/)).toBeVisible();
  await expect(page.getByText(/40 \/ 100/)).toBeVisible();
});
