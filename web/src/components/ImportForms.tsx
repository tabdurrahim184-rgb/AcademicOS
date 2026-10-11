"use client";
import { useActionState } from "react";
import { bulkImportAction, importDebimCourseAction, type ImportState } from "@/app/actions/lms";
import { SubmitButton } from "./SubmitButton";

const LABEL = { eklendi: "Eklendi", yinelenen: "Zaten var", atlandi: "Atlandı", hata: "Hata" } as const;
const CLS = { eklendi: "badge-ok", yinelenen: "badge", atlandi: "badge-warn", hata: "badge-err" } as const;

function Report({ state }: { state: ImportState }) {
  if (!state) return null;
  if (state.error) return <p role="alert" className="alert-err mt-3">{state.error}</p>;
  if (!state.outcomes) return null;
  const s = state.summary!;
  return (
    <div className="mt-3 space-y-2" role="status" data-testid="aktarim-raporu">
      <p className="alert-ok">{s.eklendi} dosya eklendi · {s.yinelenen} zaten vardı · {s.atlandi} atlandı · {s.hata} hata</p>
      <ul className="max-h-72 space-y-1 overflow-y-auto text-sm">
        {state.outcomes.map((o, i) => (
          <li key={i}><span className={CLS[o.status]}>{LABEL[o.status]}</span> {o.filename} <span className="muted">— {o.message}</span></li>
        ))}
      </ul>
    </div>
  );
}

export function DebimImportButton({ lmsCourseId }: { lmsCourseId: number }) {
  const [state, action] = useActionState(importDebimCourseAction, undefined);
  return (
    <form action={action}>
      <input type="hidden" name="lmsCourseId" value={lmsCourseId} />
      <SubmitButton pendingText="Materyaller aktarılıyor…">Ders materyallerimi aktar</SubmitButton>
      <Report state={state} />
    </form>
  );
}

export function BulkImportForm({ courses, defaultCourseId }: { courses: Array<{ id: string; code: string; name: string }>; defaultCourseId?: string }) {
  const [state, action] = useActionState(bulkImportAction, undefined);
  return (
    <form action={action} className="space-y-3">
      <div className="grid gap-3 sm:grid-cols-2">
        <label className="text-sm">Ders
          <select name="courseId" className="input mt-1" defaultValue={defaultCourseId} required>
            {courses.map((c) => <option key={c.id} value={c.id}>{c.code} {c.name}</option>)}
          </select>
        </label>
        <label className="text-sm">Dosyalar veya ZIP
          <input name="files" type="file" multiple required className="input mt-1" accept=".zip,.pdf,.docx,.pptx,.txt,.md,.srt,.vtt,.png,.jpg,.jpeg,.webp" />
        </label>
        <label className="text-sm">Konu (ZIP dışındaki dosyalar için, isteğe bağlı)<input name="topicTitle" className="input mt-1" /></label>
        <label className="text-sm">Hafta (isteğe bağlı)<input name="week" type="number" min={1} max={20} className="input mt-1" /></label>
      </div>
      <p className="muted">ZIP içinde her klasör bir konu olarak eşleştirilir; klasör adındaki &quot;3. Hafta&quot; gibi ifadeler hafta numarası olur. Aynı içerikteki dosyalar ikinci kez eklenmez.</p>
      <SubmitButton pendingText="İçe aktarılıyor…">İçe aktar</SubmitButton>
      <Report state={state} />
    </form>
  );
}
