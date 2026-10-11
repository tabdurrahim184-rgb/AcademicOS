/**
 * Arka plan işleri (OCR, transkripsiyon). Uygulama sürecinde (next start) çalışır.
 * - İlerleme her birimden (sayfa / ses parçası) sonra kaydedilir.
 * - İptal: birimler arasında kontrol edilir.
 * - Devam: tamamlanan birimler atlanır; sunucu yeniden başlarsa iş "Devam ettir" ile sürdürülür.
 * Sunucusuz (serverless) barındırmada uzun işler kesilebilir; kalıcı bir Node sunucusu önerilir.
 */
import { withUser, type Tx } from "./db";
import { advanceTopicStatus, isUuid } from "./data/courses";
import { createOcrWorker, ocrImage, OCR_MAX_PAGES, pdfPageCount, renderPdfPage } from "./ocr";
import { getSourceFile } from "./data/sources";
import { runTranscriptionUnit, transcriptionUnits } from "./transcription";

export type Job = {
  id: string; kind: "ocr" | "transkripsiyon"; target_id: string; status: "bekliyor" | "calisiyor" | "tamamlandi" | "hata" | "iptal";
  progress: number; total: number; message: string; created_at: Date; updated_at: Date;
};

const running = new Set<string>();

export async function listJobs(tx: Tx, targetId?: string): Promise<Job[]> {
  const { rows } = await tx.query<Job>(
    `SELECT id, kind, target_id, status, progress, total, message, created_at, updated_at FROM jobs
     ${targetId ? "WHERE target_id=$1" : ""} ORDER BY created_at DESC LIMIT 50`,
    targetId ? [targetId] : [],
  );
  return rows;
}

export async function getJob(tx: Tx, id: string): Promise<Job | null> {
  if (!isUuid(id)) return null;
  return (await tx.query<Job>("SELECT id, kind, target_id, status, progress, total, message, created_at, updated_at FROM jobs WHERE id=$1", [id])).rows[0] ?? null;
}

async function update(userId: string, id: string, fields: Partial<Pick<Job, "status" | "progress" | "total" | "message">>) {
  const sets = Object.keys(fields).map((k, i) => `${k}=$${i + 2}`).join(", ");
  await withUser(userId, (tx) => tx.query(`UPDATE jobs SET ${sets}, updated_at=now() WHERE id=$1`, [id, ...Object.values(fields)]));
}

export async function createJob(tx: Tx, userId: string, kind: Job["kind"], targetId: string): Promise<string> {
  const active = await tx.query("SELECT 1 FROM jobs WHERE target_id=$1 AND status IN ('bekliyor','calisiyor')", [targetId]);
  if (active.rowCount) throw new Error("Bu kayıt için zaten devam eden bir iş var.");
  const { rows } = await tx.query<{ id: string }>("INSERT INTO jobs (user_id, kind, target_id) VALUES ($1,$2,$3) RETURNING id", [userId, kind, targetId]);
  return rows[0].id;
}

export async function cancelJob(tx: Tx, id: string) {
  await tx.query("UPDATE jobs SET status='iptal', message='Kullanıcı iptal etti.', updated_at=now() WHERE id=$1 AND status IN ('bekliyor','calisiyor')", [id]);
}

/** İşi arka planda başlatır (bekletmez). Aynı iş aynı süreçte iki kez çalışmaz. */
export function startJob(userId: string, jobId: string) {
  if (running.has(jobId)) return;
  running.add(jobId);
  void runJob(userId, jobId)
    .catch(async (e) => {
      console.error("İş hatası", jobId, e);
      await update(userId, jobId, { status: "hata", message: (e as Error).message.slice(0, 500) }).catch(() => {});
    })
    .finally(() => running.delete(jobId));
}

/** İşi sonuna kadar çalıştırır (testlerde doğrudan beklenir). */
export async function runJob(userId: string, jobId: string) {
  const job = await withUser(userId, (tx) => getJob(tx, jobId));
  if (!job || job.status === "tamamlandi" || job.status === "iptal") return;
  await update(userId, jobId, { status: "calisiyor", message: "" });
  if (job.kind === "ocr") await runOcr(userId, job);
  else await runTranscription(userId, job);
}

const isCancelled = async (userId: string, id: string) => (await withUser(userId, (tx) => getJob(tx, id)))?.status === "iptal";

