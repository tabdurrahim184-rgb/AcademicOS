/**
 * iCalendar (RFC 5545) üretimi. Ders saatleri Europe/Nicosia saat diliminde
 * haftalık tekrar eden olaylar olarak yazılır; dönem sonu bilinmiyorsa tekrar
 * sonu uydurulmaz (UNTIL yazılmaz).
 */
export type IcsEvent = {
  uid: string;
  title: string;
  description?: string;
  date: string; // YYYY-MM-DD (yerel)
  start: string | null; // HH:MM yerel; null = tüm gün
  end: string | null;
  weeklyUntil?: string | null; // haftalık tekrar; null = sonsuz, undefined = tekrar yok
};

const TZ = "Europe/Nicosia";

// Kıbrıs (Lefkoşa) saat dilimi: AB kuralları — Mart son pazar 03:00 → UTC+3, Ekim son pazar 04:00 → UTC+2
const VTIMEZONE = [
  "BEGIN:VTIMEZONE", `TZID:${TZ}`,
  "BEGIN:DAYLIGHT", "TZOFFSETFROM:+0200", "TZOFFSETTO:+0300", "TZNAME:EEST", "DTSTART:19700329T030000", "RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=-1SU", "END:DAYLIGHT",
  "BEGIN:STANDARD", "TZOFFSETFROM:+0300", "TZOFFSETTO:+0200", "TZNAME:EET", "DTSTART:19701025T040000", "RRULE:FREQ=YEARLY;BYMONTH=10;BYDAY=-1SU", "END:STANDARD",
  "END:VTIMEZONE",
];

export function escapeText(s: string) {
  return s.replace(/\\/g, "\\\\").replace(/;/g, "\;").replace(/,/g, "\\,").replace(/\r?\n/g, "\\n");
}

/** 75 oktet sınırında satır katlama (UTF-8 çok baytlı karakterleri bölmeden). */
export function fold(line: string): string {
  const out: string[] = [];
  let cur = "";
  let bytes = 0;
  for (const ch of line) {
    const b = Buffer.byteLength(ch, "utf8");
    if (bytes + b > (out.length ? 74 : 75)) {
      out.push(cur);
      cur = "";
      bytes = 0;
    }
    cur += ch;
    bytes += b;
  }
  out.push(cur);
  return out.join("\r\n ");
}

const compactDate = (d: string) => d.replace(/-/g, "");
const compactTime = (t: string) => t.replace(":", "") + "00";

export function buildIcs(events: IcsEvent[], stamp: Date, calName = "TÜRKMENOĞLU Akademik"): string {
  const dtstamp = stamp.toISOString().replace(/[-:]/g, "").replace(/\.\d{3}/, "");
  const lines = ["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//TURKMENOGLU//AcademicOS//TR", "CALSCALE:GREGORIAN", `X-WR-CALNAME:${escapeText(calName)}`, `X-WR-TIMEZONE:${TZ}`, ...VTIMEZONE];
  for (const e of events) {
    lines.push("BEGIN:VEVENT", `UID:${e.uid}`, `DTSTAMP:${dtstamp}`, `SUMMARY:${escapeText(e.title)}`);
    if (e.description) lines.push(`DESCRIPTION:${escapeText(e.description)}`);
    if (e.start) {
      lines.push(`DTSTART;TZID=${TZ}:${compactDate(e.date)}T${compactTime(e.start)}`);
      if (e.end) lines.push(`DTEND;TZID=${TZ}:${compactDate(e.date)}T${compactTime(e.end)}`);
    } else {
      lines.push(`DTSTART;VALUE=DATE:${compactDate(e.date)}`);
    }
    if (e.weeklyUntil !== undefined) {
      // UNTIL, DTSTART yerel saatli olduğunda UTC olarak verilmelidir; gün sonunu kapsayacak şekilde 21:59Z (Kıbrıs 23:59/00:59)
      lines.push(e.weeklyUntil ? `RRULE:FREQ=WEEKLY;UNTIL=${compactDate(e.weeklyUntil)}T215900Z` : "RRULE:FREQ=WEEKLY");
    }
    lines.push("END:VEVENT");
  }
  lines.push("END:VCALENDAR");
  return lines.map(fold).join("\r\n") + "\r\n";
}
