"use server";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { requireUser } from "@/lib/auth";
import { withUser } from "@/lib/db";
import { EncryptionUnavailableError } from "@/lib/crypto";
import { importOne, parseZip, summarize, type ImportItem, type ImportOutcome } from "@/lib/data/bulk-import";
import { getCourse, isUuid } from "@/lib/data/courses";
import { UploadError } from "@/lib/extract";
import { connect, disconnect, importCourseMaterials, linkCourse } from "@/lib/lms/debim";
import { MoodleError } from "@/lib/lms/moodle";

const str = (f: FormData, k: string) => String(f.get(k) ?? "").trim();
const go = (p: string, params: Record<string, string>) => `${p}?${new URLSearchParams(params)}`;
const msg = (e: unknown) => (e instanceof MoodleError || e instanceof EncryptionUnavailableError || e instanceof UploadError ? e.message : "Beklenmeyen hata.");

export async function connectDebimAction(form: FormData) {
  const user = await requireUser();
  let name = "";
  try {
    const info = await connect(user.id, str(form, "site"), str(form, "token"));
    name = info.fullname;
  } catch (e) {
    if (!(e instanceof MoodleError || e instanceof EncryptionUnavailableError)) console.error("DEBİM bağlantı hatası", e);
    redirect(go("/debim", { hata: msg(e) }));
  }
  revalidatePath("/debim");
  redirect(go("/debim", { tamam: `DEBİM'e bağlanıldı (${name}). Anahtar şifreli saklandı; şifren hiçbir yerde tutulmaz.` }));
}

export async function disconnectDebimAction() {
  const user = await requireUser();
  await withUser(user.id, (tx) => disconnect(tx));
  revalidatePath("/debim");
  redirect(go("/debim", { tamam: "DEBİM bağlantısı kaldırıldı ve anahtar silindi. Aktarılmış materyaller korunuyor." }));
}

export async function linkCourseAction(form: FormData) {
  const user = await requireUser();
  const courseId = str(form, "courseId");
  try {
    await withUser(user.id, (tx) => linkCourse(tx, user.id, Number(str(form, "lmsCourseId")), str(form, "lmsCourseName"), isUuid(courseId) ? courseId : null));
  } catch (e) {
    redirect(go("/debim", { hata: (e as Error).message }));
  }
  revalidatePath("/debim");
  redirect(go("/debim", { tamam: courseId ? "Ders eşleştirildi." : "Eşleştirme kaldırıldı." }));
}

export type ImportState = { error?: string; outcomes?: ImportOutcome[]; summary?: ReturnType<typeof summarize> } | undefined;

export async function importDebimCourseAction(_: ImportState, form: FormData): Promise<ImportState> {
  const user = await requireUser();
  try {
    const r = await importCourseMaterials(user.id, Number(str(form, "lmsCourseId")));
    revalidatePath("/", "layout");
    return r;
  } catch (e) {
    if (!(e instanceof MoodleError)) console.error("DEBİM aktarım hatası", e);
    return { error: msg(e) };
  }
}

/** Çoklu dosya veya ZIP (ör. DEBİM "ders içeriğini indir" dışa aktarımı) içe aktarma. */
export async function bulkImportAction(_: ImportState, form: FormData): Promise<ImportState> {
  const user = await requireUser();
  const courseId = str(form, "courseId");
  const files = form.getAll("files").filter((f): f is File => f instanceof File && f.size > 0);
  if (!files.length) return { error: "En az bir dosya veya ZIP seçin." };
  const totalSize = files.reduce((n, f) => n + f.size, 0);
  if (totalSize > 200 * 1024 * 1024) return { error: "Toplam boyut 200 MB'ı aşamaz." };
  try {
    const outcomes: ImportOutcome[] = [];
    const items: ImportItem[] = [];
    for (const f of files) {
      const data = Buffer.from(await f.arrayBuffer());
      if (/\.zip$/i.test(f.name)) {
        const z = await parseZip(data);
        items.push(...z.items);
        outcomes.push(...z.skipped);
      } else {
        items.push({ filename: f.name, data, topicTitle: str(form, "topicTitle") || null, week: str(form, "week") ? Number(str(form, "week")) : null });
      }
    }
    await withUser(user.id, async (tx) => {
      if (!(await getCourse(tx, courseId))) throw new UploadError("Ders bulunamadı.");
      for (const it of items) outcomes.push(await importOne(tx, user.id, courseId, it));
    });
    revalidatePath("/", "layout");
    return { outcomes, summary: summarize(outcomes) };
  } catch (e) {
    if (!(e instanceof UploadError)) console.error("Toplu içe aktarma hatası", e);
    return { error: msg(e) };
  }
}
