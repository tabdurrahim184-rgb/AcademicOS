# Gerçek test sonuçları

**Son çalıştırma:** 10–11 Ekim 2026 · Node.js 22.22 · PostgreSQL 16.15 (gerçek sunucu) · Chromium 141 (Playwright 1.56.1)
· ffmpeg 6.1 · Tesseract (tesseract.js 7, Türkçe dil verisi) · Dal: `claude/optimistic-newton-lqcwno`

## Kalite kapıları

| Kontrol | Sonuç |
|---|---|
| ESLint (0 uyarı) | ✅ |
| TypeScript | ✅ |
| Birim + entegrasyon (`npm test`) | ✅ 21 dosya, **131/131** |
| Üretim derlemesi | ✅ |
| Uçtan uca (`npm run test:e2e`) | ✅ **14/14** |
| GitHub Actions | Son gönderimden sonra kontrol edilecek (önceki tüm koşular ✅) |

Önceki 104 birim/entegrasyon ve 9 tarayıcı testi korunmuştur; hiçbiri silinmedi veya devre dışı bırakılmadı.
Bir test sürüm numarasını sabit "2" bekliyordu; yedek biçimi bilinçli olarak 3'e yükseltildiği için geçerli sürüm sabitine bağlandı.

## Bu turda eklenen testler

- `lms.test.ts` (5): AES-256-GCM şifreleme/bozulma tespiti, DEBİM adres doğrulama (SSRF), hafta çıkarımı, ZIP ayrıştırma.
- `debim.test.ts` (3, Moodle REST **test ikizi**): geçersiz anahtar reddi; bağlantı, anahtarın şifreli saklanması, ders eşleştirme, bölüm → konu/hafta, desteklenmeyen dosya atlama, aynı içeriğin yinelenen sayılması, ikinci aktarımda yeniden indirme olmaması, bağlantı kaldırılınca anahtarın silinmesi; kullanıcı izolasyonu.
- `providers.test.ts` (4): Gerçek OpenAI ve Anthropic SDK sınıfları yerel sunuculara karşı — OpenAI Responses isteği (`instructions`, `store:false`), token ayrıştırma, 401'in anahtar sızdırmadan Türkçe hataya çevrilmesi; Anthropic (uyarlanabilir düşünme, efor, önbellek, yedek yönlendirme başlığı; Haiku'da yedek gönderilmemesi; reddetme).
- `ocr.test.ts` (2): **gerçek** Tesseract ile görselden ve metin katmanı olmayan PDF'ten Türkçe metin.
- `work-schedule.test.ts` (5): **Test I** — 500'den fazla senaryoda hafta içi 08.30–18.00'e iş konmaması; ders/taahhüt/diğer işlerle çakışmama; günlük iş sınırı; etkilenen çalışmaların listelenmesi.
- `modules.test.ts` (8): ZIP içe aktarma (yinelenen ve bozuk dosya), OCR işi (kuyruk, çift iş engeli, düzenleme + ham çıktı), deşifre işi (gerçek ffmpeg + OpenAI test ikizi, segmentler, düzenleme, SRT/VTT/DOCX), iptal, izolasyon, Bölüm Projesi → plan/takvim, tartışma kaynak doğrulaması, İş Merkezi (seed, çakışma, analiz, planlama, planın işle çakışmaması, geçmiş, dakika listesi), yedek sürüm 3.
- e2e `moduller.spec.ts` (5): DEBİM bağlantı/aktarım (test ikizi), ZIP içe aktarma, OCR (gerçek), kayıt yükleme + Range oynatma, proje/tartışma/iş merkezi. `mobil.spec.ts` yeni sayfalarda yatay taşma kontrolü.

## Bu turda bulunan ve düzeltilen hatalar

1. Next.js paketleyicisi yerel `@napi-rs/canvas` ikilisini paketlemeye çalışıyordu → `serverExternalPackages`.
2. OCR dil yolu, paketlenmiş sunucuda `require.resolve` modül numarasına dönüştüğü için bozuluyordu → çalışma dizini tabanlı yol (`OCR_LANG_PATH` ile değiştirilebilir).
3. İki e2e testi tarayıcı yerel tarihini `toISOString()` ile UTC'ye çevirdiği için Kıbrıs'ta gece yarısından sonra bir gün kayıyordu → yerel tarih biçimi.
4. Yedeğin geri yüklenmesi 26 MB'lık sunucu eylemi sınırına takılabilirdi → ayrı uç nokta (aynı köken kontrolüyle).

## Doğrulanamayanlar

- **Gerçek DEBİM**: konteynerin ağ politikası `debim.neu.edu.tr`'yi engelliyor; üniversitenin web servis/anahtar sayfasını açık tutup tutmadığı bilinmiyor.
- **Gerçek OpenAI / Anthropic** (öğretmen ve deşifre): ücretli API çağrısı yapılmadı; yanıt kalitesi ve Türkçe deşifre doğruluğu ölçülmedi.
- **Docker imajı**: `docker compose config` doğrulandı; bu ortamda Docker sunucusu olmadığı için imaj derlenmedi.
- Gerçek mobil cihaz, ekran okuyucu ve yük testi.
