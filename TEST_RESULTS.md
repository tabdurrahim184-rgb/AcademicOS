# Gerçek test sonuçları

**Tarih:** 10 Ekim 2026 · **Ortam:** Claude Code bulut geliştirme konteyneri (Linux), Node.js 22.22,
PostgreSQL 16.15 (yerel, gerçek sunucu), Chromium 141 (Playwright 1.56.1) · **Dal:** `claude/optimistic-newton-lqcwno`

Bu sonuçlar geliştirme konteynerinde alınmıştır; canlı (yayındaki) bir ortam yoktur.

## Kalite kapıları

| Kontrol | Komut | Sonuç |
|---|---|---|
| ESLint (0 uyarı sınırı) | `npm run lint` | ✅ Geçti |
| TypeScript | `npm run typecheck` | ✅ Geçti |
| Birim + entegrasyon | `npm test` | ✅ 7 dosya, **57/57** test geçti |
| Üretim derlemesi | `npm run build` | ✅ Geçti |
| Uçtan uca (Playwright) | `npm run test:e2e` | ✅ **6/6** test geçti (masaüstü, yapay zekâ akışı, mobil Pixel 7) |

## Ayrıntı

### Birim (gerçek dosyalarla, ağ yok)
- `sm2.test.ts` (6): aralık dizisi 1→6→16, sıfırlama, EF alt sınırı 1.3, determinizm, geçersiz girdi.
- `grading.test.ts` (6): İ/ı Türkçe küçültme, çoktan seçmeli, D/Y, kısa cevap, eşleştirme kısmi puan.
- `extract.test.ts` (12): Chromium ile üretilmiş 2 sayfalık Türkçe PDF → "Sayfa 1/2"; metinsiz PDF → OCR uyarısı;
  bozuk PDF → hata durumu; DOCX; PPTX (slayt 1, 2, 10 sayısal sıra); sahte DOCX reddi; SRT/VTT zaman
  damgaları; Windows-1254 Türkçe metin; boş/desteklenmeyen dosya.
- `schedule.test.ts` (5): 9 ders, bilinmeyen öğretim elemanı NULL, 2 çakışma, Kıbrıs yaz/kış saati, 08.30–18.00 koruması.
- `prompts.test.ts` (6): etiket kaçışı engeli, sahte atıf ([K9]) reddi, yalnızca-kaynak istemi, rol birleştirme, JSON ayrıştırma.
- `recommend.test.ts` (8): öneri öncelikleri, tarihsiz sınav önceliği almaz, gereken not hesabı.

### Entegrasyon (gerçek PostgreSQL `academicos_test`, RLS'ye tabi uygulama rolü)
- Test A: kayıt, büyük/küçük harf duyarsız giriş, oturum çözümü, 9 ders, 2 çakışma; hız sınırı (8 hatadan sonra kilit, farklı IP etkilenmez); yinelenen e-posta reddi.
- Test B/K: PDF bayt bayt geri okuma, sayfa konumları, "çerçeveleme" ve "İLETİŞİM" araması, konu durumu "materyal alındı".
- Test L: sahte DOCX `UploadError`, bozuk PDF "hata" durumuyla kaydedilir.
- Test C/D/E/F: oturum + yanlış cevap → yanlışlar defteri, SM-2 kartı (1 gün sonra), konu "tekrar gerekiyor";
  havuz kapatılıp yeniden girişte oturum/cevap/yanlış korunur; doğru cevapla yanlış "çözüldü".
- Açık uçlu: öz değerlendirme, çift değerlendirme engeli.
- Test G: B kullanıcısı A'nın dersini/dosyasını/arama sonucunu göremez; UPDATE/DELETE 0 satır; başka kullanıcı adına INSERT RLS hatası; bağlamsız sorgu 0 satır; uygulama rolü `rolsuper=false, rolbypassrls=false`.
- Test H: yapay zekâ bağlantı hatasında öğrenci mesajı kalır, sahte öğretmen yanıtı oluşmaz; bağlantı varken kaynak bağlamı ve doğrulanmış atıf kaydı; geçersiz cevap anahtarlı üretilmiş soru reddi; açık uçlu yapay zekâ puanlaması.
  *(Sağlayıcı yerine test ikizi kullanıldı.)*
- Test J: yedek başka hesaba geri yüklenir (yeni kimlikler, dosya baytları, oturum-kaynak ilişkisi, arama); bozuk yedek reddedilir ve mevcut veri korunur.

### Uçtan uca (gerçek Next.js üretim sunucusu + PostgreSQL `academicos_e2e`)
1. Kabul akışı 1–16 (yapay zekâ kapalı) — ✅
2. Test G (HTTP): başka kullanıcıya kaynak sayfası 404, dosya 404, arama 0 sonuç; oturumsuz 401 — ✅
3. Test K/L: "ÇERÇEVELEME" araması ve vurgulama; sahte DOCX hata mesajı; metinsiz PDF uyarısı — ✅
4. Test J: yedek indirme, yanlış onay metni reddi, geri yükleme — ✅
5. Yapay zekâ akışı (yerel Anthropic API test ikizi): "Bana bu konuyu öğret" → [K1] Sayfa 1 atıflı yanıt → sohbet → soru üretimi → açık uçlu yapay zekâ değerlendirmesi — ✅
6. Mobil (Pixel 7): menü çalışır, yatay taşma yok — ✅

## Doğrulanamayanlar (açıkça)

- **Gerçek yapay zekâ sağlayıcısı** (Anthropic/OpenAI) ile hiçbir çağrı yapılmadı; API anahtarı yok ve
  ücretli kullanım onayı alınmadı. İstek biçimi resmî SDK tiplerine göre derleniyor ancak canlı API
  tarafından kabul edildiği doğrulanmadı. Öğretim kalitesi ölçülmedi.
- **Test I** (iş görevi zaman koruması): iş merkezi henüz yok.
- **iOS prototipi**: Linux konteynerde derlenemez; bu çalışmada dokunulmadı ve test edilmedi.
- **GitHub Actions `web-ci.yml`**: dosya eklendi, ancak GitHub üzerinde henüz çalışırken gözlenmedi.
- **Performans / yük testi** ve gerçek mobil cihaz testi yapılmadı (yalnızca Chromium mobil emülasyonu).
- `npm audit`: Next.js'in derleme zamanı `postcss` kopyası ve `mammoth` → `argparse` → `sprintf-js`
  için bilinen orta/yüksek uyarılar var; çalışma zamanında kullanıcı girdisiyle tetiklenen bir yol
  tespit edilmedi, ancak sürüm güncellemeleriyle izlenmeli.
