# DollChecker — project overview

A self-contained brief on what this project is, how it is built, what is
finished, and what is deliberately not. Written so someone who has never seen
the repository can review it and say what is missing.

*Status: 2026-08-03. `main` is green (Flutter analyze + test, Deno fmt/check/test,
Android APK build).*

---

## 1. The product

Parents photograph a toy. Claude Vision returns a structured analysis:

- **identification** (name, brand, category, confidence)
- **age-appropriateness**
- **safety** — choking / small parts / magnets / batteries / sharp edges / toxic
  / cords / loud sound, rolled into a red / yellow / green verdict and a 0–100
  score
- **development scores** across ~20 child-development skills
- **educational score** (0–100)
- **play ideas** — 10–20 concrete, age-appropriate activities

The scan is the entry point, not the product. What the scan produces then feeds
five long-lived surfaces: a toy collection, a development dashboard, daily play
missions with streaks, a play-idea feed, and a household-level parents panel.

Markets: international. Ships in **English and Russian** (Uzbek deliberately not
included — the product is aimed outside Uzbekistan).

---

## 2. Stack

| Layer | Choice |
|---|---|
| Mobile | Flutter (iOS + Android), Riverpod v2, go_router |
| Backend | Supabase — Postgres + Auth + Storage + Edge Functions |
| AI | Claude (`claude-sonnet-5`) with forced JSON-schema output |
| Payments | **Polar.sh** (merchant of record) |
| Notifications | `flutter_local_notifications` (device-local, no FCM/APNs) |
| CI | GitHub Actions — analyze, test, deno checks, real Android build |

Scale: ~8.1k lines of Dart across 66 files, ~4.0k lines of Dart tests across 27
test files, ~2.3k lines of TypeScript across 5 Edge Functions, 5 SQL migrations,
256 localized strings × 2 languages.

**No secret ever ships in the client.** The Anthropic key and the Polar token
live only in Edge Function secrets. The client holds the Supabase URL and anon
key, which are public by design; Row-Level Security is what protects data.

---

## 3. Data model

All tables are per-user and protected by RLS keyed on `auth.uid()`.

| Table | What it holds |
|---|---|
| `profiles` | 1:1 with `auth.users`. Tier, scan quota, locale, Polar customer/subscription state. |
| `child_profiles` | Name, birth date. Drives age context and per-child dashboards. |
| `scans` | One analysis event: image path, identification, safety, scores, the raw model response. |
| `toys` | The collection. Repeat scans of the same toy fold into one row. |
| `development_scores` | One row per skill per scan — the aggregation source. |
| `play_ideas` | Ideas produced by the analyzer; the source of daily missions. |
| `daily_missions` | Three missions per child per day, with status. Streaks are derived, never stored. |
| `billing_events` | Polar webhook log; the primary key makes a retried delivery a no-op. |
| `chat_messages` | The follow-up conversation, one thread per scan. |
| `rate_limits` | Fixed-window counters, per user and per IP. Service-role only. |
| `ai_usage` | Token counts per model call — what makes abuse visible before the invoice. |

Three pieces of logic live in SQL because they must not drift:

- `upsert_toy_from_scan` — resolves a scan to a collection entry by
  `(user_id, lower(name), lower(brand))`, so scanning the same toy twice updates
  one row. A toy the model could not name is left out entirely rather than
  collapsing every unnamed toy together.
- `child_skill_summary` — the dashboard aggregate, with an explicit
  `auth.uid()` filter.
- `apply_subscription_state` — the only writer of the tier. Ignores an event
  older than the one already recorded, because Polar guarantees no ordering.
- `consume_scan_quota` — takes one scan from the allowance under a row lock,
  before the model call. The previous read-at-start/write-at-end arrangement let
  a burst of concurrent requests walk through the cap entirely.
- `hit_rate_limit` — a fixed-window counter every function calls per user and
  per IP.

---

## 4. Edge Functions

| Function | JWT | Purpose |
|---|---|---|
| `analyze-toy` | ✅ | Claude Vision proxy. Enforces the monthly free quota, stores the image, persists scan + scores + ideas, folds the toy into the collection. |
| `chat-toy` | ✅ | Follow-up conversation about a scan. **Premium only.** |
| `delete-account` | ✅ | Deletes storage objects, then the auth user (every table cascades). |
| `polar-billing` | ✅ | Returns a hosted checkout URL or a customer-portal URL. |
| `polar-webhook` | ❌ | Polar sends no JWT; a Standard Webhooks signature authenticates it instead. The only writer of `profiles.tier`. |

