// paypal-return — the bounce redirect PayPal sends the browser to after approval.
//
// PayPal does not accept a custom scheme (io.supabase.keepsims://) as return_url,
// so the redirect makes this HTTPS hop.
// We return an HTTP 302 redirect with Location: io.supabase.keepsims://payment-success...
// which immediately opens KeepSIMs and dismisses the browser tab.
//
// Note: Supabase Edge Functions API Gateway automatically rewrites Content-Type: text/html
// to text/plain (with CSP sandbox), so serving raw HTML causes browsers to display plain text code.
// Returning an HTTP 302 Location header solves this by redirecting directly without serving HTML.

function sanitizeToken(raw: string | null): string {
  if (!raw || raw.length > 64) return "";
  return /^[A-Za-z0-9_-]+$/.test(raw) ? raw : "";
}

Deno.serve((req: Request): Response => {
  const url = new URL(req.url);

  const cancelled = url.searchParams.get("ks_cancel") === "1";
  const orderId = sanitizeToken(url.searchParams.get("token"));

  const params = new URLSearchParams({ status: cancelled ? "cancel" : "success" });
  if (orderId) params.set("order_id", orderId);
  const deepLink = `io.supabase.keepsims://payment-success?${params.toString()}`;

  return new Response(null, {
    status: 302,
    headers: {
      "Location": deepLink,
      "Cache-Control": "no-store, no-cache, must-revalidate",
    },
  });
});
