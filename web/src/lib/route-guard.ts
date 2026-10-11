/** Rota işleyicileri için aynı köken (CSRF) kontrolü: tarayıcı Origin başlığı sunucu adresiyle eşleşmeli. */
export function sameOrigin(req: Request): boolean {
  const origin = req.headers.get("origin");
  if (!origin) return false;
  const host = req.headers.get("x-forwarded-host") ?? req.headers.get("host");
  try {
    return new URL(origin).host === host;
  } catch {
    return false;
  }
}
