/**
 * Öğrenme durumu hesapları — saf fonksiyonlar.
 * Ustalık, tamamlanan görev sayısına değil, her sorunun EN SON cevabına göre ölçülür.
 */
export type AttemptLite = { question_id: string; is_correct: boolean | null; created_at: Date | string; confidence?: string | null };
export type QuestionLite = { id: string; concept: string; objective_id: string | null };

/** Her soru için en son değerlendirilmiş cevap. */
export function latestGraded(attempts: AttemptLite[]): Map<string, AttemptLite> {
  const out = new Map<string, AttemptLite>();
  for (const a of attempts) {
    if (a.is_correct == null) continue;
    const prev = out.get(a.question_id);
    if (!prev || new Date(a.created_at).getTime() >= new Date(prev.created_at).getTime()) out.set(a.question_id, a);
  }
  return out;
}

export type MasteryLevel = "kanit_yok" | "zayif" | "gelisiyor" | "ogrenildi";
export const MASTERY_LABELS: Record<MasteryLevel, string> = {
  kanit_yok: "Henüz ölçülmedi",
  zayif: "Zayıf",
  gelisiyor: "Gelişiyor",
  ogrenildi: "Öğrenildi",
};

/**
 * Bir soru kümesinin ustalık düzeyi:
 *  - cevaplanmış soru yoksa: kanıt yok
 *  - en son cevapların tamamı doğru ve en az 2 soru (veya kümedeki tek soru) cevaplanmışsa: öğrenildi
 *  - doğruluk ≥ %60: gelişiyor; aksi halde zayıf
 * Tahminle verilmiş doğru cevaplar "öğrenildi" sayılmaz.
 */
export function mastery(questionIds: string[], latest: Map<string, AttemptLite>) {
  const answered = questionIds.map((id) => latest.get(id)).filter((a): a is AttemptLite => !!a);
  const correct = answered.filter((a) => a.is_correct).length;
  const accuracy = answered.length ? correct / answered.length : null;
  let level: MasteryLevel = "kanit_yok";
  if (answered.length) {
    const solid = answered.every((a) => a.is_correct && a.confidence !== "tahmin");
    const enough = answered.length >= Math.min(2, questionIds.length);
    level = solid && enough ? "ogrenildi" : accuracy! >= 0.6 ? "gelisiyor" : "zayif";
  }
  return { total: questionIds.length, answered: answered.length, correct, accuracy, level };
}

/** Kavram bazlı doğruluk; zayıftan güçlüye sıralı. */
export function conceptStats(questions: QuestionLite[], latest: Map<string, AttemptLite>) {
  const groups = new Map<string, string[]>();
  for (const q of questions) {
    const c = q.concept.trim();
    if (!c) continue;
    groups.set(c, [...(groups.get(c) ?? []), q.id]);
  }
  return [...groups.entries()]
    .map(([concept, ids]) => ({ concept, ...mastery(ids, latest) }))
    .filter((c) => c.answered > 0)
    .sort((a, b) => (a.accuracy ?? 1) - (b.accuracy ?? 1) || a.concept.localeCompare(b.concept, "tr"));
}

export type StepInput = {
  sourcesWithText: number;
  status: string;
  readingSessions: number;
  notes: number;
  questions: number;
  answered: number;
  openMistakes: number;
  objectives: number;
  objectivesLearned: number;
};

export type Step = { key: string; title: string; done: boolean; hint: string };

/** Konu çalışma adımları; her adımın tamamlanması gerçek veriden belirlenir. */
export function studySteps(i: StepInput): Step[] {
  const readOrBeyond = ["okundu", "not_cikarildi", "soru_calisildi", "tamamlandi"].includes(i.status);
  return [
    { key: "materyal", title: "Materyali yükle", done: i.sourcesWithText > 0, hint: "Konunun ders notunu, slaytını veya kaydını yükle." },
    { key: "hedef", title: "Öğrenme hedeflerini yaz", done: i.objectives > 0, hint: "Bu konunun sonunda neyi açıklayabilmen gerektiğini 2–4 madde olarak yaz." },
    { key: "oku", title: "Kaynağı oku / dinle", done: readOrBeyond || i.readingSessions > 0, hint: "Kaynakla çalışma oturumu aç ve dikkatle oku." },
    { key: "not", title: "Kendi cümlelerinle not çıkar", done: i.notes > 0, hint: "Okuduğunu bakmadan özetle; özet çıkarmak aktif hatırlamadır." },
    { key: "soru", title: "Soru çöz", done: i.answered > 0 && i.answered >= Math.min(3, i.questions), hint: "Kendi sorularını ekle veya hazır soruları çöz; notlara bakma." },
    { key: "yanlis", title: "Yanlışları tamamla", done: i.answered > 0 && i.openMistakes === 0, hint: "Yanlışlar defterindeki açıklamaları oku ve soruları yeniden çöz." },
    { key: "dogrula", title: "Hedefleri doğrula", done: i.objectives > 0 && i.objectivesLearned === i.objectives, hint: "Her hedefe bağlı soruları doğru ve emin şekilde cevapla." },
  ];
}
