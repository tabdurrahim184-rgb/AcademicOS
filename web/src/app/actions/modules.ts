"use server";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { requireUser } from "@/lib/auth";
import { withUser, type Tx } from "@/lib/db";
import { isUuid } from "@/lib/data/courses";
import { createEntry, deleteEntry, ENTRY_KINDS, saveProfile, setEntryStatus, updateEntry, type EntryKind } from "@/lib/data/project";
import { addDebateSource, createDebate, deleteDebate, deleteDebateSource, setSourceVerified, updateDebate, DEBATE_THEMES, type DebateTheme } from "@/lib/data/debates";
import {
  addCommitment, addRevision, createWorkTask, deleteCommitment, deleteWorkTask, scheduleWorkTask, setWorkStatus, updateMinuteList, WORK_STATUSES,
  type WorkStatus,
} from "@/lib/data/work";

const str = (f: FormData, k: string) => String(f.get(k) ?? "").trim();
const go = (path: string, params: Record<string, string>) => {
  const [p, q] = path.split("?");
  const sp = new URLSearchParams(q);
  for (const [k, v] of Object.entries(params)) sp.set(k, v);
  return `${p}?${sp.toString()}`;
};

/** Ortak eylem kalıbı: yetki, işlem, hata mesajı ve yönlendirme. */
async function run(form: FormData, fallback: string, ok: string, fn: (tx: Tx, userId: string) => Promise<unknown>) {
  const user = await requireUser();
  const back = str(form, "returnTo") || fallback;
  try {
    await withUser(user.id, (tx) => fn(tx, user.id));
  } catch (e) {
    redirect(go(back, { hata: (e as Error).message }));
  }
  revalidatePath("/", "layout");
  redirect(go(back, { tamam: ok }));
}

// ---------------------------------------------------------------- Bölüm Projesi
export async function saveProjectProfileAction(form: FormData) {
  await run(form, "/proje", "Proje bilgileri kaydedildi.", (tx, uid) =>
    saveProfile(tx, uid, {
      title: str(form, "title"), aim: str(form, "aim"), research_questions: str(form, "research_questions"),
      method: str(form, "method"), format: str(form, "format"), advisor: str(form, "advisor"),
    }),
  );
}
export async function createProjectEntryAction(form: FormData) {
  const kind = str(form, "kind") as EntryKind;
  await run(form, "/proje", `${ENTRY_KINDS[kind] ?? "Kayıt"} eklendi.`, (tx, uid) =>
    createEntry(tx, uid, {
      kind, title: str(form, "title"), body: String(form.get("body") ?? ""), eventDate: str(form, "eventDate"), dueDate: str(form, "dueDate"),
      sourceId: isUuid(str(form, "sourceId")) ? str(form, "sourceId") : null,
    }),
  );
}
export async function updateProjectEntryAction(form: FormData) {
  await run(form, "/proje", "Kayıt güncellendi.", (tx) =>
    updateEntry(tx, str(form, "entryId"), { title: str(form, "title"), body: String(form.get("body") ?? ""), eventDate: str(form, "eventDate"), dueDate: str(form, "dueDate") }),
  );
}
export async function toggleProjectEntryAction(form: FormData) {
  await run(form, "/proje", "Durum güncellendi.", (tx) => setEntryStatus(tx, str(form, "entryId"), str(form, "status") === "tamamlandi" ? "tamamlandi" : "acik"));
}
export async function deleteProjectEntryAction(form: FormData) {
  await run(form, "/proje", "Kayıt silindi.", (tx) => deleteEntry(tx, str(form, "entryId")));
}

