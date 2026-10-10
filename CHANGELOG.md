# Değişiklik günlüğü

## [web 0.2.0] — 2026-10-10

### Güvenlik
- Bütün kullanıcı ilişkilerine (kolon, user_id) sahiplik FK'leri: FK kontrolleri RLS'yi atladığı için başka kullanıcının kaydına referans veritabanı düzeyinde engellendi.
- `X-Forwarded-For` yalnızca `TRUST_PROXY=true` iken kullanılır (hız sınırı atlatılamaz).

### Eklendi
- **14 günlük çalışma planı** (`/plan`): deterministik planlayıcı; çalışma aralıkları, ders saatleri, günlük kapasite, telafi payı, mola, son tarih kuralları; tamamla / ertele / taşı / sabitle / kendi görevini ekle; sığmayanların gerekçeli listesi; günlük otomatik yeniden planlama.
- **Plan ayarları** (`/plan/ayarlar`): kapasite, görev uzunluğu, mola, telafi payı, dönem sonu, çalışma aralıkları.
- **Telafi** (`/telafi`): ders bazında eksik materyal, çalışılmamış ve konu girilmemiş haftalar, yanlışlar, kavram yanılgıları, tekrar gereken kavramlar; telafi işareti.
- **Takvim** (`/takvim`) ve `.ics` dışa aktarma (Europe/Nicosia).
- **Konu çalışma sayfası** (`/konular/[id]`): 7 adımlı çalışma yolu, öğrenme hedefleri, hedef/kavram bazlı ustalık, çalışma geçmişi.
- Cevaplarda **eminlik** bildirimi ve SM-2 kişiselleştirmesi; **kavram yanılgısı** işareti.
- **Kaynak denetimi** ve kaynak bilgisi düzeltme.
- Yapay zekâ: kullanım kaydı, günlük istek ve aylık bütçe sınırı, tahmini maliyet, yanlışların gerekçeli açıklaması, eksik kavramların yanlışlar defterine yazılması, kaynak dışı bilgi vurgusu, istem önbelleği.
- Kontrol panelinde bugünkü plan.

### Değişti
- Yapay zekâda **varsayılan model kaldırıldı**; `AI_MODEL` bilinçli seçilmelidir (desteklenen: `claude-haiku-5-5`, `claude-sonnet-5-5`, `claude-opus-5-5`, veya OpenAI modeli). Varsayılan efor `low`.
- Yedek biçimi sürüm 2 (plan, hedefler, ayarlar); sürüm 1 yedekleri yüklenebilir.
- Aynı işlemde eklenen satırların sırası kararlı (`clock_timestamp()`).

## [web 0.1.0] — 2026-10-10

İlk bulut web sürümü (`web/`). iOS prototipi değiştirilmedi.

### Eklendi
- Next.js 15 + TypeScript + Tailwind + PostgreSQL uygulama iskeleti, SQL migration ve FORCE RLS.
- Hesap, giriş/çıkış, oturum yönetimi, giriş hız sınırı.
- Dokuz dönem dersi başlangıç verisi, ders düzenleme, ders saatleri ve çakışma gösterimi.
- Konu/hafta yönetimi ve ilerleme durumları; telafi tablosu.
- Kaynak yükleme ve metin çıkarma (PDF, DOCX, PPTX, TXT/MD, SRT, VTT; görsel saklama), kaynak görüntüleyici, Türkçe arama.
- Çalışma oturumları, öğretmen sohbeti (yapay zekâ yapılandırılmışsa), soru bankası, otomatik/öz/yapay zekâ değerlendirme.
- Yanlışlar defteri ve SM-2 aralıklı tekrar.
- Kontrol paneli ve "Şimdi ne çalışmalısın?" önerisi.
- Sınav/ödev takibi ve gereken not hesabı; notlar.
- JSON yedek dışa aktarma / geri yükleme.
- Vitest birim/entegrasyon ve Playwright uçtan uca testleri; `web-ci.yml` iş akışı.
- Proje belgeleri: README, ARCHITECTURE, REQUIREMENTS, PROJECT_STATUS, TEST_RESULTS, NEXT_STEPS.
