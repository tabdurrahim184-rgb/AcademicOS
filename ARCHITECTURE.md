# Mimari ve teknoloji kararları

## Başlangıç durumu (depo incelemesi, 10 Ekim 2026)

- Depoda yalnızca bir **iOS (SwiftUI) prototipi** vardı: yerel SQLite, Keychain, Firebase AI/Apple
  Foundation Models denemeleri, NEU portal WebKit bağlayıcısı, Swift testleri ve bir HTML önizleme.
- Web uygulaması, bulut veritabanı, sunucu tarafı kimlik doğrulama yoktu.
- Kodda gerçek gizli anahtar bulunmadı (yalnızca test fikstürlerinde sahte parolalar).
  `GoogleService-Info.plist` zaten `.gitignore` içinde.
- Swift kodu bu Linux ortamında derlenemedi; iOS durumu doğrulanmadı ve değiştirilmedi.

Karar: iOS kodu korunur; bulut web uygulaması bağımsız olarak `web/` altında geliştirilir.

## Genel yapı

```
Tarayıcı (masaüstü / mobil)
   │  HTTPS, httpOnly oturum çerezi
   ▼
Next.js 15 (App Router, React Server Components, Server Actions) — tek Node.js süreci
   ├─ src/lib/auth-core.ts     kimlik doğrulama (scrypt, oturum tablosu, hız sınırı)
   ├─ src/lib/db.ts            withUser(): her istek bir işlemde, app.user_id ayarlı
   ├─ src/lib/data/*           veri erişimi (dersler, kaynaklar, oturumlar, sorular, yedek…)
   ├─ src/lib/extract.ts       PDF/DOCX/PPTX/TXT/SRT/VTT metin çıkarma, dosya imzası doğrulama
   ├─ src/lib/sm2.ts           SM-2 aralıklı tekrar (deterministik)
   ├─ src/lib/grading.ts       nesnel soru değerlendirme (Türkçe normalleştirme)
   ├─ src/lib/recommend.ts     "Şimdi ne çalışmalısın?" kural motoru
   ├─ src/lib/planner.ts       14 günlük planlayıcı (saf, deterministik)
   ├─ src/lib/planner-demand.ts gerçek durumdan çalışma talepleri
   ├─ src/lib/mastery.ts       hedef/kavram ustalığı, çalışma adımları
   ├─ src/lib/ics.ts           iCalendar üretimi
   ├─ src/lib/source-audit.ts  kaynak denetimi
   └─ src/lib/ai/*             sağlayıcıdan bağımsız yapay zekâ katmanı (Anthropic / OpenAI)
   ▼
PostgreSQL 16  (Row Level Security + FORCE; uygulama rolü RLS'yi atlayamaz)
```

## Teknoloji seçimleri ve gerekçeler

| Karar | Gerekçe |
|---|---|
| **Next.js 15 + React 19 + TypeScript** | Sunucu bileşenleri sayesinde veri ve gizli anahtarlar tarayıcıya çıkmaz; Server Actions yerleşik CSRF (Origin) korumasıyla gelir; tek dağıtım birimi. 15.5.27 sürümü kritik RSC güvenlik açığı (GHSA-9qr9-h5gf-34mp) için yamalı sürümdür. |
| **Tailwind CSS 3** | Tutarlı, hafif arayüz; açık/koyu tema `prefers-color-scheme` ile. |
| **PostgreSQL + `pg` (ORM yok)** | Şema elle yazılmış SQL migration'larıyla açık ve denetlenebilir. RLS'nin işlem değişkeniyle (`set_config('app.user_id', …, true)`) çalışması için bağlantı kontrolü gerekiyordu. |
| **Supabase yerine kendi kimlik doğrulama** | Supabase hesabı açmak dış hizmet/olası ücret onayı gerektirir. Uygulama herhangi bir yönetilen PostgreSQL'e (Supabase dahil) taşınabilir; yalnızca `DATABASE_URL` değişir. Parolalar scrypt (N=16384) ile özetlenir, oturum belirteçlerinin yalnızca SHA-256 özeti saklanır. |
| **Dosyalar PostgreSQL `bytea` içinde** | Tek kullanıcı ve 25 MB sınırı için en basit ve tutarlı çözüm: yükleme, metin çıkarma ve kayıt tek işlemde; yedek dosyaları da içerir; sunucusuz/kalıcı diski olmayan barındırmada çalışır. Ses/video ve büyük arşiv geldiğinde nesne depolamaya (S3 uyumlu) geçilecek. |
| **Tam metin arama: PostgreSQL `turkish` sözlüğü + ILIKE** | Ek servis gerektirmez; Türkçe kök bulma ve alt dize araması birlikte. Vektör arama henüz gerekli görülmedi. |
| **unpdf (pdf.js), mammoth, JSZip** | Saf JavaScript, yerel bağımlılık yok. PPTX metni DrawingML'den doğrudan okunur. |
| **SM-2** | Belgelenmiş, basit, deterministik; birim testleriyle doğrulandı. FSRS daha isabetli olabilir ancak parametre eğitimi için kullanım verisi gerekir — sonraki aşamada değerlendirilecek. |
| **Vitest + Playwright** | Birim/entegrasyon testleri gerçek PostgreSQL'e karşı; uçtan uca testler gerçek Next.js sunucusuna karşı. |

## Güvenlik

