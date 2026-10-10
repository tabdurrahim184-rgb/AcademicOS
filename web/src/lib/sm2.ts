/**
 * SM-2 aralıklı tekrar algoritması (Wozniak, 1990; SuperMemo 2).
 * Deterministiktir: aynı girdi her zaman aynı çıktıyı verir.
 *
 * quality: 0–5
 *   5 = kusursuz hatırlama, 4 = doğru ama tereddütlü, 3 = zorlanarak doğru,
 *   2 = yanlış ama doğru cevap tanıdık geldi, 1 = yanlış, 0 = hiç hatırlamadı.
 */
export type CardState = { ease: number; intervalDays: number; repetitions: number; lapses: number };

export const NEW_CARD: CardState = { ease: 2.5, intervalDays: 0, repetitions: 0, lapses: 0 };
const MIN_EASE = 1.3;

export function sm2(state: CardState, quality: number): CardState {
  if (!Number.isInteger(quality) || quality < 0 || quality > 5) throw new RangeError("quality 0–5 arasında tam sayı olmalı");
  let { ease, intervalDays, repetitions, lapses } = state;
  if (quality < 3) {
    repetitions = 0;
    intervalDays = 1;
    lapses += 1;
  } else {
    repetitions += 1;
    if (repetitions === 1) intervalDays = 1;
    else if (repetitions === 2) intervalDays = 6;
    else intervalDays = Math.round(intervalDays * ease);
  }
  ease = ease + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
  ease = Math.max(MIN_EASE, Math.round(ease * 100) / 100);
  return { ease, intervalDays, repetitions, lapses };
}

export function nextDueDate(from: Date, intervalDays: number): Date {
  return new Date(from.getTime() + intervalDays * 86400_000);
}

/** Otomatik değerlendirilen bir denemeyi SM-2 kalitesine çevirir. */
export function qualityFromResult(isCorrect: boolean, score?: number | null): number {
  if (score != null) {
    if (score >= 90) return 5;
    if (score >= 75) return 4;
    if (score >= 60) return 3;
    if (score >= 40) return 2;
    if (score > 0) return 1;
    return 0;
  }
  return isCorrect ? 4 : 1;
}
