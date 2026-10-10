import { describe, expect, it } from "vitest";
import { recommend, type RecInput } from "@/lib/recommend";
import { requiredRemainingAverage } from "@/lib/data/assessments";

const now = new Date("2026-10-12T09:00:00Z");
const base: RecInput = {
  now,
  courses: [{ id: "c1", code: "İLF431", name: "Siyasal İletişim" }, { id: "c2", code: "İLF413", name: "İletişim Etiği" }],
  topics: [],
  dueCardsByCourse: {},
  openMistakesByCourse: {},
  assessments: [],
  activeSession: null,
};

describe("Şimdi Ders Çalış önerisi", () => {
  it("konu yoksa konu eklemeyi önerir", () => {
    expect(recommend(base).action).toBe("konu_ekle");
  });
  it("yarım oturum varsa devam ettirir", () => {
    const r = recommend({ ...base, activeSession: { id: "s", course_id: "c1", last_activity_at: new Date(now.getTime() - 3600_000) } });
    expect(r.action).toBe("devam");
  });
  it("zamanı gelen tekrarı yeni konudan önce önerir", () => {
    const r = recommend({
      ...base,
      dueCardsByCourse: { c2: 3 },
      topics: [{ id: "t", course_id: "c1", title: "Çerçeveleme", week: 3, status: "materyal_alindi", sourceCount: 1 }],
    });
    expect(r).toMatchObject({ action: "calis", courseId: "c2", mode: "hizli_tekrar" });
  });
  it("7 gün içindeki sınavı önceliklendirir", () => {
    const r = recommend({ ...base, dueCardsByCourse: { c2: 3 }, assessments: [{ course_id: "c1", title: "Vize", due_at: new Date(now.getTime() + 3 * 86400_000) }] });
    expect(r).toMatchObject({ courseId: "c1", mode: "sinav_hazirligi" });
  });
  it("tarihi bilinmeyen sınav öncelik almaz", () => {
    const r = recommend({ ...base, assessments: [{ course_id: "c1", title: "Final", due_at: null }] });
    expect(r.action).toBe("konu_ekle");
  });
  it("materyali eksik konuda yükleme ister", () => {
    const r = recommend({ ...base, topics: [{ id: "t", course_id: "c1", title: "X", week: 1, status: "materyal_eksik", sourceCount: 0 }] });
    expect(r.action).toBe("materyal_yukle");
  });
});

describe("Gereken not hesabı", () => {
  it("ağırlıklar eksikse hesaplamaz", () => {
    expect(requiredRemainingAverage([{ weight: 40, score: 70 }, { weight: null, score: null }], 60).ok).toBe(false);
  });
  it("kalan ağırlıktan gereken ortalamayı hesaplar", () => {
    const r = requiredRemainingAverage([{ weight: 40, score: 50 }, { weight: 60, score: null }], 60);
    expect(r).toMatchObject({ ok: true, required: 66.7, current: 20 });
  });
});
