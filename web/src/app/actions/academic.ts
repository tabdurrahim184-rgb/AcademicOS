"use server";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { requireUser } from "@/lib/auth";
import { withUser } from "@/lib/db";
import {
  addMeeting, deleteMeeting, createTopic, setTopicStatus, updateCourse, isUuid, getCourse, TOPIC_STATUSES, type TopicStatus,
} from "@/lib/data/courses";
import { deleteSource, saveUploadedSource, SOURCE_KINDS, updateSource, type SourceKind } from "@/lib/data/sources";
import { createAssessment, deleteAssessment, updateAssessmentScore, type AssessmentKind } from "@/lib/data/assessments";
import { UploadError } from "@/lib/extract";
import { toMinutes } from "@/lib/schedule";

const str = (f: FormData, k: string) => String(f.get(k) ?? "").trim();
const back = (path: string, params: Record<string, string>) => `${path}?${new URLSearchParams(params).toString()}`;

export async function updateCourseAction(form: FormData) {
  const user = await requireUser();
  const id = str(form, "courseId");
  const code = str(form, "code");
  const name = str(form, "name");
  if (!code || !name) redirect(back(`/dersler/${id}`, { hata: "Ders kodu ve adı boş olamaz." }));
  const delivery = str(form, "delivery") === "cevrimici" ? "cevrimici" : "yuz_yuze";
  await withUser(user.id, (tx) =>
    updateCourse(tx, id, { code, name, instructor: str(form, "instructor") || null, delivery, notes: str(form, "notes") }),
  );
  revalidatePath("/", "layout");
  redirect(back(`/dersler/${id}`, { tamam: "Ders bilgileri kaydedildi." }));
}

export async function addMeetingAction(form: FormData) {
  const user = await requireUser();
  const id = str(form, "courseId");
  const weekday = Number(form.get("weekday"));
  const start = str(form, "start");
  const end = str(form, "end");
  if (!(weekday >= 1 && weekday <= 7) || !/^\d{2}:\d{2}$/.test(start) || !/^\d{2}:\d{2}$/.test(end) || toMinutes(end) <= toMinutes(start)) {
    redirect(back(`/dersler/${id}`, { hata: "Geçerli bir gün ve saat aralığı girin (bitiş başlangıçtan sonra olmalı)." }));
  }
  await withUser(user.id, (tx) => addMeeting(tx, user.id, id, weekday, start, end));
  revalidatePath("/", "layout");
  redirect(back(`/dersler/${id}`, { tamam: "Ders saati eklendi." }));
}

export async function deleteMeetingAction(form: FormData) {
  const user = await requireUser();
  await withUser(user.id, (tx) => deleteMeeting(tx, str(form, "meetingId")));
  revalidatePath("/", "layout");
  redirect(back(`/dersler/${str(form, "courseId")}`, { tamam: "Ders saati silindi." }));
}

export async function createTopicAction(form: FormData) {
  const user = await requireUser();
  const courseId = str(form, "courseId");
  const title = str(form, "title");
  const weekRaw = str(form, "week");
  const week = weekRaw ? Number(weekRaw) : null;
  if (title.length < 2 || (week != null && !(week >= 1 && week <= 20))) {
    redirect(back(`/dersler/${courseId}`, { hata: "Konu adı en az 2 karakter, hafta 1–20 arası olmalı." }));
  }
  await withUser(user.id, (tx) =>
    createTopic(tx, user.id, courseId, { title, week, description: str(form, "description"), isCatchUp: form.get("isCatchUp") === "on" }),
  );
  revalidatePath("/", "layout");
  redirect(back(str(form, "returnTo") || `/dersler/${courseId}`, { tamam: "Konu eklendi." }));
}

export async function setTopicStatusAction(form: FormData) {
  const user = await requireUser();
  const status = str(form, "status") as TopicStatus;
  if (!(status in TOPIC_STATUSES)) throw new Error("Geçersiz durum");
  await withUser(user.id, (tx) => setTopicStatus(tx, str(form, "topicId"), status));
  revalidatePath("/", "layout");
  redirect(str(form, "returnTo") || "/telafi");
}

