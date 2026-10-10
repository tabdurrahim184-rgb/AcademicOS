import { restoreBackupAction } from "@/app/actions/study";
import { Flash } from "@/components/Flash";
import { SubmitButton } from "@/components/SubmitButton";
import { getAIStatus } from "@/lib/ai/provider";
import { requireUser } from "@/lib/auth";

export const metadata = { title: "Ayarlar ve yedek" };
export const dynamic = "force-dynamic";

export default async function SettingsPage({ searchParams }: { searchParams: Promise<Record<string, string | undefined>> }) {
  const sp = await searchParams;
  const user = await requireUser();
  const ai = getAIStatus();
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
          <p className="text-sm"><span className="badge-ok">Bağlı</span> Sağlayıcı: {ai.provider} · Model: {ai.model}</p>
        ) : (
          <p className="text-sm"><span className="badge-warn">Bağlı değil</span> {ai.reason}</p>
        )}
        <div className="alert-info space-y-2">
          <p><strong>Abonelik ≠ API erişimi.</strong> ChatGPT Plus/Pro ve Claude Pro/Max abonelikleri yalnızca sohbet uygulamalarını kapsar; üçüncü taraf bir uygulamanın kullanabileceği API erişimi içermez. Bu uygulama yapay zekâyı yalnızca resmî, ayrıca ücretlendirilen API anahtarlarıyla kullanır.</p>
          <p>Bağlamak için sunucu ortam değişkenlerinde <code>AI_PROVIDER</code> (<code>anthropic</code> veya <code>openai</code>), ilgili API anahtarı ve gerekirse <code>AI_MODEL</code> ayarlanır. Anahtarlar tarayıcıya hiçbir zaman gönderilmez.</p>
          <p>Yapay zekâ açıkken seçili kaynak metinlerin ilgili bölümleri ve mesajların, yanıt üretmek için seçilen sağlayıcıya gönderilir. Kapalıyken hiçbir veri dışarı gönderilmez.</p>
        </div>
      </section>

      <section className="card space-y-3" aria-labelledby="yedek">
        <h2 id="yedek">Yedekleme ve geri yükleme</h2>
        <p className="text-sm">Yedek; derslerini, konularını, yüklediğin dosyaların kendisini, notlarını, çalışma oturumlarını, sorularını, cevaplarını, yanlışlar defterini ve tekrar planını tek bir JSON dosyasında içerir. Dosyayı güvenli bir yerde sakla; kişisel akademik verilerini içerir.</p>
        <a href="/api/yedek" className="btn" download>Yedeği indir</a>
        <form action={restoreBackupAction} className="space-y-3 border-t border-slate-200 pt-4 dark:border-slate-800">
          <h3 className="font-semibold">Yedekten geri yükle</h3>
          <p className="alert-err">Dikkat: Geri yükleme, bu hesaptaki mevcut bütün akademik verilerini siler ve yerine yedektekileri koyar. İşlem tek adımda yapılır; hata olursa hiçbir değişiklik uygulanmaz. Önce güncel bir yedek indirmen önerilir.</p>
          <input type="file" name="file" accept="application/json,.json" required className="input" aria-label="Yedek dosyası" />
          <label className="block text-sm">Onaylamak için <strong>GERİ YÜKLE</strong> yaz
            <input name="confirm" className="input mt-1" autoComplete="off" />
          </label>
          <SubmitButton pendingText="Geri yükleniyor…" className="btn-danger">Geri yükle</SubmitButton>
        </form>
      </section>

      <section className="card space-y-2 text-sm" aria-labelledby="durum">
        <h2 id="durum">Henüz olmayan özellikler</h2>
        <ul className="list-disc space-y-1 pl-5">
          <li>DEBİM / UZEM otomatik aktarımı yok; materyaller elle yüklenir.</li>
          <li>Görsel ve taranmış PDF için metin okuma (OCR), ses/video transkripsiyonu yok.</li>
          <li>İş merkezi (Ahmet Özsoy / Hasan Bey), günlük kapasite planlayıcısı, ICS dışa aktarma ve Bölüm Projesi çalışma alanı sonraki aşamalarda.</li>
        </ul>
      </section>
    </div>
  );
}
