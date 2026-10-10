import { readFileSync } from "node:fs";
import path from "node:path";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { createOcrWorker, ocrImage, pdfPageCount, renderPdfPage } from "@/lib/ocr";

const fx = (f: string) => readFileSync(path.join(__dirname, "..", "fixtures", f));
let worker: Awaited<ReturnType<typeof createOcrWorker>>;
beforeAll(async () => { worker = await createOcrWorker(); }, 120_000);
afterAll(async () => { await worker?.terminate(); });

describe("OCR (Tesseract, Türkçe, çevrimdışı)", () => {
  it("görselden Türkçe karakterli metni okur", async () => {
    const r = await ocrImage(worker, fx("taranmis.png"));
    expect(r.text).toMatch(/Gündem belirleme kuram/);
    expect(r.text).toMatch(/Çerçeveleme/);
    expect(r.confidence).toBeGreaterThan(60);
  }, 120_000);
  it("metin katmanı olmayan (taranmış) PDF sayfasını görüntüye çevirip okur", async () => {
    expect(await pdfPageCount(fx("taranmis.pdf"))).toBe(1);
    const png = await renderPdfPage(fx("taranmis.pdf"), 1);
    expect(png.subarray(1, 4).toString()).toBe("PNG");
    const r = await ocrImage(worker, png);
    expect(r.text).toMatch(/haberin hangi yönünün/);
  }, 120_000);
});