export async function uploadSourceAction(form: FormData) {
  const user = await requireUser();
  const courseId = str(form, "courseId");
  const file = form.get("file");
  if (!(file instanceof File) || file.size === 0) redirect(back(`/dersler/${courseId}`, { hata: "Lütfen bir dosya seçin." }));
  const kind = str(form, "kind") as SourceKind;
  const topicId = str(form, "topicId") || null;
  let result: { id: string; status: string; note: string };
  try {
    const data = Buffer.from(await (file as File).arrayBuffer());
    result = await withUser(user.id, (tx) =>
      saveUploadedSource(tx, user.id, {
        courseId, topicId: topicId && isUuid(topicId) ? topicId : null, title: str(form, "title"),
        kind: kind in SOURCE_KINDS ? kind : "diger", filename: (file as File).name, data,
      }),
    );
  } catch (e) {
    const msg = e instanceof UploadError ? e.message : "Dosya kaydedilemedi.";
    if (!(e instanceof UploadError)) console.error("Yükleme hatası", e);
    redirect(back(`/dersler/${courseId}`, { hata: msg }));
  }
  revalidatePath("/", "layout");
  redirect(back(`/kaynaklar/${result.id}`, { yuklendi: "1" }));
}

export async function deleteSourceAction(form: FormData) {
  const user = await requireUser();
  const courseId = str(form, "courseId");
  await withUser(user.id, (tx) => deleteSource(tx, str(form, "sourceId")));
  revalidatePath("/", "layout");
  redirect(back(`/dersler/${courseId}`, { tamam: "Kaynak silindi." }));
}

export async function createAssessmentAction(form: FormData) {
  const user = await requireUser();
  const courseId = str(form, "courseId");
  const date = str(form, "dueDate");
  const time = str(form, "dueTime") || "09:00";
  const weightRaw = str(form, "weight");
  // Tarih/saat Kıbrıs yerel saati olarak girilir; sunucuda Europe/Nicosia ofsetiyle çevrilir.
  const dueAt = date ? nicosiaToUtc(date, time) : null;
  const weight = weightRaw ? Number(weightRaw) : null;
  if (weight != null && !(weight >= 0 && weight <= 100)) redirect(back(`/dersler/${courseId}`, { hata: "Ağırlık 0–100 arası olmalı." }));
  await withUser(user.id, async (tx) => {
    if (!(await getCourse(tx, courseId))) throw new Error("Ders bulunamadı");
    await createAssessment(tx, user.id, { courseId, kind: str(form, "kind") as AssessmentKind, title: str(form, "title"), dueAt, weight });
  });
  revalidatePath("/", "layout");
  redirect(back(`/dersler/${courseId}`, { tamam: "Değerlendirme eklendi." }));
}

export async function updateAssessmentScoreAction(form: FormData) {
  const user = await requireUser();
  const raw = str(form, "score");
  const score = raw === "" ? null : Number(raw);
  if (score != null && !(score >= 0 && score <= 100)) redirect(back(`/dersler/${str(form, "courseId")}`, { hata: "Not 0–100 arası olmalı." }));
  await withUser(user.id, (tx) => updateAssessmentScore(tx, str(form, "assessmentId"), score));
  revalidatePath("/", "layout");
  redirect(back(`/dersler/${str(form, "courseId")}`, { tamam: "Not kaydedildi." }));
}

export async function deleteAssessmentAction(form: FormData) {
  const user = await requireUser();
  await withUser(user.id, (tx) => deleteAssessment(tx, str(form, "assessmentId")));
  revalidatePath("/", "layout");
  redirect(back(`/dersler/${str(form, "courseId")}`, { tamam: "Değerlendirme silindi." }));
}

/** "2026-11-20" + "09:00" (Kıbrıs yerel saati) → UTC Date. Yaz/kış saati otomatik hesaplanır. */
function nicosiaToUtc(date: string, time: string): Date {
  const naive = new Date(`${date}T${time}:00Z`);
  const fmt = new Intl.DateTimeFormat("en-GB", { timeZone: "Europe/Nicosia", timeZoneName: "longOffset" });
  const off = fmt.formatToParts(naive).find((p) => p.type === "timeZoneName")?.value ?? "GMT+02:00";
  const m = off.match(/GMT([+-])(\d{2}):(\d{2})/);
  const minutes = m ? (m[1] === "-" ? -1 : 1) * (Number(m[2]) * 60 + Number(m[3])) : 120;
  return new Date(naive.getTime() - minutes * 60_000);
}

export async function updateSourceAction(form: FormData) {
  const user = await requireUser();
  const id = str(form, "sourceId");
  const topicId = str(form, "topicId");
  try {
    await withUser(user.id, (tx) =>
      updateSource(tx, id, { title: str(form, "title"), kind: str(form, "kind") as SourceKind, topicId: isUuid(topicId) ? topicId : null }),
    );
  } catch (e) {
    redirect(back(`/kaynaklar/${id}`, { hata: (e as Error).message }));
  }
  revalidatePath("/", "layout");
  redirect(back(`/kaynaklar/${id}`, { tamam: "Kaynak bilgileri güncellendi." }));
}
