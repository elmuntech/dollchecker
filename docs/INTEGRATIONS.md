# Third-party integrations — what still needs wiring

Everything in this file is **external setup**: an account to create, a key to
issue, a URL to publish, or a console setting to flip. The code that consumes
each item is already written (or is being written) — nothing here blocks
development, and each row can be filled in at the end in one pass.

Legend: **Owner** = who can do it (account holder). **Blocks** = what stays
non-functional until it is done.

---

## 1. Supabase (already in use)

| Item | Where it goes | Blocks | Status |
|------|---------------|--------|--------|
| Project ref + URL + anon key | `app/.env` (`SUPABASE_URL`, `SUPABASE_ANON_KEY`) | The whole app | ⬜ |
| `ANTHROPIC_API_KEY` | `supabase secrets set` | Toy analysis, AI chat | ⬜ |
| `supabase db push` for migrations `0001`–`0005` | Supabase project | Everything | ⬜ |
| Deploy `analyze-toy`, `chat-toy`, `delete-account`, `polar-billing` | `supabase functions deploy <name>` | Scanning, chat, account deletion, checkout | ⬜ |
| Deploy `polar-webhook` **with `--no-verify-jwt`** | `supabase functions deploy polar-webhook --no-verify-jwt` | Tier upgrades (Polar sends no JWT; the signature check authenticates it) | ⬜ |
| Auth → URL configuration → **Redirect URLs**: add `dollchecker://auth-callback` | Supabase dashboard | Password-reset deep link | ⬜ |
| Auth → Email templates: confirm-signup and reset-password wording/branding | Supabase dashboard | Nice-to-have | ⬜ |
| Auth → "Confirm email" on/off decision | Supabase dashboard | Sign-up flow copy (the app handles both) | ⬜ |
| SMTP sender (custom domain) — Supabase's built-in mailer is rate-limited and not for production | Supabase dashboard → Auth → SMTP | Password reset + confirmation emails at volume | ⬜ |

## 2. Polar.sh (payments)

The code is complete: `polar-billing` creates checkouts and portal sessions,
`polar-webhook` is the only writer of the tier. Until the secrets below exist,
`polar-billing` answers `503` and the paywall says premium is not open yet — the
app stays fully usable.

| Item | Where it goes | Blocks | Status |
|------|---------------|--------|--------|
| Polar organization + product ("DollChecker Premium", monthly and/or yearly price) | Polar dashboard | Paywall | ⬜ |
| `POLAR_ACCESS_TOKEN` (organization access token, server-side only) | `supabase secrets set` | Checkout + portal | ⬜ |
| `POLAR_PRODUCT_ID` | `supabase secrets set` | Checkout | ⬜ |
| `POLAR_WEBHOOK_SECRET` (`whsec_…`) | `supabase secrets set` | Tier upgrades landing in the DB | ⬜ |
| `POLAR_SERVER=sandbox` → `production` at launch | `supabase secrets set` | Real charges (defaults to sandbox, deliberately) | ⬜ |
| `POLAR_SUCCESS_URL=dollchecker://checkout-done` | `supabase secrets set` | Returning to the app after paying | ⬜ |
| Webhook endpoint in Polar → `https://<project>.supabase.co/functions/v1/polar-webhook`, events `subscription.*` and `order.paid` | Polar dashboard | Tier upgrades | ⬜ |
| `PREMIUM_PRICE_LABEL` (optional, e.g. `$4.99 / month`) | `app/.env` | Only the price line on the paywall; blank hides it | ⬜ |

**Verify the two API shapes when wiring this up.** `polar-billing` posts to
`/v1/checkouts/` and `/v1/customer-sessions/`, and `polar-webhook` reads
`data.status`, `data.customer_id`, `data.current_period_end` and
`metadata.user_id`. Those are isolated in `utils.ts` in each function and covered
by tests, so a field rename is a small edit — but check them against the current
Polar docs rather than assuming.

> Note: Polar is a merchant of record, so no separate tax/VAT setup is needed.
> App-store rules still apply to **iOS**: digital goods sold inside an iOS app
> normally require Apple IAP. Decide before submitting: either (a) web-only
> checkout opened outside the app, or (b) add StoreKit/RevenueCat for iOS.
> This affects only iOS; Android and web can use Polar directly.

## 3. Legal / store

| Item | Where it goes | Blocks | Status |
|------|---------------|--------|--------|
| Privacy policy URL | `app/.env` → `PRIVACY_URL` | Store submission (mandatory) | ⬜ |
| Terms of service URL | `app/.env` → `TERMS_URL` | Store submission | ⬜ |
| Support / contact email | `app/.env` → `SUPPORT_EMAIL` | Store submission | ⬜ |
| Refund / cancellation policy page (Polar requires one) | Polar dashboard + terms page | Polar account approval | ⬜ |
| Apple Developer account ($99/yr), App Store Connect app record | Apple | iOS release | ⬜ |
| Google Play Console account ($25 once) | Google | Android release | ⬜ |
| App icon + splash source assets (1024×1024 PNG) | `app/assets/` | Store submission | ⬜ |
| Data-safety / privacy-nutrition answers (camera, photos, email, analytics) | Store consoles | Store submission | ⬜ |

## 4. Platform config (in the generated `android/` + `ios/` folders)

These folders are not committed (`flutter create` regenerates them), so each
item has to be applied once when the release project is set up.

| Item | Where | Blocks |
|------|-------|--------|
| Deep-link scheme `dollchecker://` | `AndroidManifest.xml` intent-filter + iOS `CFBundleURLTypes` | Password reset, checkout return |
| `<queries><intent>` for `https` | `AndroidManifest.xml` | Opening privacy/terms links on Android 11+ |
| Camera + photo-library usage strings | `Info.plist` (`NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`) | iOS scanning (app crashes without them) |
| `POST_NOTIFICATIONS` permission + `SCHEDULE_EXACT_ALARM` not needed (inexact scheduling is used deliberately) | `AndroidManifest.xml` | Daily reminders on Android 13+ |
| Notification icon `@mipmap/ic_launcher` present (default from `flutter create`) | `android/app/src/main/res` | Android reminder rendering |
| Notification capability + `UNUserNotificationCenter` delegate (added by the plugin) | Xcode | iOS reminders |
| Release signing (keystore, provisioning profiles) | `android/key.properties`, Xcode | Any release build |

## 5. Optional / later

| Item | Purpose | Status |
|------|---------|--------|
| Sentry DSN | Crash reporting | ⬜ |
| Analytics key (PostHog / Firebase) | Funnel + retention | ⬜ |
| FCM / APNs keys | Remote push only — the shipped daily reminder is local and needs no keys | ⬜ |
| Toy recall data source | Real recall checks instead of AI-only guidance | ⬜ |
