"use server";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { requireUser } from "@/lib/auth";
import { withUser } from "@/lib/db";
import { isUuid } from "@/lib/data/courses";
import { createNote, deleteNote } from "@/lib/data/notes";
import { createObjective, deleteObjective } from "@/lib/data/objectives";
import { restoreBackup } from "@/lib/data/backup";
import {
  createQuestion, deleteQuestion, endStudySession, finalizeAttempt, startStudySession, STUDY_MODES, submitAnswer,
  updateSessionSources, type StudyMode,
} from "@/lib/data/study";
import { QUESTION_TYPES, type QuestionType } from "@/lib/grading";
import { AIRequestError, AIUnavailableError, getProvider } from "@/lib/ai/provider";
import { explainMistake, generateQuestions, generateTutorReply, gradeAttemptWithAI, saveStudentMessage, testConnection } from "@/lib/ai/tutor";

const str = (f: FormData, k: string) => String(f.get(k) ?? "").trim();
const withParams = (path: string, params: Record<string, string>) => {
  const [p, q] = path.split("?");
  const sp = new URLSearchParams(q);
  for (const [k, v] of Object.entries(params)) sp.set(k, v);
  return `${p}?${sp.toString()}`;
};
const aiMessage = (e: unknown) =>
  e instanceof AIUnavailableError || e instanceof AIRequestError ? e.message : e instanceof Error ? e.message : "Beklenmeyen hata.";

export async function startSessionAction(form: FormData) {
  const user = await requireUser();
  const mode = str(form, "mode") as StudyMode;
  const courseId = str(form, "courseId");
  const topicId = str(form, "topicId");
  const sourceIds = form.getAll("sourceIds").map(String);
  let id: string;
  try {
    id = await withUser(user.id, (tx) =>
      startStudySession(tx, user.id, {
        courseId, topicId: isUuid(topicId) ? topicId : null, mode: mode in STUDY_MODES ? mode : "okuma",
        goal: str(form, "goal"), sourceIds, onlySelected: form.get("onlySelected") === "on",
      }),
    );
  } catch (e) {
    redirect(withParams("/calis", { hata: (e as Error).message, ders: courseId }));
  }
  const starter = str(form, "starter");
  let error = "";
  if (starter) {
    await saveStudentMessage(user.id, id, starter);
    try {
      await generateTutorReply(user.id, id, getProvider());
    } catch (e) {
      error = `Öğretmen yanıtı alınamadı: ${aiMessage(e)}`;
    }
  }
  revalidatePath("/", "layout");
  redirect(error ? withParams(`/oturum/${id}`, { hata: error }) : `/oturum/${id}`);
}

export type ChatState = { error?: string } | undefined;

/** Öğrenci mesajını kaydeder (her durumda), ardından yapay zekâ yanıtını dener. */
export async function sendMessageAction(_: ChatState, form: FormData): Promise<ChatState> {
  const user = await requireUser();
  const sessionId = str(form, "sessionId");
  const text = str(form, "quick") || str(form, "message");
  if (!text) return { error: "Mesaj boş olamaz." };
  try {
    await saveStudentMessage(user.id, sessionId, text);
  } catch (e) {
    return { error: (e as Error).message };
  }
  revalidatePath(`/oturum/${sessionId}`);
  try {
    await generateTutorReply(user.id, sessionId, getProvider());
  } catch (e) {
    return { error: `Mesajın kaydedildi, ancak öğretmen yanıtı alınamadı: ${aiMessage(e)}` };
  }
  revalidatePath(`/oturum/${sessionId}`);
  return undefined;
}

export async function updateSessionSourcesAction(form: FormData) {
  const user = await requireUser();
  const sessionId = str(form, "sessionId");
  await withUser(user.id, (tx) => updateSessionSources(tx, sessionId, form.getAll("sourceIds").map(String), form.get("onlySelected") === "on"));
  revalidatePath(`/oturum/${sessionId}`);
  redirect(`/oturum/${sessionId}`);
}

export async function endSessionAction(form: FormData) {
  const user = await requireUser();
  const sessionId = str(form, "sessionId");
  await withUser(user.id, (tx) => endStudySession(tx, sessionId));
  revalidatePath("/", "layout");
  redirect(`/oturum/${sessionId}`);
}

