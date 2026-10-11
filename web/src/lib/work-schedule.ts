/**
 * İş görevlerinin zamanlaması — saf ve deterministik.
 *
 * Kural: hafta içi 08.30–18.00 akademik zamandır; buraya OTOMATİK iş görevi asla konmaz.
 * Ders araları iş için müsaitlik sayılmaz. İş aralıkları varsayılan olarak hafta içi 18.30–23.00,
 * hafta sonu 10.00–20.00'dir (18.00 sonrası sınırsız kapasite varsayılmaz: günlük iş üst sınırı vardır).
 */
import { addDays, dateRange, weekdayOf } from "./planner";
import { fromMinutes, toMinutes } from "./schedule";

export type Block = { date: string; start: string; minutes: number; label: string; kind: "ders" | "calisma" | "is" | "taahhut" };

export const WORK_WINDOWS: Array<{ weekday: number; start: string; end: string }> = [
  ...[1, 2, 3, 4, 5].map((d) => ({ weekday: d, start: "18:30", end: "23:00" })),
  ...[6, 7].map((d) => ({ weekday: d, start: "10:00", end: "20:00" })),
];
export const MAX_WORK_MIN_PER_DAY = 240;

/** Bir zaman aralığının hafta içi akademik koruma aralığıyla kesişip kesişmediği. */
export function overlapsAcademic(date: string, start: string, minutes: number): boolean {
  const wd = weekdayOf(date);
  if (wd > 5) return false;
  const s = toMinutes(start);
  return s < toMinutes("18:00") && s + minutes > toMinutes("08:30");
}

const overlap = (a: [number, number], b: [number, number]) => a[0] < b[1] && b[0] < a[1];

export type SlotResult =
  | { ok: true; date: string; start: string; affected: Block[] }
  | { ok: false; reason: string };

/**
 * Teslim tarihinden önceki en erken uygun iş zamanını bulur.
 * Önce hiçbir çalışma görevine dokunmayan yer aranır; bulunamazsa yalnızca ders ÇALIŞMA görevleriyle
 * çakışan (ders saati, sabit taahhüt ve diğer işlerle asla çakışmayan) en erken yer önerilir ve
 * etkilenecek çalışmalar listelenir.
 */
export function findWorkSlot(i: {
  fromDate: string; fromTime: string | null; dueDate: string | null; minutes: number; blocks: Block[]; horizonDays?: number;
}): SlotResult {
  if (i.minutes > MAX_WORK_MIN_PER_DAY) return { ok: false, reason: `Tek bir iş görevi günde en fazla ${MAX_WORK_MIN_PER_DAY} dakika olabilir; görevi bölün.` };
  const last = i.dueDate ?? addDays(i.fromDate, (i.horizonDays ?? 14) - 1);
  if (last < i.fromDate) return { ok: false, reason: "Teslim tarihi geçmiş." };
  const days = dateRange(i.fromDate, Math.min(60, Math.round((Date.parse(last) - Date.parse(i.fromDate)) / 86400000) + 1));
  for (const pass of ["temiz", "calisma_etkilenir"] as const) {
    for (const date of days) {
      const dayBlocks = i.blocks.filter((b) => b.date === date);
      const workToday = dayBlocks.filter((b) => b.kind === "is").reduce((n, b) => n + b.minutes, 0);
      if (workToday + i.minutes > MAX_WORK_MIN_PER_DAY) continue;
      for (const w of WORK_WINDOWS.filter((w) => w.weekday === weekdayOf(date))) {
        let s = toMinutes(w.start);
        if (date === i.fromDate && i.fromTime) s = Math.max(s, Math.ceil(toMinutes(i.fromTime) / 15) * 15);
        for (; s + i.minutes <= toMinutes(w.end); s += 15) {
          const span: [number, number] = [s, s + i.minutes];
          const hits = dayBlocks.filter((b) => overlap(span, [toMinutes(b.start), toMinutes(b.start) + b.minutes]));
          const hard = hits.filter((b) => b.kind !== "calisma");
          if (hard.length) continue;
          if (pass === "temiz" && hits.length) continue;
          const start = fromMinutes(s);
          if (overlapsAcademic(date, start, i.minutes)) continue; // savunma amaçlı ikinci kontrol
          return { ok: true, date, start, affected: hits };
        }
      }
    }
  }
  return { ok: false, reason: "Teslim tarihine kadar akademik zamanı ihlal etmeden uygun iş zamanı bulunamadı." };
}
