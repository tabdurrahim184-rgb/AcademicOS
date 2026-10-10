import { NextRequest, NextResponse } from "next/server";
import { getCurrentUser } from "@/lib/auth";
import { finishChatGPTAuthorization } from "@/lib/ai/chatgpt";

export async function GET(req: NextRequest) {
  const user = await getCurrentUser();
  if (!user) return NextResponse.redirect(new URL("/giris", req.url));
  try {
    await finishChatGPTAuthorization(user.id, new URL(req.url));
    return NextResponse.redirect(new URL("/ayarlar?tamam=ChatGPT%20hesab%C4%B1n%20ba%C4%9Fland%C4%B1.", req.url));
  } catch (error) {
    return NextResponse.redirect(new URL("/ayarlar?hata=" + encodeURIComponent(error instanceof Error ? error.message : "ChatGPT girişi başarısız."), req.url));
  }
}