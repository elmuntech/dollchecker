// Assertions come from `node:assert`, which Deno provides natively — the test
// suite therefore needs no registry download and runs fully offline.
import { deepStrictEqual } from "node:assert/strict";
import {
  constantTimeEquals,
  decodeWebhookSecret,
  extractSubscription,
  isFreshTimestamp,
  parseSignatures,
  signedPayload,
  tierForStatus,
} from "./utils.ts";

const decoder = new TextDecoder();

Deno.test("decodeWebhookSecret strips whsec_ and base64-decodes", () => {
  // "topsecret" base64-encoded.
  deepStrictEqual(
    decoder.decode(decodeWebhookSecret("whsec_dG9wc2VjcmV0")),
    "topsecret",
  );
});

Deno.test("decodeWebhookSecret falls back to raw bytes", () => {
  deepStrictEqual(
    decoder.decode(decodeWebhookSecret("not base64!!")),
    "not base64!!",
  );
});

Deno.test("signedPayload joins id, timestamp and body", () => {
  deepStrictEqual(
    signedPayload("msg_1", "1700000000", "{}"),
    "msg_1.1700000000.{}",
  );
});

Deno.test("parseSignatures reads every v1 entry", () => {
  deepStrictEqual(parseSignatures("v1,aaa v1,bbb"), ["aaa", "bbb"]);
});

Deno.test("parseSignatures ignores other versions and empties", () => {
  // A v2 signature is not ours to verify; accepting it would be pretending.
  deepStrictEqual(parseSignatures("v2,zzz v1,aaa"), ["aaa"]);
  deepStrictEqual(parseSignatures("v1,"), []);
  deepStrictEqual(parseSignatures(null), []);
  deepStrictEqual(parseSignatures(""), []);
});

Deno.test("constantTimeEquals compares by value", () => {
  deepStrictEqual(constantTimeEquals("abc", "abc"), true);
  deepStrictEqual(constantTimeEquals("abc", "abd"), false);
  deepStrictEqual(constantTimeEquals("abc", "abcd"), false);
  deepStrictEqual(constantTimeEquals("", ""), true);
});

Deno.test("isFreshTimestamp accepts drift within tolerance", () => {
  deepStrictEqual(isFreshTimestamp("1000", 1000), true);
  deepStrictEqual(isFreshTimestamp("1000", 1200), true);
  deepStrictEqual(isFreshTimestamp("1200", 1000), true);
});

Deno.test("isFreshTimestamp rejects a replay or a bad clock", () => {
  deepStrictEqual(isFreshTimestamp("1000", 2000), false);
  deepStrictEqual(isFreshTimestamp("2000", 1000), false);
  deepStrictEqual(isFreshTimestamp("later", 1000), false);
  deepStrictEqual(isFreshTimestamp(null, 1000), false);
});

Deno.test("tierForStatus grants premium only while paid up", () => {
  deepStrictEqual(tierForStatus("active"), "premium");
  deepStrictEqual(tierForStatus("trialing"), "premium");
  deepStrictEqual(tierForStatus("canceled"), "free");
  deepStrictEqual(tierForStatus("past_due"), "free");
  deepStrictEqual(tierForStatus("revoked"), "free");
  deepStrictEqual(tierForStatus(undefined), "free");
});

Deno.test("extractSubscription reads a subscription event", () => {
  const state = extractSubscription({
    type: "subscription.active",
    data: {
      id: "sub_1",
      status: "active",
      customer_id: "cus_1",
      current_period_end: "2026-09-01T00:00:00Z",
      metadata: { user_id: "user-1" },
      customer: { id: "cus_1", email: "parent@example.com" },
    },
  });
  deepStrictEqual(state, {
    userId: "user-1",
    customerId: "cus_1",
    subscriptionId: "sub_1",
    status: "active",
    currentPeriodEnd: "2026-09-01T00:00:00Z",
    email: "parent@example.com",
  });
});

Deno.test("extractSubscription reads an order's nested subscription", () => {
  const state = extractSubscription({
    type: "order.paid",
    data: {
      id: "order_1",
      subscription: {
        id: "sub_2",
        status: "active",
        customer_id: "cus_2",
        metadata: { user_id: "user-2" },
      },
    },
  });
  deepStrictEqual(state?.subscriptionId, "sub_2");
  deepStrictEqual(state?.userId, "user-2");
});

Deno.test("extractSubscription falls back to the external customer id", () => {
  // A subscription created outside the app carries no metadata of ours.
  const state = extractSubscription({
    type: "subscription.updated",
    data: {
      id: "sub_3",
      status: "canceled",
      customer_external_id: "user-3",
      customer: { id: "cus_3" },
    },
  });
  deepStrictEqual(state?.userId, "user-3");
  deepStrictEqual(state?.customerId, "cus_3");
  deepStrictEqual(state?.status, "canceled");
});

Deno.test("extractSubscription reports an unknown status", () => {
  const state = extractSubscription({
    type: "subscription.updated",
    data: { id: "sub_4", metadata: { user_id: "user-4" } },
  });
  deepStrictEqual(state?.status, "unknown");
  deepStrictEqual(state?.currentPeriodEnd, null);
});

Deno.test("extractSubscription ignores events with no subscription", () => {
  deepStrictEqual(
    extractSubscription({ type: "benefit.created", data: {} }),
    null,
  );
  deepStrictEqual(extractSubscription({ type: "subscription.active" }), null);
  deepStrictEqual(extractSubscription(null), null);
  deepStrictEqual(extractSubscription("nope"), null);
});
