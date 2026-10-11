import Link from "next/link";
import { redirect } from "next/navigation";
import { loginAction } from "@/app/actions/auth";
import { AuthForm } from "@/components/AuthForm";
import { getCurrentUser } from "@/lib/auth";

export const metadata = { title: "Giriş" };

export default async function LoginPage() {
  if (await getCurrentUser()) redirect("/");
  return (
    <>
      <h1 className="mb-4">Giriş yap</h1>
      <AuthForm action={loginAction} mode="giris" />
      {process.env.ALLOW_REGISTRATION !== "false" && (
        <p className="muted mt-4">Hesabın yok mu? <Link href="/kayit">Hesap oluştur</Link></p>
      )}
    </>
  );
}
