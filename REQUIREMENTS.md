# İşlevler ve kabul kriterleri

Durum: ✅ uygulandı ve otomatik testle doğrulandı · 🟡 kısmen / doğrulanmamış bileşen var · ⏳ planlandı · ❌ şimdilik kapsam dışı

## İlk kullanılabilir sürüm kabul akışı (talimat §24)

| # | Adım | Durum | Doğrulama |
|---|---|---|---|
| 1–2 | Uygulamayı aç, hesaba giriş yap | ✅ | e2e `acceptance.spec.ts` |
| 3 | Dokuz dersi gör | ✅ | e2e + entegrasyon Test A |
| 4 | Siyasal İletişim'i seç | ✅ | e2e |
| 5–6 | Gerçek PDF yükle, derse kaydedilsin | ✅ | e2e (bayt bayt karşılaştırma) |
| 7 | PDF içeriği okunup konuyla ilişkilendirilsin | ✅ | e2e + birim `extract.test.ts` |
| 8–9 | "Bana bu konuyu öğret"; yapay zekâ yapılandırılmışsa kaynaklı öğretim | 🟡 | Akış **yerel test ikiziyle** doğrulandı; **gerçek sağlayıcıyla doğrulanmadı**. Yapay zekâ kapalıyken "Kaynakla çalış" açılır. |
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
| G | Başka kullanıcı özel verilere erişemez (RLS + sahiplik FK + HTTP) | ✅ |
| H | Yapay zekâ bağlantısı kesilince kayıtlı veri kaybolmaz | ✅ (entegrasyon, bağlantı hatası simüle edildi) |
| I | Akademik zamanlara otomatik **iş** görevi atanmaz | ⏳ İş merkezi henüz yok. Çalışma planlayıcısı ders saatlerine görev koymaz (✅ test edildi). |
| J | Yedek geri yüklenebilir | ✅ (sürüm 2, plan verisi dahil; sürüm 1 uyumluluğu) |
| K | Türkçe karakterler korunur | ✅ |
| L | Bozuk dosya uygun hatayla yönetilir | ✅ |

## Modül durumu

### Akademik temel
| Özellik | Durum |
|---|---|
| Hesap, oturum, giriş hız sınırı (TRUST_PROXY ile vekil desteği) | ✅ |
| Kullanıcı izolasyonu: FORCE RLS + (kolon, user_id) sahiplik FK'leri | ✅ |
| Dokuz ders, ders saatleri, çakışma gösterimi, düzenleme | ✅ |
| Kaynak yükleme (PDF/DOCX/PPTX/TXT/SRT/VTT; görsel saklama), Türkçe arama | ✅ |
| Kaynak düzeltme (başlık, tür, konu) ve **kaynak denetimi** (yinelenen dosya, okunamayan metin, konusuz kaynak, konu başlığı–içerik uyuşmazlığı) | ✅ |
| OCR, ses/video transkripsiyonu | ⏳ |

### Ders çalışma motoru
| Özellik | Durum |
|---|---|
| **Konu çalışma sayfası** (`/konular/[id]`): 7 adımlı çalışma yolu, her adımın durumu gerçek veriden | ✅ |
| **Öğrenme hedefleri**, sorulara bağlama, hedef bazlı ustalık (en son cevaplara göre) | ✅ |
| **Kavram bazlı doğruluk** ve zayıf kavramlar | ✅ |
| Cevapta **eminlik** bildirimi → SM-2 aralığı kişiselleşir; emin olunarak yapılan yanlış = **kavram yanılgısı** | ✅ |
| Yanlışlar defteri, SM-2 aralıklı tekrar | ✅ |
| 10 çalışma modu | 🟡 3 mod yapay zekâsız; 7 mod yapay zekâ gerektirir (gerçek sağlayıcıyla denenmedi) |

### Telafi ve planlama
| Özellik | Durum |
|---|---|
| Ders bazında: eksik materyal, çalışılmamış haftalar, konu girilmemiş haftalar, tamamlananlar, açık yanlış, kavram yanılgısı, tekrar gereken kavramlar, vadesi gelen tekrar | ✅ |
| Konuyu "telafi" olarak işaretleme, kaçırılan haftayı ekleme | ✅ |
| **14 günlük düzenlenebilir plan**: çalışma aralıkları, ders saatleri, günlük kapasite, telafi payı, ders başına günlük sınır, mola, son tarih | ✅ (14 birim + 7 entegrasyon testi) |
| Güncel dersler: her ders oturumundan sonra 2 gün içinde gözden geçirme (telafiden önce gelir) | ✅ |
| Yapılmayan görev yeniden planlanır; kullanıcının taşıdığı/eklediği görev korunur; erteleme | ✅ |
| Sığmayan çalışmaların gerekçeli listesi (kapasite aşılmaz) | ✅ |
| Tarihi bilinmeyen sınava hazırlık tarihi uydurulmaz | ✅ |

### Takvim
| Özellik | Durum |
|---|---|
| Haftalık takvim: ders saatleri (çakışma işaretli), plan görevleri, tarihli sınav/ödev, gerçekleşen çalışma oturumları | ✅ |
| "Tarih bekleniyor" listesi | ✅ |
| `.ics` dışa aktarma (Europe/Nicosia, yaz/kış saati; dönem sonu bilinmiyorsa tekrar sonu yazılmaz) | ✅ |

### Yapay zekâ öğretmeni
| Özellik | Durum |
|---|---|
| Sağlayıcıdan bağımsız katman (Anthropic / OpenAI resmî SDK) | 🟡 test ikiziyle doğrulandı, gerçek sağlayıcıyla **doğrulanmadı** |
| Varsayılan model yok; model bilinçli seçilmeli | ✅ |
| Günlük istek sınırı, aylık bütçe sınırı, kullanım ve tahmini maliyet kaydı | ✅ |
| Kaynaklı anlatım, Sokratik soru-cevap, "anlamadım" için farklı örnek, gazetecilik örnekleri | 🟡 istem düzeyinde uygulandı; kalite ölçülmedi |
| Açık uçlu değerlendirme; eksik kavramların yanlışlar defterine yazılması | 🟡 akış test ikiziyle doğrulandı |
| Yanlışların gerekçeli açıklaması (yanlışlar defterinde) | 🟡 akış test ikiziyle doğrulandı |
| Kaynak dışı bilginin işaretlenmesi ve arayüzde ayrı gösterilmesi | 🟡 istem + arayüz; model uyumu ölçülmedi |

### Kapsam dışı / bekleyen
Bölüm Projesi çalışma alanı, İslam düşüncesi tartışma alanı, iş merkezi, transkripsiyon, DEBİM/UZEM otomatik aktarım (⏳/❌).