// ---------------------------------------------------------------- OCR
async function runOcr(userId: string, job: Job) {
  const src = await withUser(userId, async (tx) => {
    const { rows } = await tx.query<{ file_type: string; topic_id: string | null }>("SELECT file_type, topic_id FROM sources WHERE id=$1", [job.target_id]);
    return rows[0] ? { ...rows[0], file: await getSourceFile(tx, job.target_id) } : null;
  });
  if (!src?.file) throw new Error("Kaynak bulunamadı.");
  if (!["pdf", "image"].includes(src.file_type)) throw new Error("OCR yalnızca PDF ve görseller için kullanılabilir.");
  const pages = src.file_type === "pdf" ? Math.min(await pdfPageCount(src.file), OCR_MAX_PAGES) : 1;
  await update(userId, job.id, { total: pages });
  const worker = await createOcrWorker();
  const confidences: number[] = [];
  try {
    for (let page = job.progress + 1; page <= pages; page++) {
      if (await isCancelled(userId, job.id)) return;
      const img = src.file_type === "pdf" ? await renderPdfPage(src.file, page) : src.file;
      const r = await ocrImage(worker, img);
      confidences.push(r.confidence);
      await withUser(userId, async (tx) => {
        await tx.query("DELETE FROM source_chunks WHERE source_id=$1 AND ord=$2", [job.target_id, page - 1]);
        if (r.text) {
          await tx.query(
            "INSERT INTO source_chunks (user_id, source_id, ord, locator_type, locator, content, raw_ocr) VALUES ($1,$2,$3,'sayfa',$4,$5,$5)",
            [userId, job.target_id, page - 1, src.file_type === "pdf" ? `Sayfa ${page}` : "Görsel", r.text],
          );
        }
        await tx.query("UPDATE jobs SET progress=$2, updated_at=now() WHERE id=$1", [job.id, page]);
      });
    }
  } finally {
    await worker.terminate();
  }
  const avg = confidences.length ? Math.round(confidences.reduce((a, b) => a + b, 0) / confidences.length) : null;
  await withUser(userId, async (tx) => {
    const { rows } = await tx.query<{ n: number }>("SELECT count(*)::int AS n FROM source_chunks WHERE source_id=$1", [job.target_id]);
    const ok = rows[0].n > 0;
    await tx.query("UPDATE sources SET extraction_status=$2, extraction_note=$3, unit_count=$4 WHERE id=$1", [
      job.target_id, ok ? "tamam" : "metin_yok",
      ok ? `OCR ile okundu${avg != null ? ` (bu çalıştırmada ortalama güven %${avg})` : ""}. Tanıma hataları olabilir; metni düzenleyebilirsin, ham OCR çıktısı ayrıca saklanır.` : "OCR metin bulamadı.",
      pages,
    ]);
    if (ok && src.topic_id) await advanceTopicStatus(tx, src.topic_id, "materyal_alindi");
    await tx.query("UPDATE jobs SET status='tamamlandi', message=$2, updated_at=now() WHERE id=$1", [job.id, ok ? `${rows[0].n} sayfa okundu.` : "Metin bulunamadı."]);
  });
}

// ---------------------------------------------------------------- Transkripsiyon
async function runTranscription(userId: string, job: Job) {
  await withUser(userId, (tx) => tx.query("UPDATE recordings SET status='desifre_ediliyor' WHERE id=$1", [job.target_id]));
  try {
    const units = await transcriptionUnits(userId, job.target_id);
    await update(userId, job.id, { total: units });
    for (let i = job.progress; i < units; i++) {
      if (await isCancelled(userId, job.id)) {
        await withUser(userId, (tx) => tx.query("UPDATE recordings SET status='yuklendi' WHERE id=$1", [job.target_id]));
        return;
      }
      await runTranscriptionUnit(userId, job.target_id, i);
      await update(userId, job.id, { progress: i + 1 });
    }
    await withUser(userId, async (tx) => {
      await tx.query("UPDATE recordings SET status='hazir' WHERE id=$1", [job.target_id]);
      await tx.query("UPDATE jobs SET status='tamamlandi', message='Deşifre tamamlandı.', updated_at=now() WHERE id=$1", [job.id]);
    });
  } catch (e) {
    await withUser(userId, (tx) => tx.query("UPDATE recordings SET status='hata' WHERE id=$1", [job.target_id]));
    throw e;
  }
}
