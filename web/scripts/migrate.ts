/**
 * Veritabanı migration çalıştırıcısı.
 * DATABASE_URL_OWNER (tablo sahibi) ile bağlanır, db/migrations altındaki
 * SQL dosyalarını sırayla ve her biri tek işlem içinde uygular, ardından
 * uygulama rolüne (APP_DB_ROLE) gerekli yetkileri verir.
 */
import { readdirSync, readFileSync } from "node:fs";
import path from "node:path";
import { Client } from "pg";

export async function migrate(ownerUrl: string, appRole: string, log = console.log) {
  if (!/^[a-z_][a-z0-9_]*$/.test(appRole)) throw new Error("Geçersiz APP_DB_ROLE");
  const client = new Client({ connectionString: ownerUrl });
  await client.connect();
  try {
    await client.query(`CREATE TABLE IF NOT EXISTS schema_migrations (
      name text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now())`);
    const dir = path.join(process.cwd(), "db", "migrations");
    const files = readdirSync(dir).filter((f) => f.endsWith(".sql")).sort();
    const done = new Set(
      (await client.query<{ name: string }>("SELECT name FROM schema_migrations")).rows.map((r) => r.name),
    );
    for (const file of files) {
      if (done.has(file)) continue;
      const sql = readFileSync(path.join(dir, file), "utf8");
      await client.query("BEGIN");
      try {
        await client.query(sql);
        await client.query("INSERT INTO schema_migrations (name) VALUES ($1)", [file]);
        await client.query("COMMIT");
        log(`uygulandı: ${file}`);
      } catch (err) {
        await client.query("ROLLBACK");
        throw new Error(`${file} uygulanamadı: ${(err as Error).message}`);
      }
    }
    await client.query(`GRANT USAGE ON SCHEMA public TO ${appRole}`);
    await client.query(`GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO ${appRole}`);
    await client.query(`GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO ${appRole}`);
    await client.query(`REVOKE ALL ON schema_migrations FROM ${appRole}`);
  } finally {
    await client.end();
  }
}

if (process.argv[1] && process.argv[1].endsWith("migrate.ts")) {
  const url = process.env.DATABASE_URL_OWNER;
  if (!url) {
    console.error("DATABASE_URL_OWNER tanımlı değil.");
    process.exit(1);
  }
  migrate(url, process.env.APP_DB_ROLE ?? "academicos_app")
    .then(() => console.log("Migration tamamlandı."))
    .catch((e) => {
      console.error(e.message);
      process.exit(1);
    });
}
