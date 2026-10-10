"use client";
import { useActionState, useRef } from "react";
import { useFormStatus } from "react-dom";
import { sendMessageAction, type ChatState } from "@/app/actions/study";

function Buttons() {
  const { pending } = useFormStatus();
  return (
    <div className="flex flex-wrap gap-2">
      <button type="submit" className="btn" disabled={pending} aria-busy={pending}>{pending ? "Öğretmen yanıtlıyor…" : "Gönder"}</button>
      <button type="submit" name="quick" value="Anlamadım. Farklı bir örnekle ve daha basit anlatır mısın?" className="btn-secondary" disabled={pending} formNoValidate>Anlamadım</button>
      <button type="submit" name="quick" value="Beni bu konuda tek bir soruyla sına." className="btn-secondary" disabled={pending} formNoValidate>Beni sına</button>
    </div>
  );
}

export function ChatBox({ sessionId }: { sessionId: string }) {
  const [state, action] = useActionState<ChatState, FormData>(sendMessageAction, undefined);
  const ref = useRef<HTMLFormElement>(null);
  return (
    <form
      ref={ref}
      action={async (fd) => {
        await action(fd);
      }}
      onSubmit={() => setTimeout(() => ref.current?.reset(), 0)}
      className="space-y-2"
    >
      {state?.error && <p role="alert" className="alert-err">{state.error}</p>}
      <input type="hidden" name="sessionId" value={sessionId} />
      <label htmlFor="mesaj" className="sr-only">Mesajın</label>
      <textarea id="mesaj" name="message" className="input min-h-24" placeholder="Cevabını veya sorunu yaz…" />
      <Buttons />
    </form>
  );
}
