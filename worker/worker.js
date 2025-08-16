// Cloudflare Worker - /ping და /ask
export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === "/ping") return json({ ok: true });

    if (url.pathname === "/ask" && request.method === "POST") {
      const body = await request.json().catch(() => ({}));
      const prompt = (body.prompt ?? "").toString();
      const providers = Array.isArray(body.providers) ? body.providers : ["OpenAI","Grok","Gemini"];
      const coop = !!body.coop;
      const rounds = Math.max(1, Number(body.rounds) || 1);
      if (!prompt) return json({ error: "missing prompt" }, 400);

      const want = new Set(providers.map(String));
      const answers = {};
      let context = prompt;

      const runRound = async () => {
        const tasks = [];
        if (want.has("OpenAI") && env.OPENAI_KEY) tasks.push(
          askOpenAI(env, context).then(t => answers.openai = t).catch(e => answers.openai = "ERR: " + e.message)
        );
        if (want.has("Grok") && env.XAI_KEY) tasks.push(
          askGrok(env, context).then(t => answers.grok = t).catch(e => answers.grok = "ERR: " + e.message)
        );
        if (want.has("Gemini") && env.GEMINI_KEY) tasks.push(
          askGemini(env, context).then(t => answers.gemini = t).catch(e => answers.gemini = "ERR: " + e.message)
        );
        await Promise.all(tasks);
      };

      if (coop) {
        for (let i = 0; i < rounds; i++) {
          await runRound();
          const summary = summarize(answers);
          context =
            `${prompt}\n\n--- Round ${i + 1} responses ---\n` +
            `OpenAI: ${answers.openai || ""}\nGrok: ${answers.grok || ""}\nGemini: ${answers.gemini || ""}\n\n` +
            `Improve together. User goal: ${prompt}\nCurrent summary: ${summary}`;
        }
      } else {
        await runRound();
      }

      return json({ unified: summarize(answers), ...answers });
    }

    return new Response("Not found", { status: 404 });
  }
};

function json(obj, status = 200) {
  return new Response(JSON.stringify(obj), {
    status, headers: { "content-type": "application/json" }
  });
}

function summarize(a) {
  const parts = [a.openai, a.grok, a.gemini].filter(Boolean);
  return parts.length ? parts.join("\n---\n") : "No provider replied.";
}

async function askOpenAI(env, prompt) {
  const r = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: { "Authorization": `Bearer ${env.OPENAI_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({ model: "gpt-4o-mini", messages: [{ role: "user", content: prompt }], temperature: 0.5 })
  });
  const j = await r.json();
  if (!r.ok) throw new Error(j.error?.message || r.statusText);
  return j.choices?.[0]?.message?.content?.toString()?.trim() ?? "";
}

async function askGrok(env, prompt) {
  const r = await fetch("https://api.x.ai/v1/chat/completions", {
    method: "POST",
    headers: { "Authorization": `Bearer ${env.XAI_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({ model: "grok-beta", messages: [{ role: "user", content: prompt }], temperature: 0.5 })
  });
  const j = await r.json();
  if (!r.ok) throw new Error(j.error?.message || r.statusText);
  return j.choices?.[0]?.message?.content?.toString()?.trim() ?? "";
}

async function askGemini(env, prompt) {
  const url = `https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent?key=${env.GEMINI_KEY}`;
  const r = await fetch(url, {
    method: "POST", headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ contents: [{ role: "user", parts: [{ text: prompt }] }] })
  });
  const j = await r.json();
  if (!r.ok) throw new Error(j.error?.message || r.statusText);
  return j.candidates?.[0]?.content?.parts?.[0]?.text?.toString()?.trim() ?? "";
}
