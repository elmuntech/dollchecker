// Assertions come from `node:assert`, which Deno provides natively — the test
// suite therefore needs no registry download and runs fully offline.
import { deepStrictEqual, notDeepStrictEqual } from "node:assert/strict";
import {
  base64ByteLength,
  base64ToBytes,
  evaluateQuota,
  FREE_MONTHLY_SCANS,
  isAllowedMedia,
  monthsSince,
  nextMonthStart,
  normalizeLocale,
  toyIdentity,
  toyImagePath,
} from "./utils.ts";
import { SKILL_KEYS } from "./schema.ts";

Deno.test("isAllowedMedia accepts only the three supported image types", () => {
  deepStrictEqual(isAllowedMedia("image/jpeg"), true);
  deepStrictEqual(isAllowedMedia("image/png"), true);
  deepStrictEqual(isAllowedMedia("image/webp"), true);
  deepStrictEqual(isAllowedMedia("image/gif"), false);
  deepStrictEqual(isAllowedMedia("application/pdf"), false);
  deepStrictEqual(isAllowedMedia(null), false);
  deepStrictEqual(isAllowedMedia(42), false);
});

Deno.test("normalizeLocale falls back to English", () => {
  deepStrictEqual(normalizeLocale("ru"), "ru");
  deepStrictEqual(normalizeLocale("en"), "en");
  deepStrictEqual(normalizeLocale("uz"), "en");
  deepStrictEqual(normalizeLocale(undefined), "en");
});

Deno.test("base64ToBytes round-trips binary data", () => {
  const original = new Uint8Array([0, 1, 127, 128, 255, 42]);
  const b64 = btoa(String.fromCharCode(...original));
  deepStrictEqual(Array.from(base64ToBytes(b64)), Array.from(original));
});

Deno.test("base64ByteLength matches the decoded length", () => {
  for (const size of [0, 1, 2, 3, 10, 999]) {
    const bytes = new Uint8Array(size).fill(7);
    const b64 = btoa(String.fromCharCode(...bytes));
    deepStrictEqual(base64ByteLength(b64), size, `size ${size}`);
  }
});

Deno.test("monthsSince counts whole months only", () => {
  const now = new Date("2026-07-26T12:00:00Z");
  deepStrictEqual(monthsSince("2025-07-26", now), 12);
  deepStrictEqual(monthsSince("2026-01-26", now), 6);
  // Birthday later this month — the month is not complete yet.
  deepStrictEqual(monthsSince("2026-01-27", now), 5);
  // Future dates clamp at zero rather than going negative.
  deepStrictEqual(monthsSince("2027-01-01", now), 0);
  deepStrictEqual(monthsSince("not-a-date", now), 0);
});

Deno.test("nextMonthStart rolls the year over in December", () => {
  deepStrictEqual(
    nextMonthStart(new Date("2026-12-15T00:00:00Z")),
    "2027-01-01T00:00:00.000Z",
  );
  deepStrictEqual(
    nextMonthStart(new Date("2026-07-01T00:00:00Z")),
    "2026-08-01T00:00:00.000Z",
  );
});

Deno.test("evaluateQuota blocks a free account at the limit", () => {
  const now = new Date("2026-07-26T00:00:00Z");
  const q = evaluateQuota({
    tier: "free",
    scanQuotaUsed: FREE_MONTHLY_SCANS,
    quotaResetAt: "2026-08-01T00:00:00Z",
  }, now);
  deepStrictEqual(q.exceeded, true);
  deepStrictEqual(q.remaining, 0);
  deepStrictEqual(q.limit, FREE_MONTHLY_SCANS);
});

Deno.test("evaluateQuota leaves headroom below the limit", () => {
  const now = new Date("2026-07-26T00:00:00Z");
  const q = evaluateQuota({
    tier: "free",
    scanQuotaUsed: 3,
    quotaResetAt: "2026-08-01T00:00:00Z",
  }, now);
  deepStrictEqual(q.exceeded, false);
  deepStrictEqual(q.used, 3);
  deepStrictEqual(q.remaining, FREE_MONTHLY_SCANS - 3);
});

