import { EmailMessage } from "cloudflare:email";
import { createMimeMessage } from "mimetext";

/**
 * POST /api/pack
 * Accepts JSON from the landing-page modal and emails the details to your verified destination.
 *
 * Anti-spam:
 * - Honeypot field: "website" must be empty
 * - Required: work_email + company
 */
export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.pathname !== "/api/pack") {
      return new Response("Not found", { status: 404 });
    }

    // CORS preflight
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders(request) });
    }

    if (request.method !== "POST") {
      return new Response("Method not allowed", { status: 405, headers: corsHeaders(request) });
    }

    let data = {};
    const ct = request.headers.get("content-type") || "";

    try {
      if (ct.includes("application/json")) {
        data = await request.json();
      } else {
        const fd = await request.formData();
        for (const [k, v] of fd.entries()) data[k] = v;
      }
    } catch {
      return json(request, { ok: false, error: "Bad request" }, 400);
    }

    // Honeypot (if filled, silently succeed)
    if (data.website) return json(request, { ok: true });

    const workEmail = (data.work_email || "").toString().trim();
    const company = (data.company || "").toString().trim();

    if (!workEmail || !company) {
      return json(request, { ok: false, error: "Missing required fields" }, 400);
    }

    // IMPORTANT:
    // - "from" must be an address on your domain with Email Routing enabled
    // - destination is controlled by the send_email binding (destination_address)
    const from = "contact@aegiscloud.site";
    const to = env.DEST_EMAIL || "achahboune@gmail.com";

    const subject = `Security Pack request — ${company} (${workEmail})`;

    const body = [
      "New Security Pack request",
      "------------------------",
      `Work email: ${workEmail}`,
      `Company: ${company}`,
      `Compliance: ${safe(data.compliance)}`,
      `Team size: ${safe(data.team_size)}`,
      `Note: ${safe(data.note)}`,
      "",
      `Source: ${safe(data.source)}`,
      `Page: ${safe(data.page)}`,
      `Time (UTC): ${new Date().toISOString()}`,
    ].join("\n");

    const mime = createMimeMessage();
    mime.setSender({ name: "aegiscloud", addr: from });
    mime.setRecipient(to);
    mime.setSubject(subject);
    mime.addMessage({ contentType: "text/plain", data: body });

    const msg = new EmailMessage(from, to, mime.asRaw());

    try {
      // Binding name must match wrangler.toml: [[send_email]] name = "EMAIL"
      await env.EMAIL.send(msg);
      return json(request, { ok: true });
    } catch (e) {
      return json(request, { ok: false, error: e?.message || "Send failed" }, 500);
    }
  },
};

function safe(v) {
  if (v === undefined || v === null) return "";
  return String(v).replace(/\r?\n/g, " ").slice(0, 2000);
}

function corsHeaders(request) {
  const origin = request.headers.get("Origin") || "";
  const allow = new Set([
    "https://aegiscloud.site",
    "https://www.aegiscloud.site",
  ]);

  // If called from a browser on allowed origins, echo it back.
  // Otherwise (curl, etc.) allow all.
  const allowOrigin = allow.has(origin) ? origin : "*";

  return {
    "Access-Control-Allow-Origin": allowOrigin,
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
    "Vary": "Origin",
  };
}

function json(request, obj, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      ...corsHeaders(request),
    },
  });
}
