import { randomUUID } from "node:crypto";
import { registerUser } from "@/lib/auth-core";

process.env.DATABASE_URL =
  process.env.TEST_DATABASE_URL ?? "postgres://academicos_app:devapp@localhost:5432/academicos_test";

export async function newUser(name = "Test Öğrenci") {
  const email = `test-${randomUUID()}@ornek.edu.tr`;
  const password = "çokGizliParola-123";
  const id = await registerUser({ email, name, password });
  return { id, email, password };
}
