# Proje durumu

**Sürüm:** web v0.2.0 · **Güncelleme:** 10 Ekim 2026 · **PR:** [tabdurrahim184-rgb/AcademicOS#1](https://github.com/tabdurrahim184-rgb/AcademicOS/pull/1) (taslak, `main`'e birleştirilmedi)

## Özet

| Aşama | Durum |
|---|---|
| PHASE 0 — İnceleme ve mimari | ✅ |
| PHASE 1 — Akademik temel | ✅ |
| PHASE 2 — Ders çalışma sistemi | ✅ yapay zekâsız kısım; 🟡 yapay zekâ gerçek sağlayıcıyla doğrulanmadı |
| PHASE 3 — Akademik planlama | ✅ telafi, 14 günlük plan, kapasite, takvim, ICS · ⏳ Bölüm Projesi alanı |
| PHASE 4 — Gelişmiş öğrenme | 🟡 hedef/kavram ustalığı, eminlik, kavram yanılgısı ✅ · sözlü sınav provası ⏳ |
| PHASE 5 — Özel modüller | ⏳ |
| PHASE 6 — Üretim kalitesi | 🟡 CI, güvenlik sertleştirmesi, yedek ✅ · dağıtım ve yük testi ⏳ |

Uygulama henüz internette yayımlanmadı.

## Modüllere göre tamamlananlar ve kalan eksikler

### Güvenlik ve veri
- ✅ FORCE RLS (20 kullanıcı tablosu), sahiplik FK'leri, güvenilir vekil ayarı, yedek sürüm 2.
- ⏳ Parola sıfırlama, hesap silme, oturum listesi; otomatik veritabanı yedeği (barındırmaya bağlı).

### Ders çalışma
- ✅ Konu çalışma sayfası (adımlar, hedefler, ustalık, kavramlar, kaynaklar, geçmiş).
- ✅ Eminlik → aralıklı tekrar; kavram yanılgısı işareti.
- ✅ Kaynak denetimi ve kaynak bilgisi düzeltme.
- ⏳ Sözlü sınav provası, öğrenme analitiği grafikleri.

### Telafi, plan, takvim
- ✅ Ders bazında eksik takibi; telafi işareti; 14 günlük plan; kapasite/aralık ayarları; tamamla/ertele/taşı/sabitle; sığmayanlar listesi; haftalık takvim; ICS.
- Bilinen sınırlamalar: planlayıcı açgözlü (greedy) bir algoritmadır, en iyi çözümü garanti etmez; kurallarını garanti eder. Hafta numaraları ile takvim tarihleri eşleştirilmez (dönem başlangıcı bilinmiyor).

### Yapay zekâ
- ✅ Varsayılan model yok; günlük istek ve aylık bütçe sınırı; kullanım ve tahmini maliyet; yanlış açıklaması; eksik kavramların yanlışlar defterine yazılması; kaynak dışı bilgi işaretleme; önbellek.
- 🟡 **Gerçek sağlayıcıyla hiç denenmedi** — tamamlanmış sayılmaz.

### Bekleyen modüller
Bölüm Projesi çalışma alanı, İslam düşüncesi tartışma alanı, iş merkezi (Ahmet Özsoy / Hasan Bey), OCR ve transkripsiyon, DEBİM/UZEM.

## Gizlilik notu

Depo herkese açıksa kişisel ders dosyaları depoya eklenmemeli; materyaller yalnızca uygulamanın veritabanına yüklenir.
