import { createHash } from "node:crypto";
import type { Tx } from "../db";
import { detectFileType, extractContent, imageMime, MIME, UploadError } from "../extract";
import { advanceTopicStatus, getCourse, getTopic, isUuid } from "./courses";

export const SOURCE_KINDS = {
  hoca: "Hocanın verdiği materyal",
  kendi_notum: "Kendi notum",
  arkadas: "Arkadaş notu",
  akademik: "Akademik araştırma",
  diger: "Diğer kaynak",
} as const;
export type SourceKind = keyof typeof SOURCE_KINDS;

export const EXTRACTION_LABELS = {
  tamam: "Metin çıkarıldı",
  metin_yok: "Metin bulunamadı",
  hata: "Okuma hatası",
  desteklenmiyor: "Metin çıkarma desteklenmiyor",
} as const;

export type Source = {
  id: string;
  course_id: string;
  topic_id: string | null;
  title: string;
  kind: SourceKind;
  filename: string;
  mime: string;
  size_bytes: number;
  sha256: string;
  file_type: string;
  extraction_status: keyof typeof EXTRACTION_LABELS;
  extraction_note: string;
  unit_count: number;
  created_at: Date;
};
export type SourceChunk = { id: string; source_id: string; ord: number; locator_type: string; locator: string; content: string };

const SOURCE_COLS =
  "id, course_id, topic_id, title, kind, filename, mime, size_bytes, sha256, file_type, extraction_status, extraction_note, unit_count, created_at";

export async function saveUploadedSource(
  tx: Tx,
  userId: string,
  input: { courseId: string; topicId: string | null; title: string; kind: SourceKind; filename: string; data: Buffer },
): Promise<{ id: string; status: Source["extraction_status"]; note: string }> {
  if (!(await getCourse(tx, input.courseId))) throw new UploadError("Ders bulunamadı.");
  if (input.topicId) {
    const t = await getTopic(tx, input.topicId);
    if (!t || t.course_id !== input.courseId) throw new UploadError("Konu bu derse ait değil.");
  }
  if (!(input.kind in SOURCE_KINDS)) throw new UploadError("Geçersiz kaynak türü.");
  const filename = input.filename.normalize("NFC").replace(/[\\/\u0000-\u001f]/g, "_").slice(0, 200) || "dosya";
  const fileType = await detectFileType(filename, input.data);
  const result = await extractContent(fileType, input.data);
  const sha = createHash("sha256").update(input.data).digest("hex");
  const title = (input.title.trim() || filename.replace(/\.[^.]+$/, "")).normalize("NFC").slice(0, 200);
  const mime = fileType === "image" ? imageMime(filename) : MIME[fileType];

  const { rows } = await tx.query<{ id: string }>(
    `INSERT INTO sources (user_id, course_id, topic_id, title, kind, filename, mime, size_bytes, sha256, file_type,
       extraction_status, extraction_note, unit_count)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13) RETURNING id`,
    [userId, input.courseId, input.topicId, title, input.kind, filename, mime, input.data.length, sha, fileType,
      result.status, result.note, result.unitCount],
  );
  const id = rows[0].id;
  await tx.query("INSERT INTO source_files (source_id, user_id, content) VALUES ($1,$2,$3)", [id, userId, input.data]);
  let ord = 0;
  for (const c of result.chunks) {
    await tx.query(
      "INSERT INTO source_chunks (user_id, source_id, ord, locator_type, locator, content) VALUES ($1,$2,$3,$4,$5,$6)",
      [userId, id, ord++, c.locatorType, c.locator, c.content],
    );
  }
  if (input.topicId) await advanceTopicStatus(tx, input.topicId, "materyal_alindi");
  return { id, status: result.status, note: result.note };
}

export async function listSources(tx: Tx, filter: { courseId?: string; topicId?: string } = {}): Promise<Source[]> {
  const where: string[] = [];
  const params: unknown[] = [];
  if (filter.courseId) where.push(`course_id = $${params.push(filter.courseId)}`);
  if (filter.topicId) where.push(`topic_id = $${params.push(filter.topicId)}`);
  const { rows } = await tx.query<Source>(
    `SELECT ${SOURCE_COLS} FROM sources ${where.length ? "WHERE " + where.join(" AND ") : ""} ORDER BY created_at DESC`,
    params,
  );
  return rows;
}

