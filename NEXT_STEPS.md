# Sonraki adımlar

## Senin vermen gereken izinler / bilgiler
1. **Çalıştırma yeri:** Ya kendi bilgisayarında `docker compose` (ücretsiz, yalnızca sen erişirsin) ya da bir bulut barındırma + yönetilen PostgreSQL (hesap ve olası ücret).
2. **APP_ENCRYPTION_KEY:** DEBİM bağlantısı için sunucuda 32 baytlık gizli anahtar (sen üretip ortam değişkenine eklersin).
3. **DEBİM güvenlik anahtarı:** DEBİM → Tercihler → Güvenlik anahtarları. Sayfa yoksa üniversite web servislerini kapatmıştır; ZIP içe aktarmayı kullan.
4. **Yapay zekâ (ücretli, isteğe bağlı):** `AI_PROVIDER=openai`, `OPENAI_API_KEY`, `AI_MODEL` (OpenAI model kimliğini resmî sayfadan seç), fiyatlar ve `AI_MONTHLY_BUDGET_USD`. Ardından Ayarlar → "Bağlantıyı test et".
5. **Deşifre (ücretli, isteğe bağlı):** `TRANSCRIPTION_PROVIDER=openai`, `TRANSCRIPTION_MODEL=whisper-1` (zaman damgaları için), `TRANSCRIPTION_PRICE_PER_MIN`.
6. **PR #1'in `main`'e birleştirilmesi.**

## Geliştirme
1. Gerçek sağlayıcı ve gerçek DEBİM ile ilk doğrulama (izinler verildikten sonra).
2. Parola sıfırlama, hesap silme, oturum yönetimi.
3. Deşifrede konuşmacı ayrımı (destekleyen model seçilirse), sözlü sınav provası, öğrenme analitiği.
