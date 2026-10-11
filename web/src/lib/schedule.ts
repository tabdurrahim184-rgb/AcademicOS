export const WEEKDAYS = ["", "Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi", "Pazar"] as const;

export type Meeting = { id?: string; courseId: string; courseLabel: string; weekday: number; start: string; end: string };
export type Conflict = { weekday: number; a: Meeting; b: Meeting; overlapStart: string; overlapEnd: string };

export const toMinutes = (t: string) => {
  const [h, m] = t.slice(0, 5).split(":").map(Number);
  return h * 60 + m;
};
export const fromMinutes = (n: number) => `${String(Math.floor(n / 60)).padStart(2, "0")}:${String(n % 60).padStart(2, "0")}`;
/** "15:30" → "15.30" (Türkçe saat yazımı) */
export const trTime = (t: string) => t.slice(0, 5).replace(":", ".");

/**
 * Aynı gün içinde zaman aralığı kesişen farklı derslerin oturumlarını bulur.
 * Bitişik aralıklar (biri 16.30'da biterken diğeri 16.30'da başlıyorsa) çakışma sayılmaz.
 */
export function findConflicts(meetings: Meeting[]): Conflict[] {
  const out: Conflict[] = [];
  const sorted = [...meetings].sort((x, y) => x.weekday - y.weekday || toMinutes(x.start) - toMinutes(y.start));
  for (let i = 0; i < sorted.length; i++) {
    for (let j = i + 1; j < sorted.length; j++) {
      const a = sorted[i], b = sorted[j];
      if (a.weekday !== b.weekday) break;
      if (a.courseId === b.courseId) continue;
      const s = Math.max(toMinutes(a.start), toMinutes(b.start));
      const e = Math.min(toMinutes(a.end), toMinutes(b.end));
      if (s < e) out.push({ weekday: a.weekday, a, b, overlapStart: fromMinutes(s), overlapEnd: fromMinutes(e) });
    }
  }
  return out;
}

/** Europe/Nicosia saat diliminde bir tarihin hafta günü (1=Pzt..7=Paz) ve "SS:DD" saati. */
export function localParts(date: Date, timeZone = "Europe/Nicosia") {
  const fmt = new Intl.DateTimeFormat("en-GB", { timeZone, weekday: "short", hour: "2-digit", minute: "2-digit", hour12: false, year: "numeric", month: "2-digit", day: "2-digit" });
  const parts = Object.fromEntries(fmt.formatToParts(date).map((p) => [p.type, p.value]));
  const wd = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"].indexOf(parts.weekday) + 1;
  const hour = parts.hour === "24" ? "00" : parts.hour;
  return { weekday: wd, time: `${hour}:${parts.minute}`, date: `${parts.year}-${parts.month}-${parts.day}` };
}

/** Hafta içi 08.30–18.00 akademik koruma aralığında mı? */
export function isProtectedAcademicTime(weekday: number, time: string): boolean {
  if (weekday < 1 || weekday > 5) return false;
  const m = toMinutes(time);
  return m >= toMinutes("08:30") && m < toMinutes("18:00");
}
