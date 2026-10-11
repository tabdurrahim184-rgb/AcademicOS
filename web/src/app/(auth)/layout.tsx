export default function AuthLayout({ children }: { children: React.ReactNode }) {
  return (
    <main className="mx-auto flex min-h-screen max-w-md flex-col justify-center px-4 py-10">
      <p className="mb-1 text-sm font-semibold uppercase tracking-wide text-indigo-700 dark:text-indigo-300">TÜRKMENOĞLU</p>
      <p className="mb-6 muted">Akademik ve Çalışma Asistanı</p>
      <div className="card">{children}</div>
    </main>
  );
}
