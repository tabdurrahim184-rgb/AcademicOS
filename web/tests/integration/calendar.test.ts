import { afterAll, describe, expect, it } from "vitest";
import { newUser } from "./helpers";
import { closePool, withUser } from "@/lib/db";
import { createAssessment } from "@/lib/data/assessments";
import { loadWeek } from "@/lib/data/calendar";
import { listCourses } from "@/lib/data/courses";
import { regeneratePlan } from "@/lib/data/plan";

afterAll(closePool);

describe("Akademik takvim — gerçek veritabanı", () => {
  it("ders saatleri, çakışmalar, plan görevleri ve tarihli sınavlar görünür; tarih uydurulmaz", async () => {
    const u = await newUser();
    await withUser(u.id, async (tx) => {
      const courses = await listCourses(tx);
      const c431 = courses.find((c) => c.code === "İLF431")!;
      await createAssessment(tx, u.id, { courseId: c431.id, kind: "vize", title: "Vize", dueAt: new Date("2026-10-14T07:00:00Z"), weight: 40 });
      await createAssessment(tx, u.id, { courseId: c431.id, kind: "final", title: "Final", dueAt: null, weight: 60 });
      await regeneratePlan(tx, u.id, new Date("2026-10-12T04:00:00Z"));
      const w = await loadWeek(tx, "2026-10-12");
      expect(w.days).toEqual(["2026-10-12", "2026-10-13", "2026-10-14", "2026-10-15", "2026-10-16", "2026-10-17", "2026-10-18"]);
      const classes = w.events.filter((e) => e.type === "ders");
      expect(classes).toHaveLength(12); // 9 dersin haftalık 12 yüz yüze oturumu (SEC351 ve İNG102 çevrimiçi)
      const friday = classes.filter((e) => e.date === "2026-10-16");
      expect(friday.filter((e) => e.conflict).map((e) => e.title.split(" ")[0]).sort()).toEqual(["İLF267", "İLF361", "İLF413", "İLF433"]);
      const exam = w.events.find((e) => e.type === "sinav")!;
      expect(exam).toMatchObject({ date: "2026-10-14", start: "10:00" }); // 07:00Z = Kıbrıs 10:00
      expect(w.undated.map((a) => a.title)).toEqual(["Final"]);
      expect(w.events.some((e) => e.title.includes("Final"))).toBe(false);
      expect(w.events.some((e) => e.type === "gorev")).toBe(true);
    });
  });
});
