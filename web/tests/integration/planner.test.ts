import { afterAll, describe, expect, it } from "vitest";
import { newUser } from "./helpers";
import { closePool, withUser } from "@/lib/db";
import { createTopic, listCourses, listMeetings, listTopics, setTopicStatus } from "@/lib/data/courses";
import { createAssessment } from "@/lib/data/assessments";
import {
  addManualTask, completeTask, ensureFreshPlan, getSettings, getWindows, listOverdueTasks, listPlanTasks, moveTask, regeneratePlan, updateSettings,
} from "@/lib/data/plan";
import { addDays, weekdayOf } from "@/lib/planner";
import { toMinutes } from "@/lib/schedule";

afterAll(closePool);

// Pazartesi 12 Ekim 2026, 07:00 Kıbrıs (UTC+3)
const MONDAY = new Date("2026-10-12T04:00:00Z");
const TODAY = "2026-10-12";

async function setup() {
  const u = await newUser();
  const ids = await withUser(u.id, async (tx) => {
    const courses = await listCourses(tx);
    const c431 = courses.find((c) => c.code === "İLF431")!;
    const c413 = courses.find((c) => c.code === "İLF413")!;
    const t1 = await createTopic(tx, u.id, c431.id, { title: "Gündem belirleme", week: 1, isCatchUp: true });
    const t2 = await createTopic(tx, u.id, c431.id, { title: "Çerçeveleme", week: 2, isCatchUp: true });
    const t3 = await createTopic(tx, u.id, c413.id, { title: "Etik kuramlar", week: 3 });
    await setTopicStatus(tx, t1, "materyal_alindi");
    await setTopicStatus(tx, t2, "tekrar_gerekiyor");
    await createAssessment(tx, u.id, { courseId: c431.id, kind: "vize", title: "Vize", dueAt: new Date("2026-10-20T06:00:00Z"), weight: 40 });
    await createAssessment(tx, u.id, { courseId: c413.id, kind: "final", title: "Final", dueAt: null, weight: 60 });
    return { c431: c431.id, c413: c413.id, t1, t2, t3 };
  });
  return { u, ...ids };
}

