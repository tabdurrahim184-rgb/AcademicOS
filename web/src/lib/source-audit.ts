/**
 * Kaynak denetimi — saf fonksiyonlar. Uyarılar kesin hüküm değildir; kullanıcıya
 * kontrol etmesi gereken noktaları gösterir.
 */
import { normalizeTr } from "./grading";

const STOP = new Set(["ve", "ile", "bir", "için", "olarak", "gibi", "kuramı", "kavramı", "giriş", "hafta", "konu", "ders", "bölüm", "temel", "nedir"]);

/** Konu başlığındaki anlamlı kelimeler (Türkçe normalleştirilmiş, ilk 6 harfle kök yaklaşımı). */
export function keyStems(title: string): string[] {
  return [...new Set(normalizeTr(title).split(" ").filter((w) => w.length >= 4 && !STOP.has(w)).map((w) => w.slice(0, 6)))];
}

/** Konu başlığının kaynak metninde geçme oranı (0–1); anlamlı kelime yoksa null. */
export function topicCoverage(title: string, text: string): number | null {
  const stems = keyStems(title);
  if (!stems.length) return null;
  const hay = normalizeTr(text);
  return stems.filter((s) => hay.includes(s)).length / stems.length;
}

export type AuditSource = {
  id: string; title: string; course_id: string; topic_id: string | null; sha256: string;
  extraction_status: string; text: string; topicTitle: string | null;
};
export type AuditIssue = { sourceId: string; level: "uyari" | "bilgi"; message: string };

export function auditSources(sources: AuditSource[], allUserSources: Array<{ id: string; sha256: string; title: string; course_label: string }>): AuditIssue[] {
  const issues: AuditIssue[] = [];
  for (const s of sources) {
    const dups = allUserSources.filter((o) => o.sha256 === s.sha256 && o.id !== s.id);
    if (dups.length) {
      issues.push({ sourceId: s.id, level: "uyari", message: `Aynı dosya başka bir kayıt olarak da yüklenmiş: ${dups.map((d) => `${d.course_label} — ${d.title}`).join("; ")}.` });
    }
    if (s.extraction_status !== "tamam") {
      issues.push({ sourceId: s.id, level: "uyari", message: "Metni okunamadı; aranamaz ve yapay zekâya kaynak olarak verilemez. Metin içeren bir sürümünü yüklemeyi dene." });
    }
    if (!s.topic_id) {
      issues.push({ sourceId: s.id, level: "bilgi", message: "Bir konuya bağlı değil; konu çalışmasında ve planda kullanılmaz." });
    } else if (s.extraction_status === "tamam" && s.topicTitle) {
      const cov = topicCoverage(s.topicTitle, s.text);
      if (cov !== null && cov === 0) {
        issues.push({ sourceId: s.id, level: "uyari", message: `Konu başlığındaki kelimeler ("${s.topicTitle}") kaynak metninde hiç geçmiyor. Kaynağın doğru konuya bağlandığını kontrol et.` });
      }
    }
  }
  return issues;
}
