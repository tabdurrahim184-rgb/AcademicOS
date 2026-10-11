import { Client } from "pg";
import { migrate } from "../../scripts/migrate";

export default async function setup() {
  const owner = process.env.E2E_DATABASE_URL_OWNER ?? "postgres://academicos_owner:devowner@localhost:5432/academicos_e2e";
  const c = new Client({ connectionString: owner });
  await c.connect();
  await c.query("DROP SCHEMA public CASCADE; CREATE SCHEMA public;");
  await c.end();
  await migrate(owner, process.env.APP_DB_ROLE ?? "academicos_app", () => {});
}
