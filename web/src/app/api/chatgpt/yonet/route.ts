import { NextRequest, NextResponse } from "next/server";
import { getCurrentUser } from "@/lib/auth";
import { chooseChatGPTModel, disconnectChatGPT } from "@/lib/ai/chatgpt";

export async function POST(req: NextRequest) {
  const user = await getCurrentUser();
  if (!user) return NextResponse.redirect(new URL("/giris", req.url));
  const origin = req.headers.get("origin");
  if (origin !== new URL(req.url).origin)
    return new NextResponse("İstek kaynağı doğrulanamadı.", { status: 403 });
  try {
    const form = await req.formData();
    const op = form.get("action");
    if (op === "disconnect") await disconnectChatGPT(user.id);
    else if (op === "model") await chooseChatGPTModel(user.id, String(form.get("model") || ""));
    else return new NextResponse("Geçersiz işlem", { status: 400 });
    return NextResponse.redirect(new URL("/ayarlar?tamam=ChatGPT%20ayarlar%C4%B1%20g%C3%BCncellendi.", req.url), { status: 303 });
  } catch (error) {
    return NextResponse.redirect(new URL("/ayarlar?hata=" + encodeURIComponent(error instanceof Error ? error.message : "Bağlantı güncellenemedi."), req.url), { status: 303 });
  }
}