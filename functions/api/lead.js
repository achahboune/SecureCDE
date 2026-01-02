export async function onRequestPost({ request, env }) {
  try {
    // --- Parse body (multipart OR urlencoded)
    const ct = request.headers.get("content-type") || "";
    let get = (k) => "";

    if (ct.includes("multipart/form-data")) {
      const fd = await request.formData();
      get = (k) => String(fd.get(k) || "").trim();
    } else {
      const text = await request.text();
      const params = new URLSearchParams(text);
      get = (k) => String(params.get(k) || "").trim();
    }

    // --- Turnstile token (accept both names)
    const token =
      get("turnstile") ||
      get("cf-turnstile-response");

    if (!token) return json({ ok: false, error: "Missing Turnstile token" }, 400);
    if (!env.TURNSTILE_SECRET_KEY) return json({ ok: false, error: "TURNSTILE_SECRET_KEY missing" }, 500);

    // --- Verify Turnstile
    const ip = request.headers.get("CF-Connecting-IP") || "";
    const verifyRes = await fetch("https://challenges.cloudflare.com/turnstile/v0/siteverify", {
      method: "POST",
      headers: { "content-type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        secret: env.TURNSTILE_SECRET_KEY,
        response: token,
        remoteip: ip
      })
    });

    const verify = await verifyRes.json();
    if (!verify.success) {
      return json({ ok: false, error: "Turnstile failed", details: verify }, 403);
    }

    // --- Lead fields
    const work_email = get("work_email");
    const company = get("company");
    const compliance = get("compliance");
    const pain = get("pain");
    const source = get("source");
    const page = get("page");

    // --- Telegram
    const BOT = env.TG_BOT_TOKEN;
    const CHAT = env.TG_CHAT_ID;

    if (!BOT || !CHAT) {
      // Fail hard so you SEE it (no silent skip)
      return json({ ok: false, error: "Missing TG_BOT_TOKEN or TG_CHAT_ID" }, 500);
    }

    const msg =
`🛡️ New Aegis lead
🏢 Company: ${company || "-"}
📧 Email: ${work_email || "-"}
✅ Compliance: ${compliance || "-"}
😣 Pain: ${pain || "-"}
🔎 Source: ${source || "-"}
🔗 Page: ${page || "-"}
🕒 ${new Date().toISOString()}`;

    const tgRes = await fetch(`https://api.telegram.org/bot${BOT}/sendMessage`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ chat_id: CHAT, text: msg })
    });

    const tg = await tgRes.json();
    if (!tg.ok) {
      return json({ ok: false, error: "Telegram failed", details: tg }, 500);
    }

    return json({ ok: true, verified: true });
  } catch (e) {
    return json({ ok: false, error: "Server error", details: String(e?.message || e) }, 500);
  }
}

function json(obj, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" }
  });
}
