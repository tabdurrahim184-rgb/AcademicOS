import { expect, type Page } from "@playwright/test";
import { randomUUID } from "node:crypto";
import path from "node:path";

export const fixture = (f: string) => path.join(__dirname, "..", "fixtures", f);

export async function register(page: Page, name = "Abdurrahim Türkmenoğlu") {
  const email = `e2e-${randomUUID().slice(0, 8)}@ornek.edu.tr`;
  const password = "Güçlü-Parola-2026";
  await page.goto("/kayit");
  await page.getByLabel("Ad soyad").fill(name);
  await page.getByLabel("E-posta").fill(email);
  await page.getByLabel("Parola", { exact: true }).fill(password);
  await page.getByLabel("Parola (tekrar)").fill(password);
  await page.getByRole("button", { name: "Hesap oluştur" }).click();
  await expect(page.getByRole("heading", { name: /Merhaba/ })).toBeVisible();
  return { email, password };
}

export async function login(page: Page, email: string, password: string) {
  await page.goto("/giris");
  await page.getByLabel("E-posta").fill(email);
  await page.getByLabel("Parola").fill(password);
  await page.getByRole("button", { name: "Giriş yap" }).click();
  await expect(page.getByRole("heading", { name: /Merhaba/ })).toBeVisible();
}

export async function openCourse(page: Page, code: string) {
  await page.goto("/dersler");
  await page.getByTestId("ders-karti").filter({ hasText: code }).click();
  await expect(page.getByRole("heading", { level: 1 })).toBeVisible();
}

export async function addTopic(page: Page, week: string, title: string) {
  const details = page.locator("#konu-ekle");
  if (!(await details.evaluate((d) => (d as HTMLDetailsElement).open))) await details.locator("summary").click();
  await page.getByLabel("Hafta", { exact: true }).fill(week);
  await page.getByLabel("Konu başlığı").fill(title);
  await page.getByRole("button", { name: "Ekle", exact: true }).first().click();
  await expect(page.getByText("Konu eklendi.")).toBeVisible();
}

export async function uploadPdf(page: Page, topicTitle: string, file = "siyasal-iletisim-hafta3.pdf") {
  const form = page.locator("#kaynak-yukle");
  await form.getByLabel(/Dosya/).setInputFiles(fixture(file));
  await form.getByLabel("Konu").selectOption({ label: `3. hafta — ${topicTitle}` });
  await form.getByRole("button", { name: "Yükle" }).click();
}
