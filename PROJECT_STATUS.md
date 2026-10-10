# Proje durumu

**Sürüm:** web v0.1.0 · **Güncelleme:** 10 Ekim 2026

## Özet

PHASE 0 (inceleme ve mimari), PHASE 1 (çalışan akademik temel) ve PHASE 2'nin (gerçek ders çalışma
sistemi) yapay zekâ dışındaki bütün parçaları tamamlandı ve testlerle doğrulandı. Yapay zekâ katmanı
yazıldı ve test ikiziyle doğrulandı; gerçek sağlayıcı bağlantısı kullanıcı onayı ve API anahtarı bekliyor.
Uygulama henüz internette yayımlanmadı.

## Tamamlanan

- Depo incelemesi; iOS prototipi korunarak `web/` altında bulut web uygulaması.
- PostgreSQL şeması (18 tablo), FORCE RLS ile kullanıcı izolasyonu, migration çalıştırıcısı.
- Hesap oluşturma, giriş/çıkış, scrypt parola, sunucu taraflı oturum, giriş hız sınırı.
- Dokuz ders (doğrulanmamış saat/öğretim elemanı uydurulmadan), düzenleme, ders saati ekleme/silme, çakışma gösterimi.
- Konu/hafta yönetimi, 7 aşamalı konu durumu, telafi durum tablosu.
- Kaynak yükleme (PDF, DOCX, PPTX, TXT/MD, SRT, VTT, görsel), dosya imzası doğrulama, metin çıkarma,
  konum bilgisi, özgün dosyayı yalnızca sahibine indirme, kaynak görüntüleyici.
- Türkçe tam metin arama.
- Çalışma oturumları (10 mod), kaynak seçimi, "yalnızca seçili kaynaklar", kalıcı geçmiş, kaldığın yerden devam.
- Soru bankası (9 tür, 3 köken), otomatik/öz/yapay zekâ değerlendirme, yanlışlar defteri, SM-2 tekrar ekranı.
- Kontrol paneli ve "Şimdi ne çalışmalısın?" önerisi.
- Sınav/ödev takibi, tarih bilinmiyorsa "Tarih bekleniyor", ağırlıklarla gereken not hesabı.
- Notlar (kullanıcı ve yapay zekâ çıktısı ayrı işaretli).
- Sağlayıcıdan bağımsız yapay zekâ katmanı (Anthropic/OpenAI resmî SDK), konu anlatımı, soru üretimi, açık uçlu değerlendirme.
- JSON yedek indirme ve tek işlemde geri yükleme.
- Türkçe arayüz, mobil uyumlu menü, açık/koyu tema, klavye erişimi (odak halkaları, "İçeriğe geç").
- 57 birim/entegrasyon + 6 uçtan uca test; GitHub Actions iş akışı.

## Bekleyen / bilinen eksikler

- Gerçek yapay zekâ sağlayıcısıyla doğrulama (onay + API anahtarı gerekli).
- Canlı dağıtım (barındırma ve yönetilen veritabanı seçimi onayı gerekli).
- OCR, ses/video transkripsiyonu, iş kuyruğu.
- Kapasiteye göre 14 günlük telafi planı, takvim görünümü, ICS dışa aktarma.
- Bölüm Projesi çalışma alanı, İslam düşüncesi tartışma modülü, iş merkezi.
- Sözlü sınav provası, öğrenme analitiği.
- Parola sıfırlama, hesap silme, oturumları yönetme.
- Ders silme/ekleme arayüzü (şimdilik yalnızca düzenleme; silme bilinçli olarak yok).

## Gizlilik notu

Depo herkese açıksa, özel ders notları veya kişisel dosyalar depoya **yüklenmemelidir**; materyaller
yalnızca uygulamanın veritabanına yüklenir. Depodaki `Documentation/NEU_Sanitized_Inspection_Exports/`
dosyaları kişisel veri içermiyor görünüyor (yalnızca sayfa yapısı ve örnek bir ders satırı).
