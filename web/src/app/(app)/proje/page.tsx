import { createProjectEntryAction, deleteProjectEntryAction, saveProjectProfileAction, toggleProjectEntryAction, updateProjectEntryAction } from "@/app/actions/modules";
import { ConfirmSubmit } from "@/components/ConfirmSubmit";
import { Flash } from "@/components/Flash";
import { SubmitButton } from "@/components/SubmitButton";
import { requireUser } from "@/lib/auth";
import { withUser } from "@/lib/db";
import { listCourses } from "@/lib/data/courses";
import { ENTRY_KINDS, getProfile, listEntries, type EntryKind } from "@/lib/data/project";
import { listSources } from "@/lib/data/sources";
import { fmtDate } from "@/lib/format";

export const metadata = { title: "Bölüm Projesi" };
export const dynamic = "force-dynamic";

const PROFILE_FIELDS = [
  ["title", "Proje konusu / başlığı", false], ["aim", "Amaç", true], ["research_questions", "Araştırma soruları", true],
  ["method", "Yöntem", true], ["format", "Çıktı biçimi (haber dosyası, belgesel, rapor…)", false], ["advisor", "Danışman", false],
] as const;

export default async function ProjectPage({ searchParams }: { searchParams: Promise<Record<string, string | undefined>> }) {
  const sp = await searchParams;
  const user = await requireUser();
  const data = await withUser(user.id, async (tx) => {
    const gzt = (await listCourses(tx)).find((c) => c.code.toUpperCase().startsWith("GZT440"));
    return { profile: await getProfile(tx), entries: await listEntries(tx), sources: gzt ? await listSources(tx, { courseId: gzt.id }) : [], gzt };
  });
  const open = data.entries.filter((e) => e.status === "acik" && e.due_date).sort((a, b) => a.due_date!.localeCompare(b.due_date!));
  const grouped = Object.keys(ENTRY_KINDS).map((k) => ({ kind: k as EntryKind, list: data.entries.filter((e) => e.kind === k) }));

  return (
    <div className="mx-auto max-w-5xl space-y-6">
      <Flash sp={sp} />
      <header>
        <h1>Bölüm Projesi (GZT440)</h1>
        <p className="muted">Proje bilgileri, kaynakça, danışman görüşmeleri, taslaklar, revizyonlar ve teslimler. Tarihli teslimler takvime ve 14 günlük plana otomatik eklenir. Bilinmeyen bilgileri boş bırakabilirsin.</p>
      </header>

      {open.length > 0 && (
        <section className="card" aria-labelledby="yaklasan">
          <h2 id="yaklasan">Yaklaşan teslimler ve görevler</h2>
          <ul className="mt-2 space-y-1 text-sm">{open.map((e) => <li key={e.id}><span className="badge mr-2">{ENTRY_KINDS[e.kind]}</span>{e.title} — <strong>{fmtDate(e.due_date)}</strong></li>)}</ul>
        </section>
      )}

      <details className="card" open={!data.profile.title}>
        <summary className="cursor-pointer font-semibold">Proje bilgileri {data.profile.title && <span className="muted font-normal">— {data.profile.title}</span>}</summary>
        <form action={saveProjectProfileAction} className="mt-3 grid gap-3 sm:grid-cols-2">
          {PROFILE_FIELDS.map(([name, label, long]) => (
            <label key={name} className={`text-sm ${long ? "sm:col-span-2" : ""}`}>{label}
              {long ? <textarea name={name} defaultValue={data.profile[name]} className="input mt-1 min-h-20" /> : <input name={name} defaultValue={data.profile[name]} className="input mt-1" />}
            </label>
          ))}
          <div><SubmitButton>Kaydet</SubmitButton></div>
        </form>
      </details>

      <section className="card space-y-3" aria-labelledby="yeni">
        <h2 id="yeni">Yeni kayıt</h2>
        <form action={createProjectEntryAction} className="grid gap-3 sm:grid-cols-3">
          <label className="text-sm">Tür<select name="kind" className="input mt-1">{Object.entries(ENTRY_KINDS).map(([k, v]) => <option key={k} value={k}>{v}</option>)}</select></label>
          <label className="text-sm sm:col-span-2">Başlık<input name="title" required className="input mt-1" placeholder="ör. Danışmanla 2. görüşme / Çekim planı / Ara teslim" /></label>
          <label className="text-sm sm:col-span-3">Ayrıntı (kaynakça künyesi, görüşme notu, geri bildirim, taslak metni…)<textarea name="body" className="input mt-1 min-h-24" /></label>
          <label className="text-sm">Tarih (yapıldığı)<input name="eventDate" type="date" className="input mt-1" /></label>
          <label className="text-sm">Son tarih (varsa)<input name="dueDate" type="date" className="input mt-1" /></label>
          <label className="text-sm">İlgili kaynak (GZT440)
            <select name="sourceId" className="input mt-1"><option value="">—</option>{data.sources.map((s) => <option key={s.id} value={s.id}>{s.title}</option>)}</select>
          </label>
          <div className="sm:col-span-3"><SubmitButton>Ekle</SubmitButton></div>
        </form>
      </section>

      {grouped.filter((g) => g.list.length).map((g) => (
        <section key={g.kind} className="card space-y-2" aria-labelledby={`k-${g.kind}`} data-testid="proje-bolumu">
          <h2 id={`k-${g.kind}`} className="text-base">{ENTRY_KINDS[g.kind]} <span className="muted font-normal">({g.list.length})</span></h2>
          <ul className="divide-y divide-slate-200 dark:divide-slate-800">
            {g.list.map((e) => (
              <li key={e.id} className="space-y-1 py-2 text-sm">
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <p className={`font-medium ${e.status === "tamamlandi" ? "line-through opacity-70" : ""}`}>
                    {e.title} {e.event_date && <span className="muted">· {fmtDate(e.event_date)}</span>} {e.due_date && <span className="badge-warn">Son: {fmtDate(e.due_date)}</span>}
                  </p>
                  <span className="flex gap-2">
                    <form action={toggleProjectEntryAction}>
                      <input type="hidden" name="entryId" value={e.id} />
                      <input type="hidden" name="status" value={e.status === "acik" ? "tamamlandi" : "acik"} />
                      <SubmitButton className="btn-secondary">{e.status === "acik" ? "Tamamlandı" : "Yeniden aç"}</SubmitButton>
                    </form>
                    <form action={deleteProjectEntryAction}>
                      <input type="hidden" name="entryId" value={e.id} />
                      <ConfirmSubmit message="Bu kayıt silinsin mi?">Sil</ConfirmSubmit>
                    </form>
                  </span>
                </div>
                {e.body && <p className="whitespace-pre-wrap">{e.body}</p>}
                <details>
                  <summary className="cursor-pointer text-xs">Düzenle</summary>
                  <form action={updateProjectEntryAction} className="mt-2 grid gap-2 sm:grid-cols-3">
                    <input type="hidden" name="entryId" value={e.id} />
                    <input name="title" defaultValue={e.title} required className="input sm:col-span-3" aria-label="Başlık" />
                    <textarea name="body" defaultValue={e.body} className="input sm:col-span-3" aria-label="Ayrıntı" />
                    <input name="eventDate" type="date" defaultValue={e.event_date ?? ""} className="input" aria-label="Tarih" />
                    <input name="dueDate" type="date" defaultValue={e.due_date ?? ""} className="input" aria-label="Son tarih" />
                    <SubmitButton className="btn-secondary">Kaydet</SubmitButton>
                  </form>
                </details>
              </li>
            ))}
          </ul>
        </section>
      ))}
    </div>
  );
}
