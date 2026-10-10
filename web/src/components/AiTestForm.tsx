"use client";
import { useActionState } from "react";
import { testAiConnectionAction, type AiTestState } from "@/app/actions/study";
import { SubmitButton } from "./SubmitButton";

export function AiTestForm() {
  const [state, action] = useActionState<AiTestState, FormData>(testAiConnectionAction, undefined);
  return (
    <form action={action} className="space-y-2">
      <label className="flex items-start gap-2 text-sm">
        <input type="checkbox" name="consent" className="mt-1" />
        <span>Sağlayıcıya tek, kısa bir <strong>ücretli</strong> istek gönderilmesini onaylıyorum (birkaç yüz token; maliyeti çok düşüktür ama sıfır değildir).</span>
      </label>
      <SubmitButton className="btn-secondary" pendingText="Test ediliyor…">Bağlantıyı test et</SubmitButton>
      {state?.error && <p role="alert" className="alert-err">{state.error}</p>}
      {state?.ok && <p role="status" className="alert-ok">{state.ok}</p>}
    </form>
  );
}
