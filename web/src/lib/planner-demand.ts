/**
 * Planlayıcı talepleri: gerçek akademik durumdan (konu durumları, tekrar kartları,
 * yanlışlar, ders saatleri, tarihli sınavlar) hangi çalışmaların gerektiğini çıkarır.
 * Saf fonksiyon; tarihi bilinmeyen sınavlar için hazırlık tarihi uydurulmaz.
 */
import type { TopicStatus } from "./data/courses";
import { addDays, dateRange, weekdayOf, weekStart, type Demand } from "./planner";

export type DemandInput = {
  today: string;
  days: number;
  courses: Array<{ id: string; code: string }>;
  topics: Array<{ id: string; course_id: string; title: string; week: number | null; status: TopicStatus; is_catch_up: boolean; openMistakes: number }>;
  meetings: Array<{ course_id: string; weekday: number; end_time: string }>;
  dueByCourseDate: Array<{ course_id: string; date: string; count: number }>; // tarihi geçmiş kartlar bugüne yazılır
  assessments: Array<{ id: string; course_id: string; title: string; due_date: string | null }>;
  completedKeys: Set<string>;
};

const EXAM_LOOKAHEAD_DAYS = 21;

export function buildDemands(i: DemandInput): Demand[] {
  const code = (id: string) => i.courses.find((c) => c.id === id)?.code ?? "";
  const last = addDays(i.today, i.days - 1);
  const out: Demand[] = [];
  const push = (d: Demand) => {
    if (!i.completedKeys.has(d.key)) out.push(d);
  };

  // 1) Konu bazlı telafi / güncel çalışma
  for (const t of i.topics) {
    const base = { courseId: t.course_id, topicId: t.id, earliest: i.today, deadline: null, catchUp: t.is_catch_up };
    const label = `${code(t.course_id)} — ${t.week ? `${t.week}. hafta: ` : ""}${t.title}`;
    const boost = t.is_catch_up ? 10 : 0;
    switch (t.status) {
      case "materyal_eksik":
        push({ ...base, key: `materyal:${t.id}`, kind: "materyal", minutes: 15, priority: 60 + boost,
          title: `Materyali temin et: ${label}`, detail: "Ders notunu/slaytı DEBİM/UZEM'den veya arkadaşından al ve sisteme yükle." });
        break;
      case "materyal_alindi":
        push({ ...base, key: `calis:${t.id}`, kind: t.is_catch_up ? "telafi" : "guncel", minutes: 50, priority: 55 + boost,
          title: `Konuyu çalış: ${label}`, detail: "Kaynağı oku, ana kavramları kendi cümlelerinle not et." });
        break;
      case "okundu":
      case "not_cikarildi":
        push({ ...base, key: `hatirla:${t.id}`, kind: t.is_catch_up ? "telafi" : "guncel", minutes: 30, priority: 50 + boost,
          title: `Aktif hatırlama ve soru: ${label}`, detail: "Notlara bakmadan anlat, ardından konu sorularını çöz." });
        break;
      case "tekrar_gerekiyor":
        push({ ...base, key: `eksik:${t.id}:${weekStart(i.today)}`, kind: "eksik", minutes: 30, priority: 80 + boost,
          title: `Eksikleri tamamla: ${label}`,
          detail: t.openMistakes ? `${t.openMistakes} açık yanlış var; önce yanlışlar defterindeki açıklamaları oku, sonra soruları yeniden çöz.` : "Konuyu yeniden çalış ve soruları tekrar çöz." });
        break;
      default:
        break;
    }
  }

  // 2) Aralıklı tekrar (kartların vade tarihine göre)
  for (const r of i.dueByCourseDate) {
    const date = r.date < i.today ? i.today : r.date;
    if (date > last || r.count <= 0) continue;
    push({
      key: `tekrar:${r.course_id}:${date}`, courseId: r.course_id, topicId: null, kind: "tekrar",
      minutes: Math.min(30, Math.max(10, Math.ceil(r.count * 2.5 / 5) * 5)), priority: 85,
      title: `Aralıklı tekrar: ${code(r.course_id)} (${r.count} soru)`, detail: "Tekrar ekranındaki zamanı gelen soruları cevapla.",
      earliest: date, deadline: addDays(date, 1), catchUp: false,
    });
  }

  // 3) Güncel dersleri ihmal etmeme: her ders oturumundan sonra 2 gün içinde gözden geçirme
  //    (son 2 günün dersleri de dahil; gözden geçirilmediyse hâlâ süresi içindedir)
  for (const date of dateRange(addDays(i.today, -2), i.days + 2)) {
    const wd = weekdayOf(date);
    const lastEnd = new Map<string, string>();
    for (const m of i.meetings.filter((x) => x.weekday === wd)) {
      const prev = lastEnd.get(m.course_id);
      if (!prev || m.end_time > prev) lastEnd.set(m.course_id, m.end_time.slice(0, 5));
    }
    for (const [courseId, endTime] of [...lastEnd.entries()].sort()) {
      const m = { course_id: courseId };
      push({
        key: `guncel:${m.course_id}:${date}`, courseId: m.course_id, topicId: null, kind: "guncel", minutes: 25, priority: 92,
        title: `Bugünkü dersi gözden geçir: ${code(m.course_id)}`,
        detail: "Ders notlarını temize çek, işlenen konuyu sisteme konu olarak ekle ve materyalini yükle.",
        earliest: date < i.today ? i.today : date, earliestTime: date < i.today ? undefined : endTime,
        deadline: addDays(date, 2), catchUp: false,
      });
    }
  }

  // 4) Tarihli sınav/ödev hazırlığı (tarih yoksa planlanmaz)
  for (const a of i.assessments) {
    if (!a.due_date || a.due_date < i.today || a.due_date > addDays(i.today, EXAM_LOOKAHEAD_DAYS)) continue;
    const prepEnd = addDays(a.due_date, -1);
    if (prepEnd < i.today) continue;
    const sessions = 3;
    for (let n = 1; n <= sessions; n++) {
      // Hazırlık oturumlarını sınavdan geriye doğru yay (en geç n. oturum, sınavdan (sessions-n+1)*2 gün önce başlayabilir)
      const earliest = maxDate(i.today, addDays(a.due_date, -(sessions - n + 1) * 3));
      push({
        key: `sinav:${a.id}:${n}`, courseId: a.course_id, topicId: null, kind: "sinav", minutes: 45, priority: 95,
        title: `Sınav hazırlığı ${n}/${sessions}: ${code(a.course_id)} — ${a.title}`,
        detail: "Zayıf konular ve yanlışlar defterinden başla; deneme soruları çöz.",
        earliest, deadline: prepEnd, catchUp: false,
      });
    }
  }
  return out;
}

const maxDate = (a: string, b: string) => (a > b ? a : b);
