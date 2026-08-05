// paypal-return — the bounce page PayPal sends the browser to after approval.
//
// PayPal will not accept a custom scheme as return_url, so the redirect has to
// make one HTTPS hop before it can reach the app. This function is that hop: it
// serves a small branded page whose only job is to hand the browser an
// `io.supabase.keepsims://payment-success` URL, which the OS resolves to the app
// and which auto-dismisses the Chrome Custom Tab the checkout screen opened.
//
// It deliberately does NOT capture the order. Capture is the webhook's job
// (CHECKOUT.ORDER.APPROVED) with capture-paypal-order as the client's idempotent
// fallback — this page is unauthenticated and must never move money.
//
// Deploy with JWT verification off; PayPal redirects a plain browser here with
// no Authorization header:
//   supabase functions deploy paypal-return --no-verify-jwt

// PayPal appends its own params to the return URL (`token` = order id,
// `PayerID`). Both are attacker-controllable in the sense that anyone can load
// this URL with any query string, and both get reflected into the page — so
// everything is whitelist-sanitised rather than escaped. Order ids are PayPal
// alphanumerics; anything else becomes empty.
// Reject rather than truncate: a sliced id is still a well-formed id, and
// handing the app a wrong-but-plausible order_id is worse than handing it none
// (none falls through to the poll; wrong looks like a mismatched order).
function sanitizeToken(raw: string | null): string {
  if (!raw || raw.length > 64) return "";
  return /^[A-Za-z0-9_-]+$/.test(raw) ? raw : "";
}

function page(deepLink: string, cancelled: boolean): string {
  const heading = cancelled ? "Payment cancelled" : "Payment received";
  const body = cancelled
    ? "No charge was made. You can return to KeepSIMs and try again."
    : "Thanks — we're confirming it now. Returning you to KeepSIMs…";
  const accent = cancelled ? "#B45309" : "#10B981";

  // deepLink is built from sanitised parts only, so it is safe in both the
  // href attribute and the script literal.
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>KeepSIMs</title>
<style>
  :root { color-scheme: light dark; }
  body {
    margin: 0; min-height: 100vh; display: flex; align-items: center;
    justify-content: center; padding: 24px; box-sizing: border-box;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    background: #F8FAFC; color: #0F172A;
  }
  .card {
    max-width: 380px; width: 100%; text-align: center; background: #FFFFFF;
    border: 1px solid #E2E8F0; border-radius: 20px; padding: 32px 24px;
    box-shadow: 0 10px 30px rgba(15, 23, 42, .06);
  }
  .dot {
    width: 56px; height: 56px; border-radius: 50%; margin: 0 auto 16px;
    background: ${accent}1A; color: ${accent}; font-size: 28px; line-height: 56px;
  }
  h1 { font-size: 20px; margin: 0 0 8px; }
  p { font-size: 15px; line-height: 1.5; margin: 0 0 24px; color: #475569; }
  a.btn {
    display: block; padding: 15px 20px; border-radius: 14px; background: #0070BA;
    color: #fff; font-weight: 700; font-size: 16px; text-decoration: none;
  }
  @media (prefers-color-scheme: dark) {
    body { background: #0B1220; color: #E2E8F0; }
    .card { background: #111C2E; border-color: #1E293B; box-shadow: none; }
    p { color: #94A3B8; }
  }
</style>
</head>
<body>
  <div class="card">
    <div class="dot">${cancelled ? "!" : "&check;"}</div>
    <h1>${heading}</h1>
    <p>${body}</p>
    <a class="btn" id="back" href="${deepLink}">Return to KeepSIMs</a>
  </div>
<script>
  // Custom Tabs dismiss themselves once the scheme resolves to the app. The
  // button stays visible for the browsers that block a scripted scheme jump.
  setTimeout(function () { window.location.replace(${JSON.stringify(deepLink)}); }, 60);
</script>
</body>
</html>`;
}

Deno.serve((req: Request): Response => {
  const url = new URL(req.url);

  // The cancel_url points at this same function with ks_cancel=1, so there is
  // only one page to keep branded and one URL to configure.
  const cancelled = url.searchParams.get("ks_cancel") === "1";
  const orderId = sanitizeToken(url.searchParams.get("token"));

  const params = new URLSearchParams({ status: cancelled ? "cancel" : "success" });
  if (orderId) params.set("order_id", orderId);
  const deepLink = `io.supabase.keepsims://payment-success?${params.toString()}`;

  return new Response(page(deepLink, cancelled), {
    status: 200,
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "no-store",
      // Nothing here is embeddable and nothing should be indexed.
      "X-Frame-Options": "DENY",
      "X-Robots-Tag": "noindex",
    },
  });
});
