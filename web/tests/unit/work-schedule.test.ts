import { describe, expect, it } from "vitest";
import { INITIAL_COURSES } from "@/lib/data/seed";
import { addDays, dateRange, weekdayOf } from "@/lib/planner";
import { toMinutes } from "@/lib/schedule";
import { findWorkSlot, MAX_WORK_MIN_PER_DAY, overlapsAcademic, type Block } from "@/lib/work-schedule";

const MONDAY = "2026-10-12";
const classBlocks = (from: string, days: number): Block[] =>
  dateRange(from, days).flatMap((date) =>
    INITIAL_COURSES.flatMap((c) => c.meetings.filter(([wd]) => wd === weekdayOf(date)).map(([, s, e]) => ({
      date, start: s, minutes: toMinutes(e) - toMinutes(s), label: c.code, kind: "ders" as const,
    }))),
  );

describe("Test I — akademik zaman koruması", () => {
  it("hafta içi 08.30–18.00 aralığına hiçbir koşulda otomatik iş görevi konmaz (yüzlerce senaryo)", () => {
    let checked = 0;
    for (let d = 0; d < 14; d++) {
      const from = addDays(MONDAY, d);
      for (const fromTime of ["00:00", "08:00", "12:00", "17:45", "21:00"]) {
        for (const minutes of [15, 45, 90, 180]) {
          for (const due of [from, addDays(from, 1), addDays(from, 6), null]) {
            const r = findWorkSlot({ fromDate: from, fromTime, dueDate: due, minutes, blocks: classBlocks(from, 14) });
            if (!r.ok) continue;
            checked++;
            expect(overlapsAcademic(r.date, r.start, minutes), `${r.date} ${r.start} ${minutes}`).toBe(false);
            if (weekdayOf(r.date) <= 5) expect(toMinutes(r.start)).toBeGreaterThanOrEqual(toMinutes("18:30"));
          }
        }
      }
    }
    expect(checked).toBeGreaterThan(500);
  });

  it("aynı gün içinde teslim edilecek iş, akademik saat dolu diye akademik saate kaydırılmaz", () => {
    const r = findWorkSlot({ fromDate: MONDAY, fromTime: "09:00", dueDate: MONDAY, minutes: 60, blocks: [] });
    expect(r).toMatchObject({ ok: true, date: MONDAY, start: "18:30" });
    const late = findWorkSlot({ fromDate: MONDAY, fromTime: "22:30", dueDate: MONDAY, minutes: 60, blocks: [] });
    expect(late.ok).toBe(false);
  });

  it("ders saatleri, sabit taahhütler ve diğer işlerle asla çakışmaz; günlük iş üst sınırını aşmaz", () => {
    const blocks: Block[] = [
      { date: MONDAY, start: "18:30", minutes: 120, label: "Canlı yayın", kind: "taahhut" },
      { date: MONDAY, start: "20:30", minutes: 90, label: "Başka iş", kind: "is" },
    ];
    const r = findWorkSlot({ fromDate: MONDAY, fromTime: null, dueDate: null, minutes: 60, blocks });
    expect(r).toMatchObject({ ok: true, date: MONDAY, start: "22:00" });
    const full: Block[] = [{ date: MONDAY, start: "18:30", minutes: MAX_WORK_MIN_PER_DAY, label: "x", kind: "is" }];
    const r2 = findWorkSlot({ fromDate: MONDAY, fromTime: null, dueDate: null, minutes: 30, blocks: full });
    expect(r2).toMatchObject({ ok: true, date: addDays(MONDAY, 1) });
  });

  it("çalışma planıyla çakışmayan yer yoksa etkilenecek ders çalışmalarını açıkça listeler", () => {
    const blocks: Block[] = [{ date: MONDAY, start: "18:30", minutes: 270, label: "Konuyu çalış: İLF431", kind: "calisma" }];
    const r = findWorkSlot({ fromDate: MONDAY, fromTime: null, dueDate: MONDAY, minutes: 60, blocks });
    expect(r).toMatchObject({ ok: true, date: MONDAY });
    expect(r.ok && r.affected.map((a) => a.label)).toEqual(["Konuyu çalış: İLF431"]);
    const free = findWorkSlot({ fromDate: MONDAY, fromTime: null, dueDate: null, minutes: 60, blocks });
    expect(free.ok && free.affected).toEqual([]); // teslim esnekse çalışmaya dokunulmaz
  });

  it("geçmiş teslim tarihi ve aşırı uzun görev reddedilir", () => {
    expect(findWorkSlot({ fromDate: MONDAY, fromTime: null, dueDate: addDays(MONDAY, -1), minutes: 30, blocks: [] }).ok).toBe(false);
    expect(findWorkSlot({ fromDate: MONDAY, fromTime: null, dueDate: null, minutes: 300, blocks: [] }).ok).toBe(false);
  });
});
