# İşlevler ve kabul kriterleri

Durum işaretleri: ✅ uygulandı ve otomatik testle doğrulandı · 🟡 kısmen · ⏳ planlandı · ❌ kapsam dışı

## İlk kullanılabilir sürüm kabul akışı (talimat §24)

| # | Adım | Durum | Doğrulama |
|---|---|---|---|
| 1–2 | Uygulamayı aç, hesaba giriş yap | ✅ | e2e `acceptance.spec.ts` |
| 3 | Dokuz dersi gör | ✅ | e2e + entegrasyon Test A |
| 4 | Siyasal İletişim'i seç | ✅ | e2e |
| 5–6 | Gerçek PDF yükle, derse kaydedilsin | ✅ | e2e (bayt bayt karşılaştırma) |
| 7 | PDF içeriği okunup konuyla ilişkilendirilsin | ✅ | e2e + birim `extract.test.ts` |
| 8–9 | "Bana bu konuyu öğret"; yapay zekâ yapılandırılmışsa kaynaklı öğretim | 🟡 | Akış e2e'de **test ikiziyle** doğrulandı; gerçek sağlayıcıyla doğrulanmadı (API anahtarı yok). Yapay zekâ kapalıyken "Kaynakla çalış" (okuma) modu açılır. |
| 10–12 | Soru çöz, cevap kaydedilsin, değerlendirme ve açıklama görünsün | ✅ | e2e + entegrasyon |
| 13 | Yanlışlar tekrar listesine eklensin | ✅ | e2e + entegrasyon Test E |
| 14 | Çalışma geçmişi saklansın | ✅ | entegrasyon Test C/F |
| 15–16 | Yeniden giriş, kaldığın yerden devam | ✅ | e2e |

## Test senaryoları (talimat §22)

| Test | Kriter | Durum |
|---|---|---|
| A | Giriş yapan kullanıcı dokuz dersini görür | ✅ |
| B | Kaynak yüklenir, gerçekten kaydedilir, yeniden açılır | ✅ |
| C | Çalışma oturumu kalıcıdır | ✅ |
| D | Cevap saklanır ve doğru oturumla ilişkilendirilir | ✅ |
| E | Yanlış cevap tekrar sürecine girer | ✅ |
| F | Çıkış/giriş sonrası notlar ve ilerleme korunur | ✅ |
| G | Başka kullanıcı özel verilere erişemez (RLS + HTTP) | ✅ |
| H | Yapay zekâ bağlantısı kesilince kayıtlı veri kaybolmaz | ✅ (entegrasyon; bağlantı hatası simüle edildi) |
| I | Akademik zamanlara otomatik iş görevi atanmaz | ⏳ İş merkezi henüz yok. Koruma fonksiyonu (`isProtectedAcademicTime`) birim testli. |
| J | Yedek geri yüklenebilir | ✅ (başka hesaba geri yükleme + bozuk yedek reddi + arayüz) |
| K | Türkçe karakterler yüklemede, aramada, veritabanında korunur | ✅ (UTF-8, Windows-1254, İ/ı normalleştirme) |
| L | Eksik/bozuk dosya uygun hatayla yönetilir | ✅ |

## Modüller

| Modül | Durum | Not |
|---|---|---|
| Kimlik doğrulama, oturum, hız sınırı | ✅ | |
| Dokuz ders başlangıç verisi, düzenleme, çakışma gösterimi | ✅ | İki çakışma gösterilir (Cuma 15.30 ve 16.30); dersler onaysız değiştirilmez. |
| Konu/hafta ve 7 aşamalı ilerleme durumu | ✅ | |
| Kaynak türleri (hoca/kendi/arkadaş/akademik/diğer) | ✅ | |
| PDF, DOCX, PPTX, TXT/MD, SRT, VTT içe aktarma | ✅ | Sayfa/slayt/zaman damgası; DOCX/TXT'de "Bölüm" (sayfa uydurulmaz). |
| Görsel yükleme | 🟡 | Saklanır; OCR yok (arayüzde belirtilir). |
| Taranmış PDF | 🟡 | "Metin bulunamadı — OCR yok" olarak işaretlenir. |
| Kaynaklarda tam metin arama | ✅ | |
| "Yalnızca seçili kaynaklara göre cevap ver" | ✅ | İstemle zorlanır; atıflar doğrulanır. Model uyumu gerçek sağlayıcıyla ölçülmedi. |
| Çalışma modları (10) | 🟡 | Okuma, aktif hatırlama, hızlı tekrar yapay zekâsız çalışır; 7 mod yapay zekâ gerektirir. |
| Soru türleri | ✅ | Çoktan seçmeli, D/Y, kısa cevap, boşluk doldurma, eşleştirme (otomatik); kavram açıklama, karşılaştırma, açık uçlu, vaka analizi (öz değerlendirme veya yapay zekâ). Sözlü sınav provası ⏳. |
| Soru kaynağı ayrımı (kendi / öğretim elemanı / yapay zekâ) | ✅ | |
| Yanlışlar defteri | ✅ | |
| SM-2 aralıklı tekrar | ✅ | |
| Şimdi Ders Çalış önerisi | ✅ | Kural tabanlı, gerekçeli. |
| Sınav/ödev takibi, "Tarih bekleniyor", gereken not hesabı | ✅ | Varsayımlar gösterilir. |
| Notlar (kullanıcı / yapay zekâ çıktısı ayrı) | ✅ | |
| Yedek dışa aktarma / geri yükleme | ✅ | |
| İki haftalık telafi | 🟡 | Konu durum tablosu var; kapasiteye göre otomatik 14 günlük plan ⏳. |
| Takvim, günlük kapasite, ICS | ⏳ | |
| Bölüm Projesi çalışma alanı | ⏳ | Şimdilik ders sayfası. |
| İslam düşüncesiyle akademik tartışma | ⏳ | |
| İş merkezi (Ahmet Özsoy, Hasan Bey) | ⏳ | |
| Transkripsiyon, ses/video | ⏳ | |
| DEBİM/UZEM otomatik aktarım | ❌ şimdilik | Resmî/izinli bir API bulunana kadar manuel yükleme. |
