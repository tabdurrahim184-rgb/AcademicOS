import Link from "next/link";
import { addWindowAction, deleteWindowAction, saveSettingsAction } from "@/app/actions/plan";
import { ConfirmSubmit } from "@/components/ConfirmSubmit";
import { Flash } from "@/components/Flash";
import { SubmitButton } from "@/components/SubmitButton";
import { requireUser } from "@/lib/auth";
import { withUser } from "@/lib/db";
import { getSettings, getWindows } from "@/lib/data/plan";
import { trTime, WEEKDAYS } from "@/lib/schedule";

export const metadata = { title: "Plan ayarları" };
export const dynamic = "force-dynamic";

export default async function PlanSettingsPage({ searchParams }: { searchParams: Promise<Record<string, string | undefined>> }) {
  const sp = await searchParams;
  const user = await requireUser();
  const { s, windows } = await withUser(user.id, async (tx) => ({ s: await getSettings(tx, user.id), windows: await getWindows(tx, user.id) }));
  const here = "/plan/ayarlar";
  return (
    <div className="mx-auto max-w-3xl space-y-6">
      <Flash sp={sp} />
      <Link href="/plan" className="text-sm">← Çalışma planı</Link>
      <h1>Kapasite ve çalışma saatleri</h1>

      <form action={saveSettingsAction} className="card grid gap-4 sm:grid-cols-2">
        <input type="hidden" name="returnTo" value={here} />
        <label className="text-sm">Hafta içi günlük ders çalışma kapasitesi (dk)
          <input name="weekdayCapacityMin" type="number" min={0} max={720} defaultValue={s.weekdayCapacityMin} className="input mt-1" />
          <span className="muted">Derslere girdiğin süre hariç, gerçekten çalışabileceğin toplam süre.</span>
        </label>
        <label className="text-sm">Hafta sonu günlük kapasite (dk)
          <input name="weekendCapacityMin" type="number" min={0} max={720} defaultValue={s.weekendCapacityMin} className="input mt-1" />
        </label>
        <label className="text-sm">En uzun tek görev (dk)
          <input name="maxTaskMin" type="number" min={15} max={180} defaultValue={s.maxTaskMin} className="input mt-1" />
        </label>
        <label className="text-sm">Görevler arası mola (dk)
          <input name="breakMin" type="number" min={0} max={60} defaultValue={s.breakMin} className="input mt-1" />
        </label>
        <label className="text-sm">Telafiye ayrılabilecek en fazla pay (%)
          <input name="catchUpShare" type="number" min={0} max={100} defaultValue={s.catchUpShare} className="input mt-1" />
          <span className="muted">Kalan süre güncel dersler, tekrar ve sınav hazırlığı için korunur.</span>
        </label>
        <label className="text-sm">Dönem sonu (biliyorsan)
          <input name="semesterEnd" type="date" defaultValue={s.semesterEnd ?? ""} className="input mt-1" />
          <span className="muted">Takvim dışa aktarımında ders tekrarları bu tarihte biter. Bilinmiyorsa boş bırak.</span>
        </label>
        <div className="sm:col-span-2"><SubmitButton>Kaydet</SubmitButton></div>
      </form>

      <section className="card space-y-3" aria-labelledby="araliklar">
        <h2 id="araliklar">Ders çalışabileceğin zaman aralıkları</h2>
        <p className="muted">Hafta içi 08.30–18.00 akademik zamandır: bu aralıkta yalnızca ders ve ders çalışma planlanır, ders saatleri otomatik olarak dışarıda tutulur. Akşam aralıklarını yemek, ulaşım ve dinlenmeyi düşünerek gerçekçi gir.</p>
        <ul className="divide-y divide-slate-200 text-sm dark:divide-slate-800">
          {windows.map((w) => (
            <li key={w.id} className="flex items-center justify-between py-2">
              <span>{WEEKDAYS[w.weekday]} {trTime(w.start)}–{trTime(w.end)}</span>
              <form action={deleteWindowAction}>
                <input type="hidden" name="windowId" value={w.id} />
                <input type="hidden" name="returnTo" value={here} />
                <ConfirmSubmit message="Bu çalışma aralığı silinsin mi?">Sil</ConfirmSubmit>
              </form>
            </li>
          ))}
        </ul>
        <form action={addWindowAction} className="flex flex-wrap items-end gap-2">
          <input type="hidden" name="returnTo" value={here} />
          <label className="text-sm">Gün<select name="weekday" className="input mt-1 w-auto">{WEEKDAYS.slice(1).map((d, i) => <option key={d} value={i + 1}>{d}</option>)}</select></label>
          <label className="text-sm">Başlangıç<input name="start" type="time" required className="input mt-1 w-auto" /></label>
          <label className="text-sm">Bitiş<input name="end" type="time" required className="input mt-1 w-auto" /></label>
          <SubmitButton className="btn-secondary">Aralık ekle</SubmitButton>
        </form>
      </section>
    </div>
  );
}
