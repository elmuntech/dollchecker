// polar-billing — starts a Polar checkout, or opens the customer portal.
//
// The app never holds the Polar token: it asks this function for a URL and
// opens it. What comes back from paying is not trusted either — the tier only
// changes when `polar-webhook` says so.
//
// Deploy:  supabase functions deploy polar-billing
// Secrets: supabase secrets set POLAR_ACCESS_TOKEN=polar_oat_... \
//                               POLAR_PRODUCT_ID=... \
//                               POLAR_SERVER=sandbox \
//                               POLAR_SUCCESS_URL=dollchecker://checkout-done

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import {
  apiBase,
  checkoutBody,
  customerSessionBody,
  extractUrl,
  isConfigured,
  normalizeServer,
  parseAction,
} from "./utils.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const POLAR_ACCESS_TOKEN = Deno.env.get("POLAR_ACCESS_TOKEN");
const POLAR_PRODUCT_ID = Deno.env.get("POLAR_PRODUCT_ID");
const POLAR_SERVER = normalizeServer(Deno.env.get("POLAR_SERVER"));
const POLAR_SUCCESS_URL = Deno.env.get("POLAR_SUCCESS_URL") ??
  "dollchecker://checkout-done";

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

async function callPolar(
  path: string,
  body: Record<string, unknown>,
): Promise<{ ok: boolean; url: string | null; detail: string }> {
  const res = await fetch(`${apiBase(POLAR_SERVER)}${path}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${POLAR_ACCESS_TOKEN}`,
    },
    body: JSON.stringify(body),
  });
  const text = await res.text();
  if (!res.ok) return { ok: false, url: null, detail: text.slice(0, 300) };

  let payload: unknown;
  try {
    payload = JSON.parse(text);
  } catch {
    return { ok: false, url: null, detail: "unparseable_response" };
  }
  return { ok: true, url: extractUrl(payload), detail: "" };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

  // Answering "not configured" rather than failing lets the app ship — and the
  // paywall explain itself — before the Polar account exists.
  if (!isConfigured(POLAR_ACCESS_TOKEN, POLAR_PRODUCT_ID)) {
    return json(503, { error: "billing_not_configured" });
  }

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const jwt = authHeader.replace(/^Bearer\s+/i, "");
    if (!jwt) return json(401, { error: "missing_token" });

    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user }, error: authErr } = await userClient.auth.getUser(
      jwt,
    );
    if (authErr || !user) return json(401, { error: "invalid_token" });

    const action = parseAction(await req.json().catch(() => null));
    if (action === null) return json(400, { error: "unknown_action" });

    if (action === "checkout") {
      const result = await callPolar(
        "/v1/checkouts/",
        checkoutBody(
          { productId: POLAR_PRODUCT_ID!, successUrl: POLAR_SUCCESS_URL },
          { id: user.id, email: user.email },
        ),
      );
      if (!result.ok || result.url === null) {
        console.error("checkout failed", result.detail);
        return json(502, { error: "checkout_failed" });
      }
      return json(200, { url: result.url });
    }

    // Portal: reuse the stored customer id when the webhook has already seen
    // this account, otherwise let Polar resolve it by external id.
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
    const { data: profile } = await admin
      .from("profiles")
      .select("polar_customer_id")
      .eq("id", user.id)
      .maybeSingle();

    const result = await callPolar(
      "/v1/customer-sessions/",
      customerSessionBody(user.id, profile?.polar_customer_id ?? null),
    );
    if (!result.ok || result.url === null) {
      console.error("portal failed", result.detail);
      return json(502, { error: "portal_failed" });
    }
    return json(200, { url: result.url });
  } catch (e) {
    console.error("polar-billing failed", e);
    return json(500, { error: "internal_error" });
  }
});
