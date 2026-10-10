// TEST İKİZİ — yalnızca uçtan uca testlerde kullanılır, üretimde çalışmaz.
// Anthropic Messages API biçiminde yanıt veren yerel sunucu. İstek gövdesine
// bakarak öğretmen yanıtı, soru üretimi veya değerlendirme döndürür.
import http from "node:http";

const reply = (text, model) => ({
  id: "msg_test", type: "message", role: "assistant", model,
  content: [{ type: "text", text }], stop_reason: "end_turn", stop_sequence: null,
  usage: { input_tokens: 1, output_tokens: 1 },
});

http.createServer((req, res) => {
  let body = "";
  req.on("data", (c) => (body += c));
  req.on("end", () => {
    if (req.method !== "POST" || !req.url.startsWith("/v1/messages")) { res.writeHead(404).end(); return; }
    const j = JSON.parse(body);
    const all = JSON.stringify(j);
    let text;
    if (String(j.system).includes("sınav sorusu hazırlıyorsun")) {
      text = JSON.stringify([
        { type: "coktan_secmeli", prompt: "Chapel Hill araştırması hangi seçimlerde yapılmıştır?", options: ["1968 ABD başkanlık seçimleri", "1980 İngiltere seçimleri"], answer: { index: 0 }, explanation: "Kaynak, Sayfa 1.", concept: "Gündem belirleme", ref: "K1" },
        { type: "acik_uclu", prompt: "Çerçevelemeyi bir haber örneğiyle açıklayın.", rubric: "Tanım ve örnek", concept: "Çerçeveleme", ref: "K2" },
      ]);
    } else if (String(j.system).includes("adil bir öğretim elemanısın")) {
      text = JSON.stringify({ score: 40, feedback: "Tanım var ama örnek eksik.", missing_concepts: ["haber örneği"] });
    } else {
      const hasSources = all.includes("<kaynaklar>");
      text = hasSources
        ? "Gündem belirleme kuramına göre medya, kamuoyunun hangi konular hakkında düşüneceğini etkiler [K1]. Sence bu, medyanın ne düşüneceğimizi belirlemesiyle aynı şey mi?"
        : "Bu oturumda seçili kaynak yok; genel bilgiyle anlatıyorum.";
    }
    res.writeHead(200, { "content-type": "application/json", "request-id": "req_test" });
    res.end(JSON.stringify(reply(text, j.model)));
  });
}).listen(3199, () => console.log("test ikizi 3199"));
