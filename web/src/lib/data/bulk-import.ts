/**
 * Ortak içe aktarma çekirdeği: DEBİM aktarımı, ZIP (Moodle "ders içeriğini indir") ve
 * çoklu dosya yükleme aynı kuralları kullanır:
 *  - Klasör / bölüm adı → konu (yoksa oluşturulur), adından hafta numarası çıkarılır.
 *  - Aynı derste aynı içerik (SHA-256) varsa dosya yeniden eklenmez ("yinelenen").
 *  - Her dosya ayrı kayıt noktasıyla (SAVEPOINT) eklenir; biri bozuksa diğerleri etkilenmez.
 */
import { createHash } from "node:crypto";
import JSZip from "jszip";
import type { Tx } from "../db";
import { MAX_UPLOAD_BYTES, UploadError } from "../extract";
import { IMPORTABLE_EXT, weekFromName } from "../lms/moodle";
import { normalizeTr } from "../grading";
import { createTopic, listTopics } from "./courses";
import { saveUploadedSource, type SourceKind } from "./sources";

export type ImportItem = { filename: string; data: Buffer; topicTitle: string | null; week: number | null; kind?: SourceKind };
export type ImportOutcome = { filename: string; status: "eklendi" | "yinelenen" | "atlandi" | "hata"; message: string; sourceId?: string };

export const ZIP_LIMITS = { maxEntries: 300, maxTotalBytes: 200 * 1024 * 1024 };

export async function findOrCreateTopic(tx: Tx, userId: string, courseId: string, title: string | null, week: number | null): Promise<string | null> {
  const clean = (title ?? "").trim().slice(0, 200);
  if (!clean && week == null) return null;
  const topics = await listTopics(tx, courseId);
  const key = normalizeTr(clean);
  const found = topics.find((t) => (clean && normalizeTr(t.title) === key) || (!clean && week != null && t.week === week));
  if (found) return found.id;
  return createTopic(tx, userId, courseId, { title: clean || `${week}. hafta`, week });
}

export async function importOne(tx: Tx, userId: string, courseId: string, item: ImportItem): Promise<ImportOutcome> {
  const filename = item.filename.split("/").pop() || item.filename;
  if (!IMPORTABLE_EXT.test(filename)) return { filename, status: "atlandi", message: "Desteklenmeyen dosya türü." };
  if (item.data.length > MAX_UPLOAD_BYTES) return { filename, status: "atlandi", message: "25 MB sınırını aşıyor." };
  const sha = createHash("sha256").update(item.data).digest("hex");
  const { rows: dup } = await tx.query<{ id: string; title: string }>("SELECT id, title FROM sources WHERE course_id=$1 AND sha256=$2 LIMIT 1", [courseId, sha]);
  if (dup[0]) return { filename, status: "yinelenen", message: `Bu derste zaten var: "${dup[0].title}".`, sourceId: dup[0].id };
  await tx.query("SAVEPOINT import_one");
  try {
    const topicId = await findOrCreateTopic(tx, userId, courseId, item.topicTitle, item.week);
    const r = await saveUploadedSource(tx, userId, { courseId, topicId, title: "", kind: item.kind ?? "hoca", filename, data: item.data });
    await tx.query("RELEASE SAVEPOINT import_one");
    return {
      filename, sourceId: r.id, status: "eklendi",
      message: r.status === "tamam" ? "Eklendi, metni çıkarıldı." : `Eklendi; ${r.note}`,
    };
  } catch (e) {
    await tx.query("ROLLBACK TO SAVEPOINT import_one");
    return { filename, status: "hata", message: e instanceof UploadError ? e.message : "Dosya işlenemedi." };
  }
}

/**
 * ZIP içeriğini içe aktarılabilir öğelere çevirir. Tüm dosyalar ortak bir üst klasördeyse
 * (ör. Moodle dışa aktarımındaki ders adı) o klasör atlanır; sonraki klasör konu olur.
 */
export async function parseZip(buf: Buffer): Promise<{ items: ImportItem[]; skipped: ImportOutcome[] }> {
  let zip: JSZip;
  try {
    zip = await JSZip.loadAsync(buf);
  } catch {
    throw new UploadError("ZIP dosyası açılamadı veya bozuk.");
  }
  const entries = Object.values(zip.files).filter((f) => !f.dir && !f.name.startsWith("__MACOSX/") && !/(^|\/)\./.test(f.name));
  if (entries.length > ZIP_LIMITS.maxEntries) throw new UploadError(`ZIP en fazla ${ZIP_LIMITS.maxEntries} dosya içerebilir.`);
  const paths = entries.map((e) => e.name.normalize("NFC").split("/").filter(Boolean));
  const common = paths.length > 1 && paths.every((p) => p.length > 1 && p[0] === paths[0][0]) ? 1 : 0;
  const items: ImportItem[] = [];
  const skipped: ImportOutcome[] = [];
  let total = 0;
  for (let i = 0; i < entries.length; i++) {
    const parts = paths[i].slice(common);
    const filename = parts[parts.length - 1];
    if (!IMPORTABLE_EXT.test(filename)) {
      skipped.push({ filename, status: "atlandi", message: "Desteklenmeyen dosya türü." });
      continue;
    }
    const data = await entries[i].async("nodebuffer");
    total += data.length;
    if (total > ZIP_LIMITS.maxTotalBytes) throw new UploadError("ZIP içeriği 200 MB sınırını aşıyor.");
    const folder = parts.length > 1 ? parts[0].trim() : null;
    items.push({ filename, data, topicTitle: folder, week: folder ? weekFromName(folder) : weekFromName(filename) });
  }
  return { items, skipped };
}

export function summarize(outcomes: ImportOutcome[]) {
  const count = (s: ImportOutcome["status"]) => outcomes.filter((o) => o.status === s).length;
  return { eklendi: count("eklendi"), yinelenen: count("yinelenen"), atlandi: count("atlandi"), hata: count("hata") };
}
