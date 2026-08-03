// Pure helpers for the analyze-toy function.
//
// Kept free of Deno/Supabase imports so they can be unit-tested with
// `deno test` without any network or environment setup.

export const ALLOWED_MEDIA = ["image/jpeg", "image/png", "image/webp"] as const;

/** Free-tier monthly allowance. Enforced by `consume_scan_quota` (migration
 *  0006), which is the only implementation — this constant just tells it the
 *  limit, and matches `kFreeMonthlyScans` in the Flutter app. */
export const FREE_MONTHLY_SCANS = 10;

/** Max decoded image size we accept (bytes). Larger payloads are rejected
 *  before we spend an Anthropic call on them. */
export const MAX_IMAGE_BYTES = 8 * 1024 * 1024;

export type MediaType = typeof ALLOWED_MEDIA[number];

export function isAllowedMedia(v: unknown): v is MediaType {
  return typeof v === "string" &&
    (ALLOWED_MEDIA as readonly string[]).includes(v);
}

/** Only 'en' and 'ru' are supported; anything else falls back to English. */
export function normalizeLocale(v: unknown): "en" | "ru" {
  return v === "ru" ? "ru" : "en";
}

export function base64ToBytes(b64: string): Uint8Array {
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

/** Decoded byte length of a base64 string, without allocating the buffer. */
export function base64ByteLength(b64: string): number {
  const clean = b64.replace(/=+$/, "");
  return Math.floor((clean.length * 3) / 4);
}

/** Whole months elapsed since `dateStr` (an ISO date), never negative. */
export function monthsSince(dateStr: string, now: Date = new Date()): number {
  const d = new Date(dateStr);
  if (Number.isNaN(d.getTime())) return 0;
  let months = (now.getFullYear() - d.getFullYear()) * 12 +
    (now.getMonth() - d.getMonth());
  // Not a full month yet if the day-of-month hasn't come around.
  if (now.getDate() < d.getDate()) months -= 1;
  return Math.max(0, months);
}

/** Storage object path for a toy image: `{user_id}/{uuid}.{ext}`, matching the
 *  storage RLS policy that keys on the first path segment. */
export function toyImagePath(
  userId: string,
  mediaType: string,
  uuid: string,
): string {
  const ext = mediaType.split("/")[1] ?? "jpg";
  return `${userId}/${uuid}.${ext}`;
}

/**
 * Collection identity for a scanned toy. Mirrors the `name_key` / `brand_key`
 * generated columns in migration 0002 — keep the two in sync.
 * Returns null when the toy has no usable name, in which case it must not be
 * added to the collection.
 */
export function toyIdentity(
  name: unknown,
  brand: unknown,
):
  | { name: string; brand: string | null; nameKey: string; brandKey: string }
  | null {
  const n = typeof name === "string" ? name.trim() : "";
  if (n === "") return null;
  const b = typeof brand === "string" ? brand.trim() : "";
  return {
    name: n,
    brand: b === "" ? null : b,
    nameKey: n.toLowerCase(),
    brandKey: b.toLowerCase(),
  };
}
