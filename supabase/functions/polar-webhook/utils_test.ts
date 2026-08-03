// Assertions come from `node:assert`, which Deno provides natively — the test
// suite therefore needs no registry download and runs fully offline.
import { deepStrictEqual } from "node:assert/strict";
import {
  constantTimeEquals,
  decodeWebhookSecret,
  expectedSignature,
  extractSubscription,
  isFreshTimestamp,
  parseSignatures,
  signedPayload,
  tierForStatus,
} from "./utils.ts";

// The Standard Webhooks reference vector. Checking against a number computed
// elsewhere is the point: a test that compares our signature to our own
// signature passes just as happily when we sign the wrong bytes.
const VECTOR = {
  secret: "whsec_MfKQ9r8GKYqrTwjUPD8ILPZIo2LaLaSw",
  id: "msg_p5jXN8AQM9LWM0D4loKWxJek",
  timestamp: "1614265330",
  body: '{"test": 2432232314}',
  signature: "g0hM9SsE+OTPJTGt/tmIKtSyZlE3uFJELVlNIOLJ1OE=",
};

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

Deno.test("the MAC matches the Standard Webhooks vector", async () => {
  const sig = await expectedSignature(
    VECTOR.secret,
    VECTOR.id,
    VECTOR.timestamp,
    VECTOR.body,
  );
  deepStrictEqual(sig, VECTOR.signature);
});

Deno.test("the whsec_ prefix is stripped from the secret", async () => {
  const withPrefix = await expectedSignature(
    VECTOR.secret,
    VECTOR.id,
    VECTOR.timestamp,
    VECTOR.body,
  );
  const without = await expectedSignature(
    VECTOR.secret.slice("whsec_".length),
    VECTOR.id,
    VECTOR.timestamp,
    VECTOR.body,
  );
  deepStrictEqual(withPrefix, without);
});

Deno.test("every signed field actually changes the MAC", async () => {
  // The failure this guards against is silent: a signature that covered only
  // the id and timestamp would verify happily while the body was rewritten,
  // and the body is what says who has paid.
  const base = await expectedSignature(
    VECTOR.secret,
    VECTOR.id,
    VECTOR.timestamp,
    VECTOR.body,
  );

  const variants = await Promise.all([
    expectedSignature(
      VECTOR.secret,
      "msg_other",
      VECTOR.timestamp,
      VECTOR.body,
    ),
    expectedSignature(VECTOR.secret, VECTOR.id, "1614265331", VECTOR.body),
    expectedSignature(VECTOR.secret, VECTOR.id, VECTOR.timestamp, "{}"),
    expectedSignature("whsec_" + btoa("another secret"), VECTOR.id,
      VECTOR.timestamp, VECTOR.body),
  ]);

  for (const variant of variants) {
    deepStrictEqual(variant === base, false);
  }
  // All four differ from each other too, not merely from the base.
  deepStrictEqual(new Set([base, ...variants]).size, 5);
});

Deno.test("a real header verifies, a rewritten body does not", async () => {
  // End to end over the pieces the handler composes: parse the header, then
  // compare in constant time against what we compute.
  const header = `v1,${VECTOR.signature}`;
  const parsed = parseSignatures(header);

  const expected = await expectedSignature(
    VECTOR.secret,
    VECTOR.id,
    VECTOR.timestamp,
    VECTOR.body,
  );
  deepStrictEqual(parsed.some((s) => constantTimeEquals(s, expected)), true);

  // The same delivery with the body swapped after signing must not verify.
  const tampered = await expectedSignature(
    VECTOR.secret,
    VECTOR.id,
    VECTOR.timestamp,
    '{"test": 9999999999}',
  );
  deepStrictEqual(parsed.some((s) => constantTimeEquals(s, tampered)), false);
});
