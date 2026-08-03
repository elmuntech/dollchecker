// polar-webhook — turns Polar subscription events into an account tier.
//
// This is the only writer of the billing columns. The client never reports its
// own subscription state: it asks the server what tier it has, and that answer
// comes from here.
//
// Deploy:  supabase functions deploy polar-webhook --no-verify-jwt
// Secret:  supabase secrets set POLAR_WEBHOOK_SECRET=whsec_...
//
// `--no-verify-jwt` is required: Polar is not a Supabase user and sends no JWT.
// The signature check below is what authenticates the caller instead.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  constantTimeEquals,
  decodeWebhookSecret,
  extractSubscription,
  isFreshTimestamp,
  parseSignatures,
  signedPayload,
} from "./utils.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const WEBHOOK_SECRET = Deno.env.get("POLAR_WEBHOOK_SECRET") ?? "";

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

/** HMAC-SHA256 of `payload` under `secret`, base64 — the Standard Webhooks MAC. */
async function sign(secret: Uint8Array, payload: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    secret,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const mac = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(payload),
  );
  return btoa(String.fromCharCode(...new Uint8Array(mac)));
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });
  if (WEBHOOK_SECRET === "") {
    console.error("POLAR_WEBHOOK_SECRET is not set");
    return json(503, { error: "not_configured" });
  }

  // The signature covers the exact bytes that arrived, so the body must be read
  // as text and parsed only after it has been verified.
  const body = await req.text();
  const id = req.headers.get("webhook-id") ?? "";
  const timestamp = req.headers.get("webhook-timestamp");
  const signatures = parseSignatures(req.headers.get("webhook-signature"));

  if (id === "" || signatures.length === 0) {
    return json(400, { error: "missing_signature_headers" });
  }
  if (!isFreshTimestamp(timestamp, Math.floor(Date.now() / 1000))) {
    return json(400, { error: "stale_timestamp" });
  }

  const expected = await sign(
    decodeWebhookSecret(WEBHOOK_SECRET),
    signedPayload(id, timestamp!, body),
  );
  if (!signatures.some((sig) => constantTimeEquals(sig, expected))) {
    return json(401, { error: "bad_signature" });
  }

  let event: unknown;
  try {
    event = JSON.parse(body);
  } catch {
    return json(400, { error: "invalid_json" });
  }

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  const type = (event as { type?: string })?.type ?? "unknown";

  // Polar retries until it gets a 2xx, so the same event id arrives more than
  // once. The primary key turns a replay into a no-op.
  const { error: seenErr } = await admin
    .from("billing_events")
    .insert({ id, type, payload: event });
  if (seenErr) {
    // 23505 = unique violation: already processed, and that is a success.
    if (seenErr.code === "23505") return json(200, { duplicate: true });
    console.error("billing_events insert failed", seenErr.message);
  }

  const sub = extractSubscription(event);
  if (!sub) return json(200, { ignored: type });

  // Resolve the account. `metadata.user_id` is attached at checkout and is the
  // normal path; the customer id covers a subscription that was created or
  // changed outside the app.
  let userId = sub.userId;
  if (!userId && sub.customerId) {
    const { data: profile } = await admin
      .from("profiles")
      .select("id")
      .eq("polar_customer_id", sub.customerId)
      .maybeSingle();
    userId = profile?.id ?? null;
  }
  if (!userId) {
    // Retrying will not conjure the link, so this is not a failure to report
    // back to Polar — it is something to fix in the checkout metadata.
    console.error("unmatched subscription event", type, sub.customerId);
    return json(200, { unmatched: true });
  }

  const { error: applyErr } = await admin.rpc("apply_subscription_state", {
    p_user_id: userId,
    p_customer_id: sub.customerId,
    p_subscription_id: sub.subscriptionId,
    p_status: sub.status,
    p_current_period_end: sub.currentPeriodEnd,
  });
  if (applyErr) {
    console.error("apply_subscription_state failed", applyErr.message);
    // A 5xx makes Polar retry, which is what we want for a transient DB error.
    return json(500, { error: "apply_failed" });
  }

  await admin
    .from("billing_events")
    .update({ user_id: userId })
    .eq("id", id);

  return json(200, { applied: sub.status });
});