// ---------------------------------------------------------------- Akademik Tartışmalar
export async function createDebateAction(form: FormData) {
  const user = await requireUser();
  let id = "";
  try {
    id = await withUser(user.id, (tx) =>
      createDebate(tx, user.id, {
        theme: str(form, "theme") as DebateTheme, title: str(form, "title"),
        courseId: isUuid(str(form, "courseId")) ? str(form, "courseId") : null,
      }),
    );
  } catch (e) {
    redirect(go("/tartismalar", { hata: (e as Error).message }));
  }
  revalidatePath("/tartismalar");
  redirect(`/tartismalar/${id}`);
}
export async function updateDebateAction(form: FormData) {
  const id = str(form, "debateId");
  await run(form, `/tartismalar/${id}`, "Tartışma kaydedildi.", (tx) =>
    updateDebate(tx, id, {
      title: str(form, "title"), theme: (str(form, "theme") in DEBATE_THEMES ? str(form, "theme") : "diger") as DebateTheme,
      claim: str(form, "claim"), academic_context: str(form, "academic_context"), counter_arguments: str(form, "counter_arguments"),
      islamic_perspective: str(form, "islamic_perspective"), class_answer: str(form, "class_answer"), weaknesses: str(form, "weaknesses"),
      uncertainties: str(form, "uncertainties"),
    }),
  );
}
export async function deleteDebateAction(form: FormData) {
  await run(form, "/tartismalar", "Tartışma silindi.", (tx) => deleteDebate(tx, str(form, "debateId")));
}
export async function addDebateSourceAction(form: FormData) {
  const id = str(form, "debateId");
  await run(form, `/tartismalar/${id}`, "Kaynak eklendi.", (tx, uid) =>
    addDebateSource(tx, uid, id, { kind: str(form, "kind"), reference: str(form, "reference"), quote: str(form, "quote"), note: str(form, "note") }),
  );
}
export async function verifyDebateSourceAction(form: FormData) {
  await run(form, "/tartismalar", "Kaynak durumu güncellendi.", (tx) => setSourceVerified(tx, str(form, "sourceId"), str(form, "verified") === "1"));
}
export async function deleteDebateSourceAction(form: FormData) {
  await run(form, "/tartismalar", "Kaynak silindi.", (tx) => deleteDebateSource(tx, str(form, "sourceId")));
}

// ---------------------------------------------------------------- İş Merkezi
export async function createWorkTaskAction(form: FormData) {
  const date = str(form, "dueDate");
  await run(form, "/is", "İş görevi eklendi.", (tx, uid) =>
    createWorkTask(tx, uid, {
      clientId: str(form, "clientId"), kind: str(form, "kind"), title: str(form, "title"), requestedBy: str(form, "requestedBy"),
      description: str(form, "description"), dueDate: date || null, dueTime: str(form, "dueTime") || "18:00",
      priority: str(form, "priority"), estimateMin: Number(str(form, "estimateMin") || 60),
    }),
  );
}
export async function setWorkStatusAction(form: FormData) {
  const s = str(form, "status") as WorkStatus;
  await run(form, "/is", "Durum güncellendi.", (tx, uid) => {
    if (!(s in WORK_STATUSES)) throw new Error("Geçersiz durum.");
    return setWorkStatus(tx, uid, str(form, "taskId"), s);
  });
}
export async function addRevisionAction(form: FormData) {
  await run(form, "/is", "Revizyon kaydedildi.", (tx, uid) => addRevision(tx, uid, str(form, "taskId"), str(form, "note")));
}
export async function scheduleWorkTaskAction(form: FormData) {
  await run(form, "/is", "İş görevi akademik zamanın dışına planlandı.", (tx, uid) => scheduleWorkTask(tx, uid, str(form, "taskId")));
}
export async function deleteWorkTaskAction(form: FormData) {
  await run(form, "/is", "İş görevi silindi.", (tx) => deleteWorkTask(tx, str(form, "taskId")));
}
export async function saveMinuteListAction(form: FormData) {
  await run(form, "/is", "Dakika listesi kaydedildi.", (tx) => updateMinuteList(tx, str(form, "taskId"), String(form.get("minutes") ?? "")));
}
export async function addCommitmentAction(form: FormData) {
  await run(form, "/is", "Sabit iş saati eklendi.", (tx, uid) =>
    addCommitment(tx, uid, { clientId: str(form, "clientId"), title: str(form, "title"), weekday: Number(str(form, "weekday")), start: str(form, "start"), end: str(form, "end") || null }),
  );
}
export async function deleteCommitmentAction(form: FormData) {
  await run(form, "/is", "Sabit iş saati silindi.", (tx) => deleteCommitment(tx, str(form, "commitmentId")));
}
