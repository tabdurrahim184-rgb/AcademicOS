import { describe, expect, it } from "vitest";
import { gradeObjective, normalizeTr } from "@/lib/grading";

describe("Türkçe normalleştirme", () => {
  it("İ ve I harflerini Türkçe kurallarıyla küçültür", () => {
    expect(normalizeTr("İLETİŞİM")).toBe("iletişim");
    expect(normalizeTr("IŞIK")).toBe("ışık");
    expect(normalizeTr("  Gündem   Belirleme. ")).toBe("gündem belirleme");
  });
});

describe("Nesnel değerlendirme", () => {
  it("çoktan seçmeli", () => {
    expect(gradeObjective("coktan_secmeli", { index: 2 }, { index: 2 }).isCorrect).toBe(true);
    expect(gradeObjective("coktan_secmeli", { index: 2 }, { index: 0 }).isCorrect).toBe(false);
  });
  it("doğru/yanlış", () => {
    expect(gradeObjective("dogru_yanlis", { value: false }, { value: false }).isCorrect).toBe(true);
    expect(gradeObjective("dogru_yanlis", { value: false }, { value: true }).feedback).toContain("Yanlış");
  });
  it("kısa cevap büyük/küçük harf ve noktalamadan bağımsız, Türkçe karakter duyarlı", () => {
    const ans = { accepted: ["Gündem belirleme", "agenda setting"] };
    expect(gradeObjective("kisa_cevap", ans, { text: "GÜNDEM BELİRLEME." }).isCorrect).toBe(true);
    expect(gradeObjective("kisa_cevap", ans, { text: "gundem belirleme" }).isCorrect).toBe(false);
    expect(gradeObjective("kisa_cevap", ans, { text: "" }).isCorrect).toBe(false);
  });
  it("eşleştirme kısmi puan verir", () => {
    const r = gradeObjective("eslestirme", { pairs: [1, 0, 2] }, { pairs: [1, 2, 0] });
    expect(r.isCorrect).toBe(false);
    expect(r.score).toBe(33);
  });
  it("açık uçlu türler otomatik değerlendirilmez", () => {
    expect(() => gradeObjective("acik_uclu", {}, {})).toThrow();
  });
});
