"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";

export const NAV = [
  { href: "/", label: "Kontrol paneli" },
  { href: "/calis", label: "Ders çalış" },
  { href: "/plan", label: "Çalışma planı" },
  { href: "/takvim", label: "Takvim" },
  { href: "/dersler", label: "Derslerim" },
  { href: "/tekrar", label: "Tekrar" },
  { href: "/yanlislar", label: "Yanlışlar defteri" },
  { href: "/telafi", label: "Telafi planı" },
  { href: "/proje", label: "Bölüm Projesi" },
  { href: "/tartismalar", label: "Akademik tartışmalar" },
  { href: "/is", label: "İş merkezi" },
  { href: "/kayitlar", label: "Kayıtlar ve deşifre" },
  { href: "/ara", label: "Kaynaklarda ara" },
  { href: "/debim", label: "DEBİM ve içe aktarma" },
  { href: "/ayarlar", label: "Ayarlar ve yedek" },
];

export function NavLinks({ onNavigate }: { onNavigate?: () => void }) {
  const path = usePathname();
  return (
    <ul className="space-y-1">
      {NAV.map((n) => {
        const active = n.href === "/" ? path === "/" : path.startsWith(n.href);
        return (
          <li key={n.href}>
            <Link
              href={n.href}
              onClick={onNavigate}
              aria-current={active ? "page" : undefined}
              className={`block rounded-lg px-3 py-2 text-sm no-underline hover:no-underline ${
                active
                  ? "bg-indigo-50 font-semibold text-indigo-800 dark:bg-indigo-950 dark:text-indigo-200"
                  : "text-slate-700 hover:bg-slate-100 dark:text-slate-300 dark:hover:bg-slate-800"
              }`}
            >
              {n.label}
            </Link>
          </li>
        );
      })}
    </ul>
  );
}