export async function getSource(tx: Tx, id: string): Promise<Source | null> {
  if (!isUuid(id)) return null;
  const { rows } = await tx.query<Source>(`SELECT ${SOURCE_COLS} FROM sources WHERE id = $1`, [id]);
  return rows[0] ?? null;
}

export async function getSourceFile(tx: Tx, id: string): Promise<Buffer | null> {
  if (!isUuid(id)) return null;
  const { rows } = await tx.query<{ content: Buffer }>("SELECT content FROM source_files WHERE source_id = $1", [id]);
  return rows[0]?.content ?? null;
}

export async function getSourceChunks(tx: Tx, sourceId: string): Promise<SourceChunk[]> {
  const { rows } = await tx.query<SourceChunk>(
    "SELECT id, source_id, ord, locator_type, locator, content FROM source_chunks WHERE source_id = $1 ORDER BY ord",
    [sourceId],
  );
  return rows;
}

export async function deleteSource(tx: Tx, id: string) {
  await tx.query("DELETE FROM sources WHERE id = $1", [id]);
}

export type SearchHit = SourceChunk & { source_title: string; course_id: string; rank: number };

/**
 * Kaynaklarda tam metin arama (PostgreSQL Türkçe sözlüğü) + alt dize eşleşmesi.
 * `sourceIds` verilirse yalnızca bu kaynaklarda arar.
 */
export async function searchChunks(
  tx: Tx,
  query: string,
  opts: { courseId?: string; sourceIds?: string[]; limit?: number } = {},
): Promise<SearchHit[]> {
  const q = query.normalize("NFC").trim().slice(0, 300);
  if (!q) return [];
  const params: unknown[] = [q, `%${q.replace(/[%_\\]/g, (m) => "\\" + m)}%`];
  const where: string[] = ["(c.tsv @@ websearch_to_tsquery('turkish', $1) OR c.content ILIKE $2)"];
  if (opts.courseId) where.push(`s.course_id = $${params.push(opts.courseId)}`);
  if (opts.sourceIds) where.push(`s.id = ANY($${params.push(opts.sourceIds)}::uuid[])`);
  const { rows } = await tx.query<SearchHit>(
    `SELECT c.id, c.source_id, c.ord, c.locator_type, c.locator, c.content, s.title AS source_title, s.course_id,
            ts_rank(c.tsv, websearch_to_tsquery('turkish', $1)) + CASE WHEN c.content ILIKE $2 THEN 0.5 ELSE 0 END AS rank
     FROM source_chunks c JOIN sources s ON s.id = c.source_id
     WHERE ${where.join(" AND ")}
     ORDER BY rank DESC, s.created_at DESC, c.ord
     LIMIT ${Math.min(opts.limit ?? 20, 50)}`,
    params,
  );
  return rows;
}

/**
 * Öğretim için bağlam parçalarını seçer: önce sorguyla eşleşenler, yetmezse
 * seçili kaynakların baştan itibaren parçaları. Toplam karakter sınırı uygulanır.
 */
export async function selectContext(
  tx: Tx,
  sourceIds: string[],
  query: string,
  maxChars = 24000,
): Promise<SearchHit[]> {
  if (!sourceIds.length) return [];
  const picked = new Map<string, SearchHit>();
  let total = 0;
  const add = (h: SearchHit) => {
    if (picked.has(h.id) || total + h.content.length > maxChars) return;
    picked.set(h.id, h);
    total += h.content.length;
  };
  if (query.trim()) {
    const words = query.split(/\s+/).filter((w) => w.length > 3).slice(0, 8).join(" OR ");
    if (words) (await searchChunks(tx, words, { sourceIds, limit: 30 })).forEach(add);
  }
  const { rows } = await tx.query<SearchHit>(
    `SELECT c.id, c.source_id, c.ord, c.locator_type, c.locator, c.content, s.title AS source_title, s.course_id, 0 AS rank
     FROM source_chunks c JOIN sources s ON s.id = c.source_id
     WHERE s.id = ANY($1::uuid[]) ORDER BY s.created_at, c.ord LIMIT 200`,
    [sourceIds],
  );
  rows.forEach(add);
  return [...picked.values()].sort((a, b) => (a.source_id === b.source_id ? a.ord - b.ord : a.source_id < b.source_id ? -1 : 1));
}
