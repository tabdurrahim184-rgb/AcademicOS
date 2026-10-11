import Link from "next/link";
import { requireUser } from "@/lib/auth";
import { withUser } from "@/lib/db";
import { listCourses } from "@/lib/data/courses";
import { searchChunks } from "@/lib/data/sources";

export const metadata = { title: "Kaynaklarda ara" };
export const dynamic = "force-dynamic";

function highlight(text: string, q: string) {
  const i = text.toLocaleLowerCase("tr-TR").indexOf(q.toLocaleLowerCase("tr-TR"));
  const start = Math.max(0, i - 160);
  const snippet = (start > 0 ? "…" : "") + text.slice(start, start + 420) + (text.length > start + 420 ? "…" : "");
  if (i < 0) return snippet;
  const j = snippet.toLocaleLowerCase("tr-TR").indexOf(q.toLocaleLowerCase("tr-TR"));
  return <>{snippet.slice(0, j)}<mark>{snippet.slice(j, j + q.length)}</mark>{snippet.slice(j + q.length)}</>;
}

export default async function SearchPage({ searchParams }: { searchParams: Promise<{ q?: string; ders?: string }> }) {
  const { q = "", ders = "" } = await searchParams;
  const user = await requireUser();
  const { courses, hits } = await withUser(user.id, async (tx) => ({
    courses: await listCourses(tx),
    hits: q.trim() ? await searchChunks(tx, q, { courseId: validCourseId(ders), limit: 40 }) : [],
  }));
  const code = (id: string) => courses.find((c) => c.id === id)?.code ?? "";
  return (
    <div className="mx-auto max-w-4xl space-y-6">
      <h1>Kaynaklarda ara</h1>
      <form className="flex flex-wrap gap-2" role="search">
        <input name="q" defaultValue={q} className="input flex-1" placeholder="Kavram, isim veya ifade…" aria-label="Arama ifadesi" />
        <select name="ders" defaultValue={ders} className="input w-auto" aria-label="Ders">
          <option value="">Bütün dersler</option>
          {courses.map((c) => <option key={c.id} value={c.id}>{c.code}</option>)}
        </select>
        <button className="btn">Ara</button>
      </form>
      {q && <p className="muted">{hits.length} sonuç (yalnızca metni çıkarılmış kaynaklarda arama yapılır).</p>}
      <ul className="space-y-3">
        {hits.map((h) => (
          <li key={h.id} className="card text-sm">
            <p className="mb-1"><span className="badge mr-2">{code(h.course_id)}</span><Link href={`/kaynaklar/${h.source_id}#parca-${h.ord}`}>{h.source_title}</Link> · {h.locator}</p>
            <p className="whitespace-pre-wrap">{highlight(h.content, q.trim())}</p>
          </li>
        ))}
      </ul>
    </div>
  );
}

function validCourseId(id: string) {
  return /^[0-9a-f-]{36}$/i.test(id) ? id : undefined;
}
