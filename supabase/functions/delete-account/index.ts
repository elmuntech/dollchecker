// delete-account — permanently deletes the caller's account and all their data.
//
// Required by both app stores (Apple guideline 5.1.1(v), Google Play data
// deletion): an account created in the app must be deletable from the app.
//
// Order matters. Storage objects are removed first, because once the auth user
// is gone there is no longer a caller to attribute the orphans to. Database
// rows need no explicit deletes: every user-owned table references
// `auth.users (id) on delete cascade` (migrations 0001 and 0003).
//
// Deploy:  supabase functions deploy delete-account

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import { chunk, isConfirmed, STORAGE_BATCH, storagePaths } from "./utils.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const BUCKET = "toy-images";
/** Page size for listing the user's stored images. */
const LIST_PAGE = 100;
/** Upper bound on listing rounds — 20k images is far beyond any real account. */
const MAX_PAGES = 200;

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const jwt = authHeader.replace(/^Bearer\s+/i, "");
    if (!jwt) return json(401, { error: "missing_token" });

    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user }, error: authErr } = await userClient.auth.getUser(
      jwt,
    );
    if (authErr || !user) return json(401, { error: "invalid_token" });

    const body = await req.json().catch(() => null);
    if (!isConfirmed(body)) {
      return json(400, { error: "confirmation_required" });
    }

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    // --- 1. Storage ------------------------------------------------------
    // Images live under `{user_id}/…`; page through the prefix and delete in
    // batches. A storage failure is logged but must not abort the deletion —
    // the user asked for their account to be gone.
    // Deleting shrinks the listing, so every page is read from the start
    // rather than at a moving offset. MAX_PAGES bounds the loop so a storage
    // error can never spin it forever.
    let removed = 0;
    for (let page = 0; page < MAX_PAGES; page++) {
      const { data: entries, error: listErr } = await admin.storage
        .from(BUCKET)
        .list(user.id, { limit: LIST_PAGE });
      if (listErr) {
        console.error("storage list failed", listErr.message);
        break;
      }
      if (!entries || entries.length === 0) break;

      const paths = storagePaths(user.id, entries);
      // Only folder placeholders left — nothing removable, so stop.
      if (paths.length === 0) break;

      let failed = false;
      for (const batch of chunk(paths, STORAGE_BATCH)) {
        const { error: removeErr } = await admin.storage
          .from(BUCKET)
          .remove(batch);
        if (removeErr) {
          console.error("storage remove failed", removeErr.message);
          failed = true;
        } else {
          removed += batch.length;
        }
      }
      if (failed || entries.length < LIST_PAGE) break;
    }

    // --- 2. Auth user (cascades every table) ------------------------------
    const { error: deleteErr } = await admin.auth.admin.deleteUser(user.id);
    if (deleteErr) {
      console.error("user delete failed", deleteErr.message);
      return json(500, { error: "delete_failed" });
    }

    return json(200, { deleted: true, images_removed: removed });
  } catch (e) {
    console.error("delete-account failed", e);
    return json(500, { error: "internal_error" });
  }
});
