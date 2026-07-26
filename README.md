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
      development             skill dashboard (radar, strengths, gaps)
      play                    Play Coach feed + favorites
      profile                 subscription tier and scan quota
      shell                   bottom-navigation shell
    shared/widgets/       safety badge, score gauge, skill bar
  test/                   unit + widget tests
supabase/
  migrations/0001_init.sql                    schema + RLS + storage bucket
  migrations/0002_v1_collection_dashboard.sql toy identity, aggregates, RPCs
  functions/analyze-toy/index.ts              Claude vision proxy
  functions/analyze-toy/utils.ts              pure helpers (quota, toy identity)
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

# Deploy the analyzer:
supabase functions deploy analyze-toy
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

## App flow

Onboarding → create a child profile → scan a toy (camera or gallery) → "Analyzing…" →
result screen (safety badge, scores, play ideas). Each scan then feeds four surfaces,
reachable from the bottom navigation bar:

| Tab | What it shows |
|-----|---------------|
| **Home** | Scan entry point, remaining free scans, recent history |
| **Collection** | One card per toy — repeat scans of the same toy fold into a single entry. Search, owned/wishlist filters, per-toy scan history |
| **Development** | Every scan for the selected child aggregated into a development index, a six-domain radar, top strengths, lowest-scoring gaps, and the skills nothing has measured yet |
| **Play** | All play ideas the analyzer has produced, with an idea of the day, favorites, and a skill filter |

Households with several children switch child from the app bar; the choice drives the
dashboard, the Play Coach feed, and the age context sent to the analyzer.

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
- **V2** — daily missions + gamification, toy rotation, AI chat.
- **V3** — pgvector RAG (similar toys, semantic search), shopping assistant, trends & reports.

## Safety disclaimer

DollChecker provides **AI-generated guidance only**. It is **not** a substitute for official
safety certifications, packaging warnings, or recall data. Always supervise young children and
verify hazards yourself.
