const TZ = "Europe/Nicosia";

export function fmtDateTime(d: Date | string | null | undefined): string {
  if (!d) return "Tarih bekleniyor";
  return new Intl.DateTimeFormat("tr-TR", { timeZone: TZ, dateStyle: "medium", timeStyle: "short" }).format(new Date(d));
}
export function fmtDate(d: Date | string | null | undefined): string {
  if (!d) return "Tarih bekleniyor";
  return new Intl.DateTimeFormat("tr-TR", { timeZone: TZ, dateStyle: "long" }).format(new Date(d));
}
export function fmtBytes(n: number): string {
  if (n < 1024) return `${n} B`;
  if (n < 1024 * 1024) return `${(n / 1024).toFixed(1).replace(".", ",")} KB`;
  return `${(n / 1024 / 1024).toFixed(1).replace(".", ",")} MB`;
}
export function relativeDays(d: Date, now = new Date()): string {
  const days = Math.round((new Date(d).getTime() - now.getTime()) / 86400_000);
  if (days === 0) return "bugün";
  if (days === 1) return "yarın";
  if (days === -1) return "dün";
  return days > 0 ? `${days} gün sonra` : `${-days} gün önce`;
}
