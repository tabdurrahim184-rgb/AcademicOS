import Link from "next/link";
import { logoutAction } from "@/app/actions/auth";
import { MobileNav } from "@/components/MobileNav";
import { NavLinks } from "@/components/NavLinks";
import { requireUser } from "@/lib/auth";

export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const user = await requireUser();
  return (
    <div className="min-h-screen lg:flex">
      <a href="#icerik" className="sr-only focus:not-sr-only focus:absolute focus:z-50 focus:p-2">İçeriğe geç</a>
      <aside className="hidden w-64 shrink-0 border-r border-slate-200 bg-white p-4 dark:border-slate-800 dark:bg-slate-900 lg:block">
        <Link href="/" className="mb-6 block no-underline hover:no-underline">
          <span className="block text-sm font-bold tracking-wide text-indigo-700 dark:text-indigo-300">TÜRKMENOĞLU</span>
          <span className="block text-xs text-slate-500">Akademik ve Çalışma Asistanı</span>
        </Link>
        <nav aria-label="Ana menü"><NavLinks /></nav>
        <div className="mt-8 border-t border-slate-200 pt-4 text-sm dark:border-slate-800">
          <p className="truncate font-medium">{user.name}</p>
          <p className="truncate text-xs text-slate-500">{user.email}</p>
          <form action={logoutAction} className="mt-2"><button className="btn-secondary w-full">Çıkış yap</button></form>
        </div>
      </aside>
      <header className="relative flex h-14 items-center justify-between border-b border-slate-200 bg-white px-4 dark:border-slate-800 dark:bg-slate-900 lg:hidden">
        <Link href="/" className="text-sm font-bold text-indigo-700 no-underline dark:text-indigo-300">TÜRKMENOĞLU</Link>
        <div className="flex items-center gap-2">
          <MobileNav />
          <form action={logoutAction}><button className="btn-secondary">Çıkış</button></form>
        </div>
      </header>
      <main id="icerik" className="min-w-0 flex-1 px-4 py-6 lg:px-8">{children}</main>
    </div>
  );
}
