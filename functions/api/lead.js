export async function onRequestPost({ request, env }) {
  try {
    // 1) Parse body (supports FormData + urlencoded)
    const contentType = request.headers.get("content-type") || "";
    let get = (k) => "";

    if (contentType.includes("multipart/form-data")) {
      const fd = await request.formData();
      get = (k) => String(fd.get(k) || "").trim();
    } else {
      const text = await request.text();
      const params = new URLSearchParams(text);
      get = (k) => String(params.get(k) || "").trim();
    }

    // 2) Turnstile token (FormData uses cf-turnstile-response)
    const token = get("cf-turnstile-response") || get("turnstile");
    if (!token) return json({ ok: false, error: "Missing Turnstile token" }, 400);

    if (!env.TURNSTILE_SECRET_KEY) {
      return json({ ok: false, error: "Server misconfig: TURNSTILE_SECRET_KEY missing" }, 500);
    }

    // 3) Verify Turnstile
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

    // 4) Read fields
    const work_email = get("work_email");
    const company = get("company");
    const compliance = get("compliance");
    const pain = get("pain");
    const source = get("source");
    const page = get("page");

    // basic validation
    if (!work_email || !work_email.includes("@")) {
      return json({ ok: false, error: "Invalid work email" }, 400);
    }
    if (!company) return json({ ok: false, error: "Company is required" }, 400);
    if (!compliance) return json({ ok: false, error: "Compliance is required" }, 400);
    if (!pain) return json({ ok: false, error: "Pain is required" }, 400);

    // 5) Send Telegram (if configured)
    if (env.TELEGRAM_BOT_TOKEN && env.TELEGRAM_CHAT_ID) {
      const msg =
`🛡️ New Aegis lead
🏢 Company: ${company}
📧 Email: ${work_email}
✅ Compliance: ${compliance}
😣 Pain: ${pain}
🔎 Source: ${source || "landing"}
🔗 Page: ${page || ""}
🕒 ${new Date().toISOString()}`;

      const tgRes = await fetch(`https://api.telegram.org/bot${env.TELEGRAM_BOT_TOKEN}/sendMessage`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          chat_id: env.TELEGRAM_CHAT_ID,
          text: msg
        })
      });

      const tg = await tgRes.json();
      if (!tg.ok) {
        return json({ ok: false, error: "Telegram failed", details: tg }, 500);
      }
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
