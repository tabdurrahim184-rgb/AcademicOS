// TEST İKİZİ — Moodle Web Services (DEBİM) alt kümesi. Yalnızca uçtan uca testlerde kullanılır.
import http from "node:http";
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const pdf = readFileSync(path.join(here, "..", "fixtures", "siyasal-iletisim-hafta3.pdf"));
const pptx = readFileSync(path.join(here, "..", "fixtures", "hak-odakli.pptx"));
const TOKEN = "e2etoken1234567890abcdef12345678";

http.createServer((req, res) => {
  const url = new URL(req.url, "http://x");
  let body = "";
  req.on("data", (c) => (body += c));
  req.on("end", () => {
    const p = new URLSearchParams(body);
    const json = (o) => { res.writeHead(200, { "content-type": "application/json" }); res.end(JSON.stringify(o)); };
    if (url.pathname === "/webservice/rest/server.php") {
      if (p.get("wstoken") !== TOKEN) return json({ exception: "moodle_exception", errorcode: "invalidtoken", message: "Invalid token" });
      const base = `http://${req.headers.host}/webservice/pluginfile.php`;
      switch (p.get("wsfunction")) {
        case "core_webservice_get_site_info": return json({ sitename: "DEBİM (test ikizi)", userid: 7, fullname: "Abdurrahim Türkmenoğlu" });
        case "core_enrol_get_users_courses": return json([{ id: 501, fullname: "İLF431 Siyasal İletişim", shortname: "ILF431" }]);
        case "core_course_get_contents": return json([
          { id: 1, name: "3. Hafta: Gündem belirleme", section: 3, modules: [{ id: 9001, name: "Not", modname: "resource", contents: [{ type: "file", filename: "hafta3.pdf", filepath: "/", filesize: pdf.length, fileurl: `${base}/1/hafta3.pdf`, timemodified: 1 }] }] },
          { id: 2, name: "Hafta 4", section: 4, modules: [{ id: 9002, name: "Sunum", modname: "resource", contents: [{ type: "file", filename: "sunum.pptx", filepath: "/", filesize: pptx.length, fileurl: `${base}/2/sunum.pptx`, timemodified: 1 }] }] },
        ]);
      }
      return json({ exception: "x", errorcode: "invalidrecord", message: "?" });
    }
    if (url.pathname.startsWith("/webservice/pluginfile.php")) {
      if (url.searchParams.get("token") !== TOKEN) return json({ error: "Invalid token" });
      res.writeHead(200, { "content-type": "application/octet-stream" });
      return res.end(url.pathname.endsWith(".pptx") ? pptx : pdf);
    }
    res.writeHead(404).end();
  });
}).listen(3198, "127.0.0.1", () => console.log("moodle test ikizi 3198"));