- **Veri izolasyonu:** Kullanıcıya ait 15 tablonun tamamında `ENABLE` + `FORCE ROW LEVEL SECURITY`
  ve `user_id = app_current_user()` politikası (USING + WITH CHECK). Uygulama `NOSUPERUSER NOBYPASSRLS`
  bir rolle bağlanır; testler bunu doğrular. Kullanıcı bağlamı olmadan hiçbir satır görünmez.
- **Sunucu tarafı yetki:** Her sayfa/eylem `requireUser()` ile başlar; üst kayıt (ders/konu/kaynak)
  sahipliği eklemeden önce RLS altında yeniden okunarak doğrulanır.
- **Dosya yükleme:** uzantı + dosya imzası (magic bytes) birlikte doğrulanır, 25 MB sınırı, dosya adı
  temizlenir; indirmede `Content-Disposition`, `nosniff`, PDF dışı türlerde `CSP: sandbox`.
- **Oturum:** httpOnly, SameSite=Lax, üretimde Secure çerez; 30 gün; çıkışta sunucudan silinir.
- **Hız sınırı:** e-posta+IP başına 15 dakikada 8 başarısız giriş.
- **Gizli anahtarlar:** yalnızca sunucu ortam değişkenlerinde; `.env*` git dışında.
- **İstem enjeksiyonu:** kaynak metinleri `<kaynak>` etiketleri içinde "yalnızca veri" olarak verilir,
  etiket kaçış girişimleri etkisizleştirilir; modelin ürettiği atıflar yalnızca gerçekten var olan
  kaynak parçalarına eşlenir.
- **Güvenlik başlıkları:** X-Frame-Options DENY, nosniff, Referrer-Policy, Permissions-Policy.

## Planlayıcı

- **Talep üretimi** (`planner-demand.ts`) gerçek durumdan çalışır: konu durumu (materyal eksik → temin,
  materyal alındı → konuyu çalış, okundu → aktif hatırlama, tekrar gerekiyor → eksik tamamlama),
  telafi işareti (öncelik +10), vadesi gelen tekrar kartları, her ders oturumundan sonra 2 gün içinde
  gözden geçirme, tarihi bilinen sınavlar için 3 hazırlık oturumu. Tarihsiz sınav planlanmaz.
- **Yerleştirme** (`planner.ts`): öncelik → son tarih → anahtar sırasıyla, gün gün açgözlü yerleştirme.
  Kurallar katıdır: çalışma aralıkları, ders saatleri (+mola), günlük kapasite, telafi payı (%),
  ders başına 120 dk, aynı konu günde bir kez, son tarih. Sığmayan talepler gerekçesiyle döner.
- **Kalıcılık** (`data/plan.ts`): otomatik ve tamamlanmamış görevler her gün (veya durum değişince)
  silinip yeniden üretilir; tamamlanan, kullanıcının taşıdığı/eklediği (kilitli) görevlere dokunulmaz.
  Durum değiştiren her veri işlemi planı "eskimiş" işaretler.
- Saat dilimi: tarih hesapları `YYYY-MM-DD` dizgileriyle UTC'de; "bugün" ve "şu an" Europe/Nicosia'dan alınır.

## Yapay zekâ entegrasyonu

- `src/lib/ai/config.ts`: yapılandırma, **varsayılan model yok**, desteklenen Anthropic modelleri ve
  resmî fiyatları (10 Ekim 2026), günlük istek ve aylık bütçe sınırları.
- `src/lib/ai/usage.ts`: her çağrıdan önce sınır kontrolü, sonra kullanım kaydı (`ai_usage`).
- `src/lib/ai/provider.ts`: Anthropic (resmî `@anthropic-ai/sdk`, uyarlanabilir düşünme, varsayılan
  `effort: low`, istem önbelleği, desteklenen modellerde sunucu tarafı reddetme yedeği) ve OpenAI
  (resmî `openai` SDK, Responses API).
- **Abonelikler API erişimi sağlamaz.** OpenAI ve Anthropic yardım merkezleri, ChatGPT Plus ve Claude
  Pro/Max aboneliklerinin API kullanımını içermediğini, API'nin ayrı faturalandığını belirtir.
  Oturum çerezi kullanımı veya resmî olmayan yollar uygulanmadı.
- Yapılandırma yoksa yapay zekâ özellikleri kapalıdır ve arayüz bunu açıkça gösterir.
- Öğrenci mesajı yapay zekâ çağrısından önce ayrı işlemde kaydedilir (bağlantı koparsa kaybolmaz).
- Üretilen sorular şema ve cevap anahtarı doğrulamasından geçmeden kaydedilmez; `origin = yapay_zeka`.

## Saat dilimi

Kullanıcı saat dilimi `Europe/Nicosia`; yaz/kış saati `Intl` ile hesaplanır. Ders saatleri yerel saat
(`time`), sınav tarihleri UTC `timestamptz` olarak saklanır.

## Dağıtım (henüz yapılmadı)

Herhangi bir Node.js barındırıcısı + yönetilen PostgreSQL yeterlidir (ör. Vercel/Fly.io/Render +
Supabase/Neon/RDS). Yayına almadan önce: ayrı üretim veritabanı ve rolleri, `ALLOW_REGISTRATION=false`
(tek kullanıcı), otomatik veritabanı yedeği, HTTPS. Bu adımlar ücret ve hesap gerektirdiği için
kullanıcı onayı bekliyor.
