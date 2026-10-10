/**
 * Test fikstürlerini üretir: gerçek PDF (Chromium ile), DOCX, PPTX, SRT, VTT,
 * metin içermeyen PDF ve bozuk dosyalar. Çıktı: tests/fixtures/
 */
import { mkdirSync, writeFileSync } from "node:fs";
import path from "node:path";
import JSZip from "jszip";
import { chromium } from "@playwright/test";

const out = path.join(process.cwd(), "tests", "fixtures");
mkdirSync(out, { recursive: true });

const page1 = `<h1>Siyasal İletişim — 3. Hafta</h1>
<p>Gündem belirleme kuramı, medyanın kamuoyunun neyi düşüneceğini değil, neyi düşüneceği hakkında düşüneceğini belirlediğini öne sürer.</p>
<p>McCombs ve Shaw, 1968 ABD başkanlık seçimlerinde Chapel Hill araştırmasını yürütmüştür.</p>`;
const page2 = `<h2>Çerçeveleme</h2>
<p>Çerçeveleme, bir olayın hangi yönlerinin öne çıkarılacağının seçilmesidir. Şeffaflık, ırkçılık, ğ ü ş ı ö ç İ Ğ Ü Ş Ö Ç karakterleri korunmalıdır.</p>`;

async function pdf(html: string, file: string) {
  const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH || undefined });
  const p = await browser.newPage();
  await p.setContent(`<html><head><meta charset="utf-8"></head><body style="font-family:sans-serif">${html}</body></html>`);
  writeFileSync(path.join(out, file), await p.pdf({ format: "A4" }));
  await browser.close();
}

async function main() {
  await pdf(`${page1}<div style="page-break-after:always"></div>${page2}`, "siyasal-iletisim-hafta3.pdf");
  await pdf(`<div style="width:300px;height:300px;background:#888"></div>`, "metinsiz.pdf");

  const docx = new JSZip();
  docx.file("[Content_Types].xml", `<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>`);
  docx.file("_rels/.rels", `<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>`);
  docx.file("word/document.xml", `<?xml version="1.0" encoding="UTF-8"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>
<w:p><w:r><w:t>İletişim Etiği Ders Notu</w:t></w:r></w:p>
<w:p><w:r><w:t>Gazetecinin temel ilkesi doğruluktur; kaynak gizliliği ve kamu yararı dengelenmelidir.</w:t></w:r></w:p>
</w:body></w:document>`);
  writeFileSync(path.join(out, "iletisim-etigi.docx"), await docx.generateAsync({ type: "nodebuffer" }));

  const pptx = new JSZip();
  pptx.file("[Content_Types].xml", `<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="xml" ContentType="application/xml"/></Types>`);
  pptx.file("ppt/presentation.xml", `<?xml version="1.0" encoding="UTF-8"?><p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"/>`);
  const slide = (t: string[]) => `<?xml version="1.0" encoding="UTF-8"?><p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><p:cSld><p:spTree>${t.map((x) => `<p:sp><p:txBody><a:p><a:r><a:t>${x}</a:t></a:r></a:p></p:txBody></p:sp>`).join("")}</p:spTree></p:cSld></p:sld>`;
  pptx.file("ppt/slides/slide1.xml", slide(["Hak Odaklı Habercilik", "Giriş"]));
  pptx.file("ppt/slides/slide2.xml", slide(["Nefret söylemi &amp; ayrımcılık", "Haberde dil seçimi önemlidir."]));
  pptx.file("ppt/slides/slide10.xml", slide(["Onuncu slayt: Özet"]));
  writeFileSync(path.join(out, "hak-odakli.pptx"), await pptx.generateAsync({ type: "nodebuffer" }));

  writeFileSync(path.join(out, "ders-kaydi.srt"), `1\n00:00:01,000 --> 00:00:04,000\nBugün çerçeveleme kuramını işleyeceğiz.\n\n2\n00:01:05,500 --> 00:01:09,000\nŞimdi gündem belirlemeye geçelim.\n`);
  writeFileSync(path.join(out, "ders-kaydi.vtt"), `WEBVTT\n\nNOTE başlık\n\n00:00.000 --> 00:03.000\n<v Hoca>Kıbrıs basın tarihi.\n`);
  writeFileSync(path.join(out, "bozuk.pdf"), Buffer.from("%PDF-1.7\nbu dosya bozuk\n"));
  writeFileSync(path.join(out, "sahte.docx"), Buffer.from("bu aslında bir metin dosyası"));
  writeFileSync(path.join(out, "windows1254.txt"), Buffer.from([0x47, 0xfc, 0x6e, 0x64, 0x65, 0x6d, 0x20, 0xfe, 0xf0, 0xfd, 0xdd])); // "Gündem şğıİ"
  console.log("Fikstürler üretildi:", out);
}
main().catch((e) => { console.error(e); process.exit(1); });
