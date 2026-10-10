import { NextRequest, NextResponse } from "next/server";
import { getCurrentUser } from "@/lib/auth";
import { beginChatGPTAuthorization } from "@/lib/ai/chatgpt";

export async function GET(req: NextRequest) {
  const user = await getCurrentUser();
  if (!user) return NextResponse.redirect(new URL("/giris", req.url));
  try {
    const url = new URL(req.url);
    const origin = url.origin;
    const target = await beginChatGPTAuthorization(user.id, origin);
    return NextResponse.redirect(target);
  } catch (error) {
    return NextResponse.redirect(new URL("/ayarlar?hata=" + encodeURIComponent(error instanceof Error ? error.message : "Bağlantı başarısız."), req.url));
  }
}