import { describe, expect, it } from "vitest";
import { INITIAL_COURSES } from "@/lib/data/seed";
import { addDays, DEFAULT_SETTINGS, DEFAULT_WINDOWS, plan, weekdayOf, type Demand, type PlanInput } from "@/lib/planner";
import { buildDemands, type DemandInput } from "@/lib/planner-demand";
import { toMinutes } from "@/lib/schedule";

const courses = INITIAL_COURSES.map((c) => ({ id: c.code, code: c.code }));
const meetings = INITIAL_COURSES.flatMap((c) => c.meetings.map(([weekday, start, end]) => ({ course_id: c.code, weekday, start, end })));
const TODAY = "2026-10-12"; // Pazartesi

function bigBacklog(): DemandInput {
  const topics = INITIAL_COURSES.flatMap((c, ci) =>
    [1, 2, 3, 4].map((w) => ({
      id: `${c.code}-t${w}`, course_id: c.code, title: `Konu ${w}`, week: w,
      status: (["materyal_eksik", "materyal_alindi", "okundu", "tekrar_gerekiyor"] as const)[(w + ci) % 4],
      is_catch_up: w <= 2, openMistakes: w === 4 ? 2 : 0,
    })),
  );
  return {
    today: TODAY, days: 14, courses, topics,
    meetings: meetings.map((m) => ({ course_id: m.course_id, weekday: m.weekday, end_time: m.end })),
    dueByCourseDate: [{ course_id: "İLF431", date: "2026-10-10", count: 6 }, { course_id: "İLF413", date: "2026-10-15", count: 3 }],
    assessments: [
      { id: "vize431", course_id: "İLF431", title: "Vize", due_date: "2026-10-20" },
      { id: "final", course_id: "İLF413", title: "Final", due_date: null },
    ],
    completedKeys: new Set(),
  };
}

function run(extra: Partial<PlanInput> = {}, demandInput = bigBacklog()) {
  const demands = buildDemands(demandInput);
  const input: PlanInput = {
    startDate: TODAY, days: 14, nowTime: null, settings: DEFAULT_SETTINGS, windows: DEFAULT_WINDOWS,
    meetings: meetings.map(({ weekday, start, end }) => ({ weekday, start, end })), fixed: [], demands, ...extra,
  };
  return { demands, input, result: plan(input) };
}

const span = (start: string, minutes: number) => [toMinutes(start), toMinutes(start) + minutes] as const;
const overlaps = (a: readonly [number, number], b: readonly [number, number]) => a[0] < b[1] && b[0] < a[1];

