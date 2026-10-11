/**
 * Türkçe ses/video deşifresi.
 * - Sağlayıcı: OpenAI Audio Transcriptions (ÜCRETLİ). Yalnızca TRANSCRIPTION_PROVIDER=openai,
 *   OPENAI_API_KEY ve TRANSCRIPTION_MODEL tanımlıysa ve kullanıcı her iş için açıkça onay verdiyse çalışır.
 * - Uzun kayıtlar ffmpeg ile 10 dakikalık parçalara bölünür (sunucuda ffmpeg gerekir).
 * - Anlaşılamayan bölümler uydurulmaz: sağlayıcının döndürdüğü ham metin değiştirilmeden saklanır;
 *   düzeltmeler ayrı alanda tutulur.
 */
import { spawn } from "node:child_process";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import JSZip from "jszip";
import OpenAI, { toFile } from "openai";
import { withUser } from "./db";
import { formatTs } from "./extract";

export const UNIT_SEC = 600;
export const MAX_MEDIA_BYTES = 100 * 1024 * 1024;
export const MEDIA_EXT = /\.(mp3|m4a|wav|ogg|oga|webm|mp4|mov|mkv|aac|flac)$/i;

type Env = Record<string, string | undefined>;
export type TranscriptionStatus = { enabled: true; model: string; pricePerMin: number | null } | { enabled: false; reason: string };

export function getTranscriptionStatus(env: Env = process.env): TranscriptionStatus {
  if ((env.TRANSCRIPTION_PROVIDER ?? "").toLowerCase() !== "openai") return { enabled: false, reason: "Deşifre sağlayıcısı yapılandırılmamış (TRANSCRIPTION_PROVIDER)." };
  if (!env.OPENAI_API_KEY) return { enabled: false, reason: "OPENAI_API_KEY tanımlı değil." };
  if (!env.TRANSCRIPTION_MODEL) return { enabled: false, reason: "TRANSCRIPTION_MODEL seçilmedi (ör. zaman damgaları için whisper-1)." };
  const p = Number(env.TRANSCRIPTION_PRICE_PER_MIN);
  return { enabled: true, model: env.TRANSCRIPTION_MODEL, pricePerMin: env.TRANSCRIPTION_PRICE_PER_MIN && p >= 0 ? p : null };
}

const ffmpegBin = () => process.env.FFMPEG_PATH || "ffmpeg";

function run(cmd: string, args: string[]): Promise<{ code: number; stderr: string }> {
  return new Promise((resolve, reject) => {
    const p = spawn(cmd, args, { stdio: ["ignore", "ignore", "pipe"] });
    let stderr = "";
    p.stderr.on("data", (d) => (stderr += d));
    p.on("error", (e) => reject(new Error(e.message.includes("ENOENT") ? "Sunucuda ffmpeg kurulu değil; ses/video işlenemiyor." : e.message)));
    p.on("close", (code) => resolve({ code: code ?? 1, stderr }));
  });
}

