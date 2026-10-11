import { getCurrentUser } from "@/lib/auth";
import { withUser } from "@/lib/db";
import { getRecording, getRecordingFile } from "@/lib/data/recordings";

/** Kaydı yalnızca sahibine oynatır; tarayıcı ileri sarma için Range isteklerini destekler. */
export async function GET(req: Request, { params }: { params: Promise<{ id: string }> }) {
  const user = await getCurrentUser();
  if (!user) return new Response("Oturum gerekli.", { status: 401 });
  const { id } = await params;
  const found = await withUser(user.id, async (tx) => {
    const r = await getRecording(tx, id);
    return r ? { r, file: await getRecordingFile(tx, id) } : null;
  });
  if (!found?.file) return new Response("Bulunamadı.", { status: 404 });
  const size = found.file.length;
  const headers = { "Content-Type": found.r.mime, "Accept-Ranges": "bytes", "Cache-Control": "private, no-store", "X-Content-Type-Options": "nosniff" };
  const range = req.headers.get("range")?.match(/^bytes=(\d*)-(\d*)$/);
  if (range) {
    const start = range[1] ? Number(range[1]) : Math.max(0, size - Number(range[2]));
    const end = range[1] && range[2] ? Math.min(Number(range[2]), size - 1) : size - 1;
    if (start >= size || start > end) return new Response(null, { status: 416, headers: { "Content-Range": `bytes */${size}` } });
    return new Response(new Uint8Array(found.file.subarray(start, end + 1)), {
      status: 206, headers: { ...headers, "Content-Range": `bytes ${start}-${end}/${size}`, "Content-Length": String(end - start + 1) },
    });
  }
  return new Response(new Uint8Array(found.file), { headers: { ...headers, "Content-Length": String(size) } });
}
