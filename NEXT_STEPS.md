# Sonraki adımlar

## Kullanıcı kararı gerektirenler

1. **Yapay zekâ sağlayıcısı ve bütçe.** Anthropic veya OpenAI API hesabı açılması, anahtarın sunucuya
   eklenmesi ve aylık harcama sınırı belirlenmesi. (Varsayılan model `claude-opus-5-5`: girdi 4 $/1M,
   çıktı 20 $/1M token. Daha düşük maliyet için `AI_MODEL=claude-sonnet-5-5` seçilebilir.)
2. **Canlı barındırma.** Node.js barındırıcısı + yönetilen PostgreSQL seçimi (ör. Vercel + Neon/Supabase),
   alan adı, otomatik yedek. Hesap açma ve olası ücret onayı gerekiyor.
3. **Depo görünürlüğü.** Depo herkese açıksa kişisel dosyaların depoya eklenmemesi.

## Geliştirme (öncelik sırasıyla)

1. Gerçek sağlayıcıyla yapay zekâ doğrulaması: istek biçimi, atıf oranı, "yalnızca kaynak" uyumu için küçük bir değerlendirme seti.
2. Yayına hazırlık: üretim migration süreci, `ALLOW_REGISTRATION=false`, hata kaydı, otomatik veritabanı yedeği ve geri yükleme provası.
3. **PHASE 3:** kapasite modeli (hafta içi 08.30–18.00 akademik koruma, akşam sınırı, hafta sonu), 14 günlük telafi planlayıcısı, takvim görünümü, ICS dışa aktarma, Bölüm Projesi çalışma alanı.
4. Parola sıfırlama, hesap verisini silme, oturum listesi.
5. **PHASE 4:** sözlü sınav provası, gazetecilik vaka analizi şablonları, öğrenme analitiği; FSRS değerlendirmesi.
6. **PHASE 5:** OCR ve transkripsiyon (iş kuyruğu + nesne depolama), İslam düşüncesiyle akademik tartışma alanı (ayrı kategori, kaynak doğrulama), iş merkezi (Ahmet Özsoy / Hasan Bey) ve "bu işi alırsam hangi çalışma etkilenir?" hesabı.
7. Bağımlılık güvenlik uyarılarının takibi (`npm audit`), Next.js 16'ya geçiş değerlendirmesi.
