import Link from "next/link";
import { redirect } from "next/navigation";
import { registerAction } from "@/app/actions/auth";
import { AuthForm } from "@/components/AuthForm";
import { getCurrentUser } from "@/lib/auth";

export const metadata = { title: "Hesap oluştur" };

export default async function RegisterPage() {
  if (await getCurrentUser()) redirect("/");
  if (process.env.ALLOW_REGISTRATION === "false") {
    return <p>Yeni hesap oluşturma bu sunucuda kapalı. <Link href="/giris">Giriş yap</Link></p>;
  }
  return (
    <>
      <h1 className="mb-1">Hesap oluştur</h1>
      <p className="muted mb-4">Hesabın dokuz dönem dersinle birlikte oluşturulur; bütün bilgileri sonradan düzenleyebilirsin.</p>
      <AuthForm action={registerAction} mode="kayit" />
      <p className="muted mt-4">Zaten hesabın var mı? <Link href="/giris">Giriş yap</Link></p>
    </>
  );
}
