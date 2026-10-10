import { getCurrentUser } from "@/lib/auth";
import { withUser } from "@/lib/db";
import { getRecording, listSegments } from "@/lib/data/recordings";
import { toDocx, toSrt, toTxt, toVtt } from "@/lib/transcription";

export async function GET(req: Request, { params }: { params: Promise<{ id: string }> }) {
  const user = await getCurrentUser();
  if (!user) return new Response("Oturum gerekli.", { status: 401 });
  const { id } = await params;
  const data = await withUser(user.id, async (tx) => {
    const r = await getRecording(tx, id);
    return r ? { r, segs: await listSegments(tx, id) } : null;
  });
  if (!data) return new Response("Bulunamadı.", { status: 404 });
  if (!data.segs.length) return new Response("Bu kaydın deşifresi yok.", { status: 404 });
  const format = new URL(req.url).searchParams.get("bicim") ?? "txt";
  const name = encodeURIComponent(data.r.title.replace(/[^\p{L}\p{N} _-]/gu, "").slice(0, 80) || "desifre");
  const disp = (ext: string) => `attachment; filename*=UTF-8''${name}.${ext}`;
  switch (format) {
    case "srt": return new Response(toSrt(data.segs), { headers: { "Content-Type": "application/x-subrip; charset=utf-8", "Content-Disposition": disp("srt") } });
    case "vtt": return new Response(toVtt(data.segs), { headers: { "Content-Type": "text/vtt; charset=utf-8", "Content-Disposition": disp("vtt") } });
    case "docx": return new Response(new Uint8Array(await toDocx(data.r.title, data.segs)), {
      headers: { "Content-Type": "application/vnd.openxmlformats-officedocument.wordprocessingml.document", "Content-Disposition": disp("docx") },
    });
    default: return new Response(toTxt(data.segs), { headers: { "Content-Type": "text/plain; charset=utf-8", "Content-Disposition": disp("txt") } });
  }
}
