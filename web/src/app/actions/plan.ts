"use server";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { requireUser } from "@/lib/auth";
import { withUser } from "@/lib/db";
import {
  addManualTask, addWindow, completeTask, deleteWindow, moveTask, postponeTask, regeneratePlan, releaseTask, reopenTask, updateSettings,
} from "@/lib/data/plan";
import { isUuid, setTopicCatchUp } from "@/lib/data/courses";

const str = (f: FormData, k: string) => String(f.get(k) ?? "").trim();
const go = (path: string, params: Record<string, string>) => {
  const [p, q] = path.split("?");
  const sp = new URLSearchParams(q);
  for (const [k, v] of Object.entries(params)) sp.set(k, v);
  return `${p}?${sp.toString()}`;
};
const back = (f: FormData) => str(f, "returnTo") || "/plan";

async function run(form: FormData, fn: (userId: string) => Promise<unknown>, ok: string) {
  const user = await requireUser();
  try {
    await fn(user.id);
  } catch (e) {
    redirect(go(back(form), { hata: (e as Error).message }));
  }
  revalidatePath("/", "layout");
  redirect(go(back(form), { tamam: ok }));
}

export async function regenerateAction(form: FormData) {
  await run(form, (uid) => withUser(uid, (tx) => regeneratePlan(tx, uid)), "Plan güncel duruma göre yeniden oluşturuldu.");
}
export async function completeTaskAction(form: FormData) {
  await run(form, (uid) => withUser(uid, (tx) => completeTask(tx, str(form, "taskId"))), "Görev tamamlandı olarak işaretlendi.");
}
export async function reopenTaskAction(form: FormData) {
  await run(form, (uid) => withUser(uid, (tx) => reopenTask(tx, str(form, "taskId"))), "Görev yeniden açıldı.");
}
export async function postponeTaskAction(form: FormData) {
  await run(form, (uid) => withUser(uid, (tx) => postponeTask(tx, str(form, "taskId"))), "Görev ertelendi; uygun bir sonraki güne planlanacak.");
}
export async function releaseTaskAction(form: FormData) {
  await run(form, (uid) => withUser(uid, (tx) => releaseTask(tx, str(form, "taskId"))), "Görev otomatik planlamaya bırakıldı.");
}
export async function moveTaskAction(form: FormData) {
  await run(form, (uid) => withUser(uid, (tx) => moveTask(tx, str(form, "taskId"), str(form, "date"), str(form, "start"))), "Görev taşındı ve sabitlendi.");
}
export async function addTaskAction(form: FormData) {
  const topicId = str(form, "topicId");
  await run(
    form,
    (uid) =>
      withUser(uid, (tx) =>
        addManualTask(tx, uid, {
          courseId: str(form, "courseId"), topicId: isUuid(topicId) ? topicId : null, title: str(form, "title"),
          date: str(form, "date"), start: str(form, "start"), minutes: Number(str(form, "minutes")),
        }),
      ),
    "Görev eklendi.",
  );
}

export async function saveSettingsAction(form: FormData) {
  const n = (k: string) => Number(str(form, k));
  const semesterEnd = str(form, "semesterEnd");
  await run(
    form,
    async (uid) => {
      const s = {
        weekdayCapacityMin: n("weekdayCapacityMin"), weekendCapacityMin: n("weekendCapacityMin"), maxTaskMin: n("maxTaskMin"),
        breakMin: n("breakMin"), catchUpShare: n("catchUpShare"), semesterEnd: /^\d{4}-\d{2}-\d{2}$/.test(semesterEnd) ? semesterEnd : null,
      };
      if (!(s.weekdayCapacityMin >= 0 && s.weekdayCapacityMin <= 720 && s.weekendCapacityMin >= 0 && s.weekendCapacityMin <= 720))
        throw new Error("Günlük kapasite 0–720 dakika olmalı.");
      if (!(s.maxTaskMin >= 15 && s.maxTaskMin <= 180)) throw new Error("Görev uzunluğu 15–180 dakika olmalı.");
      if (!(s.breakMin >= 0 && s.breakMin <= 60)) throw new Error("Mola 0–60 dakika olmalı.");
      if (!(s.catchUpShare >= 0 && s.catchUpShare <= 100)) throw new Error("Telafi payı 0–100 olmalı.");
      await withUser(uid, (tx) => updateSettings(tx, uid, s));
    },
    "Plan ayarları kaydedildi; plan yeni ayarlarla yeniden oluşturulacak.",
  );
}
export async function addWindowAction(form: FormData) {
  await run(
    form,
    (uid) => withUser(uid, (tx) => addWindow(tx, uid, { weekday: Number(str(form, "weekday")), start: str(form, "start"), end: str(form, "end") })),
    "Çalışma aralığı eklendi.",
  );
}
export async function deleteWindowAction(form: FormData) {
  await run(form, (uid) => withUser(uid, (tx) => deleteWindow(tx, str(form, "windowId"))), "Çalışma aralığı silindi.");
}
export async function setCatchUpAction(form: FormData) {
  await run(
    form,
    async (uid) => {
      await withUser(uid, (tx) => setTopicCatchUp(tx, str(form, "topicId"), str(form, "value") === "1"));
    },
    "Telafi işareti güncellendi.",
  );
}
