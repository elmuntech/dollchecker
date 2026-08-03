// Rate limiting shared by every function.
//
// The counter lives in Postgres (`hit_rate_limit`, migration 0006) rather than
// in memory: Edge Functions run as many short-lived isolates, so an in-process
// counter would reset constantly and limit nothing.

/** One limit to enforce. */
export interface RateLimitRule {
  /** What is being limited — `analyze`, `chat`, … */
  action: string;
  /** Who: a user id, or an IP. */
  subject: string;
  /** What kind of subject, so two subjects cannot collide in one bucket. */
  kind: "user" | "ip";
  limit: number;
  windowSeconds: number;
}

/**
 * The bucket key for a rule.
 *
 * The kind is part of the key: without it a user whose id happened to equal an
 * IP string would share a counter with it, and more practically, per-user and
 * per-IP limits on the same action would fight over one row.
 */
export function bucketKey(rule: RateLimitRule): string {
  return `${rule.action}:${rule.kind}:${rule.subject}`;
}

/**
 * The client's address, as far as it can be trusted.
 *
 * Behind a proxy the socket address is the proxy's, so `x-forwarded-for` is all
 * there is — and it is client-supplied, so a determined attacker can rotate it.
 * Per-IP limiting is therefore a speed bump for casual abuse, not a defence;
 * the per-user limit and the quota are what actually bound the cost.
 */
export function clientIp(headers: Headers): string {
  const forwarded = headers.get("x-forwarded-for") ?? "";
  const first = forwarded.split(",")[0]?.trim() ?? "";
  if (first !== "") return first;
  return headers.get("cf-connecting-ip") ?? "unknown";
}

/** Retry-After, in seconds, never below one. */
export function retryAfterSeconds(value: unknown): number {
  const n = typeof value === "number" ? value : Number(value);
  return Number.isFinite(n) && n > 0 ? Math.ceil(n) : 1;
}

export interface RateLimitVerdict {
  allowed: boolean;
  retryAfter: number;
}

type Rpc = {
  rpc: (
    name: string,
    params: Record<string, unknown>,
  ) => PromiseLike<{ data: unknown; error: { message: string } | null }>;
};

/**
 * Applies every rule and reports the first refusal.
 *
 * Rules are checked in order and every one is counted, including those after a
 * refusal — a request that was rejected still consumed attention, and not
 * counting it would let a caller stay under a per-hour limit by tripping the
 * per-minute one forever.
 *
 * A database failure allows the request. The alternative is an outage in the
 * limiter taking the whole product down, which is a worse failure than a
 * window of unlimited requests — the quota still bounds the spend.
 */
export async function enforceRateLimits(
  db: Rpc,
  rules: readonly RateLimitRule[],
): Promise<RateLimitVerdict> {
  let verdict: RateLimitVerdict = { allowed: true, retryAfter: 0 };

  for (const rule of rules) {
    const { data, error } = await db.rpc("hit_rate_limit", {
      p_bucket: bucketKey(rule),
      p_limit: rule.limit,
      p_window_seconds: rule.windowSeconds,
    });
    if (error) {
      console.error("rate limit check failed", error.message);
      continue;
    }
    const row = Array.isArray(data) ? data[0] : data;
    const allowed = (row as { allowed?: boolean })?.allowed !== false;
    if (!allowed && verdict.allowed) {
      verdict = {
        allowed: false,
        retryAfter: retryAfterSeconds(
          (row as { retry_after?: unknown })?.retry_after,
        ),
      };
    }
  }

  return verdict;
}

/** The 429 a refused request gets, with the header a client should obey. */
export function rateLimitedResponse(
  retryAfter: number,
  extraHeaders: Record<string, string> = {},
): Response {
  return new Response(
    JSON.stringify({ error: "rate_limited", retry_after: retryAfter }),
    {
      status: 429,
      headers: {
        ...extraHeaders,
        "Content-Type": "application/json",
        "Retry-After": String(retryAfter),
      },
    },
  );
}

/** Token counts from an Anthropic response, for `ai_usage`. */
export function usageFromCompletion(
  completion: unknown,
): { input: number; output: number } {
  const usage = (completion as { usage?: Record<string, unknown> })?.usage;
  const read = (key: string): number => {
    const value = usage?.[key];
    return typeof value === "number" && Number.isFinite(value) ? value : 0;
  };
  return {
    // Cache reads and writes are billed too; folding them into the input count
    // keeps one number meaning "what this call cost on the way in".
    input: read("input_tokens") + read("cache_creation_input_tokens") +
      read("cache_read_input_tokens"),
    output: read("output_tokens"),
  };
}
