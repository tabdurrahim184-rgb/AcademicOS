"use client";
import { useState } from "react";
import { QUESTION_TYPES, type QuestionType } from "@/lib/grading";
import { SubmitButton } from "./SubmitButton";

export function QuestionForm({
  action,
  courseId,
  topics,
  returnTo,
  defaultTopicId = "",
  objectives = [],
}: {
  action: (f: FormData) => Promise<void>;
  courseId: string;
  topics: Array<{ id: string; title: string }>;
  returnTo: string;
  defaultTopicId?: string;
  objectives?: Array<{ id: string; topic_id: string; text: string }>;
}) {
  const [type, setType] = useState<QuestionType>("coktan_secmeli");
  const [topicId, setTopicId] = useState(defaultTopicId);
  const topicObjectives = objectives.filter((o) => o.topic_id === topicId);
  const open = !["coktan_secmeli", "dogru_yanlis", "kisa_cevap", "bosluk_doldurma", "eslestirme"].includes(type);
  return (
    <form action={action} className="mt-3 space-y-3">
      <input type="hidden" name="courseId" value={courseId} />
      <input type="hidden" name="returnTo" value={returnTo} />
      <div className="grid gap-3 sm:grid-cols-3">
        <label className="text-sm">Tür
          <select name="type" className="input mt-1" value={type} onChange={(e) => setType(e.target.value as QuestionType)}>
            {Object.entries(QUESTION_TYPES).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
          </select>
        </label>
        <label className="text-sm">Konu
          <select name="topicId" className="input mt-1" value={topicId} onChange={(e) => setTopicId(e.target.value)}>
            <option value="">—</option>
            {topics.map((t) => <option key={t.id} value={t.id}>{t.title}</option>)}
          </select>
        </label>
        <label className="text-sm">Kaynağı
          <select name="origin" className="input mt-1" defaultValue="kullanici">
            <option value="kullanici">Kendi sorum</option>
            <option value="ogretim_elemani">Öğretim elemanının sorusu</option>
          </select>
        </label>
      </div>
      {topicObjectives.length > 0 && (
        <label className="block text-sm">Ölçtüğü öğrenme hedefi
          <select name="objectiveId" className="input mt-1" defaultValue="">
            <option value="">—</option>
            {topicObjectives.map((o) => <option key={o.id} value={o.id}>{o.text}</option>)}
          </select>
        </label>
      )}
      <label className="block text-sm">Soru metni{type === "bosluk_doldurma" && " (boşluğu ____ ile göster)"}
        <textarea name="prompt" required className="input mt-1" />
      </label>
      {type === "coktan_secmeli" && (
        <>
          <label className="block text-sm">Seçenekler (her satıra bir seçenek)<textarea name="options" required className="input mt-1 min-h-24" /></label>
          <label className="block text-sm">Doğru seçeneğin sırası (1 = ilk satır)<input name="correctIndex" type="number" min={1} required className="input mt-1 w-24" /></label>
        </>
      )}
      {type === "dogru_yanlis" && (
        <fieldset className="flex gap-4 text-sm"><legend className="mb-1">Doğru cevap</legend>
          <label className="flex items-center gap-1"><input type="radio" name="correctBool" value="dogru" required /> Doğru</label>
          <label className="flex items-center gap-1"><input type="radio" name="correctBool" value="yanlis" /> Yanlış</label>
        </fieldset>
      )}
      {(type === "kisa_cevap" || type === "bosluk_doldurma") && (
        <label className="block text-sm">Kabul edilen cevaplar (birden fazlaysa | ile ayır)<input name="accepted" required className="input mt-1" /></label>
      )}
      {type === "eslestirme" && (
        <label className="block text-sm">Eşleştirmeler (her satıra &quot;sol = sağ&quot;; en az 2 satır)<textarea name="options" required className="input mt-1 min-h-24" /></label>
      )}
      {open && (
        <label className="block text-sm">Değerlendirme ölçütü<textarea name="rubric" required className="input mt-1" placeholder="Cevapta bulunması gereken unsurlar" /></label>
      )}
      <label className="block text-sm">Açıklama / örnek cevap<textarea name="explanation" className="input mt-1" /></label>
      <label className="block text-sm">Ölçülen kavram<input name="concept" className="input mt-1" /></label>
      <SubmitButton>Soruyu kaydet</SubmitButton>
    </form>
  );
}
