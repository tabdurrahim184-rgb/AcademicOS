import { expect, test } from "@playwright/test";
import { openCourse, register, uploadPdf, addTopic } from "./helpers";

test.describe("Telafi, 14 günlük plan, takvim ve konu çalışması", () => {
  test("telafi konusu → plan görevleri → tamamla / taşı → takvim ve .ics", async ({ page }) => {
    await register(page);

    // Telafi sayfasından kaçırılan haftayı ekle
    await page.goto("/telafi");
    await expect(page.getByTestId("telafi-dersi")).toHaveCount(9);
    const course = page.getByTestId("telafi-dersi").filter({ hasText: "İLF431 Siyasal İletişim" });
    await course.getByText("Kaçırdığın bir haftayı ekle").click();
    await course.getByLabel("Hafta").fill("1");
    await course.getByLabel("Konu başlığı").fill("Siyasal iletişime giriş");
    await course.getByRole("button", { name: "Telafi konusu ekle" }).click();
    await expect(page.getByText("Konu eklendi.")).toBeVisible();
    const row = page.getByTestId("telafi-dersi").filter({ hasText: "İLF431 Siyasal İletişim" });
    await expect(row.getByText("Telafi", { exact: true })).toBeVisible();
    await expect(row.getByText("Siyasal iletişime giriş").first()).toBeVisible();

    // Plan
    await page.goto("/plan");
    await expect(page.getByTestId("plan-gunu")).toHaveCount(14);
    const material = page.getByTestId("plan-gorevi").filter({ hasText: "Materyali temin et: İLF431 — 1. hafta: Siyasal iletişime giriş" });
    await expect(material).toHaveCount(1);
    // Günlük kapasite göstergesi
    const totals = await page.getByTestId("gun-toplami").allTextContents();
    expect(totals).toHaveLength(14);
    for (const text of totals) {
      const [used, cap] = text.replace(" dk", "").split(" / ").map(Number);
      expect(used).toBeLessThanOrEqual(cap);
    }

    // Bir görevi tamamla
    const first = page.getByTestId("plan-gorevi").first();
    const title = (await first.locator("p.font-medium").first().textContent())!;
    await first.getByRole("button", { name: "Tamamlandı" }).click();
    await expect(page.getByText("Görev tamamlandı olarak işaretlendi.")).toBeVisible();
    const doneItem = page.getByTestId("plan-gorevi").filter({ has: page.locator(".badge-ok", { hasText: "Tamamlandı" }) });
    await expect(doneItem).toHaveCount(1);
    await expect(doneItem).toContainText(title);
    await expect(doneItem.getByRole("button", { name: "Geri al" })).toBeVisible();

    // Görevi ders saatine taşımaya çalış (Salı 13.30–15.30 İLF431) → reddedilir
    const task = page.getByTestId("plan-gorevi").filter({ hasNot: page.locator(".badge-ok") }).first();
    await task.getByText("Diğer").click();
    const nextTuesday = await page.evaluate(() => {
      const d = new Date();
      d.setDate(d.getDate() + ((2 - d.getDay() + 7) % 7 || 7));
      return d.toISOString().slice(0, 10);
    });
    await task.getByLabel("Tarih").fill(nextTuesday);
    await task.getByLabel("Saat").fill("14:00");
    await task.getByRole("button", { name: "Taşı ve sabitle" }).click();
    await expect(page.locator("p[role=alert]")).toHaveText(/ders saatiyle çakışıyor/);

    // Takvim
    await page.goto(`/takvim?hafta=${nextTuesday}`);
    await expect(page.getByTestId("takvim-gunu")).toHaveCount(7);
    const tuesday = page.getByTestId("takvim-gunu").filter({ hasText: "Salı" });
    await expect(tuesday.getByText("İLF431 Siyasal İletişim")).toBeVisible();
    const friday = page.getByTestId("takvim-gunu").filter({ hasText: "Cuma" });
    await expect(friday.getByText(/Çakışma:/).first()).toBeVisible();

    const ics = await page.request.get("/api/takvim.ics");
    expect(ics.status()).toBe(200);
    expect(ics.headers()["content-type"]).toContain("text/calendar");
    const body = await ics.text();
    expect(body).toContain("BEGIN:VEVENT");
    expect(body).toContain("TZID:Europe/Nicosia");
    expect(body.replace(/\r\n /g, "")).toContain("SUMMARY:İLF431 Siyasal İletişim");
  });

  test("konu çalışma sayfası: hedef, hedefe bağlı soru, eminlik, kavram yanılgısı", async ({ page }) => {
    await register(page);
    await openCourse(page, "İLF431");
    await addTopic(page, "3", "Gündem belirleme");
    await uploadPdf(page, "Gündem belirleme");
    await expect(page.getByText(/Dosya kaydedildi/)).toBeVisible();
    await openCourse(page, "İLF431");
    await page.getByRole("link", { name: "3. hafta — Gündem belirleme" }).click();
    await expect(page.getByRole("heading", { name: "3. hafta — Gündem belirleme" })).toBeVisible();

    // Adımlar: materyal tamam, sıradaki hedef yazma
    const steps = page.getByTestId("calisma-adimi");
    await expect(steps).toHaveCount(7);
    await expect(steps.nth(0)).toContainText("Tamam");
    await expect(page.locator('[aria-current="step"]')).toContainText("Öğrenme hedeflerini yaz");

    await page.getByLabel("Yeni hedef").fill("Gündem belirlemenin kökenini açıklayabilirim.");
    await page.getByRole("button", { name: "Hedef ekle" }).click();
    await expect(page.getByText("Öğrenme hedefi eklendi.")).toBeVisible();
    await expect(page.getByText("Henüz ölçülmedi").first()).toBeVisible();

    // Hedefe bağlı soru ekle
    await page.locator('select[name="type"]').selectOption("dogru_yanlis");
    await page.locator('select[name="objectiveId"]').selectOption({ label: "Gündem belirlemenin kökenini açıklayabilirim." });
    await page.getByLabel(/Soru metni/).fill("Chapel Hill araştırması 1968 seçimlerinde yapılmıştır.");
    await page.getByLabel("Doğru", { exact: true }).check();
    await page.getByLabel("Ölçülen kavram").fill("Kuramın kökeni");
    await page.getByRole("button", { name: "Soruyu kaydet" }).click();
    await expect(page.getByText("Soru kaydedildi.")).toBeVisible();

    // Soruları çöz adımından aktif hatırlama oturumu → emin olarak yanlış cevap
    await page.getByRole("button", { name: "Soruları çöz" }).click();
    await expect(page.getByRole("heading", { name: /Aktif hatırlama/ })).toBeVisible();
    await page.getByLabel("Yanlış", { exact: true }).check();
    await page.getByLabel("Eminim").check();
    await page.getByRole("button", { name: "Cevabı gönder" }).click();
    await expect(page.getByText(/kavram yanılgısı olabilir/)).toBeVisible();

    await page.goto("/yanlislar");
    await expect(page.getByText("Kavram yanılgısı olabilir")).toBeVisible();
    await page.goBack();
    await page.goto("/telafi");
    await expect(page.getByText(/1 tanesi emin olunarak yapılmış/)).toBeVisible();
    await expect(page.getByText("Kuramın kökeni (1)")).toBeVisible();
  });
});
