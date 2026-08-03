# DollChecker — Toy Analyzer

An AI-powered parenting assistant. Parents scan any toy with the phone camera and
Claude Vision returns a full analysis: identification, age-appropriateness, **safety**
(choking / small parts / magnets / batteries / sharp edges / toxic → Red/Yellow/Green),
**development scores** across ~20 child-development skills, an **educational score (0–100)**,
and an **AI Play Coach** with personalized play ideas.

The scan is only the entry point — the product is a long-term toy-intelligence and
child-development assistant.

## Stack

| Layer | Choice |
|-------|--------|
| Mobile | **Flutter** (iOS + Android) — `app/` |
| State | Riverpod v2 |
| Backend | **Supabase** — Postgres + Auth + Storage — `supabase/` |
| AI proxy | Supabase **Edge Function** `analyze-toy` (Deno/TS) holding the Anthropic key |
| AI | **Claude vision** (`claude-sonnet-5`), structured JSON output |
| Languages | English + Russian |

The Anthropic API key never ships in the client — it lives only in the Edge Function secrets.

## Repository layout

```
app/                      Flutter application
  lib/
    core/                 config, domain (skill keys/groups), router, theme, supabase
    l10n/                 app_en.arb, app_ru.arb
    features/
      auth, child_profile, onboarding
      scan, history           camera → analysis → result
      collection              toy collection (grid, detail, wishlist)
      missions                daily missions, streaks, toy rotation
      development             skill dashboard (radar, strengths, gaps)
      parents                 parents panel (household week, safety review, account)
      play                    Play Coach feed + favorites
      profile                 subscription tier and scan quota
      shell                   bottom-navigation shell
    shared/widgets/       safety badge, score gauge, skill bar
  test/                   unit + widget tests
supabase/
  migrations/0001_init.sql                    schema + RLS + storage bucket
  migrations/0002_v1_collection_dashboard.sql toy identity, aggregates, RPCs
  migrations/0003_daily_missions.sql          daily missions + toy rotation
  functions/analyze-toy/index.ts              Claude vision proxy
  functions/analyze-toy/utils.ts              pure helpers (quota, toy identity)
  functions/delete-account/index.ts           account + storage deletion (store requirement)
docs/INTEGRATIONS.md      third-party setup still to be wired (keys, URLs, store accounts)
.github/workflows/ci.yml  analyze + test, Flutter and Deno
```

## Getting started

### 1. Supabase

```bash
# Install the Supabase CLI, then from repo root:
supabase login
supabase link --project-ref <your-project-ref>
supabase db push                       # applies everything in migrations/

# Set the Anthropic key as an Edge Function secret (never in the client):
supabase secrets set ANTHROPIC_API_KEY=sk-ant-...

# Deploy the functions:
supabase functions deploy analyze-toy
supabase functions deploy delete-account
```

Create the `toy-images` storage bucket (private) — the migration adds it, or create it in the
dashboard if you prefer.

### 2. Flutter app

```bash
cd app
# Set your public Supabase values (URL + anon key). app/.env holds placeholders:
#   SUPABASE_URL=...   SUPABASE_ANON_KEY=...
$EDITOR .env

# Generate the platform folders (android/ ios/), which are not committed:
flutter create --platforms=android,ios --project-name dollchecker .

flutter pub get        # also runs gen-l10n (generate: true in pubspec)
flutter run
```

Models are hand-written and state is manual Riverpod, so **no `build_runner` is needed** —
only the official `gen-l10n` (runs automatically on `flutter pub get` / `flutter run`).

`SUPABASE_ANON_KEY` is a public client key — safe to ship. Row-Level Security protects data.
`.env` also carries `AUTH_REDIRECT_URL` (the deep link email confirmations and password
resets return to) and the optional `PRIVACY_URL` / `TERMS_URL` / `SUPPORT_EMAIL` links —
the parents panel hides whichever of those is still blank.

Everything that needs an external account, key or published URL is tracked in
[`docs/INTEGRATIONS.md`](docs/INTEGRATIONS.md).

## App flow

Onboarding → create a child profile → scan a toy (camera or gallery) → "Analyzing…" →
result screen (safety badge, scores, play ideas). Each scan then feeds four surfaces,
reachable from the bottom navigation bar:

