// analyze-toy — Claude Vision proxy.
//
// Responsibilities (all server-side, so the Anthropic key never ships in the app):
//   1. Verify the caller's Supabase JWT.
//   2. Enforce a per-user monthly scan quota (free tier).
//   3. Store the toy image in the private `toy-images` bucket.
//   4. Call Claude Vision with a forced JSON schema (guaranteed valid output).
//   5. Persist scan + development_scores + play_ideas.
//   6. Return the analysis to the client.
//
// Deploy:  supabase functions deploy analyze-toy
// Secret:  supabase secrets set ANTHROPIC_API_KEY=sk-ant-...

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import { ANALYSIS_SCHEMA } from "./schema.ts";
import { buildUserText, SYSTEM_PROMPT } from "./prompt.ts";

const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const MODEL = "claude-sonnet-5";
const FREE_MONTHLY_SCANS = 10;
const ALLOWED_MEDIA = ["image/jpeg", "image/png", "image/webp"];

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

  try {
    // --- 1. Auth ----------------------------------------------------------
    const authHeader = req.headers.get("Authorization") ?? "";
    const jwt = authHeader.replace(/^Bearer\s+/i, "");
    if (!jwt) return json(401, { error: "missing_token" });

    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user }, error: authErr } = await userClient.auth.getUser(jwt);
    if (authErr || !user) return json(401, { error: "invalid_token" });

    // Service-role client for privileged writes (bypasses RLS).
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    // --- 2. Parse & validate input ---------------------------------------
    const body = await req.json().catch(() => null);
    if (!body?.image_base64 || typeof body.image_base64 !== "string") {
      return json(400, { error: "image_base64_required" });
    }
    const mediaType: string = body.media_type ?? "image/jpeg";
    if (!ALLOWED_MEDIA.includes(mediaType)) {
      return json(400, { error: "unsupported_media_type" });
    }
    const locale: string = body.locale === "ru" ? "ru" : "en";
    const childProfileId: string | null = body.child_profile_id ?? null;

    // --- 3. Quota ---------------------------------------------------------
    const { data: profile } = await admin
      .from("profiles")
      .select("tier, scan_quota_used, quota_reset_at")
      .eq("id", user.id)
      .single();

    let used = profile?.scan_quota_used ?? 0;
    const resetAt = profile?.quota_reset_at ? new Date(profile.quota_reset_at) : null;
    if (resetAt && Date.now() >= resetAt.getTime()) {
      used = 0; // window rolled over
    }
    if ((profile?.tier ?? "free") === "free" && used >= FREE_MONTHLY_SCANS) {
      return json(429, { error: "quota_exceeded", limit: FREE_MONTHLY_SCANS });
    }

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
    const ext = mediaType.split("/")[1];
    const objectPath = `${user.id}/${crypto.randomUUID()}.${ext}`;
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
          { type: "text", text: SYSTEM_PROMPT, cache_control: { type: "ephemeral" } },
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
                source: { type: "base64", media_type: mediaType, data: body.image_base64 },
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
      return json(502, { error: "analysis_failed", status: anthropicRes.status });
    }

    const completion = await anthropicRes.json();
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

    // --- 8. Bump quota ----------------------------------------------------
    await admin
      .from("profiles")
      .update({
        scan_quota_used: used + 1,
        quota_reset_at:
          resetAt && Date.now() >= resetAt.getTime()
            ? nextMonthStart()
            : profile?.quota_reset_at,
      })
      .eq("id", user.id);

    return json(200, { scan_id: scan.id, image_path: imageUrl, analysis });
  } catch (e) {
    console.error("unhandled", e);
    return json(500, { error: "internal_error" });
  }
});

// --- helpers ------------------------------------------------------------
function base64ToBytes(b64: string): Uint8Array {
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

function monthsSince(dateStr: string): number {
  const d = new Date(dateStr);
  const now = new Date();
  return Math.max(
    0,
    (now.getFullYear() - d.getFullYear()) * 12 + (now.getMonth() - d.getMonth()),
  );
}

function nextMonthStart(): string {
  const d = new Date();
  return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + 1, 1)).toISOString();
}

// --- types (mirror schema.ts) ------------------------------------------
interface Analysis {
  identification: Record<string, unknown>;
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
