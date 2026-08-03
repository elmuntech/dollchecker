// Assertions come from `node:assert`, which Deno provides natively — the test
// suite therefore needs no registry download and runs fully offline.
import { deepStrictEqual, throws } from "node:assert/strict";
import { chunk, isConfirmed, storagePaths } from "./utils.ts";

Deno.test("storagePaths qualifies names with the user prefix", () => {
  deepStrictEqual(
    storagePaths("user-1", [
      { name: "a.jpg", id: "1" },
      { name: "b.png", id: "2" },
    ]),
    ["user-1/a.jpg", "user-1/b.png"],
  );
});

Deno.test("storagePaths skips folder placeholders", () => {
  // `list` marks folders with a null id; removing one fails the whole batch.
  deepStrictEqual(
    storagePaths("user-1", [
      { name: "nested", id: null },
      { name: "a.jpg", id: "1" },
    ]),
    ["user-1/a.jpg"],
  );
});

Deno.test("storagePaths ignores unusable entries", () => {
  deepStrictEqual(
    storagePaths("user-1", [{ name: "", id: "1" }, { id: "2" }]),
    [],
  );
});

Deno.test("storagePaths does not double the separator", () => {
  deepStrictEqual(
    storagePaths("user-1/", [{ name: "a.jpg", id: "1" }]),
    ["user-1/a.jpg"],
  );
});

Deno.test("chunk splits into batches", () => {
  deepStrictEqual(chunk([1, 2, 3, 4, 5], 2), [[1, 2], [3, 4], [5]]);
});

Deno.test("chunk of an empty list is empty", () => {
  deepStrictEqual(chunk([], 10), []);
});

Deno.test("chunk rejects a zero size rather than looping forever", () => {
  throws(() => chunk([1], 0), RangeError);
});

Deno.test("isConfirmed requires an explicit true", () => {
  deepStrictEqual(isConfirmed({ confirm: true }), true);
  deepStrictEqual(isConfirmed({ confirm: "true" }), false);
  deepStrictEqual(isConfirmed({}), false);
  deepStrictEqual(isConfirmed(null), false);
  deepStrictEqual(isConfirmed("confirm"), false);
});
