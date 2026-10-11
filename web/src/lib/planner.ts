/**
 * 14 günlük çalışma planlayıcısı — saf ve deterministik.
 *
 * Kurallar (otomatik testlerle doğrulanır):
 *  - Görevler yalnızca kullanıcının tanımladığı çalışma aralıklarına yerleşir.
 *  - Ders saatleriyle ve sabit (kilitli/tamamlanmış) görevlerle çakışmaz.
 *  - Günlük toplam süre günlük kapasiteyi aşmaz.
 *  - Bir günün telafi süresi, kapasitenin belirlenen payını aşmaz (güncel dersler ihmal edilmez).
 *  - Bir derse bir günde en fazla MAX_COURSE_MIN_PER_DAY dakika ayrılır; aynı konu aynı gün iki kez planlanmaz.
 *  - Son tarihli görevler son tarihten sonra planlanmaz; sığmayanlar gerekçesiyle "plana sığmadı" listesine düşer.
 */
import { fromMinutes, toMinutes } from "./schedule";

export type PlanSettings = {
  weekdayCapacityMin: number;
  weekendCapacityMin: number;
  maxTaskMin: number;
  breakMin: number;
  catchUpShare: number; // 0–100
};

export type Window = { weekday: number; start: string; end: string };
export type Meeting = { weekday: number; start: string; end: string };
export type FixedTask = { date: string; start: string; minutes: number; topicId?: string | null; courseId?: string; catchUp?: boolean };

export type TaskKind = "telafi" | "guncel" | "tekrar" | "eksik" | "sinav" | "materyal";

export type Demand = {
  key: string;
  courseId: string;
  topicId: string | null;
  kind: TaskKind;
  title: string;
  detail: string;
  minutes: number;
  priority: number; // büyük olan önce
  earliest: string; // YYYY-MM-DD
  earliestTime?: string; // earliest günü bu saatten önce başlamaz (ör. ders bitişi)
  deadline: string | null; // bu tarih dahil, en geç
  catchUp: boolean;
};

export type Placed = Omit<Demand, "earliest" | "deadline" | "earliestTime"> & { date: string; start: string };
export type Unplaced = Demand & { reason: string };

export const MAX_COURSE_MIN_PER_DAY = 120;
export const DEFAULT_SETTINGS: PlanSettings = { weekdayCapacityMin: 150, weekendCapacityMin: 180, maxTaskMin: 50, breakMin: 10, catchUpShare: 60 };

/** Varsayılan çalışma aralıkları (kullanıcı düzenleyebilir). Hafta içi 08.30–18.00 akademik zamandır. */
export const DEFAULT_WINDOWS: Window[] = [
  ...[1, 2, 3, 4, 5].flatMap((d) => [
    { weekday: d, start: "08:30", end: "18:00" },
    { weekday: d, start: "20:00", end: "21:30" },
  ]),
  ...[6, 7].flatMap((d) => [
    { weekday: d, start: "10:00", end: "13:00" },
    { weekday: d, start: "15:00", end: "18:00" },
  ]),
];

// ------------------------------------------------------------ tarih yardımcıları (UTC, saat dilimi bağımsız)
export function addDays(date: string, n: number): string {
  const d = new Date(`${date}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
}
/** 1 = Pazartesi … 7 = Pazar */
export function weekdayOf(date: string): number {
  const w = new Date(`${date}T00:00:00Z`).getUTCDay();
  return w === 0 ? 7 : w;
}
export function dateRange(start: string, days: number): string[] {
  return Array.from({ length: days }, (_, i) => addDays(start, i));
}
/** Haftanın pazartesi günü */
export function weekStart(date: string): string {
  return addDays(date, 1 - weekdayOf(date));
}

// ------------------------------------------------------------ aralık işlemleri
type Interval = [number, number];

function subtract(free: Interval[], busy: Interval[]): Interval[] {
  let out = free;
  for (const [bs, be] of busy) {
    const next: Interval[] = [];
    for (const [fs, fe] of out) {
      if (be <= fs || bs >= fe) next.push([fs, fe]);
      else {
        if (bs > fs) next.push([fs, bs]);
        if (be < fe) next.push([be, fe]);
      }
    }
    out = next;
  }
  return out.filter(([s, e]) => e > s).sort((a, b) => a[0] - b[0]);
}

function mergeIntervals(list: Interval[]): Interval[] {
  const sorted = [...list].sort((a, b) => a[0] - b[0]);
  const out: Interval[] = [];
  for (const [s, e] of sorted) {
    const last = out[out.length - 1];
    if (last && s <= last[1]) last[1] = Math.max(last[1], e);
    else out.push([s, e]);
  }
  return out;
}

export function capacityFor(date: string, s: PlanSettings) {
  return weekdayOf(date) <= 5 ? s.weekdayCapacityMin : s.weekendCapacityMin;
}

/** Uzun talepleri en fazla maxTaskMin dakikalık parçalara böler; parçalar ardışık günlere yayılır. */
export function splitDemands(demands: Demand[], maxTaskMin: number): Demand[] {
  return demands.flatMap((d) => {
    if (d.minutes <= maxTaskMin) return [d];
    const parts = Math.ceil(d.minutes / maxTaskMin);
    const per = Math.ceil(d.minutes / parts);
    return Array.from({ length: parts }, (_, i) => ({
      ...d,
      earliestTime: i === 0 ? d.earliestTime : undefined,
      key: `${d.key}#${i + 1}`,
      title: `${d.title} (${i + 1}/${parts})`,
      minutes: per,
      earliest: addDays(d.earliest, i),
    }));
  });
}

