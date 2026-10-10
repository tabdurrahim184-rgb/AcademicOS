/**
 * Ders materyali içe aktarma: dosya türü doğrulama ve metin çıkarma.
 * Kaynak metni olduğu gibi korunur; konum bilgisi (sayfa / slayt / zaman
 * damgası / bölüm) yalnızca dosyadan gerçekten belirlenebiliyorsa üretilir.
 */
import JSZip from "jszip";

export const MAX_UPLOAD_BYTES = 25 * 1024 * 1024;

export type FileType = "pdf" | "docx" | "pptx" | "txt" | "srt" | "vtt" | "image";
export type Chunk = { locatorType: "sayfa" | "slayt" | "zaman" | "bolum"; locator: string; content: string };
export type ExtractionResult = {
  fileType: FileType;
  status: "tamam" | "metin_yok" | "hata" | "desteklenmiyor";
  note: string;
  unitCount: number;
  chunks: Chunk[];
};

export class UploadError extends Error {}

const ext = (name: string) => (name.toLowerCase().match(/\.([a-z0-9]+)$/)?.[1] ?? "");

const startsWith = (buf: Buffer, bytes: number[]) => bytes.every((b, i) => buf[i] === b);

/** Uzantı ve dosya imzasını (magic bytes) birlikte doğrular. */
export async function detectFileType(filename: string, buf: Buffer): Promise<FileType> {
  if (buf.length === 0) throw new UploadError("Dosya boş.");
  if (buf.length > MAX_UPLOAD_BYTES) throw new UploadError("Dosya 25 MB sınırını aşıyor.");
  const e = ext(filename);
  if (e === "pdf") {
    if (!buf.subarray(0, 1024).includes(Buffer.from("%PDF-"))) throw new UploadError("Dosya geçerli bir PDF değil veya bozuk.");
    return "pdf";
  }
  if (e === "docx" || e === "pptx") {
    if (!startsWith(buf, [0x50, 0x4b, 0x03, 0x04])) throw new UploadError(`Dosya geçerli bir ${e.toUpperCase()} değil veya bozuk.`);
    let zip: JSZip;
    try {
      zip = await JSZip.loadAsync(buf);
    } catch {
      throw new UploadError(`Dosya geçerli bir ${e.toUpperCase()} değil veya bozuk.`);
    }
    const marker = e === "docx" ? "word/document.xml" : "ppt/presentation.xml";
    if (!zip.file(marker)) throw new UploadError(`Dosya geçerli bir ${e.toUpperCase()} değil.`);
    return e;
  }
  if (["png", "jpg", "jpeg", "webp"].includes(e)) {
    const ok =
      startsWith(buf, [0x89, 0x50, 0x4e, 0x47]) ||
      startsWith(buf, [0xff, 0xd8, 0xff]) ||
      (buf.subarray(0, 4).toString("latin1") === "RIFF" && buf.subarray(8, 12).toString("latin1") === "WEBP");
    if (!ok) throw new UploadError("Görsel dosyası geçerli değil.");
    return "image";
  }
  if (e === "txt" || e === "md" || e === "srt" || e === "vtt") {
    if (buf.subarray(0, 8192).includes(0)) throw new UploadError("Metin dosyası ikili (binary) veri içeriyor.");
    return e === "md" ? "txt" : (e as FileType);
  }
  throw new UploadError("Desteklenmeyen dosya türü. PDF, DOCX, PPTX, TXT, MD, SRT, VTT, PNG, JPG veya WEBP yükleyin.");
}

export const MIME: Record<FileType, string> = {
  pdf: "application/pdf",
  docx: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  pptx: "application/vnd.openxmlformats-officedocument.presentationml.presentation",
  txt: "text/plain; charset=utf-8",
  srt: "application/x-subrip; charset=utf-8",
  vtt: "text/vtt; charset=utf-8",
  image: "application/octet-stream",
};

export function imageMime(filename: string) {
  const e = ext(filename);
  return e === "png" ? "image/png" : e === "webp" ? "image/webp" : "image/jpeg";
}

/** UTF-8 dener; geçersizse Türkçe Windows kod sayfasına (1254) düşer. */
export function decodeText(buf: Buffer): string {
  let b = buf;
  if (startsWith(b, [0xef, 0xbb, 0xbf])) b = b.subarray(3);
  try {
    return new TextDecoder("utf-8", { fatal: true }).decode(b).normalize("NFC");
  } catch {
    return new TextDecoder("windows-1254").decode(b).normalize("NFC");
  }
}

