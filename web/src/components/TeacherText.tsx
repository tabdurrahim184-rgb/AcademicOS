/** Öğretmen yanıtı: "(Kaynak dışı bilgi)" ile başlayan paragrafları görsel olarak ayırır. */
export function TeacherText({ text }: { text: string }) {
  const paras = text.split(/\n{2,}/);
  return (
    <div className="space-y-2 text-sm leading-relaxed">
      {paras.map((p, i) =>
        /kaynak dışı/i.test(p) ? (
          <p key={i} className="whitespace-pre-wrap rounded border-l-4 border-amber-400 bg-amber-50 px-2 py-1 dark:bg-amber-950/40">
            <span className="badge-warn mr-1">Kaynak dışı</span>
            {p}
          </p>
        ) : (
          <p key={i} className="whitespace-pre-wrap">{p}</p>
        ),
      )}
    </div>
  );
}