export type PlanInput = {
  startDate: string;
  days: number;
  nowTime?: string | null; // başlangıç günü için; bu saatten önceye görev konmaz
  settings: PlanSettings;
  windows: Window[];
  meetings: Meeting[];
  fixed: FixedTask[];
  demands: Demand[];
  /** Kapasiteden düşülmeyen ama kullanılamayan zamanlar (iş taahhütleri, planlanmış iş görevleri). */
  busy?: Array<{ date: string; start: string; minutes: number }>;
};

export function plan(input: PlanInput): { placed: Placed[]; unplaced: Unplaced[] } {
  const s = input.settings;
  const dates = dateRange(input.startDate, input.days);
  const lastDate = dates[dates.length - 1];
  const demands = splitDemands(input.demands, s.maxTaskMin).sort(
    (a, b) =>
      b.priority - a.priority ||
      (a.deadline ?? "9999").localeCompare(b.deadline ?? "9999") ||
      a.earliest.localeCompare(b.earliest) ||
      a.key.localeCompare(b.key),
  );
  const placedKeys = new Set<string>();
  const placed: Placed[] = [];

  for (const date of dates) {
    const wd = weekdayOf(date);
    const fixedToday = input.fixed.filter((f) => f.date === date);
    let used = fixedToday.reduce((n, f) => n + f.minutes, 0);
    const cap = capacityFor(date, s);
    const catchCap = Math.floor((cap * s.catchUpShare) / 100);
    let catchUsed = fixedToday.filter((f) => f.catchUp).reduce((n, f) => n + f.minutes, 0);
    const perCourse = new Map<string, number>();
    const topicsToday = new Set<string>();
    for (const f of fixedToday) {
      if (f.courseId) perCourse.set(f.courseId, (perCourse.get(f.courseId) ?? 0) + f.minutes);
      if (f.topicId) topicsToday.add(f.topicId);
    }

    const windows = mergeIntervals(input.windows.filter((w) => w.weekday === wd).map((w) => [toMinutes(w.start), toMinutes(w.end)] as Interval));
    const busy: Interval[] = [
      ...input.meetings.filter((m) => m.weekday === wd).map((m) => [toMinutes(m.start), toMinutes(m.end) + s.breakMin] as Interval),
      ...fixedToday.map((f) => [toMinutes(f.start), toMinutes(f.start) + f.minutes + s.breakMin] as Interval),
      ...(input.busy ?? []).filter((b) => b.date === date).map((b) => [toMinutes(b.start), toMinutes(b.start) + b.minutes + s.breakMin] as Interval),
    ];
    if (date === input.startDate && input.nowTime) busy.push([0, toMinutes(input.nowTime)]);
    let free = subtract(windows, busy);

    for (const d of demands) {
      if (placedKeys.has(d.key)) continue;
      if (d.earliest > date) continue;
      if (d.deadline && d.deadline < date) continue;
      // Bir parçanın önceki parçası henüz yerleşmediyse bekle.
      const m = d.key.match(/^(.*)#(\d+)$/);
      if (m && Number(m[2]) > 1 && !placedKeys.has(`${m[1]}#${Number(m[2]) - 1}`)) continue;
      if (used + d.minutes > cap) continue;
      if (d.catchUp && catchUsed + d.minutes > catchCap) continue;
      if ((perCourse.get(d.courseId) ?? 0) + d.minutes > MAX_COURSE_MIN_PER_DAY) continue;
      if (d.topicId && topicsToday.has(d.topicId)) continue;
      const minStart = d.earliestTime && d.earliest === date ? toMinutes(d.earliestTime) : 0;
      const slot = free.find(([fs, fe]) => fe - Math.max(fs, minStart) >= d.minutes);
      if (!slot) continue;
      const start = Math.max(slot[0], minStart);
      placed.push({
        key: d.key, courseId: d.courseId, topicId: d.topicId, kind: d.kind, title: d.title, detail: d.detail,
        minutes: d.minutes, priority: d.priority, catchUp: d.catchUp, date, start: fromMinutes(start),
      });
      placedKeys.add(d.key);
      used += d.minutes;
      if (d.catchUp) catchUsed += d.minutes;
      perCourse.set(d.courseId, (perCourse.get(d.courseId) ?? 0) + d.minutes);
      if (d.topicId) topicsToday.add(d.topicId);
      free = subtract(free, [[start, start + d.minutes + s.breakMin]]);
    }
  }

  const unplaced: Unplaced[] = demands
    .filter((d) => !placedKeys.has(d.key))
    .map((d) => ({
      ...d,
      reason:
        d.deadline && d.deadline < input.startDate
          ? "Son tarihi geçmiş."
          : d.earliest > lastDate
            ? "14 günlük plan aralığının dışında."
            : "Günlük kapasite veya uygun zaman aralığı yetmedi.",
    }));
  placed.sort((a, b) => a.date.localeCompare(b.date) || a.start.localeCompare(b.start));
  return { placed, unplaced };
}
