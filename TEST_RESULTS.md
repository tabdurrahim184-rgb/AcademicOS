# Gerçek test sonuçları

**Son çalıştırma:** 10 Ekim 2026 · **Ortam:** Claude Code bulut geliştirme konteyneri (Linux), Node.js 22.22,
PostgreSQL 16.15 (gerçek sunucu), Chromium 141 (Playwright 1.56.1) · **Dal:** `claude/optimistic-newton-lqcwno`

Canlı (yayındaki) bir ortam yoktur; bütün sonuçlar geliştirme konteynerinde ve GitHub Actions'ta alınmıştır.

## Kalite kapıları

| Kontrol | Komut | Sonuç |
|---|---|---|
| ESLint (0 uyarı) | `npm run lint` | ✅ |
| TypeScript | `npm run typecheck` | ✅ |
| Birim + entegrasyon | `npm test` | ✅ 15 dosya, **104/104** |
| Üretim derlemesi | `npm run build` | ✅ |
| Uçtan uca | `npm run test:e2e` | ✅ **9/9** (masaüstü 6, yapay zekâ akışı 1, mobil 2) |
| GitHub Actions `web-ci.yml` | push + pull_request | ✅ (çalıştırma #1, #3, #4 başarılı) |
| GitHub Actions `ios-build.yml` (PR tetikledi) | | ✅ (çalıştırma #9) — iOS koduna dokunulmadı |

İlk sürümdeki 57 birim/entegrasyon ve 6 uçtan uca test korunmuştur (hepsi geçiyor; iki e2e testine yalnızca yeni adımlar eklendi).

## Bu aşamada bulunan ve düzeltilen hatalar

1. **Aralıklı başarısız test / belirsiz sıralama:** Aynı işlemde eklenen satırlar `now()` nedeniyle aynı zaman damgasını alıyordu; soru sırası rastgeleleşebiliyordu. `004_stable_ordering.sql` ile `clock_timestamp()`; test 5 kez art arda çalıştırılarak doğrulandı.
2. **Güvenlik — FK'ler RLS'yi atlıyordu:** Başka kullanıcının UUID'si bilinirse ona referans veren satır eklenebilirdi (uygulama katmanı engelliyordu, veritabanı engellemiyordu). `002_ownership_fks.sql` ile bütün ilişkiler (kolon, user_id) çiftine bağlandı; entegrasyon testi doğrudan SQL ile denemenin `foreign key` hatasıyla reddedildiğini doğrular.
3. **Güvenlik — X-Forwarded-For sahteciliği:** Giriş hız sınırı başlık değiştirilerek atlatılabilirdi. Artık yalnızca `TRUST_PROXY=true` iken (vekilin eklediği son adres) kullanılır.
4. **Yedek eksikliği:** Yeni tablolar yedeğe girmiyordu; yedek biçimi sürüm 2'ye yükseltildi, sürüm 1 yedekleri hâlâ yüklenebiliyor (testli).
5. **Planlayıcı önceliği:** Telafi görevleri güncel derslerin gözden geçirmesini 2 gün ileri itiyordu; öncelik düzeltildi ve "≥ %75 aynı gün, taşanlar yalnızca Cuma (5 ders 17.30'a kadar)" testi eklendi.
6. **Kullanıcının taşıdığı görev** otomatik bir görevle aynı saate denk geldiğinde reddediliyordu; artık kullanıcı kararı önceliklidir, otomatik görev yeniden yerleştirilir.

## Ayrıntılı kapsam

### Birim (ağ ve veritabanı yok)
- `planner.test.ts` (14): 9 dersin gerçek programıyla — yalnızca çalışma aralıkları, ders saatiyle çakışmama, görevler arası mola, günlük kapasite, telafi payı, ders başına 120 dk, aynı konu günde bir kez, birikimin güne yığılmaması, ders sonrası gözden geçirme (≥%75 aynı gün), sınav hazırlığının sınavdan önce bitmesi, tarihsiz sınava tarih uydurmama, vadesi geçmiş tekrarın bugüne alınması, determinizm, tamamlananın yeniden üretilmemesi, kilitli görevin kapasiteden düşülmesi, "şu andan önce" kuralı, sıfır kapasite, uzun görevin parçalanması.
- `ics.test.ts` (5): CRLF, VTIMEZONE, yerel saat, tekrar sonu uydurmama, kaçış, 75 oktet katlama (UTF-8 güvenli).
- `mastery.test.ts` (5): en son cevap, ustalık düzeyleri (tahminle doğru "öğrenildi" sayılmaz), kavram sıralaması, adımlar, eminlik → SM-2 kalitesi.
- `source-audit.test.ts` (3), `ai-config.test.ts` (5: varsayılan model yok, desteklenmeyen model reddi, fiyat/maliyet, günlük/aylık sınır).
- Önceki: `sm2` (6), `grading` (6), `extract` (12), `schedule` (5), `prompts` (6), `recommend` (8).

### Entegrasyon (gerçek PostgreSQL, RLS'ye tabi uygulama rolü)
- `planner.test.ts` (6): plan üretimi ve kuralları, tamamlama → konu durumunun ilerlemesi ve sonraki adımın planlanması, ertesi gün yeniden planlama + taşınan/eklenen görevin korunması + ders saatine taşıma reddi, kapasite değişikliği, kullanıcı izolasyonu ve sahiplik FK'si, erteleme.
- `calendar.test.ts` (1): 12 haftalık ders oturumu, Cuma çakışmaları, Kıbrıs saatiyle sınav (07:00Z → 10:00), "Tarih bekleniyor", plan görevleri.
- `learning.test.ts` (4): hedef ustalığı, yanlış konuya hedef bağlama reddi, eminliğe göre aralık (emin > kısmen > tahmin), kavram yanılgısı, kaynak denetimi ve düzeltme, başka dersin konusuna bağlama reddi.
- `academic.test.ts` (19): ilk sürümün 15 testi + yedek sürüm 2, yapay zekâ kullanım kaydı ve günlük sınır (sınırda sağlayıcı çağrılmaz, başarısız çağrı da kaydedilir), öğretmen istemi içeriği, yanlış açıklaması, eksik kavramların yanlışlar defterine yazılması.

### Uçtan uca (gerçek Next.js üretim sunucusu)
1–4. İlk sürüm kabul akışı, Test G (HTTP), Test K/L, Test J.
5. Telafi konusu ekleme → plan (14 gün, kapasite ≤ sınır) → görev tamamlama → ders saatine taşıma reddi → takvim (Salı dersi, Cuma çakışmaları) → `.ics` indirme.
6. Konu sayfası: adımlar, hedef ekleme, hedefe bağlı soru, "Soruları çöz" oturumu, emin olunarak yanlış → kavram yanılgısı uyarısı, yanlışlar defteri ve telafi sayfasında görünmesi.
7. Yapay zekâ akışı (yerel Anthropic API **test ikizi**): öğretim, atıf, soru üretimi, açık uçlu değerlendirme, yanlış açıklaması, kullanım sayacı.
8–9. Mobil (Pixel 7): menü; plan/takvim/telafi/ayarlar/çalış sayfalarında yatay taşma yok.

## Doğrulanamayanlar (açıkça)

- **Gerçek yapay zekâ sağlayıcısı:** hiçbir ücretli API çağrısı yapılmadı (onay ve anahtar yok). İstek biçimi resmî SDK tiplerine göre derleniyor; canlı API'nin kabul ettiği, yanıt kalitesi, atıf oranı ve "yalnızca kaynak" uyumu **ölçülmedi**.
- **OpenAI fiyatları ve model kimlikleri:** resmî fiyat sayfasına bu konteynerden erişilemedi (DNS hatası); yalnızca arama sonuçlarında görüldü. Uygulamada OpenAI için yerleşik fiyat yoktur.
- **Test I** (iş görevleri): iş merkezi yok.
- Gerçek mobil cihaz, ekran okuyucu ve yük/performans testi yapılmadı.
- `npm audit`: Next.js'in derleme zamanı `postcss` kopyası ve `mammoth → argparse → sprintf-js` için uyarılar sürüyor.