function parseQuestionForm(form: FormData) {
  const type = str(form, "type") as QuestionType;
  if (!(type in QUESTION_TYPES)) throw new Error("Geçersiz soru türü.");
  const options = str(form, "options").split("\n").map((s) => s.trim()).filter(Boolean);
  let answer: unknown = null;
  if (type === "coktan_secmeli") answer = { index: Number(str(form, "correctIndex")) - 1 };
  if (type === "dogru_yanlis") answer = { value: str(form, "correctBool") === "dogru" };
  if (type === "kisa_cevap" || type === "bosluk_doldurma") answer = { accepted: str(form, "accepted").split("|").map((s) => s.trim()).filter(Boolean) };
  if (type === "eslestirme") {
    // Satır biçimi: "sol = sağ". Sağ sütun karıştırılarak saklanır.
    const pairs = options.map((l) => l.split("=").map((s) => s.trim()));
    if (pairs.some((p) => p.length !== 2 || !p[0] || !p[1])) throw new Error("Eşleştirme satırları 'sol = sağ' biçiminde olmalı.");
    const right = pairs.map((p) => p[1]);
    const order = right.map((_, i) => i).sort((a, b) => right[a].localeCompare(right[b], "tr"));
    const shuffledRight = order.map((i) => right[i]);
    return {
      type, prompt: `${str(form, "prompt")}\n${pairs.map((p, i) => `${i + 1}. ${p[0]}`).join("\n")}`,
      options: shuffledRight, answer: { pairs: pairs.map((_, i) => order.indexOf(i)) },
    };
  }
  return { type, prompt: str(form, "prompt"), options: type === "coktan_secmeli" ? options : [], answer };
}

export async function createQuestionAction(form: FormData) {
  const user = await requireUser();
  const returnTo = str(form, "returnTo") || "/dersler";
  try {
    const q = parseQuestionForm(form);
    const topicId = str(form, "topicId");
    await withUser(user.id, (tx) =>
      createQuestion(tx, user.id, {
        ...q, courseId: str(form, "courseId"), topicId: isUuid(topicId) ? topicId : null,
        objectiveId: isUuid(str(form, "objectiveId")) ? str(form, "objectiveId") : null,
        rubric: str(form, "rubric"), explanation: str(form, "explanation"), concept: str(form, "concept"),
        origin: str(form, "origin") === "ogretim_elemani" ? "ogretim_elemani" : "kullanici",
      }),
    );
  } catch (e) {
    redirect(withParams(returnTo, { hata: (e as Error).message }));
  }
  revalidatePath("/", "layout");
  redirect(withParams(returnTo, { tamam: "Soru kaydedildi." }));
}

export async function deleteQuestionAction(form: FormData) {
  const user = await requireUser();
  await withUser(user.id, (tx) => deleteQuestion(tx, str(form, "questionId")));
  revalidatePath("/", "layout");
  redirect(withParams(str(form, "returnTo") || "/dersler", { tamam: "Soru silindi." }));
}

export async function answerAction(form: FormData) {
  const user = await requireUser();
  const type = str(form, "type") as QuestionType;
  const returnTo = str(form, "returnTo");
  let response: unknown;
  if (type === "coktan_secmeli") response = { index: Number(form.get("choice") ?? -1) };
  else if (type === "dogru_yanlis") response = { value: str(form, "choice") === "dogru" };
  else if (type === "eslestirme") response = { pairs: form.getAll("pair").map((v) => Number(v)) };
  else response = { text: str(form, "text") };
  if (type !== "coktan_secmeli" && type !== "dogru_yanlis" && type !== "eslestirme" && !(response as { text: string }).text) {
    redirect(withParams(returnTo, { hata: "Cevap boş olamaz." }));
  }
  if ((type === "coktan_secmeli" || type === "dogru_yanlis") && !form.get("choice")) {
    redirect(withParams(returnTo, { hata: "Bir seçenek işaretleyin." }));
  }
  const sessionId = str(form, "sessionId");
  const res = await withUser(user.id, (tx) =>
    submitAnswer(tx, user.id, {
      questionId: str(form, "questionId"), sessionId: isUuid(sessionId) ? sessionId : null, response,
      confidence: (["tahmin", "kismen", "emin"].includes(str(form, "confidence")) ? str(form, "confidence") : null) as "tahmin" | "kismen" | "emin" | null,
    }),
  );
  revalidatePath("/", "layout");
  redirect(withParams(returnTo, { sonuc: res.attemptId }));
}

export async function selfGradeAction(form: FormData) {
  const user = await requireUser();
  const score = Number(str(form, "score"));
  await withUser(user.id, (tx) =>
    finalizeAttempt(tx, user.id, str(form, "attemptId"), {
      method: "oz_degerlendirme", score, feedback: str(form, "feedback") || "Öğrencinin öz değerlendirmesi.",
    }),
  );
  revalidatePath("/", "layout");
  redirect(withParams(str(form, "returnTo"), { sonuc: str(form, "attemptId") }));
}

export async function aiGradeAction(form: FormData) {
  const user = await requireUser();
  const returnTo = str(form, "returnTo");
  try {
    await gradeAttemptWithAI(user.id, str(form, "attemptId"), getProvider());
  } catch (e) {
    redirect(withParams(returnTo, { hata: `Yapay zekâ değerlendirmesi yapılamadı: ${aiMessage(e)}`, sonuc: str(form, "attemptId") }));
  }
  revalidatePath("/", "layout");
  redirect(withParams(returnTo, { sonuc: str(form, "attemptId") }));
}

