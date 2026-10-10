import { Flash } from "@/components/Flash";
import { AiTestForm } from "@/components/AiTestForm";
import { ANTHROPIC_MODELS } from "@/lib/ai/config";
import { getAIStatus } from "@/lib/ai/provider";
import { usageSummary } from "@/lib/ai/usage";
import { withUser } from "@/lib/db";
import { requireUser } from "@/lib/auth";

export const metadata = { title: "Ayarlar ve yedek" };
export const dynamic = "force-dynamic";

export default async function SettingsPage({ searchParams }: { searchParams: Promise<Record<string, string | undefined>> }) {
  const sp = await searchParams;
  const user = await requireUser();
  const ai = getAIStatus();
  const usage = await withUser(user.id, (tx) => usageSummary(tx, ai.enabled ? ai.provider : null, ai.enabled ? ai.model : null));
  return (
    <div className="mx-auto max-w-3xl space-y-6">
      <Flash sp={sp} />
      <h1>Ayarlar ve yedek</h1>

      <section className="card space-y-2" aria-labelledby="hesap">
        <h2 id="hesap">Hesap</h2>
        <p className="text-sm">{user.name} · {user.email} · Saat dilimi: {user.timezone} (Kıbrıs, yaz/kış saati otomatik)</p>
      </section>

      <section className="card space-y-3" aria-labelledby="yz">
        <h2 id="yz">Yapay zekâ bağlantısı</h2>
        {ai.enabled ? (
          <p className="text-sm"><span className="badge-ok">Yapılandırıldı</span> Sağlayıcı: {ai.provider} · Model: {ai.model}</p>
        ) : (
          <p className="text-sm"><span className="badge-warn">Bağlı değil</span> {ai.reason}</p>
        )}
        <p className="text-sm">
          <strong>Doğrulama durumu:</strong> Yapay zekâ öğretmeni yalnızca yerel bir test ikiziyle denendi; gerçek bir sağlayıcıyla henüz
          doğrulanmadı. İlk gerçek kullanımda yanıt kalitesini ve kaynak atıflarını kontrol et.
        </p>
        {ai.enabled && <AiTestForm />}
        <div className="alert-info space-y-2">
          <p><strong>&quot;Sign in with ChatGPT&quot; durumu:</strong> OpenAI, ChatGPT Plus/Pro aboneliğinin üçüncü taraf uygulamalarda kullanılmasını yalnızca başvurusu kabul edilen sınırlı sayıda ortak uygulamaya açtı (Ekim 2026). Bu özel uygulama için resmî bir erişim yolu yoktur; bu yüzden AcademicOS yalnızca resmî OpenAI API anahtarıyla (<code>AI_PROVIDER=openai</code>) çalışır. OpenAI isteklerinde <code>store: false</code> kullanılır.</p>
          <p><strong>Abonelik ≠ API erişimi.</strong> ChatGPT Plus/Pro ve Claude Pro/Max abonelikleri yalnızca sohbet uygulamalarını kapsar; bu uygulamanın kullanabileceği API erişimi içermez. API kullanımı ayrıca ücretlendirilir.</p>
          <p>Bağlamak için sunucu ortam değişkenlerinde <code>AI_PROVIDER</code>, ilgili API anahtarı ve <strong>bilinçli olarak seçilmiş</strong> <code>AI_MODEL</code> gerekir; varsayılan model yoktur. Anahtarlar tarayıcıya gönderilmez.</p>
          <p>Yapay zekâ açıkken seçili kaynak metinlerin ilgili bölümleri, mesajların ve cevapların seçilen sağlayıcıya gönderilir. Kapalıyken hiçbir veri dışarı gönderilmez.</p>
        </div>
        <h3 className="font-semibold">Desteklenen Anthropic modelleri (resmî fiyatlar, 1 milyon token başına)</h3>
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead><tr className="muted"><th className="py-1 font-medium">Model (AI_MODEL)</th><th className="font-medium">Girdi</th><th className="font-medium">Çıktı</th><th className="font-medium">Not</th></tr></thead>
            <tbody>
              {Object.entries(ANTHROPIC_MODELS).map(([id, m]) => (
                <tr key={id} className="border-t border-slate-200 dark:border-slate-800">
                  <td className="py-1"><code>{id}</code></td><td>{m.input.toFixed(2)} $</td><td>{m.output.toFixed(2)} $</td><td className="muted">{m.note}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <p className="muted">Kaynak: Anthropic fiyat sayfası (10 Ekim 2026). Kaba bir ölçek: kaynak bağlamlı tek bir öğretmen yanıtı yaklaşık 6.000 girdi + 600 çıktı token&apos;dır; bu, Haiku 5.5 ile yaklaşık 0,001 $, Sonnet 5.5 ile 0,018 $, Opus 5.5 ile 0,036 $ eder. Modelin düşünme (thinking) token&apos;ları çıktı olarak ücretlendirildiği için gerçek tutar daha yüksek olabilir; önbellek ise girdi maliyetini düşürür. OpenAI kullanılacaksa model kimliği ve fiyatı OpenAI&apos;nin resmî sayfasından doğrulanıp <code>AI_PRICE_INPUT_PER_MTOK</code> / <code>AI_PRICE_OUTPUT_PER_MTOK</code> ile girilmelidir.</p>
        <h3 className="font-semibold">Kullanım ve sınırlar</h3>
        <ul className="list-disc space-y-1 pl-5 text-sm">
          <li>Bugünkü istek: {usage.todayRequests} / {usage.limits.dailyRequests} (AI_DAILY_REQUEST_LIMIT)</li>
          <li>Bu ay: {usage.monthRequests} istek{usage.monthFailed ? ` (${usage.monthFailed} başarısız)` : ""}, {usage.monthInputTokens.toLocaleString("tr-TR")} girdi + {usage.monthOutputTokens.toLocaleString("tr-TR")} çıktı token</li>
          <li>Tahmini aylık maliyet: {usage.monthCostUsd == null ? "fiyat bilinmiyor" : `${usage.monthCostUsd.toFixed(3)} $`}{usage.limits.monthlyBudgetUsd != null ? ` / bütçe ${usage.limits.monthlyBudgetUsd} $ (AI_MONTHLY_BUDGET_USD)` : " · aylık bütçe sınırı tanımlı değil"}</li>
        </ul>
      </section>

      <section className="card space-y-3" aria-labelledby="yedek">
        <h2 id="yedek">Yedekleme ve geri yükleme</h2>
        <p className="text-sm">Yedek; derslerini, konularını, yüklediğin dosyaların kendisini, notlarını, çalışma oturumlarını, sorularını, cevaplarını, yanlışlar defterini ve tekrar planını tek bir JSON dosyasında içerir. Dosyayı güvenli bir yerde sakla; kişisel akademik verilerini içerir.</p>
        <a href="/api/yedek" className="btn" download>Yedeği indir</a>
        <form action="/api/yedek" method="post" encType="multipart/form-data" className="space-y-3 border-t border-slate-200 pt-4 dark:border-slate-800">
          <h3 className="font-semibold">Yedekten geri yükle</h3>
          <p className="alert-err">Dikkat: Geri yükleme, bu hesaptaki mevcut bütün akademik verilerini siler ve yerine yedektekileri koyar. İşlem tek adımda yapılır; hata olursa hiçbir değişiklik uygulanmaz. Önce güncel bir yedek indirmen önerilir.</p>
          <input type="file" name="file" accept="application/json,.json" required className="input" aria-label="Yedek dosyası" />
          <label className="block text-sm">Onaylamak için <strong>GERİ YÜKLE</strong> yaz
            <input name="confirm" className="input mt-1" autoComplete="off" />
          </label>
          <button className="btn-danger">Geri yükle</button>
        </form>
      </section>

      <section className="card space-y-2 text-sm" aria-labelledby="durum">
        <h2 id="durum">Entegrasyonların gerçek durumu</h2>
        <ul className="list-disc space-y-1 pl-5">
          <li>DEBİM: Moodle web servisleriyle bağlantı ve aktarım hazır; gerçek DEBİM ile henüz denenmedi. Web servisleri kapalıysa ZIP / toplu yükleme kullanılabilir.</li>
          <li>OCR: sunucuda çevrimdışı çalışır (Türkçe); el yazısı ve düşük kaliteli taramalarda hata oranı yüksektir.</li>
          <li>Deşifre: ücretli OpenAI sağlayıcısı yapılandırılırsa ve her iş için onay verirsen çalışır; gerçek sağlayıcıyla henüz denenmedi.</li>
          <li>Parola sıfırlama ve hesap silme henüz yok.</li>
        </ul>
      </section>
    </div>
  );
}
