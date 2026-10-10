# İşlevler ve kabul kriterleri

Durum: ✅ uygulandı ve otomatik testle doğrulandı · 🟡 kodu ve testi var, gerçek dış hizmetle doğrulanmadı · ⏳ planlandı

## İlk sürüm kabul akışı (talimat §24)

| # | Adım | Durum |
|---|---|---|
| 1–7 | Giriş, 9 ders, Siyasal İletişim, gerçek PDF yükleme, metin çıkarma, konuya bağlama | ✅ e2e |
| 8–9 | "Bana bu konuyu öğret", kaynaklı öğretim | 🟡 test ikiziyle doğrulandı; gerçek sağlayıcı (OpenAI/Anthropic) denenmedi |
| 10–16 | Soru çözme, değerlendirme, yanlışlar → tekrar, geçmiş, yeniden giriş ve devam | ✅ e2e |

## Test senaryoları (talimat §22)

| Test | Durum |
|---|---|
| A–H, J–L | ✅ (ayrıntı: TEST_RESULTS.md) |
| I — Akademik zamanlara otomatik iş görevi atanmaz | ✅ birim (14 gün × 5 başlangıç saati × 4 süre × 4 teslim; >500 senaryo) + entegrasyon + e2e |

## Modüller

| Modül | Durum | Not |
|---|---|---|
| Hesap, RLS izolasyonu, sahiplik FK'leri | ✅ | |
| 9 ders, ders saatleri, çakışmalar | ✅ | |
| Kaynak yükleme / metin çıkarma / arama / denetim | ✅ | |
| **Toplu ve ZIP içe aktarma** (klasör → konu/hafta, yinelenen dosya tespiti) | ✅ | DEBİM'in "ders içeriğini indir" ZIP'i dahil |
| **DEBİM (Moodle web servisleri) bağlantısı ve materyal aktarımı** | 🟡 | Kod + Moodle REST API test ikiziyle entegrasyon/e2e testleri ✅. **Gerçek DEBİM'e bağlanılarak doğrulanmadı** (geliştirme ortamının ağ politikası `debim.neu.edu.tr`'yi engelliyor; ayrıca üniversitenin web servis erişimini açık tutup tutmadığı bilinmiyor). |
| **OCR** (taranmış PDF ve görseller, Türkçe, çevrimdışı) | ✅ | Gerçek Tesseract ile test edildi; düzenlenebilir metin, ham çıktı korunur; kuyruk, ilerleme, iptal, devam |
| **Ses/video kayıtları** (yükleme, oynatma, ders/iş arşivleri) | ✅ | 100 MB'a kadar; Range destekli oynatma |
| **Deşifre** (OpenAI Audio, Türkçe, zaman damgaları, düzenleme, TXT/SRT/VTT/DOCX) | 🟡 | ffmpeg parçalama gerçek; sağlayıcı yalnızca test ikiziyle doğrulandı. Ücretli; her iş için onay ister |
| Konu çalışma, öğrenme hedefleri, eminlik, kavram yanılgısı | ✅ | |
| Yanlışlar defteri, SM-2 tekrar | ✅ | |
| 14 günlük telafi planı, takvim, ICS | ✅ | İş taahhütleri ve planlanmış işler plan için meşgul sayılır |
| **Bölüm Projesi (GZT440)** | ✅ | Proje bilgileri, kaynakça, görüşmeler, geri bildirim, taslak, revizyon, çekim planı, teslim; teslimler takvim ve plana yansır |
| **Akademik tartışmalar** | ✅ | 7 aşamalı hazırlık alanı, tema, kaynak künyesi + "asıl kaynaktan kontrol ettim" doğrulaması; sistem ayet/hadis üretmez |
| **İş Merkezi** (Ahmet Özsoy, Hasan Bey) | ✅ | Görev türleri, öncelik, süre, durum, revizyon geçmişi, Reels dakika listesi, sabit program, çakışma uyarısı, etki analizi ("bu işi alırsam…"), akademik zaman koruması |
| Yapay zekâ öğretmeni (OpenAI / Anthropic) | 🟡 | Resmî SDK'lar; istek biçimleri yerel test sunucusuyla doğrulandı; maliyet sınırları ✅; gerçek sağlayıcı denenmedi |
| "Sign in with ChatGPT" | ❌ | OpenAI bu yolu yalnızca başvurusu kabul edilen ortaklara açtı; bu uygulama için resmî erişim yok |
| Yedekleme (sürüm 3, bütün modüller) | ✅ | Büyük yedekler için ayrı geri yükleme uç noktası |
