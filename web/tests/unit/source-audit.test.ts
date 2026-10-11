import { describe, expect, it } from "vitest";
import { auditSources, keyStems, topicCoverage } from "@/lib/source-audit";

describe("Kaynak denetimi", () => {
  it("konu başlığından anlamlı kökleri çıkarır", () => {
    expect(keyStems("Gündem Belirleme Kuramı ve Medya")).toEqual(["gündem", "belirl", "medya"]);
    expect(keyStems("Giriş")).toEqual([]);
  });
  it("Türkçe çekim eklerine rağmen kapsamayı ölçer", () => {
    expect(topicCoverage("Gündem belirleme", "Gündemi belirlemek için medyanın…")).toBe(1);
    expect(topicCoverage("Çerçeveleme", "Bu metin futbol hakkındadır.")).toBe(0);
    expect(topicCoverage("Giriş", "her şey")).toBeNull();
  });
  it("yinelenen, okunamayan, konusuz ve ilgisiz kaynakları raporlar", () => {
    const base = { course_id: "c", sha256: "x", extraction_status: "tamam", text: "Gündem belirleme kuramı", topicTitle: "Gündem belirleme" };
    const issues = auditSources(
      [
        { ...base, id: "1", title: "A", topic_id: "t" },
        { ...base, id: "2", title: "B", topic_id: null, sha256: "y" },
        { ...base, id: "3", title: "C", topic_id: "t", sha256: "z", text: "Spor haberleri", topicTitle: "Gündem belirleme" },
        { ...base, id: "4", title: "D", topic_id: "t", sha256: "w", extraction_status: "metin_yok", text: "" },
      ],
      [{ id: "1", sha256: "x", title: "A", course_label: "İLF431" }, { id: "9", sha256: "x", title: "Eski kopya", course_label: "İLF413" }],
    );
    expect(issues.find((i) => i.sourceId === "1")!.message).toContain("İLF413 — Eski kopya");
    expect(issues.find((i) => i.sourceId === "2")!.level).toBe("bilgi");
    expect(issues.find((i) => i.sourceId === "3")!.message).toContain("hiç geçmiyor");
    expect(issues.find((i) => i.sourceId === "4")!.message).toContain("okunamadı");
    expect(issues.filter((i) => i.sourceId === "1")).toHaveLength(1);
  });
});
