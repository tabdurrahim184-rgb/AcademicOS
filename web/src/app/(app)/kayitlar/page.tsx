import Link from "next/link";
import { Flash } from "@/components/Flash";
import { requireUser } from "@/lib/auth";
import { withUser } from "@/lib/db";
import { listCourses } from "@/lib/data/courses";
import { listRecordings } from "@/lib/data/recordings";
import { ensureWorkSetup, listClients } from "@/lib/data/work";
import { fmtBytes, fmtDateTime } from "@/lib/format";
import { formatTs } from "@/lib/extract";
import { getTranscriptionStatus } from "@/lib/transcription";

export const metadata = { title: "Kayıtlar ve deşifre" };
export const dynamic = "force-dynamic";

const STATUS = { yuklendi: "Deşifre edilmedi", desifre_ediliyor: "Deşifre ediliyor", hazir: "Deşifre hazır", hata: "Hata" } as Record<string, string>;

export default async function RecordingsPage({ searchParams }: { searchParams: Promise<Record<string, string | undefined>> }) {
  const sp = await searchParams;
  const user = await requireUser();
  const archive = sp.arsiv === "is" ? "is" : "ders";
  const data = await withUser(user.id, async (tx) => {
    await ensureWorkSetup(tx, user.id);
    return { recs: await listRecordings(tx, archive), courses: await listCourses(tx), clients: await listClients(tx) };
  });
  const t = getTranscriptionStatus();
  return (
    <div className="mx-auto max-w-4xl space-y-6">
      <Flash sp={sp} />
      <h1>Kayıtlar ve deşifre</h1>
      <p className="muted">Ders ve iş kayıtları aynı altyapıyı kullanır ama ayrı arşivlerde tutulur. Kayıtlar yalnızca senin hesabında saklanır.</p>
      {!t.enabled ? (
        <p className="alert-info">Otomatik deşifre kapalı: {t.reason} Kaydı yükleyip dinleyebilirsin; deşifre için ücretli bir sağlayıcının (OpenAI) yapılandırılması ve her iş için senin onayın gerekir.</p>
      ) : (
        <p className="alert-info">Deşifre sağlayıcısı: OpenAI ({t.model}). Başlatılan her deşifrede ses dosyası parçalar hâlinde OpenAI&apos;ye gönderilir ve ücretlendirilir; her iş için ayrıca onay istenir.</p>
      )}
      <nav className="flex gap-2" aria-label="Arşiv">
        <Link href="/kayitlar?arsiv=ders" className={archive === "ders" ? "btn" : "btn-secondary"}>Ders kayıtları</Link>
        <Link href="/kayitlar?arsiv=is" className={archive === "is" ? "btn" : "btn-secondary"}>İş kayıtları</Link>
      </nav>
      <form action="/api/kayitlar" method="post" encType="multipart/form-data" className="card grid gap-3 sm:grid-cols-2">
        <input type="hidden" name="archive" value={archive} />
        <label className="text-sm sm:col-span-2">Ses / video dosyası (en fazla 100 MB)
          <input name="file" type="file" required className="input mt-1" accept="audio/*,video/*,.mp3,.m4a,.wav,.ogg,.webm,.mp4,.mov,.mkv,.aac,.flac" />
        </label>
        <label className="text-sm">Başlık<input name="title" className="input mt-1" /></label>
        {archive === "ders" ? (
          <label className="text-sm">Ders<select name="courseId" className="input mt-1"><option value="">—</option>{data.courses.map((c) => <option key={c.id} value={c.id}>{c.code} {c.name}</option>)}</select></label>
        ) : (
          <label className="text-sm">İşveren<select name="clientId" className="input mt-1"><option value="">—</option>{data.clients.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}</select></label>
        )}
        <div><button className="btn">Yükle</button></div>
      </form>
      <ul className="space-y-2">
        {data.recs.length === 0 && <li className="card muted">Bu arşivde kayıt yok.</li>}
        {data.recs.map((r) => (
          <li key={r.id} className="card text-sm">
            <Link href={`/kayitlar/${r.id}`} className="font-medium">{r.title}</Link>
            <p className="muted">{r.duration_sec ? formatTs(Number(r.duration_sec)) : "?"} · {fmtBytes(Number(r.size_bytes))} · {STATUS[r.status]} · {fmtDateTime(r.created_at)}</p>
          </li>
        ))}
      </ul>
    </div>
  );
}