describe("Planlayıcı kuralları (9 dersin gerçek programıyla)", () => {
  const { result, input } = run();

  it("görevler yalnızca çalışma aralıklarına yerleşir", () => {
    for (const p of result.placed) {
      const [s, e] = span(p.start, p.minutes);
      const ok = DEFAULT_WINDOWS.some((w) => w.weekday === weekdayOf(p.date) && toMinutes(w.start) <= s && e <= toMinutes(w.end));
      expect(ok, `${p.date} ${p.start} ${p.title}`).toBe(true);
    }
  });

  it("hiçbir görev ders saatiyle çakışmaz", () => {
    for (const p of result.placed) {
      for (const m of input.meetings.filter((m) => m.weekday === weekdayOf(p.date))) {
        expect(overlaps(span(p.start, p.minutes), [toMinutes(m.start), toMinutes(m.end)]), `${p.date} ${p.start} ${p.title}`).toBe(false);
      }
    }
  });

  it("görevler birbiriyle çakışmaz ve aralarında mola vardır", () => {
    const byDate = Map.groupBy(result.placed, (p) => p.date);
    for (const list of byDate.values()) {
      for (let i = 1; i < list.length; i++) {
        const prevEnd = toMinutes(list[i - 1].start) + list[i - 1].minutes;
        expect(toMinutes(list[i].start)).toBeGreaterThanOrEqual(prevEnd + DEFAULT_SETTINGS.breakMin);
      }
    }
  });

  it("günlük kapasite, telafi payı ve ders başına sınır aşılmaz", () => {
    const byDate = Map.groupBy(result.placed, (p) => p.date);
    for (const [date, list] of byDate) {
      const cap = weekdayOf(date) <= 5 ? DEFAULT_SETTINGS.weekdayCapacityMin : DEFAULT_SETTINGS.weekendCapacityMin;
      expect(list.reduce((n, p) => n + p.minutes, 0)).toBeLessThanOrEqual(cap);
      expect(list.filter((p) => p.catchUp).reduce((n, p) => n + p.minutes, 0)).toBeLessThanOrEqual(Math.floor((cap * DEFAULT_SETTINGS.catchUpShare) / 100));
      const perCourse = Map.groupBy(list, (p) => p.courseId);
      for (const l of perCourse.values()) expect(l.reduce((n, p) => n + p.minutes, 0)).toBeLessThanOrEqual(120);
      const topics = list.filter((p) => p.topicId).map((p) => p.topicId);
      expect(new Set(topics).size).toBe(topics.length);
    }
  });

  it("büyük birikimde bütün eksikler ilk güne yığılmaz; sığmayanlar raporlanır", () => {
    const first = result.placed.filter((p) => p.date === TODAY);
    expect(first.reduce((n, p) => n + p.minutes, 0)).toBeLessThanOrEqual(150);
    expect(new Set(result.placed.map((p) => p.date)).size).toBeGreaterThanOrEqual(10);
    for (const u of result.unplaced) expect(u.reason.length).toBeGreaterThan(0);
  });

  it("güncel dersler ihmal edilmez: ders gününden sonra 2 gün içinde gözden geçirme planlanır", () => {
    const guncel = result.placed.filter((p) => p.key.startsWith("guncel:"));
    expect(guncel.length).toBeGreaterThan(10);
    // Gözden geçirmelerin büyük çoğunluğu dersin yapıldığı gün yapılır. Cuma günü 5 ders
    // 17.30'a kadar sürdüğünden bir kısmı fiziksel olarak ertesi güne kayar.
    const sameDay = guncel.filter((g) => g.date === g.key.split(":")[2]);
    expect(sameDay.length / guncel.length).toBeGreaterThanOrEqual(0.75);
    const spilled = guncel.filter((g) => g.date !== g.key.split(":")[2]);
    for (const g of spilled) expect(weekdayOf(g.key.split(":")[2]), JSON.stringify([g, result.placed.filter((p) => p.date === g.key.split(":")[2])])).toBe(5);
    for (const g of guncel) {
      const classDate = g.key.split(":")[2];
      expect(g.date >= classDate && g.date <= addDays(classDate, 2)).toBe(true);
      if (g.date === classDate) {
        const ends = meetings.filter((m) => m.course_id === g.courseId && m.weekday === weekdayOf(classDate)).map((m) => toMinutes(m.end));
        expect(toMinutes(g.start)).toBeGreaterThanOrEqual(Math.max(...ends));
      }
    }
  });

  it("tarihli sınav hazırlığı sınavdan önce biter; tarihi bilinmeyen sınava tarih uydurulmaz", () => {
    const prep = result.placed.filter((p) => p.key.startsWith("sinav:vize431"));
    expect(prep).toHaveLength(3);
    for (const p of prep) expect(p.date < "2026-10-20").toBe(true);
    expect(result.placed.some((p) => p.key.includes("final"))).toBe(false);
  });

  it("vadesi geçmiş tekrar kartları bugüne alınır", () => {
    expect(result.placed.find((p) => p.key === `tekrar:İLF431:${TODAY}`)?.date).toBe(TODAY);
  });

  it("deterministiktir", () => {
    expect(run().result).toEqual(result);
  });
});

describe("Yeniden planlama ve sabit görevler", () => {
  it("tamamlanan görev yeniden üretilmez", () => {
    const di = bigBacklog();
    const key = buildDemands(di).find((d) => d.kind === "eksik")!.key;
    di.completedKeys = new Set([key]);
    expect(buildDemands(di).some((d) => d.key === key)).toBe(false);
  });

  it("kilitli görevler kapasiteden düşülür ve üzerine görev konmaz", () => {
    const fixed = [{ date: TODAY, start: "12:30", minutes: 120, courseId: "İLF431", topicId: null }];
    const { result } = run({ fixed });
    const today = result.placed.filter((p) => p.date === TODAY);
    expect(today.reduce((n, p) => n + p.minutes, 0)).toBeLessThanOrEqual(30);
    for (const p of today) expect(overlaps(span(p.start, p.minutes), [toMinutes("12:30"), toMinutes("14:40")])).toBe(false);
  });

  it("başlangıç gününde şu andan önceye görev konmaz", () => {
    const { result } = run({ nowTime: "17:00" });
    for (const p of result.placed.filter((p) => p.date === TODAY)) expect(toMinutes(p.start)).toBeGreaterThanOrEqual(toMinutes("17:00"));
  });

  it("kapasite sıfırsa hiçbir şey planlanmaz ve hepsi gerekçeli raporlanır", () => {
    const { result, demands } = run({ settings: { ...DEFAULT_SETTINGS, weekdayCapacityMin: 0, weekendCapacityMin: 0 } });
    expect(result.placed).toHaveLength(0);
    expect(result.unplaced.length).toBeGreaterThanOrEqual(demands.length);
  });

  it("uzun görev parçalara bölünür ve parçalar sırayla farklı günlere yerleşir", () => {
    const d: Demand = { key: "uzun", courseId: "İLF431", topicId: "x", kind: "telafi", title: "Uzun", detail: "", minutes: 120,
      priority: 50, earliest: TODAY, deadline: null, catchUp: false };
    const r = plan({ startDate: TODAY, days: 14, settings: DEFAULT_SETTINGS, windows: DEFAULT_WINDOWS, meetings: [], fixed: [], demands: [d] });
    expect(r.placed.map((p) => p.key)).toEqual(["uzun#1", "uzun#2", "uzun#3"]);
    expect(r.placed.every((p) => p.minutes <= 50)).toBe(true);
    expect(new Set(r.placed.map((p) => p.date)).size).toBe(3);
  });
});
