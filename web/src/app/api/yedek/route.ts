import { getCurrentUser } from "@/lib/auth";
import { withUser } from "@/lib/db";
import { exportBackup } from "@/lib/data/backup";

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
