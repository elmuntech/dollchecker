// Assertions come from `node:assert`, which Deno provides natively — the test
// suite therefore needs no registry download and runs fully offline.
import { deepStrictEqual } from "node:assert/strict";
import {
  bucketKey,
  clientIp,
  enforceRateLimits,
  rateLimitedResponse,
  retryAfterSeconds,
  usageFromCompletion,
} from "./rate_limit.ts";

Deno.test("bucketKey separates action, kind and subject", () => {
  deepStrictEqual(
    bucketKey({
      action: "analyze",
      kind: "user",
      subject: "u1",
      limit: 1,
      windowSeconds: 60,
    }),
    "analyze:user:u1",
  );
});

Deno.test("bucketKey keeps a user and an IP in separate buckets", () => {
  const rule = {
    action: "analyze",
    subject: "1.2.3.4",
    limit: 1,
    windowSeconds: 60,
  };
  deepStrictEqual(
    bucketKey({ ...rule, kind: "user" }) === bucketKey({ ...rule, kind: "ip" }),
    false,
  );
});

Deno.test("clientIp reads the first forwarded address", () => {
  const headers = new Headers({ "x-forwarded-for": "1.2.3.4, 5.6.7.8" });
  deepStrictEqual(clientIp(headers), "1.2.3.4");
});

Deno.test("clientIp falls back and never returns empty", () => {
  deepStrictEqual(
    clientIp(new Headers({ "cf-connecting-ip": "9.9.9.9" })),
    "9.9.9.9",
  );
  deepStrictEqual(clientIp(new Headers()), "unknown");
  deepStrictEqual(
    clientIp(new Headers({ "x-forwarded-for": "  " })),
    "unknown",
  );
});

Deno.test("retryAfterSeconds never suggests retrying immediately", () => {
  deepStrictEqual(retryAfterSeconds(30), 30);
  deepStrictEqual(retryAfterSeconds(0.2), 1);
  deepStrictEqual(retryAfterSeconds(0), 1);
  deepStrictEqual(retryAfterSeconds(-5), 1);
  deepStrictEqual(retryAfterSeconds("nope"), 1);
  deepStrictEqual(retryAfterSeconds(undefined), 1);
});

/** Replays prepared rows for each rpc call. */
function fakeDb(results: unknown[], calls: string[] = []) {
  let i = 0;
  return {
    calls,
    rpc(_name: string, params: Record<string, unknown>) {
      calls.push(String(params.p_bucket));
      const data = results[i++] ?? [{ allowed: true }];
      return Promise.resolve({ data, error: null });
    },
  };
}

const rule = (action: string, limit: number) => ({
  action,
  kind: "user" as const,
  subject: "u1",
  limit,
  windowSeconds: 60,
});

Deno.test("enforceRateLimits allows when every rule allows", async () => {
  const db = fakeDb([[{ allowed: true }], [{ allowed: true }]]);
  const verdict = await enforceRateLimits(db, [rule("a", 5), rule("b", 5)]);
  deepStrictEqual(verdict.allowed, true);
});

Deno.test("enforceRateLimits reports the first refusal", async () => {
  const db = fakeDb([
    [{ allowed: false, retry_after: 42 }],
    [{ allowed: false, retry_after: 900 }],
  ]);
  const verdict = await enforceRateLimits(db, [rule("a", 1), rule("b", 1)]);
  deepStrictEqual(verdict, { allowed: false, retryAfter: 42 });
});

Deno.test("enforceRateLimits counts every rule after a refusal", async () => {
  // Otherwise a caller could sit under an hourly limit forever by tripping the
  // per-minute one on every request.
  const calls: string[] = [];
  const db = fakeDb(
    [[{ allowed: false, retry_after: 5 }], [{ allowed: true }]],
    calls,
  );
  await enforceRateLimits(db, [rule("a", 1), rule("b", 100)]);
  deepStrictEqual(calls, ["a:user:u1", "b:user:u1"]);
});

Deno.test("enforceRateLimits allows when the limiter fails", async () => {
  // An outage in the limiter must not take the product down; the quota still
  // bounds what an unlimited window can cost.
  const db = {
    rpc: () => Promise.resolve({ data: null, error: { message: "down" } }),
  };
  deepStrictEqual((await enforceRateLimits(db, [rule("a", 1)])).allowed, true);
});

Deno.test("rateLimitedResponse carries the Retry-After header", () => {
  const res = rateLimitedResponse(30, { "x-test": "1" });
  deepStrictEqual(res.status, 429);
  deepStrictEqual(res.headers.get("Retry-After"), "30");
  deepStrictEqual(res.headers.get("x-test"), "1");
});

Deno.test("usageFromCompletion folds cache tokens into input", () => {
  deepStrictEqual(
    usageFromCompletion({
      usage: {
        input_tokens: 100,
        cache_creation_input_tokens: 20,
        cache_read_input_tokens: 5,
        output_tokens: 50,
      },
    }),
    { input: 125, output: 50 },
  );
});

Deno.test("usageFromCompletion survives a response with no usage", () => {
  deepStrictEqual(usageFromCompletion({}), { input: 0, output: 0 });
  deepStrictEqual(usageFromCompletion(null), { input: 0, output: 0 });
  deepStrictEqual(
    usageFromCompletion({ usage: { input_tokens: "lots" } }),
    { input: 0, output: 0 },
  );
});
