# Sonraki adımlar

## Senin kararını bekleyenler

1. **Yapay zekâ sağlayıcısı, model ve bütçe** (ücretli). Öneri: ilk deneme için `claude-haiku-5-5`
   (1M token: 0,10 $ girdi / 0,50 $ çıktı), `AI_MONTHLY_BUDGET_USD=5` ve `AI_DAILY_REQUEST_LIMIT=50`.
   Kalite yetersizse `claude-sonnet-5-5`'e (2 $ / 10 $) geçilir. Onay verirsen: anahtarı sunucu ortamına
   sen eklersin, ardından küçük bir gerçek doğrulama seti (5–10 istek, birkaç sent) çalıştırılır.
2. **Canlı barındırma** (hesap ve olası ücret): Node.js barındırıcısı + yönetilen PostgreSQL.
3. **PR #1**: CI yeşil; incelemeden sonra `main`'e birleştirme kararı sende.

## Geliştirme sırası

1. Gerçek sağlayıcıyla doğrulama (onaydan sonra): istek biçimi, atıf oranı, "yalnızca kaynak" uyumu, Türkçe kalite, maliyet ölçümü.
2. Bölüm Projesi (GZT440) çalışma alanı: araştırma soruları, yöntem, kaynakça, danışman görüşmeleri, taslak/teslim takibi (plana bağlı).
3. Dönem başlangıç tarihi ayarı → hafta numaralarının takvim tarihleriyle eşlenmesi.
4. Sözlü sınav provası ve öğrenme analitiği (haftalık doğruluk, tekrar uyumu).
5. Parola sıfırlama, hesap silme, oturum yönetimi; yayına hazırlık (`ALLOW_REGISTRATION=false`, otomatik yedek).
6. İş merkezi ve Test I (akademik saatlere iş görevi atanmaması), İslam düşüncesi tartışma alanı, OCR/transkripsiyon.