describe("14 günlük plan — gerçek veritabanı", () => {
  it("plan üretilir, kalıcıdır ve kurallara uyar", async () => {
    const { u } = await setup();
    const r = await withUser(u.id, (tx) => regeneratePlan(tx, u.id, MONDAY));
    expect(r.placed).toBeGreaterThan(10);
    await withUser(u.id, async (tx) => {
      const tasks = await listPlanTasks(tx, TODAY, addDays(TODAY, 13));
      expect(tasks.length).toBe(r.placed);
      const meetings = await listMeetings(tx);
      const settings = await getSettings(tx, u.id);
      for (const t of tasks) {
        const s = toMinutes(t.start_time), e = s + t.duration_min;
        for (const m of meetings.filter((m) => m.weekday === weekdayOf(t.scheduled_date))) {
          expect(s < toMinutes(m.end_time) && toMinutes(m.start_time) < e, `${t.title} ${t.scheduled_date} ${t.start_time}`).toBe(false);
        }
      }
      const perDay = Map.groupBy(tasks, (t) => t.scheduled_date);
      for (const [date, list] of perDay) {
        const cap = weekdayOf(date) <= 5 ? settings.weekdayCapacityMin : settings.weekendCapacityMin;
        expect(list.reduce((n, t) => n + t.duration_min, 0)).toBeLessThanOrEqual(cap);
      }
      expect(tasks.filter((t) => t.kind === "sinav").every((t) => t.scheduled_date < "2026-10-20")).toBe(true);
      expect(tasks.some((t) => t.title.includes("Final"))).toBe(false);
      expect(tasks.some((t) => t.kind === "eksik" && t.title.includes("Çerçeveleme"))).toBe(true);
      expect(tasks.some((t) => t.kind === "materyal" && t.title.includes("Etik kuramlar"))).toBe(true);
      expect((await getWindows(tx, u.id)).length).toBe(14);
    });
  });

  it("tamamlanan görev konunun durumunu ilerletir ve yeniden üretilmez", async () => {
    const { u, t1 } = await setup();
    await withUser(u.id, (tx) => regeneratePlan(tx, u.id, MONDAY));
    const task = (await withUser(u.id, (tx) => listPlanTasks(tx, TODAY, addDays(TODAY, 13)))).find((t) => t.topic_id === t1)!;
    expect(task.origin_key).toBe(`calis:${t1}`);
    await withUser(u.id, (tx) => completeTask(tx, task.id));
    expect((await withUser(u.id, listTopics)).find((t) => t.id === t1)!.status).toBe("okundu");
    await withUser(u.id, (tx) => regeneratePlan(tx, u.id, MONDAY));
    const after = await withUser(u.id, (tx) => listPlanTasks(tx, TODAY, addDays(TODAY, 13)));
    expect(after.filter((t) => t.origin_key === `calis:${t1}`)).toHaveLength(1); // yalnızca tamamlanan kayıt
    expect(after.some((t) => t.origin_key === `hatirla:${t1}`)).toBe(true); // sonraki adım planlandı
  });

  it("yapılmayan görev ertesi gün yeniden planlanır; kullanıcının taşıdığı görev korunur", async () => {
    const { u, c431 } = await setup();
    await withUser(u.id, (tx) => regeneratePlan(tx, u.id, MONDAY));
    const first = await withUser(u.id, (tx) => listPlanTasks(tx, TODAY, TODAY));
    expect(first.length).toBeGreaterThan(0);
    const moved = first[0];
    await withUser(u.id, (tx) => moveTask(tx, moved.id, "2026-10-17", "10:00"));
    // Ders saatine taşınamaz (Salı 13.30–15.30 Siyasal İletişim)
    await expect(withUser(u.id, (tx) => moveTask(tx, first[1]?.id ?? moved.id, "2026-10-13", "14:00"))).rejects.toThrow("ders saatiyle");
    await withUser(u.id, (tx) => addManualTask(tx, u.id, { courseId: c431, topicId: null, title: "Kütüphane okuması", date: "2026-10-18", start: "11:00", minutes: 60 }));

    // Ertesi gün: pazartesi görevleri yapılmadı
    const tuesday = new Date("2026-10-13T04:00:00Z");
    await withUser(u.id, (tx) => ensureFreshPlan(tx, u.id, tuesday));
    await withUser(u.id, async (tx) => {
      expect(await listOverdueTasks(tx, "2026-10-13")).toHaveLength(0); // otomatik görevler taşındı
      const all = await listPlanTasks(tx, "2026-10-12", "2026-10-26");
      const mondayKeys = first.filter((f) => f.id !== moved.id).map((f) => f.origin_key);
      for (const k of mondayKeys) {
        const again = all.find((t) => t.origin_key === k);
        if (k.startsWith("guncel:") || k.startsWith("tekrar:")) continue; // süreli görevler süresi içinde
        expect(again?.scheduled_date, k).toBeDefined();
        expect(again!.scheduled_date >= "2026-10-13").toBe(true);
      }
      const kept = all.find((t) => t.id === moved.id)!;
      expect(kept).toMatchObject({ scheduled_date: "2026-10-17", start_time: "10:00", locked: true });
      expect(all.some((t) => t.title === "Kütüphane okuması" && t.scheduled_date === "2026-10-18")).toBe(true);
      // Planlayıcı kilitli görevle aynı saate görev koymaz
      const sat = all.filter((t) => t.scheduled_date === "2026-10-17" && t.id !== moved.id);
      for (const t of sat) {
        const s = toMinutes(t.start_time);
        expect(s < toMinutes("10:00") + moved.duration_min && toMinutes("10:00") < s + t.duration_min).toBe(false);
      }
    });
  });

  it("kapasite ayarı değişince plan yeniden üretilir ve yeni sınıra uyar", async () => {
    const { u } = await setup();
    await withUser(u.id, async (tx) => {
      await updateSettings(tx, u.id, { weekdayCapacityMin: 60, weekendCapacityMin: 30, maxTaskMin: 30, breakMin: 5, catchUpShare: 50, semesterEnd: null });
      await ensureFreshPlan(tx, u.id, MONDAY);
      const tasks = await listPlanTasks(tx, TODAY, addDays(TODAY, 13));
      for (const [date, list] of Map.groupBy(tasks, (t) => t.scheduled_date)) {
        expect(list.reduce((n, t) => n + t.duration_min, 0)).toBeLessThanOrEqual(weekdayOf(date) <= 5 ? 60 : 30);
        expect(list.every((t) => t.duration_min <= 30)).toBe(true);
      }
      const s = await getSettings(tx, u.id);
      expect(s.lastUnplaced.length).toBeGreaterThan(0); // dar kapasitede sığmayanlar dürüstçe raporlanır
    });
  });

  it("plan görevleri başka kullanıcıya görünmez ve başka kullanıcının dersine bağlanamaz", async () => {
    const a = await setup();
    const b = await newUser();
    await withUser(a.u.id, (tx) => regeneratePlan(tx, a.u.id, MONDAY));
    await withUser(b.id, async (tx) => {
      expect(await listPlanTasks(tx, TODAY, addDays(TODAY, 13))).toHaveLength(0);
      await expect(addManualTask(tx, b.id, { courseId: a.c431, topicId: null, title: "x y", date: TODAY, start: "20:00", minutes: 30 })).rejects.toThrow("Ders bulunamadı");
    });
    // Veritabanı düzeyinde: B, A'nın ders kimliğini doğrudan yazamaz (sahiplik FK'si)
    await expect(
      withUser(b.id, (tx) =>
        tx.query(
          "INSERT INTO plan_tasks (user_id, course_id, kind, title, origin_key, scheduled_date, start_time, duration_min) VALUES ($1,$2,'serbest','x','k','2026-10-12','20:00',30)",
          [b.id, a.c431],
        ),
      ),
    ).rejects.toThrow(/foreign key/);
    await expect(
      withUser(b.id, (tx) => tx.query("INSERT INTO topics (user_id, course_id, title) VALUES ($1,$2,'sızma')", [b.id, a.c431])),
    ).rejects.toThrow(/foreign key/);
  });
});

describe("Erteleme", () => {
  it("ertelenen görev bugün değil, sonraki günlerde yeniden planlanır", async () => {
    const { u } = await setup();
    await withUser(u.id, (tx) => regeneratePlan(tx, u.id, MONDAY));
    const today = await withUser(u.id, (tx) => listPlanTasks(tx, TODAY, TODAY));
    const target = today.find((t) => t.kind !== "guncel" && t.kind !== "tekrar")!;
    const { postponeTask } = await import("@/lib/data/plan");
    await withUser(u.id, (tx) => postponeTask(tx, target.id));
    await withUser(u.id, (tx) => ensureFreshPlan(tx, u.id, MONDAY));
    const all = await withUser(u.id, (tx) => listPlanTasks(tx, TODAY, addDays(TODAY, 13)));
    const again = all.filter((t) => t.origin_key === target.origin_key && t.status === "planlandi");
    expect(again).toHaveLength(1);
    expect(again[0].scheduled_date > TODAY).toBe(true);
  });
});
