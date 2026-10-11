import { connectDebimAction, disconnectDebimAction, linkCourseAction } from "@/app/actions/lms";
import { ConfirmSubmit } from "@/components/ConfirmSubmit";
import { Flash } from "@/components/Flash";
import { BulkImportForm, DebimImportButton } from "@/components/ImportForms";
import { SubmitButton } from "@/components/SubmitButton";
import { requireUser } from "@/lib/auth";
import { encryptionAvailable } from "@/lib/crypto";
import { withUser } from "@/lib/db";
import { listCourses } from "@/lib/data/courses";
import { fmtDateTime } from "@/lib/format";
import { getConnection, remoteCourses } from "@/lib/lms/debim";
import { DEFAULT_SITE, MoodleError } from "@/lib/lms/moodle";

export const metadata = { title: "DEBİM ve içe aktarma" };
export const dynamic = "force-dynamic";

export default async function DebimPage({ searchParams }: { searchParams: Promise<Record<string, string | undefined>> }) {
  const sp = await searchParams;
  const user = await requireUser();
  const { conn, courses } = await withUser(user.id, async (tx) => ({ conn: await getConnection(tx), courses: await listCourses(tx) }));
  let remote: Awaited<ReturnType<typeof remoteCourses>> = [];
  let remoteError = "";
  if (conn) {
    try {
      remote = await remoteCourses(user.id);
    } catch (e) {
      remoteError = e instanceof MoodleError ? e.message : "DEBİM ders listesi alınamadı.";
    }
  }
  const canEncrypt = encryptionAvailable();

  return (
    <div className="mx-auto max-w-4xl space-y-6">
      <Flash sp={sp} />
      <h1>DEBİM ve materyal içe aktarma</h1>

      <section className="card space-y-3" aria-labelledby="baglan">
        <h2 id="baglan">DEBİM&apos;e bağlan</h2>
        {conn ? (
          <>
            <p className="text-sm"><span className="badge-ok">Bağlı</span> {conn.site_name || conn.site_url} · {conn.lms_full_name} · bağlantı {fmtDateTime(conn.connected_at)}{conn.last_sync_at ? ` · son aktarım ${fmtDateTime(conn.last_sync_at)}` : ""}</p>
            <form action={disconnectDebimAction}>
              <ConfirmSubmit message="DEBİM bağlantısı kaldırılsın ve saklanan anahtar silinsin mi? Aktarılmış materyaller silinmez." className="btn-secondary">Bağlantıyı kaldır</ConfirmSubmit>
            </form>
          </>
        ) : (
          <>
            <div className="alert-info space-y-2 text-sm">
              <p>DEBİM bir Moodle sistemidir ve Google hesabıyla (SSO) giriş yapılır. AcademicOS üniversite şifreni <strong>istemez ve saklamaz</strong>. Bağlantı, Moodle&apos;ın resmî web servisleri ve senin oluşturacağın kişisel bir güvenlik anahtarıyla kurulur:</p>
              <ol className="list-decimal space-y-1 pl-5">
                <li>DEBİM&apos;e tarayıcıdan normal şekilde giriş yap.</li>
                <li>Sağ üstteki profil menüsünden <em>Tercihler → Güvenlik anahtarları</em> sayfasını aç.</li>
                <li>&quot;Moodle mobile web service&quot; satırındaki anahtarı kopyala (yoksa &quot;Sıfırla&quot; ile oluştur) ve aşağıya yapıştır.</li>
              </ol>
              <p>Bu sayfa görünmüyorsa üniversite web servis erişimini kapatmış olabilir; o durumda aşağıdaki <strong>ZIP / toplu yükleme</strong> yolunu kullan (DEBİM&apos;de ders sayfasındaki &quot;Ders içeriğini indir&quot; seçeneği varsa ZIP doğrudan içe aktarılabilir).</p>
              <p>Anahtar yalnızca sunucuda AES-256-GCM ile şifreli tutulur, tarayıcıya geri gönderilmez ve &quot;Bağlantıyı kaldır&quot; ile silinir.</p>
            </div>
            {!canEncrypt ? (
              <p className="alert-err">Sunucuda <code>APP_ENCRYPTION_KEY</code> tanımlı olmadığı için anahtar güvenle saklanamaz; bağlantı devre dışı.</p>
            ) : (
              <form action={connectDebimAction} className="grid gap-3 sm:grid-cols-2">
                <label className="text-sm">Site adresi<input name="site" defaultValue={DEFAULT_SITE} required className="input mt-1" /></label>
                <label className="text-sm">Güvenlik anahtarı (token)<input name="token" required autoComplete="off" className="input mt-1" type="password" /></label>
                <div className="sm:col-span-2"><SubmitButton pendingText="Doğrulanıyor…">DEBİM&apos;e bağlan</SubmitButton></div>
              </form>
            )}
          </>
        )}
      </section>

      {conn && (
        <section className="card space-y-3" aria-labelledby="dersler">
          <h2 id="dersler">DEBİM derslerim</h2>
          {remoteError && <p className="alert-err">{remoteError}</p>}
          {!remoteError && remote.length === 0 && <p className="muted">DEBİM&apos;de kayıtlı ders bulunamadı.</p>}
          <ul className="divide-y divide-slate-200 dark:divide-slate-800">
            {remote.map((r) => (
              <li key={r.id} className="space-y-2 py-3">
                <p className="font-medium">{r.fullname} <span className="muted">({r.shortname})</span></p>
                <form action={linkCourseAction} className="flex flex-wrap items-end gap-2">
                  <input type="hidden" name="lmsCourseId" value={r.id} />
                  <input type="hidden" name="lmsCourseName" value={r.fullname} />
                  <label className="text-sm">AcademicOS dersi
                    <select name="courseId" defaultValue={r.linkedCourseId ?? ""} className="input mt-1 w-auto">
                      <option value="">Eşleştirilmedi</option>
                      {courses.map((c) => <option key={c.id} value={c.id}>{c.code} {c.name}</option>)}
                    </select>
                  </label>
                  <SubmitButton className="btn-secondary">Eşleştir</SubmitButton>
                </form>
                {r.linkedCourseId && <DebimImportButton lmsCourseId={r.id} />}
              </li>
            ))}
          </ul>
        </section>
      )}

      <section className="card space-y-3" aria-labelledby="toplu">
        <h2 id="toplu">ZIP veya toplu dosya yükleme</h2>
        <p className="muted">DEBİM bağlantısı olmadan da çalışır. Dosyalar seçtiğin derse eklenir, metinleri çıkarılır ve konu çalışmasında, aramada ve planda kullanılır.</p>
        <BulkImportForm courses={courses} />
      </section>
    </div>
  );
}
