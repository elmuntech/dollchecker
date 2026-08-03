// analyze-toy — Claude Vision proxy.
//
// Responsibilities (all server-side, so the Anthropic key never ships in the app):
//   1. Verify the caller's Supabase JWT, then rate limit it.
//   2. Take one scan from the monthly quota — before the model call, atomically.
//   3. Store the toy image in the private `toy-images` bucket.
//   4. Call Claude Vision with a forced JSON schema (guaranteed valid output).
//   5. Persist scan + development_scores + play_ideas.
//   6. Fold the toy into the user's collection (`upsert_toy_from_scan`).
//   7. Return the analysis — plus the caller's remaining quota — to the client.
//
// Deploy:  supabase functions deploy analyze-toy
// Secret:  supabase secrets set ANTHROPIC_API_KEY=sk-ant-...

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import {
  clientIp,
  enforceRateLimits,
  rateLimitedResponse,
  usageFromCompletion,
} from "../_shared/rate_limit.ts";
import { ANALYSIS_SCHEMA } from "./schema.ts";
import { buildUserText, SYSTEM_PROMPT } from "./prompt.ts";
import {
  base64ByteLength,
  base64ToBytes,
  FREE_MONTHLY_SCANS,
  isAllowedMedia,
  MAX_IMAGE_BYTES,
  monthsSince,
  normalizeLocale,
  toyIdentity,
  toyImagePath,
} from "./utils.ts";

const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const MODEL = "claude-sonnet-5";

