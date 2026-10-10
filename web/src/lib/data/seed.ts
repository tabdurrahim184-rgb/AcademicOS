import type { Tx } from "../db";

type SeedCourse = {
  code: string;
  name: string;
  instructor: string | null;
  delivery: "yuz_yuze" | "cevrimici";
  meetings: Array<[weekday: number, start: string, end: string]>;
};

/**
 * Başlangıç dersleri (kullanıcı tarafından verilen bilgiler).
 * Bilinmeyen öğretim elemanı NULL bırakılır; saatler uydurulmaz.
 * Gün numarası: 1 = Pazartesi ... 5 = Cuma.
 */
export const INITIAL_COURSES: SeedCourse[] = [
  { code: "SEC351", name: "21. Yüzyıl Becerileri", instructor: null, delivery: "cevrimici", meetings: [] },
  { code: "İLF413", name: "İletişim Etiği", instructor: "Ayhan Dolunay", delivery: "yuz_yuze",
    meetings: [[2, "15:30", "17:30"], [5, "15:30", "16:30"]] },
  { code: "İLF431", name: "Siyasal İletişim", instructor: "Ayça Demet Atay", delivery: "yuz_yuze",
    meetings: [[2, "13:30", "15:30"], [4, "08:30", "09:30"]] },
  { code: "İLF433 / SEC300", name: "Hak Odaklı Habercilik", instructor: "İbrahim Özejder", delivery: "yuz_yuze",
    meetings: [[3, "12:30", "14:30"], [5, "16:30", "17:30"]] },
  { code: "GZT440", name: "Bölüm Projesi", instructor: "İbrahim Özejder", delivery: "yuz_yuze",
    meetings: [[4, "09:30", "12:30"]] },
  { code: "İNG102", name: "İngilizce 2", instructor: null, delivery: "cevrimici", meetings: [] },
  { code: "İLF325", name: "Kıbrıs Haberciliği ve Pratikleri", instructor: "Hüseyin Turan", delivery: "yuz_yuze",
    meetings: [[5, "08:30", "11:30"]] },
  { code: "İLF361", name: "Etkili İletişim Teknikleri", instructor: "Ayhan Dolunay", delivery: "yuz_yuze",
    meetings: [[2, "10:30", "12:30"], [5, "16:30", "17:30"]] },
  { code: "İLF267", name: "İletişim Alanında Girişimcilik", instructor: "Hüseyin Turan", delivery: "yuz_yuze",
    meetings: [[1, "08:30", "10:30"], [5, "15:30", "16:30"]] },
];

/** Kullanıcının hiç dersi yoksa dokuz başlangıç dersini ekler (tekrar çağrılması güvenlidir). */
export async function seedInitialCourses(tx: Tx, userId: string): Promise<number> {
  const { rows } = await tx.query<{ n: string }>("SELECT count(*) AS n FROM courses");
  if (Number(rows[0].n) > 0) return 0;
  for (const c of INITIAL_COURSES) {
    const { rows: ins } = await tx.query<{ id: string }>(
      "INSERT INTO courses (user_id, code, name, instructor, delivery, created_at) VALUES ($1,$2,$3,$4,$5, clock_timestamp()) RETURNING id",
      [userId, c.code, c.name, c.instructor, c.delivery],
    );
    for (const [weekday, start, end] of c.meetings) {
      await tx.query(
        "INSERT INTO course_meetings (user_id, course_id, weekday, start_time, end_time) VALUES ($1,$2,$3,$4,$5)",
        [userId, ins[0].id, weekday, start, end],
      );
    }
  }
  return INITIAL_COURSES.length;
}
