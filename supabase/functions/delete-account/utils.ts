// Pure helpers for the delete-account function.
//
// Kept free of Deno/Supabase imports so they can be unit-tested with
// `deno test` without any network or environment setup.

/** How many objects one storage `remove` call may carry. */
export const STORAGE_BATCH = 100;

export interface StorageEntry {
  name?: unknown;
  id?: unknown;
}

/**
 * Full object paths for a user's storage listing.
 *
 * `storage.list(userId)` returns names relative to the prefix, so each one has
 * to be re-qualified before `remove`. Folder placeholders come back with a null
 * `id` and are skipped — passing one to `remove` fails the whole batch.
 */
export function storagePaths(
  userId: string,
  entries: readonly StorageEntry[],
): string[] {
  const prefix = userId.replace(/\/+$/, "");
  return entries
    .filter((e) => e.id !== null && typeof e.name === "string" && e.name !== "")
    .map((e) => `${prefix}/${e.name as string}`);
}

/** Splits `items` into chunks of at most `size`, never emitting an empty one. */
export function chunk<T>(items: readonly T[], size: number): T[][] {
  if (size < 1) throw new RangeError("size must be >= 1");
  const out: T[][] = [];
  for (let i = 0; i < items.length; i += size) {
    out.push(items.slice(i, i + size));
  }
  return out;
}

/**
 * Whether a deletion request carries the confirmation the client is required
 * to send. A stray POST from a replayed token must not wipe an account, so the
 * body has to say so explicitly.
 */
export function isConfirmed(body: unknown): boolean {
  if (typeof body !== "object" || body === null) return false;
  return (body as Record<string, unknown>).confirm === true;
}
