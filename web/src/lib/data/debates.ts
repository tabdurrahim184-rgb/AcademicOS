/**
 * Akademik Tartışmalar: üniversite derslerinde tartışılan konuları İslam düşüncesinin
 * bilim, akıl, insan, ahlak, adalet, devlet, toplum, sanat ve kâinat anlayışıyla ilişkilendiren
 * hazırlık alanı. Fetva veya genel dinî soru-cevap alanı değildir.
 *
 * Kaynak dürüstlüğü: ayet, hadis ve eser referanslarını öğrenci kendisi girer; sistem
 * referans üretmez. Her kaynak öğrenci asıl metinden kontrol edene kadar "doğrulanmadı" görünür.
 */
import type { Tx } from "../db";
import { getCourse, isUuid } from "./courses";

export const DEBATE_THEMES = {
  bilim: "Bilim", akil: "Akıl ve bilgi", insan: "İnsan", ahlak: "Ahlak", adalet: "Adalet", devlet: "Devlet ve siyaset",
  toplum: "Toplum", sanat: "Sanat", kainat: "Kâinat", diger: "Diğer",
} as const;
export type DebateTheme = keyof typeof DEBATE_THEMES;

export const DEBATE_SOURCE_KINDS = {
  kuran: "Kur'an-ı Kerîm",
  hadis: "Hadis (kaynak eser ve numarasıyla)",
  klasik_eser: "Klasik eser (ör. Aziz Mahmud Hüdâyî, Akşemseddin)",
  cagdas_eser: "Çağdaş eser",
  akademik: "Akademik çalışma",
  diger: "Diğer",
} as const;

export type Debate = {
  id: string; course_id: string | null; theme: DebateTheme; title: string; claim: string; academic_context: string;
  counter_arguments: string; islamic_perspective: string; class_answer: string; weaknesses: string; uncertainties: string;
  created_at: Date; updated_at: Date;
};
export type DebateSource = { id: string; debate_id: string; kind: keyof typeof DEBATE_SOURCE_KINDS; reference: string; quote: string; note: string; verified: boolean };

const COLS = "id, course_id, theme, title, claim, academic_context, counter_arguments, islamic_perspective, class_answer, weaknesses, uncertainties, created_at, updated_at";

export async function listDebates(tx: Tx): Promise<Array<Debate & { sources: number; unverified: number }>> {
  const { rows } = await tx.query(
    `SELECT ${COLS.split(", ").map((c) => `d.${c}`).join(", ")},
       (SELECT count(*)::int FROM debate_sources s WHERE s.debate_id=d.id) AS sources,
       (SELECT count(*)::int FROM debate_sources s WHERE s.debate_id=d.id AND NOT s.verified) AS unverified
     FROM debates d ORDER BY d.updated_at DESC`,
  );
  return rows;
}

export async function getDebate(tx: Tx, id: string): Promise<Debate | null> {
  if (!isUuid(id)) return null;
  const { rows } = await tx.query<Debate>(`SELECT ${COLS} FROM debates WHERE id=$1`, [id]);
  return rows[0] ?? null;
}

export async function createDebate(tx: Tx, userId: string, d: { theme: DebateTheme; title: string; courseId: string | null }): Promise<string> {
  if (!(d.theme in DEBATE_THEMES)) throw new Error("Geçersiz tema.");
  if (d.title.trim().length < 2) throw new Error("Tartışma başlığı girin.");
  if (d.courseId && !(await getCourse(tx, d.courseId))) throw new Error("Ders bulunamadı.");
  const { rows } = await tx.query<{ id: string }>(
    "INSERT INTO debates (user_id, theme, title, course_id) VALUES ($1,$2,$3,$4) RETURNING id",
    [userId, d.theme, d.title.trim().slice(0, 300), d.courseId],
  );
  return rows[0].id;
}

export async function updateDebate(tx: Tx, id: string, d: Omit<Debate, "id" | "course_id" | "created_at" | "updated_at">) {
  if (d.title.trim().length < 2) throw new Error("Tartışma başlığı girin.");
  const clip = (s: string) => s.slice(0, 20000);
  const { rowCount } = await tx.query(
    `UPDATE debates SET title=$2, theme=$3, claim=$4, academic_context=$5, counter_arguments=$6, islamic_perspective=$7,
       class_answer=$8, weaknesses=$9, uncertainties=$10, updated_at=now() WHERE id=$1`,
    [id, d.title.trim().slice(0, 300), d.theme, clip(d.claim), clip(d.academic_context), clip(d.counter_arguments),
      clip(d.islamic_perspective), clip(d.class_answer), clip(d.weaknesses), clip(d.uncertainties)],
  );
  if (!rowCount) throw new Error("Tartışma bulunamadı.");
}

export async function deleteDebate(tx: Tx, id: string) {
  if (isUuid(id)) await tx.query("DELETE FROM debates WHERE id=$1", [id]);
}

export async function listDebateSources(tx: Tx, debateId: string): Promise<DebateSource[]> {
  const { rows } = await tx.query<DebateSource>(
    "SELECT id, debate_id, kind, reference, quote, note, verified FROM debate_sources WHERE debate_id=$1 ORDER BY created_at",
    [debateId],
  );
  return rows;
}

export async function addDebateSource(tx: Tx, userId: string, debateId: string, s: { kind: string; reference: string; quote: string; note: string }) {
  if (!(s.kind in DEBATE_SOURCE_KINDS)) throw new Error("Geçersiz kaynak türü.");
  if (s.reference.trim().length < 2) throw new Error("Kaynağın künyesini girin (ör. sure/ayet, hadis kaynağı ve numarası, eser ve sayfa).");
  if (!(await getDebate(tx, debateId))) throw new Error("Tartışma bulunamadı.");
  await tx.query(
    "INSERT INTO debate_sources (user_id, debate_id, kind, reference, quote, note) VALUES ($1,$2,$3,$4,$5,$6)",
    [userId, debateId, s.kind, s.reference.trim().slice(0, 500), s.quote.slice(0, 5000), s.note.slice(0, 5000)],
  );
}

export async function setSourceVerified(tx: Tx, id: string, verified: boolean) {
  if (isUuid(id)) await tx.query("UPDATE debate_sources SET verified=$2 WHERE id=$1", [id, verified]);
}

export async function deleteDebateSource(tx: Tx, id: string) {
  if (isUuid(id)) await tx.query("DELETE FROM debate_sources WHERE id=$1", [id]);
}
