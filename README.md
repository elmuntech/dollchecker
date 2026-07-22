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
    core/                 config, router, theme, network, supabase, errors
    l10n/                 app_en.arb, app_ru.arb
    features/             onboarding, auth, child_profile, scan, history, ...
    shared/widgets/       safety badge, score gauge, skill bar
supabase/
  migrations/0001_init.sql        schema + RLS + storage bucket
  functions/analyze-toy/index.ts  Claude vision proxy
```

## Getting started

### 1. Supabase

```bash
# Install the Supabase CLI, then from repo root:
supabase login
supabase link --project-ref <your-project-ref>
supabase db push                       # applies migrations/0001_init.sql

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

## MVP flow

Onboarding → create a child profile → scan a toy (camera or gallery) → "Analyzing…" →
result screen (safety badge, scores, play ideas) → the scan is saved to History.

## Roadmap

- **V1** — toy collection, full development dashboard, Play Coach surface, subscriptions (RevenueCat), offline history.
- **V2** — daily missions + gamification, toy rotation, AI chat.
- **V3** — pgvector RAG (similar toys, semantic search), shopping assistant, trends & reports.

## Safety disclaimer

DollChecker provides **AI-generated guidance only**. It is **not** a substitute for official
safety certifications, packaging warnings, or recall data. Always supervise young children and
verify hazards yourself.