---

## 5. App surfaces

- **Home** — scan entry point, remaining free scans, recent history, upgrade
  affordance for free accounts.
- **Today** — three daily missions for the selected child, streak, milestones,
  toys due back out of the cupboard.
- **Collection** — one card per toy, search, owned/wishlist filters, per-toy
  scan history.
- **Development** — every scan for a child aggregated into an index, a
  six-domain radar, strengths, gaps, and the skills nothing has measured yet.
- **Play** — every play idea, an idea of the day, favourites, skill filter.
- **Parents panel** — the only household-wide surface: the week's scans /
  missions / active days across all children, a per-child card, a **safety
  review** of owned toys whose latest analysis was not green, and the account
  (plan, children, legal links, delete account).
- **Chat** — per-scan conversation, opened from a stored scan.
- **Paywall**, **Settings** (language, reminders, sign out), **Auth** (sign in,
  sign up, password reset).

### How daily missions work

Missions are assembled from play ideas the analyzer has already produced — no
extra model call. Each morning every stored idea is scored on three signals and
the top three kept, preferring a different toy for each:

1. **Skill gap** — how weak the child is in the skills the idea targets.
2. **Toy rotation** — how long that toy has sat unused, saturating after 30
   days. Completing a mission stamps `last_played_at`, so today's play shapes
   next week's suggestions.
3. **Per-day jitter** — deterministic noise seeded on the idea id and the date,
   so the set is stable all day and different tomorrow.

Streaks are derived from the mission rows rather than stored, so they cannot
drift. A streak survives an untouched today and only breaks once a full day is
missed.

---

## 6. Decisions worth reviewing

Each of these was a judgement call, with the reasoning stated so it can be
challenged.

1. **Chat is Premium-only.** A scan is one bounded model call; a conversation
   has no natural end, so a free tier here is an unmetered bill per user. Free
   accounts get the paywall rather than an error.
2. **Payments through Polar, not the app stores.** Polar is a merchant of
   record — no tax handling, no card data near the app. *Open risk: Apple
   normally requires IAP for digital goods sold inside an iOS app. Android and
   web are fine; iOS needs a decision.*
3. **Reminders are local, not push.** No FCM/APNs account, no server, works
   offline. The cost is that a reminder belongs to one device.
4. **`profiles.tier` is not writable by its owner.** Migration 0001 granted a
   blanket "update your own row" policy, which became a free upgrade the moment
   a tier unlocked features. Column-level grants now allow exactly
   `display_name` and `locale`.
5. **Chat messages are written server-side only.** The client can read and
   delete but not insert: a client that could write an `assistant` row could put
   words in the model's mouth and have them replayed as context.
6. **Sandbox is the default Polar server.** A misspelled setting cannot charge a
   real card.
7. **No price hard-coded in the app.** `PREMIUM_PRICE_LABEL` is optional; the
   checkout page is the authority. A stale number in the app is worse than none.
8. **`android/` and `ios/` are not committed.** Everything they need
   (permissions, deep link, desugaring, iOS usage strings) is applied by
   `tool/configure_platform.py`, which CI runs before building — so the
   configuration cannot rot into an unread checklist.
9. **The limiter fails open.** If the rate-limit table is unreachable, requests
   are allowed. An outage in the limiter taking the product down is a worse
   failure than a window of unlimited requests, and the quota still bounds cost.
10. **Safety framing is deliberately hedged.** The model is instructed never to
   claim a toy is "certified safe", and every response carries a disclaimer that
   this is AI guidance, not a substitute for certifications, packaging warnings
   or recall data.

---

## 7. Testing and CI

- **Dart**: 27 test files. Pure domain logic (skill aggregation, mission
  selection and scoring, streak arithmetic, paging, auth-error classification,
  reminder scheduling, safety ordering) plus widget tests for every screen,
  each with an English and a Russian render.
- **Deno**: pure helpers of every Edge Function — quota rollover, toy identity,
  webhook signature parsing and freshness, subscription extraction, chat history
  sanitation, storage path handling. All offline; no registry download.
- **CI** on every PR: `flutter analyze --fatal-infos`, `flutter test`, ARB JSON
  validation, `deno fmt --check`, `deno check`, `deno test`, and an **Android
  debug APK build** from a freshly generated project (uploaded as an artifact).

