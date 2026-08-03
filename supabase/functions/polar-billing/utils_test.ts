// Assertions come from `node:assert`, which Deno provides natively — the test
// suite therefore needs no registry download and runs fully offline.
import { deepStrictEqual } from "node:assert/strict";
import {
  apiBase,
  checkoutBody,
  customerSessionBody,
  extractUrl,
  isConfigured,
  normalizeServer,
  parseAction,
} from "./utils.ts";

Deno.test("normalizeServer defaults to sandbox", () => {
  // A typo must never reach the endpoint that charges real cards.
  deepStrictEqual(normalizeServer("production"), "production");
  deepStrictEqual(normalizeServer("prod"), "sandbox");
  deepStrictEqual(normalizeServer(undefined), "sandbox");
  deepStrictEqual(normalizeServer(""), "sandbox");
});

Deno.test("apiBase points at the right host", () => {
  deepStrictEqual(apiBase("production"), "https://api.polar.sh");
  deepStrictEqual(apiBase("sandbox"), "https://sandbox-api.polar.sh");
});

Deno.test("parseAction defaults to checkout", () => {
  deepStrictEqual(parseAction(null), "checkout");
  deepStrictEqual(parseAction({}), "checkout");
  deepStrictEqual(parseAction({ action: "checkout" }), "checkout");
});

Deno.test("parseAction reads the portal action", () => {
  deepStrictEqual(parseAction({ action: "portal" }), "portal");
});

Deno.test("parseAction rejects anything else", () => {
  deepStrictEqual(parseAction({ action: "refund" }), null);
  deepStrictEqual(parseAction({ action: 1 }), null);
});

Deno.test("checkoutBody carries the link back to the account", () => {
  deepStrictEqual(
    checkoutBody(
      { productId: "prod_1", successUrl: "dollchecker://done" },
      { id: "user-1", email: "parent@example.com" },
    ),
    {
      products: ["prod_1"],
      success_url: "dollchecker://done",
      customer_email: "parent@example.com",
      customer_external_id: "user-1",
      metadata: { user_id: "user-1" },
    },
  );
});

Deno.test("checkoutBody omits an unknown email", () => {
  const body = checkoutBody(
    { productId: "prod_1", successUrl: "dollchecker://done" },
    { id: "user-1", email: null },
  );
  deepStrictEqual(body.customer_email, undefined);
  deepStrictEqual(body.metadata, { user_id: "user-1" });
});

Deno.test("customerSessionBody prefers a known customer id", () => {
  deepStrictEqual(
    customerSessionBody("user-1", "cus_1"),
    { customer_id: "cus_1" },
  );
});

Deno.test("customerSessionBody falls back to the external id", () => {
  deepStrictEqual(
    customerSessionBody("user-1", null),
    { customer_external_id: "user-1" },
  );
});

Deno.test("extractUrl reads a checkout url", () => {
  deepStrictEqual(
    extractUrl({ url: "https://polar.sh/checkout/x" }),
    "https://polar.sh/checkout/x",
  );
});

Deno.test("extractUrl reads a portal url", () => {
  deepStrictEqual(
    extractUrl({ customer_portal_url: "https://polar.sh/portal/x" }),
    "https://polar.sh/portal/x",
  );
});

Deno.test("extractUrl refuses anything that is not an https link", () => {
  // Opening whatever the response happened to contain is how an open redirect
  // starts.
  deepStrictEqual(extractUrl({ url: "javascript:alert(1)" }), null);
  deepStrictEqual(extractUrl({ url: 42 }), null);
  deepStrictEqual(extractUrl({}), null);
  deepStrictEqual(extractUrl(null), null);
});

Deno.test("isConfigured requires both secrets", () => {
  deepStrictEqual(isConfigured("token", "prod_1"), true);
  deepStrictEqual(isConfigured("", "prod_1"), false);
  deepStrictEqual(isConfigured("token", ""), false);
  deepStrictEqual(isConfigured(undefined, undefined), false);
});
