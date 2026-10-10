import { describe, expect, it } from "vitest";
import { NEW_CARD, qualityFromResult, sm2 } from "@/lib/sm2";

describe("SM-2", () => {
  it("doğru cevap dizisinde aralıklar 1, 6, round(6*EF) olur", () => {
    const a = sm2(NEW_CARD, 5);
    expect(a).toEqual({ ease: 2.6, intervalDays: 1, repetitions: 1, lapses: 0 });
    const b = sm2(a, 5);
    expect(b.intervalDays).toBe(6);
    const c = sm2(b, 5);
    expect(c.intervalDays).toBe(Math.round(6 * 2.7));
  });
  it("yanlış cevap tekrar sayacını sıfırlar ve ertesi güne planlar", () => {
    const s = sm2(sm2(sm2(NEW_CARD, 5), 5), 1);
    expect(s.repetitions).toBe(0);
    expect(s.intervalDays).toBe(1);
    expect(s.lapses).toBe(1);
  });
  it("kolaylık katsayısı 1.3'ün altına düşmez", () => {
    let s = NEW_CARD;
    for (let i = 0; i < 20; i++) s = sm2(s, 0);
    expect(s.ease).toBe(1.3);
  });
  it("deterministiktir", () => {
    expect(sm2({ ease: 2.1, intervalDays: 10, repetitions: 4, lapses: 2 }, 3)).toEqual(
      sm2({ ease: 2.1, intervalDays: 10, repetitions: 4, lapses: 2 }, 3),
    );
  });
  it("geçersiz kalite reddedilir", () => {
    expect(() => sm2(NEW_CARD, 6)).toThrow();
    expect(() => sm2(NEW_CARD, 2.5)).toThrow();
  });
  it("puanı kaliteye çevirir", () => {
    expect(qualityFromResult(true)).toBe(4);
    expect(qualityFromResult(false)).toBe(1);
    expect(qualityFromResult(true, 95)).toBe(5);
    expect(qualityFromResult(false, 50)).toBe(2);
  });
});