Deno.test("evaluateQuota resets usage once the window has elapsed", () => {
  const now = new Date("2026-08-02T00:00:00Z");
  const q = evaluateQuota({
    tier: "free",
    scanQuotaUsed: 99,
    quotaResetAt: "2026-08-01T00:00:00Z",
  }, now);
  deepStrictEqual(q.rolledOver, true);
  deepStrictEqual(q.used, 0);
  deepStrictEqual(q.exceeded, false);
});

Deno.test("evaluateQuota treats premium as unlimited", () => {
  const q = evaluateQuota({
    tier: "premium",
    scanQuotaUsed: 5_000,
    quotaResetAt: "2099-01-01T00:00:00Z",
  }, new Date("2026-07-26T00:00:00Z"));
  deepStrictEqual(q.exceeded, false);
  deepStrictEqual(q.limit, null);
  deepStrictEqual(q.remaining, null);
});

Deno.test("evaluateQuota handles a missing profile row", () => {
  const q = evaluateQuota({}, new Date("2026-07-26T00:00:00Z"));
  deepStrictEqual(q.used, 0);
  deepStrictEqual(q.exceeded, false);
  deepStrictEqual(q.limit, FREE_MONTHLY_SCANS);
});

Deno.test("toyImagePath is namespaced by user id, matching storage RLS", () => {
  const path = toyImagePath("user-1", "image/png", "abc");
  deepStrictEqual(path, "user-1/abc.png");
  deepStrictEqual(path.split("/")[0], "user-1");
  deepStrictEqual(toyImagePath("u", "image/jpeg", "x"), "u/x.jpeg");
});

Deno.test("toyIdentity normalizes case and whitespace", () => {
  const a = toyIdentity("  LEGO Duplo Bricks ", " LEGO ");
  deepStrictEqual(a?.name, "LEGO Duplo Bricks");
  deepStrictEqual(a?.brand, "LEGO");
  deepStrictEqual(a?.nameKey, "lego duplo bricks");
  deepStrictEqual(a?.brandKey, "lego");
});

Deno.test("toyIdentity collapses spelling-identical scans onto one key", () => {
  const first = toyIdentity("Wooden Puzzle", "Melissa & Doug");
  const second = toyIdentity("  wooden puzzle", "melissa & doug  ");
  deepStrictEqual(first?.nameKey, second?.nameKey);
  deepStrictEqual(first?.brandKey, second?.brandKey);
});

Deno.test("toyIdentity keeps different brands apart", () => {
  const a = toyIdentity("Blocks", "Brand A");
  const b = toyIdentity("Blocks", "Brand B");
  notDeepStrictEqual(a?.brandKey, b?.brandKey);
});

Deno.test("toyIdentity rejects unnamed toys so they stay out of the collection", () => {
  deepStrictEqual(toyIdentity("", "LEGO"), null);
  deepStrictEqual(toyIdentity("   ", "LEGO"), null);
  deepStrictEqual(toyIdentity(null, "LEGO"), null);
  deepStrictEqual(toyIdentity(undefined, undefined), null);
});

Deno.test("toyIdentity maps a missing brand to null, not an empty string", () => {
  const t = toyIdentity("Rattle", "");
  deepStrictEqual(t?.brand, null);
  deepStrictEqual(t?.brandKey, "");
});

Deno.test("skill keys stay unique and non-empty", () => {
  deepStrictEqual(new Set(SKILL_KEYS).size, SKILL_KEYS.length);
  deepStrictEqual(SKILL_KEYS.length, 20);
  for (const key of SKILL_KEYS) {
    deepStrictEqual(key, key.trim());
    notDeepStrictEqual(key, "");
  }
});
