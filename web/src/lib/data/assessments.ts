import type { Tx } from "../db";
import { getCourse, markPlanStale } from "./courses";

export const ASSESSMENT_KINDS = {
  vize: "Vize", final: "Final", odev: "Ödev", proje: "Proje", sunum: "Sunum", quiz: "Kısa sınav", diger: "Diğer",
} as const;
export type AssessmentKind = keyof typeof ASSESSMENT_KINDS;

export type Assessment = {
  id: string;
  course_id: string;
  kind: AssessmentKind;
  title: string;
  due_at: Date | null;
  weight: string | null;
  score: string | null;
  notes: string;
};

export async function listAssessments(tx: Tx, courseId?: string): Promise<Assessment[]> {
  const { rows } = await tx.query<Assessment>(
    `SELECT id, course_id, kind, title, due_at, weight, score, notes FROM assessments
     ${courseId ? "WHERE course_id=$1" : ""} ORDER BY due_at NULLS LAST, created_at`,
    courseId ? [courseId] : [],
  );
  return rows;
}

export async function createAssessment(
  tx: Tx,
  userId: string,
  a: { courseId: string; kind: AssessmentKind; title: string; dueAt: Date | null; weight: number | null },
) {
  if (!(a.kind in ASSESSMENT_KINDS)) throw new Error("Geçersiz değerlendirme türü.");
  if (!(await getCourse(tx, a.courseId))) throw new Error("Ders bulunamadı.");
  await tx.query(
    "INSERT INTO assessments (user_id, course_id, kind, title, due_at, weight) VALUES ($1,$2,$3,$4,$5,$6)",
    [userId, a.courseId, a.kind, a.title.trim() || ASSESSMENT_KINDS[a.kind], a.dueAt, a.weight],
  );
  await markPlanStale(tx);
}

export async function updateAssessmentScore(tx: Tx, id: string, score: number | null) {
  await tx.query("UPDATE assessments SET score=$2 WHERE id=$1", [id, score]);
  await markPlanStale(tx);
}

export async function deleteAssessment(tx: Tx, id: string) {
  await tx.query("DELETE FROM assessments WHERE id=$1", [id]);
  await markPlanStale(tx);
}

/**
 * Ağırlıklar ve girilen notlar biliniyorsa, hedef ortalama için kalan
 * değerlendirmelerden gereken ortalama notu hesaplar. Varsayımlar döndürülür.
 */
export function requiredRemainingAverage(items: Array<{ weight: number | null; score: number | null }>, target: number) {
  if (items.some((i) => i.weight == null)) return { ok: false as const, reason: "Bütün değerlendirmelerin ağırlığı girilmeden hesaplama yapılamaz." };
  const totalW = items.reduce((s, i) => s + (i.weight ?? 0), 0);
  if (Math.abs(totalW - 100) > 0.01) return { ok: false as const, reason: `Ağırlıkların toplamı %100 olmalı (şu an %${totalW}).` };
  const earned = items.filter((i) => i.score != null).reduce((s, i) => s + (i.weight! * i.score!) / 100, 0);
  const remainingW = items.filter((i) => i.score == null).reduce((s, i) => s + i.weight!, 0);
  if (remainingW === 0) return { ok: true as const, required: null, current: earned, assumptions: "Bütün notlar girilmiş." };
  const required = ((target - earned) / remainingW) * 100;
  return {
    ok: true as const,
    required: Math.round(required * 10) / 10,
    current: Math.round(earned * 10) / 10,
    assumptions: `Hedef dönem notu ${target}; kalan %${remainingW} ağırlıktaki değerlendirmelerden aynı ortalama alınacağı varsayıldı. Geçme koşullarını (ör. final alt sınırı) ders izlencesinden doğrulayın.`,
  };
}