async function withTemp<T>(fn: (dir: string) => Promise<T>): Promise<T> {
  const dir = await mkdtemp(path.join(os.tmpdir(), "aos-medya-"));
  try {
    return await fn(dir);
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
}

/** Süreyi ffmpeg çıktısından okur (saniye). */
export async function probeDuration(media: Buffer): Promise<number> {
  return withTemp(async (dir) => {
    const f = path.join(dir, "girdi");
    await writeFile(f, media);
    const { stderr } = await run(ffmpegBin(), ["-hide_banner", "-i", f]);
    const m = stderr.match(/Duration:\s*(\d+):(\d+):(\d+(?:\.\d+)?)/);
    if (!m) throw new Error("Ses/video dosyası okunamadı veya bozuk.");
    return Number(m[1]) * 3600 + Number(m[2]) * 60 + Number(m[3]);
  });
}

/** i. parçayı (10 dk) 16 kHz mono MP3'e çevirir. */
export async function extractUnit(media: Buffer, i: number): Promise<Buffer> {
  return withTemp(async (dir) => {
    const inF = path.join(dir, "girdi");
    const outF = path.join(dir, "parca.mp3");
    await writeFile(inF, media);
    const r = await run(ffmpegBin(), ["-hide_banner", "-loglevel", "error", "-ss", String(i * UNIT_SEC), "-t", String(UNIT_SEC), "-i", inF, "-vn", "-ac", "1", "-ar", "16000", "-b:a", "48k", "-y", outF]);
    if (r.code !== 0) throw new Error("Ses parçası hazırlanamadı.");
    return readFile(outF);
  });
}

async function loadMedia(userId: string, recId: string) {
  return withUser(userId, async (tx) => {
    const { rows } = await tx.query<{ content: Buffer; duration_sec: string | null }>(
      "SELECT f.content, r.duration_sec FROM recordings r JOIN recording_files f ON f.recording_id = r.id WHERE r.id=$1",
      [recId],
    );
    if (!rows[0]) throw new Error("Kayıt bulunamadı.");
    return rows[0];
  });
}

export async function transcriptionUnits(userId: string, recId: string): Promise<number> {
  const m = await loadMedia(userId, recId);
  let dur = m.duration_sec != null ? Number(m.duration_sec) : null;
  if (dur == null) {
    dur = await probeDuration(m.content);
    await withUser(userId, (tx) => tx.query("UPDATE recordings SET duration_sec=$2 WHERE id=$1", [recId, dur]));
  }
  return Math.max(1, Math.ceil(dur / UNIT_SEC));
}

type Segment = { start: number; end: number; text: string };

/** Bir parçayı sağlayıcıya gönderir ve segmentleri kaydeder (tekrar çalıştırılması güvenlidir). */
export async function runTranscriptionUnit(userId: string, recId: string, i: number) {
  const status = getTranscriptionStatus();
  if (!status.enabled) throw new Error(status.reason);
  const m = await loadMedia(userId, recId);
  const audio = await extractUnit(m.content, i);
  const client = new OpenAI({ timeout: 300_000, maxRetries: 2 });
  const verbose = status.model.startsWith("whisper");
  let segments: Segment[];
  try {
    const res = await client.audio.transcriptions.create({
      file: await toFile(audio, `parca-${i}.mp3`, { type: "audio/mpeg" }),
      model: status.model,
      language: "tr",
      ...(verbose ? { response_format: "verbose_json" as const, timestamp_granularities: ["segment" as const] } : { response_format: "json" as const }),
    });
    const r = res as unknown as { text: string; duration?: number; segments?: Array<{ start: number; end: number; text: string }> };
    segments = r.segments?.length
      ? r.segments.map((s) => ({ start: s.start, end: s.end, text: s.text.trim() }))
      : [{ start: 0, end: r.duration ?? Math.min(UNIT_SEC, Number(m.duration_sec ?? UNIT_SEC) - i * UNIT_SEC), text: (r.text ?? "").trim() }];
  } catch (e) {
    await withUser(userId, (tx) =>
      tx.query("INSERT INTO ai_usage (user_id, provider, model, purpose, ok) VALUES ($1,'openai',$2,'transkripsiyon',false)", [userId, status.model]),
    );
    if (e instanceof OpenAI.AuthenticationError) throw new Error("OpenAI API anahtarı geçersiz.");
    if (e instanceof OpenAI.APIConnectionError) throw new Error("Deşifre hizmetine bağlanılamadı.");
    if (e instanceof OpenAI.APIError) throw new Error(`Deşifre hizmeti hata döndürdü (${e.status ?? "?"}).`);
    throw e;
  }
  const offset = i * UNIT_SEC;
  await withUser(userId, async (tx) => {
    await tx.query("DELETE FROM transcript_segments WHERE recording_id=$1 AND ord >= $2 AND ord < $3", [recId, i * 10000, (i + 1) * 10000]);
    let k = 0;
    for (const s of segments.filter((x) => x.text)) {
      await tx.query(
        "INSERT INTO transcript_segments (user_id, recording_id, ord, start_sec, end_sec, raw_text, text) VALUES ($1,$2,$3,$4,$5,$6,$6)",
        [userId, recId, i * 10000 + k++, (offset + s.start).toFixed(2), (offset + s.end).toFixed(2), s.text],
      );
    }
    await tx.query("INSERT INTO ai_usage (user_id, provider, model, purpose, ok) VALUES ($1,'openai',$2,'transkripsiyon',true)", [userId, status.model]);
  });
}

// ---------------------------------------------------------------- Dışa aktarma
export type ExportSegment = { start_sec: number | string; end_sec: number | string; text: string; speaker?: string | null };

const srtTs = (s: number) => {
  const ms = Math.round((s % 1) * 1000);
  return `${formatTs(Math.floor(s))},${String(ms).padStart(3, "0")}`;
};

export function toSrt(segs: ExportSegment[]) {
  return segs.map((s, i) => `${i + 1}\n${srtTs(Number(s.start_sec))} --> ${srtTs(Number(s.end_sec))}\n${s.text}\n`).join("\n");
}
export function toVtt(segs: ExportSegment[]) {
  return "WEBVTT\n\n" + segs.map((s) => `${srtTs(Number(s.start_sec)).replace(",", ".")} --> ${srtTs(Number(s.end_sec)).replace(",", ".")}\n${s.text}\n`).join("\n");
}
export function toTxt(segs: ExportSegment[], withTimes = true) {
  return segs.map((s) => (withTimes ? `[${formatTs(Number(s.start_sec))}] ` : "") + (s.speaker ? `${s.speaker}: ` : "") + s.text).join("\n");
}

const xmlEsc = (s: string) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

/** En küçük geçerli DOCX (WordprocessingML) — her segment bir paragraf. */
export async function toDocx(title: string, segs: ExportSegment[]): Promise<Buffer> {
  const zip = new JSZip();
  zip.file("[Content_Types].xml", `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>`);
  zip.file("_rels/.rels", `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>`);
  const p = (text: string, bold = false) => `<w:p><w:r>${bold ? "<w:rPr><w:b/></w:rPr>" : ""}<w:t xml:space="preserve">${xmlEsc(text)}</w:t></w:r></w:p>`;
  const body = [p(title, true), ...segs.map((s) => p(`[${formatTs(Number(s.start_sec))}] ${s.speaker ? `${s.speaker}: ` : ""}${s.text}`))].join("");
  zip.file("word/document.xml", `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>${body}</w:body></w:document>`);
  return zip.generateAsync({ type: "nodebuffer" });
}
