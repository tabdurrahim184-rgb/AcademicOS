import { describe, expect, it } from "vitest";
import { buildIcs, escapeText, fold } from "@/lib/ics";

describe("iCalendar üretimi", () => {
  const ics = buildIcs(
    [
      { uid: "ders-1@a", title: "İLF431 Siyasal İletişim", description: "Ayça Demet Atay", date: "2026-10-13", start: "13:30", end: "15:30", weeklyUntil: null },
      { uid: "ders-2@a", title: "İLF413 İletişim Etiği", date: "2026-10-13", start: "15:30", end: "17:30", weeklyUntil: "2027-01-15" },
      { uid: "sinav@a", title: "Vize; bölüm 1, 2", date: "2026-10-20", start: "09:00", end: null },
    ],
    new Date("2026-10-10T12:00:00Z"),
  );
  const unfolded = ics.replace(/\r\n /g, "");

  it("CRLF satır sonları ve zorunlu alanlar", () => {
    expect(ics.split("\r\n")[0]).toBe("BEGIN:VCALENDAR");
    expect(ics.endsWith("END:VCALENDAR\r\n")).toBe(true);
    expect(unfolded).toContain("DTSTAMP:20261010T120000Z");
    expect(unfolded.match(/BEGIN:VEVENT/g)).toHaveLength(3);
  });
  it("Kıbrıs saat dilimini ve yerel saatleri yazar", () => {
    expect(unfolded).toContain("TZID:Europe/Nicosia");
    expect(unfolded).toContain("DTSTART;TZID=Europe/Nicosia:20261013T133000");
    expect(unfolded).toContain("DTEND;TZID=Europe/Nicosia:20261013T153000");
  });
  it("dönem sonu bilinmiyorsa tekrar sonu uydurmaz", () => {
    expect(unfolded).toContain("RRULE:FREQ=WEEKLY\r\n");
    expect(unfolded).toContain("RRULE:FREQ=WEEKLY;UNTIL=20270115T215900Z");
  });
  it("özel karakterleri kaçışlar ve Türkçe karakterleri korur", () => {
    expect(escapeText("a;b,c\nd")).toBe("a\;b\\,c\\nd");
    expect(unfolded).toContain("SUMMARY:Vize\; bölüm 1\\, 2");
    expect(unfolded).toContain("SUMMARY:İLF413 İletişim Etiği");
  });
  it("75 oktet sınırında katlar ve çok baytlı karakteri bölmez", () => {
    const line = "SUMMARY:" + "ğ".repeat(80);
    const folded = fold(line);
    for (const part of folded.split("\r\n")) expect(Buffer.byteLength(part, "utf8")).toBeLessThanOrEqual(75);
    expect(folded.replace(/\r\n /g, "")).toBe(line);
  });
});
