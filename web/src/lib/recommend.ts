/**
 * "Şimdi Ders Çalış" önerisi — deterministik, açıklanabilir kurallar.
 * Her öneri, neden seçildiğini Türkçe olarak açıklar.
 */
import type { TopicStatus } from "./data/courses";
import type { StudyMode } from "./data/study";

export type RecInput = {
  now: Date;
  courses: Array<{ id: string; code: string; name: string }>;
  topics: Array<{ id: string; course_id: string; title: string; week: number | null; status: TopicStatus; sourceCount: number }>;
  dueCardsByCourse: Record<string, number>;
  openMistakesByCourse: Record<string, number>;
  assessments: Array<{ course_id: string; title: string; due_at: Date | null }>;
  activeSession: { id: string; course_id: string; last_activity_at: Date } | null;
};

export type Recommendation =
  | { action: "devam"; sessionId: string; courseId: string; reason: string }
  | { action: "calis"; courseId: string; topicId: string | null; mode: StudyMode; reason: string }
  | { action: "materyal_yukle"; courseId: string; topicId: string; reason: string }
  | { action: "konu_ekle"; courseId: string | null; reason: string };

const DAY = 86400_000;

export function recommend(i: RecInput): Recommendation {
  const code = (id: string) => i.courses.find((c) => c.id === id)?.code ?? "";
  if (i.activeSession && i.now.getTime() - i.activeSession.last_activity_at.getTime() < 2 * DAY) {
    return {
      action: "devam",
      sessionId: i.activeSession.id,
      courseId: i.activeSession.course_id,
      reason: `${code(i.activeSession.course_id)} dersinde yarım kalan çalışma oturumun var; kaldığın yerden devam et.`,
    };
  }
  const soon = i.assessments
    .filter((a) => a.due_at && a.due_at.getTime() >= i.now.getTime() && a.due_at.getTime() - i.now.getTime() <= 7 * DAY)
    .sort((a, b) => a.due_at!.getTime() - b.due_at!.getTime())[0];
  const dueEntries = Object.entries(i.dueCardsByCourse).filter(([, n]) => n > 0).sort((a, b) => b[1] - a[1]);
  if (dueEntries.length && !soon) {
    const [courseId, n] = dueEntries[0];
    return { action: "calis", courseId, topicId: null, mode: "hizli_tekrar", reason: `${code(courseId)} dersinde tekrar zamanı gelmiş ${n} soru var. Aralıklı tekrar, unutmadan önce hatırlamayı güçlendirir.` };
  }
  if (soon) {
    const days = Math.ceil((soon.due_at!.getTime() - i.now.getTime()) / DAY);
    const weak = i.topics.find((t) => t.course_id === soon.course_id && t.status === "tekrar_gerekiyor");
    return {
      action: "calis",
      courseId: soon.course_id,
      topicId: weak?.id ?? null,
      mode: "sinav_hazirligi",
      reason: `${code(soon.course_id)} — "${soon.title}" ${days} gün içinde.${weak ? ` Önce zayıf konu: ${weak.title}.` : ""}`,
    };
  }
  const weak = i.topics.filter((t) => t.status === "tekrar_gerekiyor").sort((a, b) => (i.openMistakesByCourse[b.course_id] ?? 0) - (i.openMistakesByCourse[a.course_id] ?? 0))[0];
  if (weak) {
    return { action: "calis", courseId: weak.course_id, topicId: weak.id, mode: "eksik_tamamlama", reason: `"${weak.title}" konusunda yanlışların var; bu konu tekrar gerektiriyor.` };
  }
  const byWeek = (a: { week: number | null }, b: { week: number | null }) => (a.week ?? 99) - (b.week ?? 99);
  const unread = i.topics.filter((t) => t.status === "materyal_alindi" && t.sourceCount > 0).sort(byWeek)[0];
  if (unread) {
    return { action: "calis", courseId: unread.course_id, topicId: unread.id, mode: "konu_anlatimi", reason: `"${unread.title}" için materyal yüklendi ama henüz çalışılmadı.` };
  }
  const inProgress = i.topics.filter((t) => ["okundu", "not_cikarildi"].includes(t.status)).sort(byWeek)[0];
  if (inProgress) {
    return { action: "calis", courseId: inProgress.course_id, topicId: inProgress.id, mode: "aktif_hatirlama", reason: `"${inProgress.title}" okundu; şimdi notlara bakmadan hatırlamayı dene.` };
  }
  const missing = i.topics.filter((t) => t.status === "materyal_eksik").sort(byWeek)[0];
  if (missing) {
    return { action: "materyal_yukle", courseId: missing.course_id, topicId: missing.id, reason: `"${missing.title}" konusunun materyali eksik. Çalışmaya başlamak için önce materyali yükle.` };
  }
  return {
    action: "konu_ekle",
    courseId: null,
    reason: "Henüz çalışılacak konu tanımlanmamış. Bir dersi seçip izlencedeki hafta/konuları ekleyerek başla.",
  };
}
