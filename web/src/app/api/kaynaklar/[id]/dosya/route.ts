import { getCurrentUser } from "@/lib/auth";
import { withUser } from "@/lib/db";
import { getSource, getSourceFile } from "@/lib/data/sources";

/** Özgün dosyayı yalnızca sahibine indirir (RLS + oturum kontrolü). */
export async function GET(_req: Request, { params }: { params: Promise<{ id: string }> }) {
  const user = await getCurrentUser();
  if (!user) return new Response("Oturum gerekli.", { status: 401 });
  const { id } = await params;
  const found = await withUser(user.id, async (tx) => {
    const s = await getSource(tx, id);
    return s ? { s, file: await getSourceFile(tx, id) } : null;
  });
  if (!found?.file) return new Response("Bulunamadı.", { status: 404 });
  const inline = found.s.file_type === "pdf" || found.s.file_type === "image";
  return new Response(new Uint8Array(found.file), {
    headers: {
      "Content-Type": found.s.mime,
      "Content-Length": String(found.file.length),
      "Content-Disposition": `${inline ? "inline" : "attachment"}; filename*=UTF-8''${encodeURIComponent(found.s.filename)}`,
      "Cache-Control": "private, no-store",
      // PDF görüntüleyici sandbox içinde çalışmadığı için PDF dışındaki türlere uygulanır.
      ...(found.s.file_type === "pdf" ? {} : { "Content-Security-Policy": "sandbox" }),
    },
  });
}
