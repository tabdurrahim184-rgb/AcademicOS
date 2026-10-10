"use client";
import { useActionState } from "react";
import type { FormState } from "@/app/actions/auth";
import { SubmitButton } from "./SubmitButton";

export function AuthForm({
  action,
  mode,
}: {
  action: (s: FormState, f: FormData) => Promise<FormState>;
  mode: "giris" | "kayit";
}) {
  const [state, formAction] = useActionState(action, undefined);
  return (
    <form action={formAction} className="space-y-4">
      {state?.error && <p role="alert" className="alert-err">{state.error}</p>}
      {mode === "kayit" && (
        <div>
          <label className="label" htmlFor="name">Ad soyad</label>
          <input className="input" id="name" name="name" required autoComplete="name" />
        </div>
      )}
      <div>
        <label className="label" htmlFor="email">E-posta</label>
        <input className="input" id="email" name="email" type="email" required autoComplete="email" />
      </div>
      <div>
        <label className="label" htmlFor="password">Parola</label>
        <input className="input" id="password" name="password" type="password" required minLength={mode === "kayit" ? 10 : undefined}
          autoComplete={mode === "kayit" ? "new-password" : "current-password"} />
        {mode === "kayit" && <p className="muted mt-1">En az 10 karakter.</p>}
      </div>
      {mode === "kayit" && (
        <div>
          <label className="label" htmlFor="password2">Parola (tekrar)</label>
          <input className="input" id="password2" name="password2" type="password" required autoComplete="new-password" />
        </div>
      )}
      <SubmitButton pendingText={mode === "kayit" ? "Hesap oluşturuluyor…" : "Giriş yapılıyor…"} className="btn w-full">
        {mode === "kayit" ? "Hesap oluştur" : "Giriş yap"}
      </SubmitButton>
    </form>
  );
}
