"use client";
import { useState } from "react";
import { NavLinks } from "./NavLinks";

export function MobileNav() {
  const [open, setOpen] = useState(false);
  return (
    <div className="lg:hidden">
      <button className="btn-secondary" aria-expanded={open} aria-controls="mobil-menu" onClick={() => setOpen((o) => !o)}>
        {open ? "Menüyü kapat" : "Menü"}
      </button>
      {open && (
        <nav id="mobil-menu" aria-label="Ana menü" className="absolute left-0 right-0 top-14 z-20 border-b border-slate-200 bg-white p-3 shadow-lg dark:border-slate-800 dark:bg-slate-900">
          <NavLinks onNavigate={() => setOpen(false)} />
        </nav>
      )}
    </div>
  );
}
