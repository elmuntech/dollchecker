// Pure helpers for the polar-billing function.
//
// Kept free of Deno/Supabase imports so they can be unit-tested with
// `deno test` without any network or environment setup.

export type PolarServer = "sandbox" | "production";

/** What the client is asking for. */
export type BillingAction = "checkout" | "portal";

export function normalizeServer(v: unknown): PolarServer {
  return v === "production" ? "production" : "sandbox";
}

/**
 * API host for the environment. Sandbox is the default everywhere so a missing
 * or misspelled setting can never charge a real card.
 */
export function apiBase(server: PolarServer): string {
  return server === "production"
    ? "https://api.polar.sh"
    : "https://sandbox-api.polar.sh";
}

export function parseAction(body: unknown): BillingAction | null {
  const raw = typeof body === "object" && body !== null
    ? (body as Record<string, unknown>).action
    : null;
  if (raw === undefined || raw === null || raw === "checkout") {
    return "checkout";
  }
  return raw === "portal" ? "portal" : null;
}

export interface CheckoutConfig {
  productId: string;
  successUrl: string;
}

/**
 * Body for `POST /v1/checkouts/`.
 *
 * `metadata.user_id` is the entire link between a Polar subscription and a
 * Supabase account — the webhook has nothing else to go on — so it is not
 * optional, and `customer_external_id` repeats it where Polar surfaces it as a
 * first-class field.
 */
export function checkoutBody(
  config: CheckoutConfig,
  user: { id: string; email?: string | null },
): Record<string, unknown> {
  return {
    products: [config.productId],
    success_url: config.successUrl,
    customer_email: user.email ?? undefined,
    customer_external_id: user.id,
    metadata: { user_id: user.id },
  };
}

/** Body for `POST /v1/customer-sessions/`, which returns a portal URL. */
export function customerSessionBody(
  userId: string,
  customerId: string | null,
): Record<string, unknown> {
  return customerId === null
    ? { customer_external_id: userId }
    : { customer_id: customerId };
}

/**
 * Pulls the URL out of a Polar response. Checkouts return `url`; customer
 * sessions return `customer_portal_url`.
 */
export function extractUrl(payload: unknown): string | null {
  if (typeof payload !== "object" || payload === null) return null;
  const record = payload as Record<string, unknown>;
  const candidates = [record.url, record.customer_portal_url];
  for (const candidate of candidates) {
    if (typeof candidate === "string" && candidate.startsWith("https://")) {
      return candidate;
    }
  }
  return null;
}

/** Whether the function has everything it needs to talk to Polar. */
export function isConfigured(
  token: string | undefined,
  productId: string | undefined,
): boolean {
  return (token ?? "") !== "" && (productId ?? "") !== "";
}
