import { expect, test } from "@playwright/test";
import { register } from "./helpers";

test("mobil görünüm: menü çalışır, yatay taşma yok", async ({ page }) => {
  await register(page);
  const overflow = await page.evaluate(() => document.documentElement.scrollWidth > window.innerWidth + 1);
  expect(overflow).toBe(false);
  await page.getByRole("button", { name: "Menü" }).click();
  await page.getByRole("link", { name: "Derslerim" }).click();
  await expect(page.getByTestId("ders-karti")).toHaveCount(9);
  expect(await page.evaluate(() => document.documentElement.scrollWidth > window.innerWidth + 1)).toBe(false);
});

test("mobil görünüm: plan, takvim, telafi ve ayarlar sayfalarında yatay taşma yok", async ({ page }) => {
  await register(page);
  for (const path of ["/plan", "/takvim", "/telafi", "/ayarlar", "/plan/ayarlar", "/calis", "/debim", "/proje", "/tartismalar", "/is", "/kayitlar"]) {
    await page.goto(path);
    await expect(page.locator("h1").first()).toBeVisible();
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
    expect(overflow, path).toBeLessThanOrEqual(1);
  }
});
