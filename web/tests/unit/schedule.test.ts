import { describe, expect, it } from "vitest";
import { INITIAL_COURSES } from "@/lib/data/seed";
import { findConflicts, isProtectedAcademicTime, localParts, type Meeting } from "@/lib/schedule";

const meetings: Meeting[] = INITIAL_COURSES.flatMap((c) =>
  c.meetings.map(([weekday, start, end]) => ({ courseId: c.code, courseLabel: c.code, weekday, start, end })),
);

describe("Başlangıç dersleri", () => {
  it("tam olarak dokuz ders vardır ve Bölüm Projesi bunlardan biridir", () => {
    expect(INITIAL_COURSES).toHaveLength(9);
    expect(INITIAL_COURSES.some((c) => c.code === "GZT440")).toBe(true);
  });
  it("bilinmeyen öğretim elemanları uydurulmaz", () => {
    expect(INITIAL_COURSES.find((c) => c.code === "SEC351")!.instructor).toBeNull();
    expect(INITIAL_COURSES.find((c) => c.code === "İNG102")!.meetings).toHaveLength(0);
  });
});

describe("Çakışma tespiti", () => {
  it("Cuma 15.30 ve 16.30 çakışmalarını bulur, bitişik saatleri çakışma saymaz", () => {
    const c = findConflicts(meetings);
    const pairs = c.map((x) => [x.a.courseId, x.b.courseId].sort().join(" & ") + ` ${x.weekday} ${x.overlapStart}`);
    expect(pairs).toContain("İLF267 & İLF413 5 15:30");
    expect(pairs).toContain("İLF361 & İLF433 / SEC300 5 16:30");
    expect(c).toHaveLength(2);
  });
});

describe("Zaman dilimi ve akademik koruma", () => {
  it("Kıbrıs yaz saati (UTC+3) ve kış saati (UTC+2) doğru hesaplanır", () => {
    expect(localParts(new Date("2026-07-15T05:30:00Z"))).toMatchObject({ weekday: 3, time: "08:30" });
    expect(localParts(new Date("2026-01-14T06:30:00Z"))).toMatchObject({ weekday: 3, time: "08:30" });
  });
  it("hafta içi 08.30–18.00 korunur; hafta sonu ve akşam korunmaz", () => {
    expect(isProtectedAcademicTime(1, "08:30")).toBe(true);
    expect(isProtectedAcademicTime(5, "17:59")).toBe(true);
    expect(isProtectedAcademicTime(5, "18:00")).toBe(false);
    expect(isProtectedAcademicTime(3, "08:29")).toBe(false);
    expect(isProtectedAcademicTime(6, "10:00")).toBe(false);
  });
});
