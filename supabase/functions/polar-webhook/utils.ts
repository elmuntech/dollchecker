// Pure helpers for the polar-webhook function.
//
// Kept free of Deno/Supabase imports so they can be unit-tested with
// `deno test` without any network or environment setup.

/** Statuses that entitle the account to premium features. */
export const PREMIUM_STATUSES = ["active", "trialing"] as const;

/** How far a webhook timestamp may drift before it is treated as a replay. */
export const TIMESTAMP_TOLERANCE_SECONDS = 5 * 60;

/**
 * Polar signs webhooks with the Standard Webhooks scheme: the secret is
 * distributed base64-encoded behind a `whsec_` prefix. A secret that is neither
 * is used as raw bytes, which is what a hand-set test secret looks like.
 */
export function decodeWebhookSecret(secret: string): Uint8Array<ArrayBuffer> {
  const raw = secret.startsWith("whsec_") ? secret.slice(6) : secret;
  try {
    const bin = atob(raw);
    const out = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
    return out;
  } catch {
    // Copied rather than returned directly: Web Crypto will not import a key
    // backed by a SharedArrayBuffer, and the plain `Uint8Array` this used to
    // be annotated as allows one. `Uint8Array.from` pins the buffer type no
    // matter what `TextEncoder.encode` is declared to return.
    return Uint8Array.from(new TextEncoder().encode(raw));
  }
}

/** The exact bytes Standard Webhooks signs: `{id}.{timestamp}.{body}`. */
export function signedPayload(
  id: string,
  timestamp: string,
  body: string,
): string {
  return `${id}.${timestamp}.${body}`;
}

/** HMAC-SHA256 of `payload` under `key`, base64 — the Standard Webhooks MAC. */
export async function hmacSha256Base64(
  key: Uint8Array<ArrayBuffer>,
  payload: string,
): Promise<string> {
  const imported = await crypto.subtle.importKey(
    "raw",
    key,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const mac = await crypto.subtle.sign(
    "HMAC",
    imported,
    new TextEncoder().encode(payload),
  );
  return btoa(String.fromCharCode(...new Uint8Array(mac)));
}

/**
 * The signature a delivery must carry to be ours.
 *
 * Lives here rather than in the handler so it can be tested: this is the only
 * thing standing between anyone on the internet and the column that decides
 * who has paid. A bug that rejects valid deliveries is loud — subscriptions
 * silently stop applying — but a bug that signs the wrong bytes is not, and
 * that is the one worth a known-answer test.
 */
export function expectedSignature(
  secret: string,
  id: string,
  timestamp: string,
  body: string,
): Promise<string> {
  return hmacSha256Base64(
    decodeWebhookSecret(secret),
    signedPayload(id, timestamp, body),
  );
}

/**
 * Signatures from the `webhook-signature` header. The header carries one or
 * more space-separated `v{n},{base64}` pairs — several while a secret is being
 * rotated — and versions other than v1 are not ours to check.
 */
export function parseSignatures(header: string | null): string[] {
  if (!header) return [];
  return header
    .split(" ")
    .map((part) => part.trim())
    .filter((part) => part.startsWith("v1,"))
    .map((part) => part.slice(3))
    .filter((sig) => sig.length > 0);
}

/** Length-independent comparison, so a mismatch leaks no timing information. */
export function constantTimeEquals(a: string, b: string): boolean {
  const len = Math.max(a.length, b.length);
  let diff = a.length ^ b.length;
  for (let i = 0; i < len; i++) {
    diff |= (a.charCodeAt(i) || 0) ^ (b.charCodeAt(i) || 0);
  }
  return diff === 0;
}

/**
 * Whether a webhook timestamp (unix seconds, as a string) is close enough to
 * now. Rejects both a stale replay and a clock far in the future.
 */
export function isFreshTimestamp(
  timestamp: string | null,
  nowSeconds: number,
  tolerance: number = TIMESTAMP_TOLERANCE_SECONDS,
): boolean {
  if (!timestamp) return false;
  const ts = Number(timestamp);
  if (!Number.isFinite(ts)) return false;
  return Math.abs(nowSeconds - ts) <= tolerance;
}

/** The tier a provider status maps to. Anything unrecognized loses premium. */
export function tierForStatus(status: unknown): "premium" | "free" {
  return typeof status === "string" &&
      (PREMIUM_STATUSES as readonly string[]).includes(status)
    ? "premium"
    : "free";
}

export interface SubscriptionState {
  userId: string | null;
  customerId: string | null;
  subscriptionId: string | null;
  status: string;
  currentPeriodEnd: string | null;
  email: string | null;
}

function asRecord(v: unknown): Record<string, unknown> | null {
  return typeof v === "object" && v !== null
    ? v as Record<string, unknown>
    : null;
}

function asString(v: unknown): string | null {
  return typeof v === "string" && v !== "" ? v : null;
}

/**
 * Pulls the subscription out of a webhook event.
 *
 * The account is identified by `metadata.user_id`, which the checkout attaches
 * — that is the only link the provider has back to a Supabase user. The
 * customer id and email are returned too so a subscription created outside the
 * app (support, a re-purchase) can still be matched to a profile.
 *
 * Returns null for an event that carries no subscription at all.
 */
export function extractSubscription(event: unknown): SubscriptionState | null {
  const root = asRecord(event);
  if (!root) return null;

  const type = asString(root.type) ?? "";
  const data = asRecord(root.data);
  if (!data) return null;

  // `subscription.*` events are the subscription; order/checkout events nest it.
  const sub = type.startsWith("subscription.")
    ? data
    : asRecord(data.subscription);
  if (!sub) return null;

  const metadata = asRecord(sub.metadata) ?? asRecord(data.metadata) ?? {};
  const customer = asRecord(sub.customer) ?? asRecord(data.customer);

  return {
    userId: asString(metadata.user_id) ??
      asString(sub.customer_external_id) ??
      asString(customer?.external_id),
    customerId: asString(sub.customer_id) ?? asString(customer?.id),
    subscriptionId: asString(sub.id),
    status: asString(sub.status) ?? "unknown",
    currentPeriodEnd: asString(sub.current_period_end) ??
      asString(sub.ends_at),
    email: asString(customer?.email),
  };
}
