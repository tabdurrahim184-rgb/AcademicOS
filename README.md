# TÜRKMENOĞLU — Akademik ve Çalışma Asistanı (AcademicOS)

Bulutta çalışmak üzere tasarlanmış, öğrenme odaklı akademik platform. Öğrencinin kendi ders
materyalleriyle **gerçekten ders çalışmasını**, cevaplarının değerlendirilmesini, yanlışlarının
takibini ve aralıklı tekrarını sağlar.

> Durum: **İlk kullanılabilir sürüm (v0.1.0)** — akademik temel ve ders çalışma motoru çalışıyor ve
> testlerle doğrulandı. Henüz internette yayımlanmadı. Ayrıntılar: [PROJECT_STATUS.md](PROJECT_STATUS.md).

## Depo yapısı

| Klasör | İçerik |
|---|---|
| `web/` | **Bulut web uygulaması** (Next.js + TypeScript + PostgreSQL). Aktif geliştirme burada. |
| `AcademicOS/`, `Tests/`, `AcademicOS.xcodeproj`, `UI-Preview/` | Önceki iOS (SwiftUI) prototipi. Silinmedi; web uygulaması bu koda bağımlı değildir. |
| `Documentation/` | iOS prototipine ait belgeler ve NEU portal inceleme çıktıları. |

## Web uygulamasını yerelde çalıştırma

Gereksinimler: Node.js 20+ (22 önerilir), PostgreSQL 16.

```bash
# 1) Veritabanı rolleri (bir kez)
psql -U postgres <<'SQL'
CREATE ROLE academicos_owner LOGIN PASSWORD 'devowner' NOSUPERUSER NOBYPASSRLS;
CREATE ROLE academicos_app   LOGIN PASSWORD 'devapp'   NOSUPERUSER NOBYPASSRLS;
CREATE DATABASE academicos OWNER academicos_owner;
SQL

# 2) Uygulama
cd web
cp .env.example .env          # bağlantı adreslerini düzenleyin
npm install
set -a; . ./.env; set +a
npm run db:migrate            # şemayı ve RLS politikalarını kurar
npm run build && npm start    # http://localhost:3000
```

`/kayit` sayfasından hesap oluşturduğunuzda dokuz dönem dersi otomatik eklenir.

### Yapay zekâ (isteğe bağlı, ücretli)

Yapay zekâ özellikleri **varsayılan olarak kapalıdır**. ChatGPT ve Claude abonelikleri API erişimi
içermez; açmak için ayrı faturalanan bir API anahtarı gerekir:

```bash
AI_PROVIDER=anthropic   ANTHROPIC_API_KEY=...   # AI_MODEL boşsa claude-opus-5-5
# veya
AI_PROVIDER=openai      OPENAI_API_KEY=...   AI_MODEL=<model adı>
```

Yapay zekâ kapalıyken kaynak yükleme/okuma, arama, not, soru bankası, soru çözme, yanlışlar defteri,
aralıklı tekrar ve yedekleme tam olarak çalışır; sahte yapay zekâ yanıtı üretilmez.

## Testler

```bash
cd web
npm run lint && npm run typecheck
npm test            # birim + entegrasyon (gerçek PostgreSQL: academicos_test)
npm run test:e2e    # Playwright uçtan uca (academicos_e2e)
```

Son gerçek sonuçlar: [TEST_RESULTS.md](TEST_RESULTS.md).

## Belgeler

- [ARCHITECTURE.md](ARCHITECTURE.md) — mimari ve teknoloji kararları
- [REQUIREMENTS.md](REQUIREMENTS.md) — işlevler ve kabul kriterleri
- [PROJECT_STATUS.md](PROJECT_STATUS.md) — tamamlanan / bekleyen işler
- [TEST_RESULTS.md](TEST_RESULTS.md) — gerçek test sonuçları
- [NEXT_STEPS.md](NEXT_STEPS.md) — sonraki geliştirme görevleri
- [CHANGELOG.md](CHANGELOG.md) — sürüm değişiklikleri
