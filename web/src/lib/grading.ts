/**
 * Nesnel soru türleri için deterministik değerlendirme.
 * Açık uçlu türler burada değerlendirilmez (yapay zekâ veya öz değerlendirme gerekir).
 */
export const QUESTION_TYPES = {
  coktan_secmeli: "Çoktan seçmeli",
  dogru_yanlis: "Doğru / Yanlış",
  kisa_cevap: "Kısa cevap",
  bosluk_doldurma: "Boşluk doldurma",
  eslestirme: "Eşleştirme",
  kavram_aciklama: "Kavram açıklama",
  karsilastirma: "Karşılaştırma",
  acik_uclu: "Açık uçlu yorum",
  vaka_analizi: "Vaka analizi",
} as const;
export type QuestionType = keyof typeof QUESTION_TYPES;

export const OBJECTIVE_TYPES: QuestionType[] = ["coktan_secmeli", "dogru_yanlis", "kisa_cevap", "bosluk_doldurma", "eslestirme"];
export const isObjective = (t: QuestionType) => OBJECTIVE_TYPES.includes(t);

/** Türkçe'ye uygun karşılaştırma için normalleştirme (İ/ı doğru küçültülür). */
export function normalizeTr(s: string): string {
  return s
    .normalize("NFC")
    .toLocaleLowerCase("tr-TR")
    .replace(/[.,;:!?"'’“”()\[\]]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

export type GradeResult = { isCorrect: boolean; score: number; feedback: string };

/**
 * answer biçimleri:
 *  - coktan_secmeli: { index: number }
 *  - dogru_yanlis:   { value: boolean }
 *  - kisa_cevap / bosluk_doldurma: { accepted: string[] }  (kabul edilen cevaplar)
 *  - eslestirme:     { pairs: number[] }  (sol i → sağ pairs[i])
 */
export function gradeObjective(type: QuestionType, answer: unknown, response: unknown): GradeResult {
  const a = answer as Record<string, unknown> | null;
  const r = response as Record<string, unknown> | null;
  if (!a || !r) throw new Error("Cevap anahtarı veya öğrenci cevabı eksik.");
  switch (type) {
    case "coktan_secmeli": {
      const ok = Number(r.index) === Number(a.index);
      return { isCorrect: ok, score: ok ? 100 : 0, feedback: ok ? "Doğru seçenek." : "Yanlış seçenek." };
    }
    case "dogru_yanlis": {
      const ok = Boolean(r.value) === Boolean(a.value);
      return { isCorrect: ok, score: ok ? 100 : 0, feedback: ok ? "Doğru." : `Yanlış. Doğru cevap: ${a.value ? "Doğru" : "Yanlış"}.` };
    }
    case "kisa_cevap":
    case "bosluk_doldurma": {
      const accepted = (a.accepted as string[]).map(normalizeTr);
      const given = normalizeTr(String(r.text ?? ""));
      const ok = given.length > 0 && accepted.includes(given);
      return {
        isCorrect: ok,
        score: ok ? 100 : 0,
        feedback: ok ? "Doğru." : `Kabul edilen cevap: ${(a.accepted as string[]).join(" / ")}.`,
      };
    }
    case "eslestirme": {
      const pairs = a.pairs as number[];
      const given = (r.pairs as number[]) ?? [];
      const correct = pairs.filter((p, i) => Number(given[i]) === p).length;
      const score = Math.round((correct / pairs.length) * 100);
      return { isCorrect: correct === pairs.length, score, feedback: `${pairs.length} eşleştirmeden ${correct} tanesi doğru.` };
    }
    default:
      throw new Error("Bu soru türü otomatik değerlendirilemez.");
  }
}
