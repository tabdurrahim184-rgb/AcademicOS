import { Pool, type PoolClient } from "pg";

export type Tx = PoolClient;

declare global {
  // Geliştirme modunda sıcak yeniden yüklemede tek havuz kullanılır.
  var __academicosPool: Pool | undefined;
}

export function getPool(): Pool {
  if (!globalThis.__academicosPool) {
    const connectionString = process.env.DATABASE_URL;
    if (!connectionString) throw new Error("DATABASE_URL tanımlı değil.");
    globalThis.__academicosPool = new Pool({ connectionString, max: 10 });
  }
  return globalThis.__academicosPool;
}

/** Kullanıcıya özel olmayan tablolar (auth) için tek sorgu. */
export async function sysQuery<T extends object = Record<string, unknown>>(text: string, params: unknown[] = []) {
  return getPool().query<T>(text, params);
}

/**
 * Kullanıcı bağlamında işlem çalıştırır. `app.user_id` yalnızca bu işlem
 * için ayarlanır; RLS politikaları bütün sorguları bu kullanıcıyla sınırlar.
 */
export async function withUser<T>(userId: string, fn: (tx: Tx) => Promise<T>): Promise<T> {
  const client = await getPool().connect();
  try {
    await client.query("BEGIN");
    await client.query("SELECT set_config('app.user_id', $1, true)", [userId]);
    const result = await fn(client);
    await client.query("COMMIT");
    return result;
  } catch (err) {
    await client.query("ROLLBACK").catch(() => {});
    throw err;
  } finally {
    client.release();
  }
}

export async function closePool() {
  if (globalThis.__academicosPool) {
    await globalThis.__academicosPool.end();
    globalThis.__academicosPool = undefined;
  }
}
