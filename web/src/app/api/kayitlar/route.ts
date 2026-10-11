import { getCurrentUser } from "@/lib/auth";
import { withUser } from "@/lib/db";
import { isUuid } from "@/lib/data/courses";
import { saveRecording } from "@/lib/data/recordings";
import { sameOrigin } from "@/lib/route-guard";
import { MAX_MEDIA_BYTES, probeDuration } from "@/lib/transcription";

/** Ses/video yükleme (100 MB'a kadar; sunucu eylemleri 26 MB ile sınırlı olduğu için ayrı uç nokta). */
export async function POST(req: Request) {
  const user = await getCurrentUser();
  if (!user) return new Response("Oturum gerekli.", { status: 401 });
  if (!sameOrigin(req)) return new Response("Geçersiz istek kaynağı.", { status: 403 });
  const len = Number(req.headers.get("content-length") ?? 0);
  if (len > MAX_MEDIA_BYTES + 1024 * 1024) return Response.redirect(new URL("/kayitlar?hata=" + encodeURIComponent("Dosya 100 MB sınırını aşıyor."), req.url), 303);
  const back = (msg: string) => Response.redirect(new URL(`/kayitlar?hata=${encodeURIComponent(msg)}`, req.url), 303);
  let form: FormData;
  try {
    form = await req.formData();
  } catch {
    return back("Yükleme okunamadı.");
  }
  const file = form.get("file");
  if (!(file instanceof File) || file.size === 0) return back("Bir ses veya video dosyası seçin.");
  const data = Buffer.from(await file.arrayBuffer());
  let duration: number;
  try {
    duration = await probeDuration(data);
  } catch (e) {
    return back((e as Error).message);
  }
  const archive = form.get("archive") === "is" ? "is" : "ders";
  const courseId = String(form.get("courseId") ?? "");
  const clientId = String(form.get("clientId") ?? "");
  try {
    const id = await withUser(user.id, (tx) =>
      saveRecording(tx, user.id, {
        archive, courseId: isUuid(courseId) ? courseId : null, clientId: isUuid(clientId) ? clientId : null,
        title: String(form.get("title") ?? ""), filename: file.name, data, durationSec: duration,
      }),
    );
    return Response.redirect(new URL(`/kayitlar/${id}?tamam=${encodeURIComponent("Kayıt yüklendi.")}`, req.url), 303);
  } catch (e) {
    return back((e as Error).message);
  }
}
