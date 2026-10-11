"use server";
import { redirect } from "next/navigation";
import { authenticate, AuthError, registerUser } from "@/lib/auth-core";
import { clientKey, endSession, startSession } from "@/lib/auth";

export type FormState = { error?: string; ok?: string } | undefined;

export async function loginAction(_: FormState, form: FormData): Promise<FormState> {
  try {
    const userId = await authenticate(String(form.get("email") ?? ""), String(form.get("password") ?? ""), await clientKey());
    await startSession(userId);
  } catch (e) {
    if (e instanceof AuthError) return { error: e.message };
    console.error("Giriş hatası", e);
    return { error: "Giriş sırasında beklenmeyen bir hata oluştu." };
  }
  redirect("/");
}

export async function registerAction(_: FormState, form: FormData): Promise<FormState> {
  if (process.env.ALLOW_REGISTRATION === "false") return { error: "Yeni hesap oluşturma kapalı." };
  if (form.get("password") !== form.get("password2")) return { error: "Parolalar eşleşmiyor." };
  try {
    const userId = await registerUser({
      email: String(form.get("email") ?? ""),
      name: String(form.get("name") ?? ""),
      password: String(form.get("password") ?? ""),
    });
    await startSession(userId);
  } catch (e) {
    if (e instanceof AuthError) return { error: e.message };
    console.error("Kayıt hatası", e);
    return { error: "Kayıt sırasında beklenmeyen bir hata oluştu." };
  }
  redirect("/");
}

export async function logoutAction() {
  await endSession();
  redirect("/giris");
}
