import { defineConfig, devices } from "@playwright/test";

/**
 * Uçtan uca testler gerçek bir Next.js sunucusu ve gerçek PostgreSQL
 * (academicos_e2e veritabanı) üzerinde çalışır.
 * İki sunucu başlatılır:
 *  - 3100: yapay zekâ KAPALI (gerçek varsayılan durum)
 *  - 3101: yapay zekâ, yerel bir test ikizi sunucusuna yönlendirilmiş (tests/e2e/mock-anthropic.mjs).
 *    Bu yalnızca uygulamanın yapay zekâ akışını test eder; gerçek sağlayıcıyı doğrulamaz.
 */
const E2E_DB = process.env.E2E_DATABASE_URL ?? "postgres://academicos_app:devapp@localhost:5432/academicos_e2e";
const chromiumPath = process.env.CHROMIUM_PATH;

export default defineConfig({
  testDir: "tests/e2e",
  fullyParallel: false,
  workers: 1,
  timeout: 30_000,
  reporter: [["list"]],
  globalSetup: "./tests/e2e/global-setup.ts",
  use: {
    trace: "retain-on-failure",
    locale: "tr-TR",
    timezoneId: "Europe/Nicosia",
    launchOptions: chromiumPath ? { executablePath: chromiumPath } : {},
  },
  projects: [
    { name: "masaustu", use: { ...devices["Desktop Chrome"], baseURL: "http://localhost:3100" }, testIgnore: /ai\.spec|mobil\.spec/ },
    { name: "yapay-zeka", use: { ...devices["Desktop Chrome"], baseURL: "http://localhost:3101" }, testMatch: /ai\.spec/ },
    { name: "mobil", use: { ...devices["Pixel 7"], baseURL: "http://localhost:3100" }, testMatch: /mobil\.spec/ },
  ],
  webServer: [
    {
      command: "npx next start -p 3100",
      port: 3100,
      reuseExistingServer: false,
      env: { DATABASE_URL: E2E_DB, AI_PROVIDER: "", NEXT_TELEMETRY_DISABLED: "1" },
    },
    { command: "node tests/e2e/mock-anthropic.mjs", port: 3199, reuseExistingServer: false },
    {
      command: "npx next start -p 3101",
      port: 3101,
      reuseExistingServer: false,
      env: {
        DATABASE_URL: E2E_DB, AI_PROVIDER: "anthropic", ANTHROPIC_API_KEY: "test-anahtari", ANTHROPIC_BASE_URL: "http://localhost:3199",
        AI_MODEL: "claude-opus-5-5", NEXT_TELEMETRY_DISABLED: "1",
      },
    },
  ],
});
