const MODEL = "gemini-2.5-flash";
const MAX_BODY_BYTES = 64 * 1024;

function corsHeaders(origin) {
  return {
    "Access-Control-Allow-Origin": origin || "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
    "Content-Type": "application/json; charset=utf-8"
  };
}

export default {
  async fetch(request, env) {
    const origin = request.headers.get("Origin") || "*";
    const headers = corsHeaders(origin);

    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers });
    }

    const url = new URL(request.url);
    if (url.pathname !== "/chat" || request.method !== "POST") {
      return new Response(JSON.stringify({ error: "Not found" }), {
        status: 404, headers
      });
    }

    if (!env.GEMINI_API_KEY) {
      return new Response(JSON.stringify({ error: "Sunucu API anahtarı ayarlanmamış." }), {
        status: 503, headers
      });
    }

    const length = Number(request.headers.get("Content-Length") || 0);
    if (length > MAX_BODY_BYTES) {
      return new Response(JSON.stringify({ error: "İstek çok büyük." }), {
        status: 413, headers
      });
    }

    let input;
    try {
      input = await request.json();
    } catch {
      return new Response(JSON.stringify({ error: "Geçersiz JSON." }), {
        status: 400, headers
      });
    }

    if (!Array.isArray(input.contents) || input.contents.length === 0 ||
        input.contents.length > 30) {
      return new Response(JSON.stringify({ error: "Geçersiz sohbet geçmişi." }), {
        status: 400, headers
      });
    }

    const contents = input.contents.map(item => ({
      role: item.role === "model" ? "model" : "user",
      parts: [{
        text: String(item.parts?.[0]?.text || "").slice(0, 12000)
      }]
    })).filter(item => item.parts[0].text.trim());

    if (!contents.length) {
      return new Response(JSON.stringify({ error: "Mesaj boş." }), {
        status: 400, headers
      });
    }

    const upstream = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-goog-api-key": env.GEMINI_API_KEY
        },
        body: JSON.stringify({
          systemInstruction: {
            parts: [{
              text: "Sen NEXORA AI adında akıllı bir asistansın. Kullanıcıyla Türkçe konuş; samimi, doğru, açık ve yardımsever ol. Önceki konuşma mesajlarını dikkate al."
            }]
          },
          contents
        })
      }
    );

    const data = await upstream.json().catch(() => ({}));
    if (!upstream.ok) {
      return new Response(JSON.stringify({
        error: data.error?.message || "Yapay zekâ servisine ulaşılamadı."
      }), { status: upstream.status, headers });
    }

    const answer = data.candidates?.[0]?.content?.parts
      ?.map(part => part.text || "").join("\n").trim();

    if (!answer) {
      return new Response(JSON.stringify({ error: "Yapay zekâ boş yanıt verdi." }), {
        status: 502, headers
      });
    }

    return new Response(JSON.stringify({ text: answer }), {
      status: 200, headers
    });
  }
};
