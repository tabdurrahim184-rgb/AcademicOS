import { describe, expect, it } from "vitest";
import { conceptStats, latestGraded, mastery, studySteps } from "@/lib/mastery";
import { qualityFromResult } from "@/lib/sm2";

const at = (q: string, ok: boolean | null, t: string, confidence: string | null = null) => ({ question_id: q, is_correct: ok, created_at: t, confidence });

describe("Ustalık", () => {
  const latest = latestGraded([at("a", false, "2026-10-01"), at("a", true, "2026-10-02", "emin"), at("b", true, "2026-10-01", "tahmin"), at("c", null, "2026-10-03")]);
  it("her sorunun yalnızca en son değerlendirilmiş cevabını kullanır", () => {
    expect(latest.get("a")!.is_correct).toBe(true);
    expect(latest.has("c")).toBe(false);
  });
  it("düzeyleri doğru belirler", () => {
    expect(mastery([], latest).level).toBe("kanit_yok");
    expect(mastery(["a"], latest).level).toBe("ogrenildi");
    expect(mastery(["a", "b"], latest).level).toBe("gelisiyor"); // b tahminle doğru
    expect(mastery(["a", "x"], latest)).toMatchObject({ answered: 1, level: "gelisiyor" }); // tek cevap, 2 soru: yeterli kanıt yok
    const wrong = latestGraded([at("p", false, "1"), at("q", false, "1"), at("r", true, "1")]);
    expect(mastery(["p", "q", "r"], wrong).level).toBe("zayif");
  });
  it("kavramları zayıftan güçlüye sıralar, kavramı boş soruları atlar", () => {
    const qs = [{ id: "a", concept: "Güçlü", objective_id: null }, { id: "p", concept: "Zayıf", objective_id: null }, { id: "z", concept: " ", objective_id: null }];
    const l = latestGraded([at("a", true, "1"), at("p", false, "1"), at("z", false, "1")]);
    expect(conceptStats(qs, l).map((c) => c.concept)).toEqual(["Zayıf", "Güçlü"]);
  });
  it("çalışma adımları gerçek veriye göre tamamlanır", () => {
    const steps = studySteps({ sourcesWithText: 1, status: "materyal_alindi", readingSessions: 0, notes: 0, questions: 0, answered: 0, openMistakes: 0, objectives: 0, objectivesLearned: 0 });
    expect(steps.filter((s) => s.done).map((s) => s.key)).toEqual(["materyal"]);
    const later = studySteps({ sourcesWithText: 1, status: "okundu", readingSessions: 1, notes: 2, questions: 5, answered: 3, openMistakes: 1, objectives: 2, objectivesLearned: 1 });
    expect(later.find((s) => !s.done)!.key).toBe("yanlis");
  });
});

describe("Eminliğe göre SM-2 kalitesi", () => {
  it("eşlemeler", () => {
    expect([qualityFromResult(true, null, "emin"), qualityFromResult(true, null, "kismen"), qualityFromResult(true, null, "tahmin")]).toEqual([5, 4, 3]);
    expect([qualityFromResult(false, null, "emin"), qualityFromResult(false, null, "kismen"), qualityFromResult(false, null, "tahmin")]).toEqual([0, 1, 2]);
    expect(qualityFromResult(true, 80, "emin")).toBe(4); // puanlı açık uçlu cevapta puan esas alınır
  });
});
