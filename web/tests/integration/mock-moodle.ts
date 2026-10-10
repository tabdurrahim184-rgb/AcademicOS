// TEST İKİZİ — Moodle Web Services REST API'sinin küçük bir alt kümesini taklit eder.
// Yalnızca testlerde kullanılır; gerçek DEBİM bağlantısını doğrulamaz.
import http from "node:http";
import { readFileSync } from "node:fs";
import path from "node:path";
import type { AddressInfo } from "node:net";

export const MOCK_TOKEN = "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6";
const pdf = readFileSync(path.join(__dirname, "..", "fixtures", "siyasal-iletisim-hafta3.pdf"));
const pptx = readFileSync(path.join(__dirname, "..", "fixtures", "hak-odakli.pptx"));

export async function startMockMoodle() {
  const requests: string[] = [];
  const server = http.createServer((req, res) => {
    const url = new URL(req.url!, "http://x");
    let body = "";
    req.on("data", (c) => (body += c));
    req.on("end", () => {
      const p = new URLSearchParams(body);
      const json = (o: unknown) => { res.writeHead(200, { "content-type": "application/json" }); res.end(JSON.stringify(o)); };
      if (url.pathname === "/webservice/rest/server.php") {
        requests.push(p.get("wsfunction") ?? "");
        if (p.get("wstoken") !== MOCK_TOKEN) return json({ exception: "moodle_exception", errorcode: "invalidtoken", message: "Invalid token" });
        const base = `http://${req.headers.host}/webservice/pluginfile.php`;
        switch (p.get("wsfunction")) {
          case "core_webservice_get_site_info":
            return json({ sitename: "DEBİM (test ikizi)", userid: 42, fullname: "Abdurrahim Türkmenoğlu" });
          case "core_enrol_get_users_courses":
            return json([{ id: 1204, fullname: "İLF431 Siyasal İletişim", shortname: "ILF431" }, { id: 1300, fullname: "İLF413 İletişim Etiği", shortname: "ILF413" }]);
          case "core_course_get_contents":
            return json([
              { id: 1, name: "Genel", section: 0, modules: [{ id: 10, name: "Duyurular", modname: "forum" }] },
              { id: 2, name: "3. Hafta: Gündem belirleme", section: 3, modules: [
                { id: 4501, name: "Hafta 3 notu", modname: "resource", contents: [{ type: "file", filename: "hafta3.pdf", filepath: "/", filesize: pdf.length, fileurl: `${base}/1/mod_resource/content/0/hafta3.pdf`, timemodified: 1700000000 }] },
              ] },
              { id: 3, name: "Hafta 4", section: 4, modules: [
                { id: 4600, name: "Sunumlar", modname: "folder", contents: [
                  { type: "file", filename: "sunum.pptx", filepath: "/", filesize: pptx.length, fileurl: `${base}/2/mod_folder/content/0/sunum.pptx`, timemodified: 1700000100 },
                  { type: "file", filename: "kopya.pdf", filepath: "/eski/", filesize: pdf.length, fileurl: `${base}/2/mod_folder/content/0/eski/kopya.pdf`, timemodified: 1700000100 },
                  { type: "file", filename: "kurulum.exe", filepath: "/", filesize: 10, fileurl: `${base}/2/x/kurulum.exe`, timemodified: 1 },
                ] },
                { id: 4700, name: "Ödev 1", modname: "assign" },
              ] },
            ]);
        }
        return json({ exception: "x", errorcode: "invalidrecord", message: "?" });
      }
      if (url.pathname.startsWith("/webservice/pluginfile.php")) {
        if (url.searchParams.get("token") !== MOCK_TOKEN) return json({ error: "Invalid token", errorcode: "invalidtoken" });
        requests.push(`indir:${url.pathname.split("/").pop()}`);
        const data = url.pathname.endsWith(".pptx") ? pptx : pdf;
        res.writeHead(200, { "content-type": "application/octet-stream" });
        return res.end(data);
      }
      res.writeHead(404).end();
    });
  });
  await new Promise<void>((r) => server.listen(0, "127.0.0.1", r));
  const { port } = server.address() as AddressInfo;
  return { url: `http://127.0.0.1:${port}`, requests, close: () => new Promise<void>((r) => server.close(() => r())) };
}
