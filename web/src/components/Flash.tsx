export function Flash({ sp }: { sp: Record<string, string | string[] | undefined> }) {
  const err = typeof sp.hata === "string" ? sp.hata : null;
  const ok = typeof sp.tamam === "string" ? sp.tamam : null;
  return (
    <>
      {err && <p role="alert" className="alert-err mb-4">{err}</p>}
      {ok && <p role="status" className="alert-ok mb-4">{ok}</p>}
    </>
  );
}