export async function generateQuestionsAction(form: FormData) {
  const user = await requireUser();
  const returnTo = str(form, "returnTo");
  const topicId = str(form, "topicId");
  let r: { saved: number; rejected: number };
  try {
    r = await generateQuestions(
      user.id,
      { courseId: str(form, "courseId"), topicId: isUuid(topicId) ? topicId : null, sourceIds: form.getAll("sourceIds").map(String), count: Number(str(form, "count") || 5) },
      getProvider(),
    );
  } catch (e) {
    redirect(withParams(returnTo, { hata: `Soru üretilemedi: ${aiMessage(e)}` }));
  }
  revalidatePath("/", "layout");
  redirect(withParams(returnTo, { tamam: `${r.saved} soru üretildi ve kaydedildi.${r.rejected ? ` ${r.rejected} soru doğrulamayı geçemediği için kaydedilmedi.` : ""}` }));
}

export async function createNoteAction(form: FormData) {
  const user = await requireUser();
  const returnTo = str(form, "returnTo");
  const topicId = str(form, "topicId");
  try {
    await withUser(user.id, (tx) =>
      createNote(tx, user.id, {
        courseId: str(form, "courseId"), topicId: isUuid(topicId) ? topicId : null, title: str(form, "title"),
        body: String(form.get("body") ?? ""), origin: str(form, "origin") === "yapay_zeka" ? "yapay_zeka" : "kullanici",
      }),
    );
  } catch (e) {
    redirect(withParams(returnTo, { hata: (e as Error).message }));
  }
  revalidatePath("/", "layout");
  redirect(withParams(returnTo, { tamam: "Not kaydedildi." }));
}

export async function deleteNoteAction(form: FormData) {
  const user = await requireUser();
  await withUser(user.id, (tx) => deleteNote(tx, str(form, "noteId")));
  revalidatePath("/", "layout");
  redirect(withParams(str(form, "returnTo"), { tamam: "Not silindi." }));
}

export async function restoreBackupAction(form: FormData) {
  const user = await requireUser();
  if (str(form, "confirm") !== "GERİ YÜKLE") redirect(withParams("/ayarlar", { hata: "Onay için kutuya GERİ YÜKLE yazın." }));
  const file = form.get("file");
  if (!(file instanceof File) || !file.size) redirect(withParams("/ayarlar", { hata: "Yedek dosyası seçin." }));
  let counts: Record<string, number>;
  try {
    const json = JSON.parse(Buffer.from(await (file as File).arrayBuffer()).toString("utf8"));
    counts = await withUser(user.id, (tx) => restoreBackup(tx, user.id, json));
  } catch (e) {
    redirect(withParams("/ayarlar", { hata: `Geri yükleme başarısız; mevcut verin değiştirilmedi. (${(e as Error).message})` }));
  }
  revalidatePath("/", "layout");
  redirect(withParams("/ayarlar", { tamam: `Geri yükleme tamamlandı: ${counts.courses} ders, ${counts.sources} kaynak, ${counts.questions} soru.` }));
}

export async function createObjectiveAction(form: FormData) {
  const user = await requireUser();
  const returnTo = str(form, "returnTo");
  try {
    await withUser(user.id, (tx) => createObjective(tx, user.id, str(form, "topicId"), str(form, "text")));
  } catch (e) {
    redirect(withParams(returnTo, { hata: (e as Error).message }));
  }
  revalidatePath("/", "layout");
  redirect(withParams(returnTo, { tamam: "Öğrenme hedefi eklendi." }));
}

export async function deleteObjectiveAction(form: FormData) {
  const user = await requireUser();
  await withUser(user.id, (tx) => deleteObjective(tx, str(form, "objectiveId")));
  revalidatePath("/", "layout");
  redirect(withParams(str(form, "returnTo"), { tamam: "Hedef silindi." }));
}

export async function explainMistakeAction(form: FormData) {
  const user = await requireUser();
  const returnTo = str(form, "returnTo") || "/yanlislar";
  try {
    await explainMistake(user.id, str(form, "mistakeId"), getProvider());
  } catch (e) {
    redirect(withParams(returnTo, { hata: `Açıklama alınamadı: ${aiMessage(e)}` }));
  }
  revalidatePath("/yanlislar");
  redirect(withParams(returnTo, { tamam: "Öğretmen açıklaması eklendi." }));
}

export type AiTestState = { error?: string; ok?: string } | undefined;

/** Ücretli tek istek: yalnızca kullanıcı onay kutusunu işaretleyip düğmeye bastığında çalışır. */
export async function testAiConnectionAction(_: AiTestState, form: FormData): Promise<AiTestState> {
  const user = await requireUser();
  if (form.get("consent") !== "on") return { error: "Ücretli test isteği için onay kutusunu işaretleyin." };
  try {
    const r = await testConnection(user.id, getProvider());
    return { ok: `Yanıt alındı (${r.model}, ${r.inputTokens} girdi + ${r.outputTokens} çıktı token): "${r.text}"` };
  } catch (e) {
    return { error: aiMessage(e) };
  }
}
