// chat-toy — the follow-up conversation about a scanned toy.
//
// The scan answers "is this toy any good?". This answers everything a parent
// asks next, with the stored analysis as context so the model is not guessing
// about a toy it cannot see.
//
// Premium only. A scan is one bounded call; a conversation has no natural end,
// so a free tier here would be an unmetered model bill per user. The tier check
// is the first thing that happens after auth.
//
// Deploy:  supabase functions deploy chat-toy

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import {
  clientIp,
  enforceRateLimits,
  rateLimitedResponse,
  usageFromCompletion,
} from "../_shared/rate_limit.ts";
import { monthsSince, normalizeLocale } from "../analyze-toy/utils.ts";
import {
  buildUserText,
  childContext,
  HISTORY_LIMIT,
  normalizeQuestion,
  toHistory,
  toyContext,
} from "./utils.ts";

const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const MODEL = "claude-sonnet-5";

// Premium is unlimited in the sense that matters — nobody hits these in normal
// use — but not literally unlimited: a subscription costs a fixed amount and a
// conversation does not, so one paid account should not be able to outspend
// every other one combined.
const RATE_LIMITS = { perMinute: 10, perDay: 100, perIpMinute: 30 };

const SYSTEM_PROMPT =
  `You are DollChecker's play coach: a warm, concrete assistant helping a parent get the most out of a toy they own.

You are given the app's own analysis of that toy and the child's age. Answer the parent's questions about it.

RULES
- Be specific and practical. Prefer one thing to try tonight over a list of generalities.
- Stay within what the analysis supports. If a question needs something the analysis does not cover, say what is unknown instead of inventing detail.
- On safety: you are not a certifying authority. Repeat that this is AI guidance, not a substitute for packaging warnings, certifications or recall data, whenever a safety question comes up.
- No medical diagnosis. If a question is medical or developmental-concern shaped, say plainly that a paediatrician is the right person to ask.
- Keep answers short — a few sentences, or a handful of bullets at most.`;

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

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    const { data: profile } = await admin
      .from("profiles")
      .select("tier")
      .eq("id", user.id)
      .maybeSingle();
    if ((profile?.tier ?? "free") === "free") {
      return json(402, { error: "premium_required" });
    }

    const limits = await enforceRateLimits(admin, [
      {
        action: "chat",
        kind: "user",
        subject: user.id,
        limit: RATE_LIMITS.perMinute,
        windowSeconds: 60,
      },
      {
        action: "chat",
        kind: "user",
        subject: user.id,
        limit: RATE_LIMITS.perDay,
        windowSeconds: 86400,
      },
      {
        action: "chat",
        kind: "ip",
        subject: clientIp(req.headers),
        limit: RATE_LIMITS.perIpMinute,
        windowSeconds: 60,
      },
    ]);
    if (!limits.allowed) {
      return rateLimitedResponse(limits.retryAfter, corsHeaders);
    }

    const body = await req.json().catch(() => null);
    const question = normalizeQuestion(body?.question);
    if (question === null) return json(400, { error: "invalid_question" });
    const scanId: string | null = body?.scan_id ?? null;
    if (!scanId) return json(400, { error: "scan_id_required" });
    const locale = normalizeLocale(body?.locale);

    // Ownership is enforced by the filter, not assumed from the id.
    const { data: scan } = await admin
      .from("scans")
      .select("id, raw_response, child_profile_id")
      .eq("id", scanId)
      .eq("user_id", user.id)
      .maybeSingle();
    if (!scan) return json(404, { error: "scan_not_found" });

    let childAgeMonths: number | null = null;
    if (scan.child_profile_id) {
      const { data: child } = await admin
        .from("child_profiles")
        .select("birth_date")
        .eq("id", scan.child_profile_id)
        .maybeSingle();
      if (child?.birth_date) childAgeMonths = monthsSince(child.birth_date);
    }

    const { data: rows } = await admin
      .from("chat_messages")
      .select("role, content")
      .eq("scan_id", scanId)
      // Newest first is the cheap end of the index; toHistory restores order.
      .order("created_at", { ascending: false })
      .limit(HISTORY_LIMIT);
    const history = toHistory(rows ?? []);

    const anthropicRes = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: MODEL,
        // Short answers by instruction; the cap is a backstop, not a target.
        max_tokens: 1000,
        system: [
          {
            type: "text",
            text: SYSTEM_PROMPT,
            cache_control: { type: "ephemeral" },
          },
        ],
        messages: [
          ...history,
          {
            role: "user",
            content: buildUserText({
              question,
              toy: toyContext(scan.raw_response),
              child: childContext(childAgeMonths),
              locale,
            }),
          },
        ],
      }),
    });

    if (!anthropicRes.ok) {
      const detail = await anthropicRes.text();
      console.error("anthropic error", anthropicRes.status, detail);
      return json(502, { error: "chat_failed" });
    }

    const completion = await anthropicRes.json();

    const usage = usageFromCompletion(completion);
    await admin.from("ai_usage").insert({
      user_id: user.id,
      function_name: "chat-toy",
      model: MODEL,
      input_tokens: usage.input,
      output_tokens: usage.output,
    });

    const reply = (completion.content ?? [])
      .filter((block: { type?: string }) => block.type === "text")
      .map((block: { text?: string }) => block.text ?? "")
      .join("")
      .trim();
    if (reply === "") return json(502, { error: "empty_reply" });

    // Both turns are written server-side: a client that could insert an
    // `assistant` row could put words in the model's mouth and have them read
    // back as context on the next turn.
    await admin.from("chat_messages").insert([
      { user_id: user.id, scan_id: scanId, role: "user", content: question },
      { user_id: user.id, scan_id: scanId, role: "assistant", content: reply },
    ]);

    return json(200, { reply });
  } catch (e) {
    console.error("chat-toy failed", e);
    return json(500, { error: "internal_error" });
  }
});