| Tab | What it shows |
|-----|---------------|
| **Home** | Scan entry point, remaining free scans, recent history |
| **Today** | Three daily missions for the selected child, streak and milestones, and the toys due to come back out |
| **Collection** | One card per toy — repeat scans of the same toy fold into a single entry. Search, owned/wishlist filters, per-toy scan history |
| **Development** | Every scan for the selected child aggregated into a development index, a six-domain radar, top strengths, lowest-scoring gaps, and the skills nothing has measured yet |
| **Play** | All play ideas the analyzer has produced, with an idea of the day, favorites, and a skill filter |

Households with several children switch child from the app bar; the choice drives the
dashboard, the Play Coach feed, and the age context sent to the analyzer.

### The parents panel

Every tab above answers "what should we play next?" for one child. The **parents panel**
— the person icon in the Home app bar, at `/parents` — is the only surface that steps
back and looks at the household:

- **This week at home** — scans, missions completed and active days across all children
  over the last 7 days, with an explicit "nothing happened this week" line.
- **Each child** — one card per child: scans, missions done out of planned, the
  development index, and a seven-dot strip of the days a mission was completed. Tapping
  a card makes that child active and opens their development dashboard.
- **Safety review** — the toys you *own* whose latest analysis came back red or yellow,
  worst first, then most recently scanned. Wishlist entries are left out: a toy that is
  not in the house cannot hurt anyone.
- **Account** — plan and remaining scans, child profiles, and app settings.

The week is assembled from two household-wide queries (scans and missions) plus one
development aggregate per child. Both queries deliberately over-fetch by a few hours,
because a date bound in UTC cannot express a local calendar day — `HouseholdReport.build`
trims the window to local days, so a scan at 23:00 counts for the day the parent made it.

### Account lifecycle

Sign-in is email + password. The flow covers what a real account needs:

- **Forgot password** emails a recovery link. Opening it on the device puts the app in
  recovery mode — the router pins the user to "set a new password" until they either
  save one or abandon the flow, which signs them out rather than dropping a
  password-less session into the app.
- **Sign-up** handles both project settings: if email confirmation is on, the form is
  replaced by "open the link we sent to <address>"; if it is off, the user goes straight in.
- **Errors are classified, not echoed.** `AuthFailure` maps Supabase's English strings to
  eight actionable cases, so a Russian user reads a Russian sentence that says what to do.
- **Delete account** (parents panel → Account) removes the storage objects first, then the
  `auth.users` row — every table cascades from it. Both stores require this to exist
  inside the app.

### How daily missions work

Missions are assembled from the play ideas the analyzer has already produced —
no extra model call. Each morning the app scores every stored idea on three
signals and keeps the top three, preferring a different toy for each:

- **Skill gap** — how weak the child is in the skills the idea targets, from the
  development dashboard's aggregate.
- **Toy rotation** — how long the toy behind the idea has sat unused, saturating
  after 30 days. Completing a mission stamps the toy's `last_played_at`, so
  today's play shapes next week's suggestions.
- **Per-day jitter** — deterministic noise seeded on the idea id and the date,
  so the set is identical all day but different tomorrow.

Streaks are derived from the mission rows rather than stored, so they cannot
drift out of sync. A streak survives an untouched today and only breaks once a
full day is missed.

### How toys are deduplicated

`upsert_toy_from_scan` (migration 0002) keys a collection entry on
`(user_id, lower(name), lower(brand))`, so scanning the same toy twice updates one row
instead of creating another. A toy the model could not name is left out of the
collection entirely rather than collapsing every unnamed toy into one entry.

## Tests

```bash
cd app && flutter test          # unit + widget tests
deno test supabase/functions/analyze-toy/   # Edge Function helpers (no network needed)
```

CI runs `flutter analyze --fatal-infos`, `flutter test`, `deno fmt --check`,
`deno check` and `deno test` on every pull request.

## Roadmap

- **V1** — ✅ toy collection, ✅ development dashboard, ✅ Play Coach surface; subscriptions (RevenueCat) and offline history still open.
- **V2** — ✅ daily missions + gamification, ✅ toy rotation, ✅ parents panel; AI chat still open.
- **V3** — pgvector RAG (similar toys, semantic search), shopping assistant, trends & reports.

## Safety disclaimer

DollChecker provides **AI-generated guidance only**. It is **not** a substitute for official
safety certifications, packaging warnings, or recall data. Always supervise young children and
verify hazards yourself.
