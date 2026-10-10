/**
 * Entegrasyon testleri gerçek bir PostgreSQL test veritabanında çalışır.
 * TEST_DATABASE_URL_OWNER ile şema sıfırlanır ve migration uygulanır;
 * testler RLS'ye tabi uygulama rolüyle (TEST_DATABASE_URL) bağlanır.
 */
import { Client } from "pg";
import { migrate } from "../scripts/migrate";

export const TEST_OWNER_URL =
  process.env.TEST_DATABASE_URL_OWNER ?? "postgres://academicos_owner:devowner@localhost:5432/academicos_test";
export const TEST_APP_URL = process.env.TEST_DATABASE_URL ?? "postgres://academicos_app:devapp@localhost:5432/academicos_test";

export default async function setup() {
  process.env.DATABASE_URL = TEST_APP_URL;
  const c = new Client({ connectionString: TEST_OWNER_URL });
  await c.connect();
  await c.query("DROP SCHEMA public CASCADE; CREATE SCHEMA public;");
  await c.end();
  await migrate(TEST_OWNER_URL, process.env.APP_DB_ROLE ?? "academicos_app", () => {});
}
