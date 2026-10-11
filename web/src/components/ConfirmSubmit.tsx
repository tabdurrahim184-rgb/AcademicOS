"use client";

/** Silme gibi geri alınamaz işlemlerden önce onay ister. */
export function ConfirmSubmit({ message, children, className = "btn-danger" }: { message: string; children: React.ReactNode; className?: string }) {
  return (
    <button
      type="submit"
      className={className}
      onClick={(e) => {
        if (!window.confirm(message)) e.preventDefault();
      }}
    >
      {children}
    </button>
  );
}
