# Submission checklist

Everything between "the code is ready" and "the app is live", in the order it
has to happen. Items marked **you** need an account or a decision only you can
make; everything else is already done in the repository.

---

## 0. Decisions to make first — they cannot be undone

- [ ] **you** — **Application ID.** Default is `com.dollchecker.app`. It is
      permanent on both stores after the first upload. To change it:
      `python3 tool/configure_platform.py app --app-id=your.id.here`, and change
      the default in `tool/configure_platform.py` so it does not revert.
- [ ] **you** — **Legal entity.** Who is publishing: a person or a company? It
      goes on both store listings, in the legal documents, and in the Polar
      account. Play requires a verified D-U-N-S number for organisations.
- [x] **iOS payments — decided: (b), ship iOS without the subscription.**
      Apple requires In-App Purchase for digital goods unlocked inside the app
      (guideline 3.1.1) and forbids steering the user to an outside purchase
      (3.1.3), which rules out both the checkout button *and* the "manage
      subscription" link. So the iOS build shows no purchase path at all:
      `kAllowIosCheckout = false` in
      `app/lib/core/config/store_billing.dart`, and that one constant is the
      only thing that decides. Premium bought on Android or the web still
      works everywhere — the tier comes from the server.

      This is a judgement about review risk, not legal advice. To change it:
      set the constant to `true` and submit with the web checkout, or add
      StoreKit/RevenueCat and gate on the platform there instead. **Android
      and web are unaffected either way.**

## 1. Backend live

- [ ] `supabase link` and `supabase db push` — migrations `0001`–`0006`
- [ ] `supabase secrets set ANTHROPIC_API_KEY=…`
- [ ] Deploy: `analyze-toy`, `chat-toy`, `delete-account`, `polar-billing`
- [ ] Deploy `polar-webhook` **with `--no-verify-jwt`**
- [ ] Auth → URL configuration → Redirect URLs: add `dollchecker://auth-callback`
- [ ] Auth → SMTP: a real sender (the built-in one is rate-limited and not for
      production — password resets will silently fail at volume)
- [ ] Confirm the `toy-images` bucket exists and is **private**
- [ ] Smoke test with a real account: scan → result → collection → mission →
      chat → delete account

## 2. Payments live

- [ ] Polar organization created and verified
- [ ] Product "DollChecker Premium" with a monthly (and optionally yearly) price
- [ ] Secrets set: `POLAR_ACCESS_TOKEN`, `POLAR_PRODUCT_ID`,
      `POLAR_WEBHOOK_SECRET`, `POLAR_SERVER=sandbox`, `POLAR_SUCCESS_URL`
- [ ] Webhook endpoint added in Polar → `…/functions/v1/polar-webhook`,
      subscribed to `subscription.*` and `order.paid`
- [ ] **Test in sandbox**: pay → webhook arrives → tier flips to premium → chat
      unlocks → cancel in the portal → tier returns to free
- [ ] Only then: `POLAR_SERVER=production`

## 3. Legal pages published

- [ ] Every `{{PLACEHOLDER}}` in `docs/legal/*.md` replaced
- [ ] Reviewed by a lawyer
- [ ] Published (GitHub Pages is enough — see `docs/legal/README.md`)
- [ ] URLs in `app/.env` **and** in the repository secrets used by the release
      workflow

## 4. Build

- [ ] Upload keystore generated and **backed up somewhere you will still have in
      three years** — losing it means never updating the app again:
      ```
      keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA \
        -keysize 2048 -validity 10000 -alias upload
      ```
- [ ] Repository secrets set (see `docs/RELEASING.md`)
- [ ] `git tag v1.0.0 && git push origin v1.0.0` → the Release workflow produces
      a signed `.aab` and `.apk`
- [ ] Install the APK on a real phone and use it for a day

## 5. Store listings

- [ ] Text from `store/listing-en.md` and `store/listing-ru.md`
- [ ] **you** — six screenshots per language, captured on a device
      (the list is in `listing-en.md`; they cannot be generated from tests)
- [ ] Feature graphic 1024×500 for Play — **you**
- [ ] Data safety answers from `store/data-safety.md`
- [ ] Content rating answers from `store/content-rating.md`
- [ ] Privacy policy URL, support email, marketing URL
- [ ] App icon — already generated, applied by `flutter_launcher_icons`

## 6. Review notes — write these, they prevent a rejection

Give the reviewer a **test account with premium already enabled**, and say:

> DollChecker analyses a photo of a children's toy. To test: sign in with the
> account below, add a child, then scan any toy — a photo of a toy from the web
> shown on another screen works.
>
> Account deletion is at: Parents panel (person icon, top right of Home) →
> Account → Delete account.
>
> The app gives AI guidance from a photograph and states throughout that it is
> not a safety certification and does not replace packaging warnings or recall
> data.

Then add the paragraph for the store you are submitting to — they are not the
same app in this one respect, and saying the wrong one invites the rejection
it was meant to prevent.

**Google Play:**

> Subscriptions are handled by Polar (merchant of record) through a hosted
> checkout in the browser. The provided account already has premium, so no
> purchase is needed to review the paid features.

**App Store:**

> This build sells nothing. There is no in-app purchase, no checkout, and no
> link to any external purchase page. Some features are marked as part of a
> paid tier; accounts that already hold that tier — including the one provided
> — have them enabled, and the entitlement is returned by our server. The
> provided account already has it, so no purchase is needed to review the paid
> features.

## 7. After the first release

- [ ] Play: start with **internal testing**, then closed, then production
- [ ] Apple: TestFlight first
- [ ] Watch the Edge Function logs for the first real scans
- [ ] Watch the first real webhook arrive before trusting the tier switch

---

## What is deliberately not on this list

- **Crash reporting and analytics.** Both need an external account and neither
  blocks a submission. Worth adding before you have real users, not before you
  have a build.
- **iOS in the release workflow.** The tagged release builds Android only;
  producing an `.ipa` needs a provisioning profile and a signing identity.
  CI *does* now have an `iOS build (manual)` job — run it from the Actions tab
  before a submission to confirm the iOS side still compiles. It is
  `workflow_dispatch` because macOS runners bill at ten times the Linux rate,
  so it costs nothing until you start it.
