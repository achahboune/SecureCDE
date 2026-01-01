export async function onRequestPost({ request, env }) {
  try {
    const contentType = request.headers.get("content-type") || "";

    // parse body (URLSearchParams)
    let params;
    if (contentType.includes("application/x-www-form-urlencoded")) {
      const text = await request.text();
      params = new URLSearchParams(text);
    } else {
      // fallback
      const text = await request.text();
      params = new URLSearchParams(text);
    }

    const token = (params.get("turnstile") || "").trim();
    if (!token) {
      return json({ ok: false, error: "Missing Turnstile token" }, 400);
    }

    // Verify Turnstile
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

    // ---- Continue your existing lead logic here ----
    // Example: read fields
    const work_email = (params.get("work_email") || "").trim();
    const company = (params.get("company") || "").trim();
    const compliance = (params.get("compliance") || "").trim();
    const pain = (params.get("pain") || "").trim();
    const source = (params.get("source") || "").trim();
    const page = (params.get("page") || "").trim();

    // TODO: your Telegram send (existing)
    // await sendTelegram(env, message)

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