const cleanWs = (s: string) => s.replace(/\r\n?/g, "\n").replace(/[ \t]+\n/g, "\n").replace(/\n{3,}/g, "\n\n").trim();

/** Paragrafları yaklaşık `max` karakterlik bölümlere toplar. */
export function chunkParagraphs(text: string, max = 1500): string[] {
  const paras = cleanWs(text).split(/\n\s*\n/).map((p) => p.trim()).filter(Boolean);
  const out: string[] = [];
  let cur = "";
  for (const p of paras) {
    if (cur && cur.length + p.length + 2 > max) {
      out.push(cur);
      cur = "";
    }
    if (p.length > max) {
      // Çok uzun paragrafları cümle sınırlarından böl.
      const sentences = p.match(/[^.!?…]+[.!?…]*\s*/g) ?? [p];
      for (const s of sentences) {
        if (cur && cur.length + s.length > max) {
          out.push(cur.trim());
          cur = "";
        }
        cur += s;
      }
      continue;
    }
    cur = cur ? `${cur}\n\n${p}` : p;
  }
  if (cur.trim()) out.push(cur.trim());
  return out;
}

function decodeXmlEntities(s: string) {
  return s
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&#(\d+);/g, (_, n) => String.fromCodePoint(Number(n)))
    .replace(/&#x([0-9a-f]+);/gi, (_, n) => String.fromCodePoint(parseInt(n, 16)))
    .replace(/&amp;/g, "&");
}

/** DrawingML XML'inden paragrafları çıkarır (<a:p> içindeki <a:t> parçaları). */
function drawingMlText(xml: string): string {
  const paras = xml.match(/<a:p[\s>][\s\S]*?<\/a:p>/g) ?? [];
  return paras
    .map((p) => (p.match(/<a:t(?:\s[^>]*)?>([\s\S]*?)<\/a:t>/g) ?? []).map((t) => decodeXmlEntities(t.replace(/<[^>]+>/g, ""))).join(""))
    .filter((t) => t.trim())
    .join("\n");
}

async function extractPptx(buf: Buffer): Promise<ExtractionResult> {
  const zip = await JSZip.loadAsync(buf);
  const slideFiles = Object.keys(zip.files)
    .filter((n) => /^ppt\/slides\/slide\d+\.xml$/.test(n))
    .sort((a, b) => Number(a.match(/(\d+)\.xml$/)![1]) - Number(b.match(/(\d+)\.xml$/)![1]));
  const chunks: Chunk[] = [];
  for (const f of slideFiles) {
    const n = Number(f.match(/(\d+)\.xml$/)![1]);
    let text = drawingMlText(await zip.file(f)!.async("string"));
    const notes = zip.file(`ppt/notesSlides/notesSlide${n}.xml`);
    if (notes) {
      const nt = drawingMlText(await notes.async("string")).replace(/^\d+$/gm, "").trim();
      if (nt) text += `\n\n[Konuşmacı notu]\n${nt}`;
    }
    if (text.trim()) chunks.push({ locatorType: "slayt", locator: `Slayt ${n}`, content: text.normalize("NFC") });
  }
  return finish("pptx", chunks, slideFiles.length, "Sunumda okunabilir metin bulunamadı (yalnızca görsel içeriyor olabilir).");
}

async function extractDocx(buf: Buffer): Promise<ExtractionResult> {
  const mammoth = await import("mammoth");
  const { value } = await mammoth.extractRawText({ buffer: buf });
  const parts = chunkParagraphs(value.normalize("NFC"));
  // DOCX'te sabit sayfa yoktur; sayfa numarası uydurulmaz, "Bölüm" kullanılır.
  const chunks = parts.map((c, i) => ({ locatorType: "bolum" as const, locator: `Bölüm ${i + 1}`, content: c }));
  return finish("docx", chunks, chunks.length, "Belgede okunabilir metin bulunamadı.");
}

async function extractPdf(buf: Buffer): Promise<ExtractionResult> {
  const { getDocumentProxy, extractText } = await import("unpdf");
  const pdf = await getDocumentProxy(new Uint8Array(buf));
  const { totalPages, text } = await extractText(pdf, { mergePages: false });
  const chunks: Chunk[] = [];
  (text as string[]).forEach((t, i) => {
    const c = cleanWs(t.normalize("NFC"));
    if (c) chunks.push({ locatorType: "sayfa", locator: `Sayfa ${i + 1}`, content: c });
  });
  return finish(
    "pdf",
    chunks,
    totalPages,
    "Bu PDF'te seçilebilir metin bulunamadı; taranmış (görüntü) bir belge olabilir. OCR desteği henüz yok — dosya saklandı ancak içeriği aranamaz.",
  );
}

const TS = /(\d{1,2}:)?\d{2}:\d{2}[.,]\d{3}/;

function parseTimestamp(s: string): number {
  const m = s.trim().replace(",", ".").split(":").map(Number);
  return m.length === 3 ? m[0] * 3600 + m[1] * 60 + m[2] : m[0] * 60 + m[1];
}
export function formatTs(sec: number): string {
  const s = Math.floor(sec);
  return [Math.floor(s / 3600), Math.floor((s % 3600) / 60), s % 60].map((n) => String(n).padStart(2, "0")).join(":");
}

/** SRT/VTT altyazı bloklarını ~60 saniyelik zaman damgalı parçalara toplar. */
export function parseSubtitles(text: string, kind: "srt" | "vtt"): { chunks: Chunk[]; cues: number } {
  const blocks = cleanWs(text).split(/\n\s*\n/);
  const cues: Array<{ start: number; end: number; text: string }> = [];
  for (const block of blocks) {
    const lines = block.split("\n");
    const tIdx = lines.findIndex((l) => l.includes("-->") && TS.test(l));
    if (tIdx < 0) continue; // WEBVTT başlığı, NOTE, numara satırları vb.
    const [a, b] = lines[tIdx].split("-->");
    const body = lines.slice(tIdx + 1).join(" ").replace(/<[^>]+>/g, "").trim();
    if (!body) continue;
    cues.push({ start: parseTimestamp(a.match(TS)![0]), end: parseTimestamp(b.match(TS)![0]), text: body });
  }
  const chunks: Chunk[] = [];
  let group: typeof cues = [];
  const flush = () => {
    if (!group.length) return;
    chunks.push({
      locatorType: "zaman",
      locator: `${formatTs(group[0].start)}–${formatTs(group[group.length - 1].end)}`,
      content: group.map((c) => c.text).join(" "),
    });
    group = [];
  };
  for (const c of cues) {
    if (group.length && (c.start - group[0].start >= 60 || group.reduce((n, g) => n + g.text.length, 0) > 1200)) flush();
    group.push(c);
  }
  flush();
  void kind;
  return { chunks, cues: cues.length };
}

function finish(fileType: FileType, chunks: Chunk[], units: number, emptyNote: string): ExtractionResult {
  if (!chunks.length) return { fileType, status: "metin_yok", note: emptyNote, unitCount: units, chunks };
  return { fileType, status: "tamam", note: "", unitCount: units, chunks };
}

export async function extractContent(fileType: FileType, buf: Buffer): Promise<ExtractionResult> {
  try {
    switch (fileType) {
      case "pdf":
        return await extractPdf(buf);
      case "docx":
        return await extractDocx(buf);
      case "pptx":
        return await extractPptx(buf);
      case "txt": {
        const parts = chunkParagraphs(decodeText(buf));
        const chunks = parts.map((c, i) => ({ locatorType: "bolum" as const, locator: `Bölüm ${i + 1}`, content: c }));
        return finish("txt", chunks, chunks.length, "Dosyada metin bulunamadı.");
      }
      case "srt":
      case "vtt": {
        const { chunks, cues } = parseSubtitles(decodeText(buf), fileType);
        return finish(fileType, chunks, cues, "Altyazı dosyasında geçerli zaman damgalı satır bulunamadı.");
      }
      case "image":
        return {
          fileType,
          status: "desteklenmiyor",
          note: "Görsel saklandı. Görsellerden metin okuma (OCR) henüz desteklenmiyor; içeriği aranamaz ve yapay zekâya kaynak olarak verilmez.",
          unitCount: 1,
          chunks: [],
        };
    }
  } catch (err) {
    return {
      fileType,
      status: "hata",
      note: `Dosya okunamadı: ${(err as Error).message.slice(0, 200)}. Dosya bozuk veya parola korumalı olabilir.`,
      unitCount: 0,
      chunks: [],
    };
  }
}
