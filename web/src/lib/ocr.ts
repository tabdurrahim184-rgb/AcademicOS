/**
 * OCR (optik karakter tanıma): Tesseract (tesseract.js, Türkçe dil verisi yerel paketten,
 * internet gerektirmez). Taranmış PDF sayfaları @napi-rs/canvas ile görüntüye çevrilir.
 * Sınırlar: el yazısı, düşük çözünürlük ve karmaşık sayfa düzenlerinde hata oranı yüksektir;
 * bu yüzden OCR metni düzenlenebilir ve ham çıktı ayrıca saklanır.
 */
import path from "node:path";

/** Türkçe dil verisi yerel npm paketinden okunur (paketleyiciden bağımsız olması için çalışma dizininden). */
export function ocrLangPath() {
  return process.env.OCR_LANG_PATH || path.join(process.cwd(), "node_modules", "@tesseract.js-data", "tur", "4.0.0_best_int");
}

export const OCR_MAX_PAGES = 40;

type Worker = { recognize: (img: Buffer) => Promise<{ data: { text: string; confidence: number } }>; terminate: () => Promise<unknown> };

export async function createOcrWorker(): Promise<Worker> {
  const { createWorker } = await import("tesseract.js");
  return (await createWorker("tur", 1, { langPath: ocrLangPath(), gzip: true, cacheMethod: "none" })) as unknown as Worker;
}

export function cleanOcrText(t: string): string {
  return t.normalize("NFC").replace(/[ \t]+\n/g, "\n").replace(/-\n(?=\p{Ll})/gu, "").replace(/\n{3,}/g, "\n\n").trim();
}

export async function ocrImage(worker: Worker, img: Buffer) {
  const r = await worker.recognize(img);
  return { text: cleanOcrText(r.data.text), confidence: Math.round(r.data.confidence) };
}

export async function pdfPageCount(buf: Buffer): Promise<number> {
  const { getDocumentProxy } = await import("unpdf");
  const pdf = await getDocumentProxy(new Uint8Array(buf));
  return pdf.numPages;
}

/** PDF sayfasını OCR için ~200 dpi PNG'ye çevirir. */
export async function renderPdfPage(buf: Buffer, page: number): Promise<Buffer> {
  const { renderPageAsImage } = await import("unpdf");
  const png = await renderPageAsImage(new Uint8Array(buf), page, { canvasImport: () => import("@napi-rs/canvas"), scale: 2.8 });
  return Buffer.from(png);
}
