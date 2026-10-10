"use server";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { requireUser } from "@/lib/auth";
import { withUser } from "@/lib/db";
import { cancelJob, createJob, getJob, startJob } from "@/lib/jobs";
import { deleteRecording, getRecording, updateOcrChunk, updateSegment } from "@/lib/data/recordings";
import { getSource } from "@/lib/data/sources";
import { getTranscriptionStatus } from "@/lib/transcription";

const str = (f: FormData, k: string) => String(f.get(k) ?? "").trim();
const go = (p: string, params: Record<string, string>) => `${p}?${new URLSearchParams(params)}`;

export async function startOcrAction(form: FormData) {
  const user = await requireUser();
  const sourceId = str(form, "sourceId");
  let jobId = "";
  try {
    jobId = await withUser(user.id, async (tx) => {
      const s = await getSource(tx, sourceId);
      if (!s) throw new Error("Kaynak bulunamadı.");
      if (!["pdf", "image"].includes(s.file_type)) throw new Error("OCR yalnızca PDF ve görseller için kullanılabilir.");
      if (s.extraction_status === "tamam") throw new Error("Bu kaynağın metni zaten çıkarılmış.");
      return createJob(tx, user.id, "ocr", sourceId);
    });
  } catch (e) {
    redirect(go(`/kaynaklar/${sourceId}`, { hata: (e as Error).message }));
  }
  startJob(user.id, jobId);
  redirect(go(`/kaynaklar/${sourceId}`, { tamam: "OCR başlatıldı. Sayfa ilerledikçe bu sayfa kendiliğinden yenilenir." }));
}

export async function startTranscriptionAction(form: FormData) {
  const user = await requireUser();
  const recId = str(form, "recordingId");
  const status = getTranscriptionStatus();
  if (!status.enabled) redirect(go(`/kayitlar/${recId}`, { hata: status.reason }));
  if (form.get("consent") !== "on") redirect(go(`/kayitlar/${recId}`, { hata: "Ücretli deşifre için onay kutusunu işaretleyin." }));
  let jobId = "";
  try {
    jobId = await withUser(user.id, async (tx) => {
      if (!(await getRecording(tx, recId))) throw new Error("Kayıt bulunamadı.");
      return createJob(tx, user.id, "transkripsiyon", recId);
    });
  } catch (e) {
    redirect(go(`/kayitlar/${recId}`, { hata: (e as Error).message }));
  }
  startJob(user.id, jobId);
  redirect(go(`/kayitlar/${recId}`, { tamam: "Deşifre başlatıldı." }));
}

export async function cancelJobAction(form: FormData) {
  const user = await requireUser();
  await withUser(user.id, (tx) => cancelJob(tx, str(form, "jobId")));
  revalidatePath("/", "layout");
  redirect(go(str(form, "returnTo") || "/kayitlar", { tamam: "İş iptal edildi." }));
}

/** Yarıda kalan (hata / sunucu yeniden başlatma) işi kaldığı birimden sürdürür. */
export async function resumeJobAction(form: FormData) {
  const user = await requireUser();
  const jobId = str(form, "jobId");
  const back = str(form, "returnTo") || "/kayitlar";
  const job = await withUser(user.id, (tx) => getJob(tx, jobId));
  if (!job || job.status === "tamamlandi") redirect(go(back, { hata: "Devam ettirilecek iş yok." }));
  if (job.kind === "transkripsiyon" && form.get("consent") !== "on") redirect(go(back, { hata: "Ücretli deşifreye devam için onay kutusunu işaretleyin." }));
  await withUser(user.id, (tx) => tx.query("UPDATE jobs SET status='bekliyor', message='' WHERE id=$1", [jobId]));
  startJob(user.id, jobId);
  redirect(go(back, { tamam: "İş kaldığı yerden sürdürülüyor." }));
}

export async function updateSegmentAction(form: FormData) {
  const user = await requireUser();
  const recId = str(form, "recordingId");
  try {
    await withUser(user.id, (tx) => updateSegment(tx, str(form, "segmentId"), String(form.get("text") ?? ""), str(form, "speaker") || null));
  } catch (e) {
    redirect(go(`/kayitlar/${recId}`, { hata: (e as Error).message }));
  }
  revalidatePath(`/kayitlar/${recId}`);
  redirect(go(`/kayitlar/${recId}`, { tamam: "Segment kaydedildi." }) + `#seg-${str(form, "segmentId")}`);
}

export async function deleteRecordingAction(form: FormData) {
  const user = await requireUser();
  await withUser(user.id, (tx) => deleteRecording(tx, str(form, "recordingId")));
  revalidatePath("/kayitlar");
  redirect(go("/kayitlar", { tamam: "Kayıt ve deşifresi silindi." }));
}

export async function updateOcrChunkAction(form: FormData) {
  const user = await requireUser();
  const sourceId = str(form, "sourceId");
  try {
    await withUser(user.id, (tx) => updateOcrChunk(tx, str(form, "chunkId"), String(form.get("content") ?? "")));
  } catch (e) {
    redirect(go(`/kaynaklar/${sourceId}`, { hata: (e as Error).message }));
  }
  revalidatePath(`/kaynaklar/${sourceId}`);
  redirect(go(`/kaynaklar/${sourceId}`, { tamam: "OCR metni düzeltildi." }));
}
