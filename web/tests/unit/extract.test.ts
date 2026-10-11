import { readFileSync } from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { chunkParagraphs, decodeText, detectFileType, extractContent, parseSubtitles, UploadError } from "@/lib/extract";

const fx = (f: string) => readFileSync(path.join(__dirname, "..", "fixtures", f));

async function load(name: string) {
  const buf = fx(name);
  return extractContent(await detectFileType(name, buf), buf);
}

describe("PDF", () => {
  it("gerçek PDF'ten sayfa numaralarıyla Türkçe metin çıkarır", async () => {
    const r = await load("siyasal-iletisim-hafta3.pdf");
    expect(r.status).toBe("tamam");
    expect(r.unitCount).toBe(2);
    expect(r.chunks.map((c) => c.locator)).toEqual(["Sayfa 1", "Sayfa 2"]);
    expect(r.chunks[0].content).toContain("Gündem belirleme kuramı");
    expect(r.chunks[1].content.replace(/\s+/g, " ")).toContain("ğ ü ş ı ö ç İ Ğ Ü Ş Ö Ç");
  });
  it("metin içermeyen PDF'i 'metin_yok' olarak işaretler ve OCR sınırını açıklar", async () => {
    const r = await load("metinsiz.pdf");
    expect(r.status).toBe("metin_yok");
    expect(r.note).toContain("OCR");
  });
  it("bozuk PDF hata durumuna düşer, uygulama çökmez", async () => {
    const r = await load("bozuk.pdf");
    expect(r.status).toBe("hata");
  });
});

describe("Office belgeleri", () => {
  it("DOCX metnini bölümlere ayırır, sayfa numarası uydurmaz", async () => {
    const r = await load("iletisim-etigi.docx");
    expect(r.status).toBe("tamam");
    expect(r.chunks[0].locatorType).toBe("bolum");
    expect(r.chunks[0].content).toContain("kaynak gizliliği");
  });
  it("PPTX slaytlarını sayısal sırayla ve slayt numarasıyla okur", async () => {
    const r = await load("hak-odakli.pptx");
    expect(r.chunks.map((c) => c.locator)).toEqual(["Slayt 1", "Slayt 2", "Slayt 10"]);
    expect(r.chunks[1].content).toContain("Nefret söylemi & ayrımcılık");
  });
  it("uzantısı DOCX olan ama ZIP olmayan dosyayı reddeder", async () => {
    await expect(detectFileType("sahte.docx", fx("sahte.docx"))).rejects.toBeInstanceOf(UploadError);
  });
});

describe("Altyazı ve metin", () => {
  it("SRT zaman damgalarını korur ve 60 sn'lik gruplara ayırır", async () => {
    const r = await load("ders-kaydi.srt");
    expect(r.chunks.map((c) => c.locator)).toEqual(["00:00:01–00:00:04", "00:01:05–00:01:09"]);
  });
  it("VTT başlık ve konuşmacı etiketlerini temizler", () => {
    const { chunks } = parseSubtitles(fx("ders-kaydi.vtt").toString("utf8"), "vtt");
    expect(chunks[0].content).toBe("Kıbrıs basın tarihi.");
  });
  it("Windows-1254 kodlu Türkçe metni doğru çözer", () => {
    expect(decodeText(fx("windows1254.txt"))).toBe("Gündem şğıİ");
  });
  it("uzun metni paragraflardan böler", () => {
    const text = Array.from({ length: 10 }, (_, i) => `Paragraf ${i} ` + "kelime ".repeat(60)).join("\n\n");
    const parts = chunkParagraphs(text, 1000);
    expect(parts.length).toBeGreaterThan(3);
    expect(parts.every((p) => p.length <= 1000)).toBe(true);
  });
  it("boş ve desteklenmeyen dosyaları reddeder", async () => {
    await expect(detectFileType("a.pdf", Buffer.alloc(0))).rejects.toThrow("boş");
    await expect(detectFileType("a.exe", Buffer.from("MZ"))).rejects.toThrow("Desteklenmeyen");
  });
});
