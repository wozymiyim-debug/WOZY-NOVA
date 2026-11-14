const MODEL = "gemini-2.5-flash";

module.exports = async function handler(req, res) {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") return res.status(204).end();
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Only POST is supported." });
  }

  if (!process.env.GEMINI_API_KEY) {
    return res.status(503).json({ error: "Sunucu API anahtarı ayarlanmamış." });
  }

  const contents = req.body?.contents;
  if (!Array.isArray(contents) || contents.length === 0 || contents.length > 30) {
    return res.status(400).json({ error: "Geçersiz sohbet geçmişi." });
  }

  const safeContents = contents.map(item => ({
    role: item.role === "model" ? "model" : "user",
    parts: [{ text: String(item.parts?.[0]?.text || "").slice(0, 12000) }]
  })).filter(item => item.parts[0].text.trim());

  if (!safeContents.length) {
    return res.status(400).json({ error: "Mesaj boş." });
  }

  try {
    const upstream = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-goog-api-key": process.env.GEMINI_API_KEY
        },
        body: JSON.stringify({
          systemInstruction: {
            parts: [{
              text: "Sen WOZY adında akıllı bir asistansın. Kullanıcıyla Türkçe konuş; samimi, doğru, açık ve yardımsever ol. Önceki konuşma mesajlarını dikkate al."
            }]
          },
          contents: safeContents
        })
      }
    );

    const data = await upstream.json().catch(() => ({}));
    if (!upstream.ok) {
      return res.status(upstream.status).json({
        error: data.error?.message || "Yapay zekâ servisine ulaşılamadı."
      });
    }

    const answer = data.candidates?.[0]?.content?.parts
      ?.map(part => part.text || "").join("\n").trim();

    if (!answer) {
      return res.status(502).json({ error: "Yapay zekâ boş yanıt verdi." });
    }
    return res.status(200).json({ text: answer });
  } catch {
    return res.status(502).json({ error: "Sunucu bağlantı hatası." });
  }
};
