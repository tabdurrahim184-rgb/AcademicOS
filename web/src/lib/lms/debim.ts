/**
 * DEBİM bağlantısı ve materyal aktarımı. Ağ çağrıları veritabanı işlemlerinin dışında yapılır.
 */
import { withUser, type Tx } from "../db";
import { decrypt, encrypt } from "../crypto";
import { MAX_UPLOAD_BYTES } from "../extract";
import { getCourse } from "../data/courses";
import { importOne, summarize, type ImportOutcome } from "../data/bulk-import";
import { IMPORTABLE_EXT, MoodleClient, MoodleError, normalizeSiteUrl, weekFromName, type MoodleSection } from "./moodle";

export type LmsConnection = { site_url: string; site_name: string; lms_user_id: number; lms_full_name: string; connected_at: Date; last_sync_at: Date | null };

export async function getConnection(tx: Tx): Promise<LmsConnection | null> {
  const { rows } = await tx.query<LmsConnection>(
    "SELECT site_url, site_name, lms_user_id, lms_full_name, connected_at, last_sync_at FROM lms_connections",
  );
  return rows[0] ?? null;
}

async function clientFor(userId: string): Promise<{ client: MoodleClient; conn: LmsConnection }> {
  const row = await withUser(userId, async (tx) => {
    const { rows } = await tx.query<LmsConnection & { token_enc: string }>("SELECT * FROM lms_connections");
    return rows[0] ?? null;
  });
  if (!row) throw new MoodleError("Önce DEBİM'e bağlanın.");
  return { client: new MoodleClient(row.site_url, decrypt(row.token_enc)), conn: row };
}

/** Anahtarı DEBİM'de doğrular, ardından yalnızca şifreli hâlini saklar. */
export async function connect(userId: string, siteInput: string, token: string) {
  const site = normalizeSiteUrl(siteInput);
  const t = token.trim();
  if (!/^[A-Za-z0-9]{16,128}$/.test(t)) throw new MoodleError("Güvenlik anahtarı biçimi geçersiz (DEBİM'deki anahtarı olduğu gibi yapıştırın).");
  const info = await new MoodleClient(site, t).siteInfo();
  await withUser(userId, (tx) =>
    tx.query(
      `INSERT INTO lms_connections (user_id, site_url, token_enc, site_name, lms_user_id, lms_full_name)
       VALUES ($1,$2,$3,$4,$5,$6)
       ON CONFLICT (user_id) DO UPDATE SET site_url=EXCLUDED.site_url, token_enc=EXCLUDED.token_enc, site_name=EXCLUDED.site_name,
         lms_user_id=EXCLUDED.lms_user_id, lms_full_name=EXCLUDED.lms_full_name, connected_at=now()`,
      [userId, site, encrypt(t), info.sitename ?? "", info.userid, info.fullname ?? ""],
    ),
  );
  return info;
}

/** Bağlantıyı kaldırır: saklanan anahtar silinir. İçe aktarılmış materyaller korunur. */
export async function disconnect(tx: Tx) {
  await tx.query("DELETE FROM lms_course_links");
  await tx.query("DELETE FROM lms_connections");
}

export async function remoteCourses(userId: string) {
  const { client, conn } = await clientFor(userId);
  const courses = await client.courses(conn.lms_user_id);
  const links = await withUser(userId, async (tx) => (await tx.query<{ lms_course_id: string; course_id: string }>("SELECT lms_course_id, course_id FROM lms_course_links")).rows);
  return courses.map((c) => ({ ...c, linkedCourseId: links.find((l) => Number(l.lms_course_id) === c.id)?.course_id ?? null }));
}

export async function linkCourse(tx: Tx, userId: string, lmsCourseId: number, lmsCourseName: string, courseId: string | null) {
  if (!courseId) {
    await tx.query("DELETE FROM lms_course_links WHERE lms_course_id=$1", [lmsCourseId]);
    return;
  }
  if (!(await getCourse(tx, courseId))) throw new Error("Ders bulunamadı.");
  await tx.query(
    `INSERT INTO lms_course_links (user_id, lms_course_id, lms_course_name, course_id) VALUES ($1,$2,$3,$4)
     ON CONFLICT (user_id, lms_course_id) DO UPDATE SET course_id=EXCLUDED.course_id, lms_course_name=EXCLUDED.lms_course_name`,
    [userId, lmsCourseId, lmsCourseName.slice(0, 300), courseId],
  );
}

/** Eşleştirilmiş bir DEBİM dersinin dosya materyallerini AcademicOS dersine aktarır. */
export async function importCourseMaterials(userId: string, lmsCourseId: number) {
  const { client } = await clientFor(userId);
  const link = await withUser(userId, async (tx) =>
    (await tx.query<{ course_id: string }>("SELECT course_id FROM lms_course_links WHERE lms_course_id=$1", [lmsCourseId])).rows[0],
  );
  if (!link) throw new MoodleError("Bu DEBİM dersi henüz bir AcademicOS dersiyle eşleştirilmedi.");
  const sections: MoodleSection[] = await client.contents(lmsCourseId);
  const outcomes: ImportOutcome[] = [];
  for (const section of sections) {
    const topicTitle = section.name?.trim() || null;
    const week = weekFromName(section.name ?? "", section.section);
    for (const mod of section.modules ?? []) {
      if (!["resource", "folder"].includes(mod.modname)) continue;
      for (const f of mod.contents ?? []) {
        if (f.type !== "file") continue;
        const path = `${f.filepath ?? "/"}${f.filename}`;
        if (!IMPORTABLE_EXT.test(f.filename)) {
          outcomes.push({ filename: f.filename, status: "atlandi", message: "Desteklenmeyen dosya türü." });
          continue;
        }
        if (f.filesize > MAX_UPLOAD_BYTES) {
          outcomes.push({ filename: f.filename, status: "atlandi", message: "25 MB sınırını aşıyor." });
          continue;
        }
        const already = await withUser(userId, async (tx) =>
          (await tx.query("SELECT 1 FROM lms_file_refs WHERE lms_module_id=$1 AND file_path=$2 AND time_modified=$3", [mod.id, path, f.timemodified])).rowCount,
        );
        if (already) {
          outcomes.push({ filename: f.filename, status: "yinelenen", message: "Daha önce aktarıldı (değişmemiş)." });
          continue;
        }
        let data: Buffer;
        try {
          data = await client.download(f.fileurl, MAX_UPLOAD_BYTES);
        } catch (e) {
          outcomes.push({ filename: f.filename, status: "hata", message: (e as Error).message });
          continue;
        }
        const out = await withUser(userId, async (tx) => {
          const r = await importOne(tx, userId, link.course_id, { filename: f.filename, data, topicTitle, week, kind: "hoca" });
          if (r.sourceId) {
            await tx.query(
              `INSERT INTO lms_file_refs (user_id, source_id, lms_course_id, lms_module_id, file_path, time_modified)
               VALUES ($1,$2,$3,$4,$5,$6) ON CONFLICT DO NOTHING`,
              [userId, r.sourceId, lmsCourseId, mod.id, path, f.timemodified],
            );
          }
          return r;
        });
        outcomes.push(out);
      }
    }
  }
  await withUser(userId, (tx) => tx.query("UPDATE lms_connections SET last_sync_at=now()"));
  return { outcomes, summary: summarize(outcomes) };
}