What is *not* covered: no integration or end-to-end tests, no golden tests, and
the Edge Function HTTP handlers themselves are untested (only their pure
helpers). Nothing has yet run against a live Supabase project.

---

## 8. Done

| Area | State |
|---|---|
| Scan → analysis → result | ✅ |
| Toy collection, dedup, wishlist | ✅ |
| Development dashboard | ✅ |
| Daily missions, streaks, toy rotation | ✅ |
| Play Coach feed | ✅ |
| Parents panel (household week, safety review, account) | ✅ |
| Auth: sign-in, sign-up + email confirmation, password reset, classified errors | ✅ |
| Account deletion (store requirement) + storage cleanup | ✅ |
| Legal / support links (hidden until published) | ✅ |
| Subscriptions: checkout, customer portal, webhook, paywall | ✅ |
| Daily reminder with permission handling | ✅ |
| Per-scan AI chat | ✅ |
| History, collection and play paged — no list stops at a hidden cap | ✅ |
| Visible errors with retry, signed-URL expiry | ✅ |
| Real Android build in CI + executable platform config | ✅ |
| App icon, application id, display name, release signing config | ✅ |
| Legal documents (privacy, terms, refunds) ready to publish | ✅ |
| Store listings EN/RU, data-safety and content-rating answers, submission checklist | ✅ |
| Tag-driven release workflow producing a signed `.aab` | ✅ |

## 9. Not done — known gaps

**Product**

- No second parent: one account = one user. Both parents cannot share the same
  children.
- No export or sharing of the weekly report (PDF / share sheet).
- No barcode scanning, shopping assistant, or "similar toys" recommendations
  (the V3 ideas: pgvector RAG, semantic search, trends).
- No recall-data source. Safety is AI judgement over a photo, with a disclaimer
  — not a check against official recalls.
- No offline mode. Everything is a live query; a scan in a shop with poor signal
  fails.

**Store submission** — what is left is account-shaped, not code-shaped:
screenshots captured on a device, a feature graphic, the legal placeholders
filled in and published, the upload keystore, and the store accounts themselves.
`store/submission-checklist.md` is the running list.

**Engineering**

- No crash reporting (Sentry) or product analytics — both need external keys.
- No integration/E2E tests; Edge Function handlers untested.
- iOS is unbuilt in CI (needs a macOS runner) and unresolved on IAP.
- `pubspec.lock` is tracked but not yet committed — it needs a resolver run
  (`flutter pub get`, or the `pubspec-lock` CI artifact). Until it exists,
  and while `intl: any` stands, builds re-resolve rather than reproduce.
- Nothing has been deployed or run against real infrastructure yet.

---

## 10. What is waiting on external setup

Tracked in full in `docs/INTEGRATIONS.md` (29 open items). Summary:

1. **Supabase** — `ANTHROPIC_API_KEY`, `supabase db push` for migrations
   0001–0005, deploy five functions (`polar-webhook` with `--no-verify-jwt`),
   add `dollchecker://auth-callback` to Redirect URLs, production SMTP.
2. **Polar** — organization + product, six secrets, webhook endpoint subscribed
   to `subscription.*` and `order.paid`, sandbox → production at launch.
3. **Legal** — privacy policy, terms, support email, refund policy.
4. **Stores** — Apple ($99/yr) and Google Play ($25) accounts, app icon, signing
   keys, data-safety answers.

Until these exist the app still runs: `polar-billing` answers `503` and the
paywall says premium is not open yet; legal rows stay hidden rather than linking
nowhere.

---

## 11. Questions worth an outside opinion

1. **iOS payments.** Is web checkout outside the app acceptable, or does this
   need StoreKit/RevenueCat alongside Polar before submission?
2. **Free-tier shape.** 10 scans/month free, chat premium-only — too generous,
   too mean, or the wrong axis entirely?
3. **Is the safety framing defensible?** AI judgement over a photo, hedged
   language, disclaimers everywhere, no recall data. Is that enough for a
   product parents will trust with a safety question — and is there liability
   exposure that the disclaimer does not cover?
4. **Retention.** The loop is: scan → missions → streak → daily reminder. Is
   there a reason a parent opens this in week three?
5. **What would you cut?** The app has six surfaces before a single user has
   tried it.
