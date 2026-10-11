import { getCurrentUser } from "@/lib/auth";
import { withUser } from "@/lib/db";
import { exportBackup, restoreBackup } from "@/lib/data/backup";
import { sameOrigin } from "@/lib/route-guard";

export async function GET() {
  const user = await getCurrentUser();
  if (!user) return new Response("Oturum gerekli.", { status: 401 });
  const backup = await withUser(user.id, exportBackup);
  const date = new Date().toISOString().slice(0, 10);
  return new Response(JSON.stringify(backup), {
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Content-Disposition": `attachment; filename="academicos-yedek-${date}.json"`,
      "Cache-Control": "private, no-store",
    },
  });
}

/** Yedekten geri yükleme (büyük yedekler için sunucu eyleminin 26 MB sınırı yerine bu uç nokta kullanılır). */
export async function POST(req: Request) {
  const user = await getCurrentUser();
  if (!user) return new Response("Oturum gerekli.", { status: 401 });
  if (!sameOrigin(req)) return new Response("Geçersiz istek kaynağı.", { status: 403 });
  const back = (key: "hata" | "tamam", msg: string) => Response.redirect(new URL(`/ayarlar?${key}=${encodeURIComponent(msg)}`, req.url), 303);
  let form: FormData;
  try {
    form = await req.formData();
  } catch {
    return back("hata", "Yedek dosyası okunamadı.");
  }
  if (String(form.get("confirm") ?? "").trim() !== "GERİ YÜKLE") return back("hata", "Onay için kutuya GERİ YÜKLE yazın.");
  const file = form.get("file");
  if (!(file instanceof File) || !file.size) return back("hata", "Yedek dosyası seçin.");
  try {
    const json = JSON.parse(Buffer.from(await file.arrayBuffer()).toString("utf8"));
    const counts = await withUser(user.id, (tx) => restoreBackup(tx, user.id, json));
    return back("tamam", `Geri yükleme tamamlandı: ${counts.courses} ders, ${counts.sources} kaynak, ${counts.questions} soru.`);
  } catch (e) {
    return back("hata", `Geri yükleme başarısız; mevcut verin değiştirilmedi. (${(e as Error).message})`);
  }
}