// A scan is a slow, expensive call, so the per-minute allowance is small: this
// is about stopping a burst, not about pacing a person taking photos.
const RATE_LIMITS = { perMinute: 6, perHour: 40, perIpMinute: 20 };

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

  // Set once the quota has been taken, so an unexpected failure below can give
  // it back — a crash must not cost the user a scan they never received.
  let reserved = false;
  let reservedFor: string | null = null;

  try {
    // --- 1. Auth ----------------------------------------------------------
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

    // Service-role client for privileged writes (bypasses RLS).
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    // --- 2. Parse & validate input ---------------------------------------
    const body = await req.json().catch(() => null);
    if (!body?.image_base64 || typeof body.image_base64 !== "string") {
      return json(400, { error: "image_base64_required" });
    }
    const mediaType: string = body.media_type ?? "image/jpeg";
    if (!isAllowedMedia(mediaType)) {
      return json(400, { error: "unsupported_media_type" });
    }
    if (base64ByteLength(body.image_base64) > MAX_IMAGE_BYTES) {
      return json(413, {
        error: "image_too_large",
        max_bytes: MAX_IMAGE_BYTES,
      });
    }
    const locale = normalizeLocale(body.locale);
    const childProfileId: string | null = body.child_profile_id ?? null;

    // --- 3. Rate limit ----------------------------------------------------
    const limits = await enforceRateLimits(admin, [
      {
        action: "analyze",
        kind: "user",
        subject: user.id,
        limit: RATE_LIMITS.perMinute,
        windowSeconds: 60,
      },
      {
        action: "analyze",
        kind: "user",
        subject: user.id,
        limit: RATE_LIMITS.perHour,
        windowSeconds: 3600,
      },
      {
        action: "analyze",
        kind: "ip",
        subject: clientIp(req.headers),
        limit: RATE_LIMITS.perIpMinute,
        windowSeconds: 60,
      },
    ]);
    if (!limits.allowed) {
      return rateLimitedResponse(limits.retryAfter, corsHeaders);
    }

    // --- 4. Quota, taken up front ------------------------------------------
    // Reserved before the model call rather than counted after it. The old
    // order read the count at the start and wrote it at the end, so a burst of
    // concurrent requests all saw the same number and all passed a cap none of
    // them respected.
    const { data: quotaRows, error: quotaErr } = await admin.rpc(
      "consume_scan_quota",
      { p_user_id: user.id, p_limit: FREE_MONTHLY_SCANS },
    );
    if (quotaErr) {
      console.error("quota check failed", quotaErr.message);
      return json(500, { error: "quota_unavailable" });
    }
    const quota = Array.isArray(quotaRows) ? quotaRows[0] : quotaRows;
    if (!quota?.allowed) {
      // 402, not 429: this is "upgrade to continue", not "slow down". The two
      // need different words in the app, so they get different statuses.
      return json(402, {
        error: "quota_exceeded",
        limit: FREE_MONTHLY_SCANS,
      });
    }

    reserved = true;
    reservedFor = user.id;

    /** Hands the allowance back when the work it paid for did not happen. */
    const refund = async () => {
      const { error } = await admin.rpc("refund_scan_quota", {
        p_user_id: user.id,
      });
      if (error) console.error("quota refund failed", error.message);
    };

    // --- 4. Child age context --------------------------------------------
    let childAgeMonths: number | null = null;
    if (childProfileId) {
      const { data: child } = await admin
        .from("child_profiles")
        .select("birth_date")
        .eq("id", childProfileId)
        .eq("user_id", user.id)
        .maybeSingle();
      if (child?.birth_date) childAgeMonths = monthsSince(child.birth_date);
    }

    // --- 5. Store image ---------------------------------------------------
    const objectPath = toyImagePath(user.id, mediaType, crypto.randomUUID());
    const bytes = base64ToBytes(body.image_base64);
    const { error: uploadErr } = await admin.storage
      .from("toy-images")
      .upload(objectPath, bytes, { contentType: mediaType, upsert: false });
    if (uploadErr) console.error("upload failed", uploadErr.message);
    const imageUrl = uploadErr ? null : objectPath; // signed URLs generated on read

    // --- 6. Claude Vision call (forced JSON schema) ----------------------
    const anthropicRes = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: MODEL,
        // Large structured output (≤20 skills + up to 20 play ideas, localized).
        // Kept under 16k so a non-streaming request stays within HTTP timeouts.
        max_tokens: 8000,
        system: [
          {
            type: "text",
            text: SYSTEM_PROMPT,
            cache_control: { type: "ephemeral" },
          },
        ],
        output_config: {
          format: { type: "json_schema", schema: ANALYSIS_SCHEMA },
        },
        messages: [
          {
            role: "user",
            content: [
              {
                type: "image",
                source: {
                  type: "base64",
                  media_type: mediaType,
                  data: body.image_base64,
                },
              },
              { type: "text", text: buildUserText({ locale, childAgeMonths }) },
            ],
          },
        ],
      }),
    });

    if (!anthropicRes.ok) {
      const detail = await anthropicRes.text();
      console.error("anthropic error", anthropicRes.status, detail);
      await refund();
      return json(502, {
        error: "analysis_failed",
        status: anthropicRes.status,
      });
    }

    const completion = await anthropicRes.json();

    // Logged before anything else can fail: the tokens were spent whatever
    // happens to the response from here on.
    const usage = usageFromCompletion(completion);
    await admin.from("ai_usage").insert({
      user_id: user.id,
      function_name: "analyze-toy",
      model: MODEL,
      input_tokens: usage.input,
      output_tokens: usage.output,
    });

    if (completion.stop_reason === "refusal") {
      return json(422, { error: "analysis_refused" });
    }
    const textBlock = (completion.content ?? []).find(
      (b: { type: string }) => b.type === "text",
    );
    let analysis: Analysis;
    try {
      analysis = JSON.parse(textBlock?.text ?? "");
    } catch (_e) {
      console.error("json parse failed", textBlock?.text);
      return json(502, { error: "invalid_analysis_json" });
    }
    // A refusal or unparseable answer still cost a model call, so the quota is
    // not refunded past this point — only a failure to reach the model is.

    // --- 7. Persist -------------------------------------------------------
    const { data: scan, error: scanErr } = await admin
      .from("scans")
      .insert({
        user_id: user.id,
        child_profile_id: childProfileId,
        image_url: imageUrl,
        identification: analysis.identification,
        age_min_months: analysis.age_recommendation?.min_months ?? null,
        age_max_months: analysis.age_recommendation?.max_months ?? null,
        age_label: analysis.age_recommendation?.label ?? null,
        materials: analysis.materials ?? [],
        safety_overall: analysis.safety?.overall ?? null,
        safety_score: analysis.safety?.score ?? null,
        safety: analysis.safety ?? null,
        educational_score: analysis.development?.educational_score ?? null,
        raw_response: analysis,
        model_used: MODEL,
        locale,
      })
      .select("id")
      .single();
    if (scanErr || !scan) {
      console.error("scan insert failed", scanErr?.message);
      return json(500, { error: "persist_failed" });
    }

    const skills = analysis.development?.skills ?? [];
    if (skills.length) {
      await admin.from("development_scores").insert(
        skills.map((s) => ({
          scan_id: scan.id,
          user_id: user.id,
          skill: s.skill,
          score: s.score,
          reason: s.reason,
          how_to_maximize: s.how_to_maximize,
        })),
      );
    }

    const ideas = analysis.play_coach?.ideas ?? [];
    if (ideas.length) {
      await admin.from("play_ideas").insert(
        ideas.map((i) => ({
          scan_id: scan.id,
          user_id: user.id,
          title: i.title,
          description: i.description,
          skills_targeted: i.skills_targeted ?? [],
          min_age_months: i.min_age_months ?? null,
          duration_minutes: i.duration_minutes ?? null,
          difficulty: i.difficulty ?? null,
        })),
      );
    }

    // --- 8. Fold into the toy collection ----------------------------------
    // An unidentifiable toy yields a null identity and gets no collection
    // entry, so the grid never fills with nameless duplicates.
    let toyId: string | null = null;
    const identity = toyIdentity(
      analysis.identification?.name,
      analysis.identification?.brand,
    );
    if (identity) {
      const { data: upsertedToyId, error: toyErr } = await admin.rpc(
        "upsert_toy_from_scan",
        {
          p_user_id: user.id,
          p_scan_id: scan.id,
          p_name: identity.name,
          p_brand: identity.brand,
          p_category: analysis.identification?.category ?? null,
          p_image_url: imageUrl,
          p_safety: analysis.safety?.overall ?? null,
          p_educational_score: analysis.development?.educational_score ?? null,
        },
      );
      // A collection failure must not fail the scan — the analysis is the value.
      if (toyErr) console.error("toy upsert failed", toyErr.message);
      else toyId = (upsertedToyId as string | null) ?? null;
    }

    // The quota was already taken in step 4; there is nothing to bump here.
    return json(200, {
      scan_id: scan.id,
      toy_id: toyId,
      image_path: imageUrl,
      analysis,
      quota: {
        limit: quota.tier === "free" ? FREE_MONTHLY_SCANS : null,
        used: quota.used,
        remaining: quota.remaining,
      },
    });
  } catch (e) {
    console.error("unhandled", e);
    if (reserved && reservedFor !== null) {
      const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
      const { error } = await admin.rpc("refund_scan_quota", {
        p_user_id: reservedFor,
      });
      if (error) console.error("quota refund failed", error.message);
    }
    return json(500, { error: "internal_error" });
  }
});

// --- types (mirror schema.ts) ------------------------------------------
interface Analysis {
  identification:
    & { name?: string; brand?: string; category?: string }
    & Record<string, unknown>;
  age_recommendation: { min_months: number; max_months: number; label: string };
  materials: string[];
  safety: { overall: string; score: number } & Record<string, unknown>;
  development: {
    educational_score: number;
    educational_summary: string;
    skills: Array<{
      skill: string;
      score: number;
      reason: string;
      how_to_maximize: string;
    }>;
  };
  play_coach: {
    ideas: Array<{
      title: string;
      description: string;
      skills_targeted: string[];
      min_age_months: number;
      duration_minutes: number;
      difficulty: string;
    }>;
  };
}
