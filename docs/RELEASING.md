# Releasing

How a build becomes something you can upload. The submission steps around it —
listings, ratings, review notes — are in
[`store/submission-checklist.md`](../store/submission-checklist.md).

---

## Versioning

`app/pubspec.yaml` carries `version: <name>+<code>`, e.g. `0.1.0+1`.

- **name** (`0.1.0`) is what users see. Semantic: breaking → major, features →
  minor, fixes → patch.
- **code** (`+1`) is Play's `versionCode` and iOS's build number. It must
  **increase on every upload**, forever, even for a build you withdraw. Never
  reuse one; the store will refuse it.

Bump both in `pubspec.yaml`, commit, then tag:

```bash
git tag v0.1.0
git push origin v0.1.0
```

The tag is what triggers the Release workflow. Keep the tag and the version name
identical — a mismatch is the fastest way to upload the wrong artifact.

## One-time setup

### 1. The upload key

```bash
keytool -genkey -v -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

**Back this file up somewhere you will still have in three years.** If you lose
it you cannot ship an update to the same listing, ever. (Play App Signing gives
you a recovery path for the *app* signing key; the upload key is still yours to
keep.)

### 2. Repository secrets

Settings → Secrets and variables → Actions:

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 upload-keystore.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | keystore password |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | key password |
| `SUPABASE_URL` | your project URL |
| `SUPABASE_ANON_KEY` | the public anon key |
| `AUTH_REDIRECT_URL` | `dollchecker://auth-callback` |
| `PRIVACY_URL`, `TERMS_URL`, `SUPPORT_EMAIL` | your published pages |
| `PREMIUM_PRICE_LABEL` | optional, e.g. `$4.99 / month` |

The committed `app/.env` holds placeholders on purpose; the workflow writes the
real one from these secrets and deletes it afterwards. A release built against
the placeholders would open straight into the "missing configuration" screen —
the workflow checks for that and fails rather than shipping it.

## What the workflow produces

`.github/workflows/release.yml`, on a `v*` tag:

1. generates `android/` from scratch (it is not committed),
2. applies `tool/configure_platform.py --release-signing` — permissions, deep
   link, desugaring, application id, signing config,
3. generates the launcher icons,
4. restores the keystore from secrets,
5. builds `app-release.aab` **and** `app-release.apk`,
6. uploads both as artifacts, then shreds the key material.

Upload the `.aab` to Play. The `.apk` is for handing directly to a tester.

## Building locally

```bash
cd app
flutter create --platforms=android,ios --project-name dollchecker .
python3 ../tool/configure_platform.py . --release-signing
flutter pub get && dart run flutter_launcher_icons
# put upload-keystore.jks and key.properties in app/android/
flutter build appbundle --release
```

`key.properties`:

```
storeFile=upload-keystore.jks
storePassword=…
keyAlias=upload
keyPassword=…
```

Both are gitignored. Without them the signing config stays inert and the build
falls back to debug signing — fine for testing, rejected by Play.

## iOS

Not automated: it needs a macOS runner, a paid Apple account and a provisioning
profile. For the first submission, from a Mac:

```bash
cd app
flutter create --platforms=ios --project-name dollchecker .
python3 ../tool/configure_platform.py .
flutter pub get && dart run flutter_launcher_icons
open ios/Runner.xcworkspace   # set the team, then Product → Archive
```

`configure_platform.py` has already set the bundle id, the display name, the
camera and photo usage strings, and the `dollchecker://` URL type. Read
[`store/submission-checklist.md`](../store/submission-checklist.md) §0 before
submitting to iOS — the payments question is unresolved there, not here.

## Reproducible builds — commit the lockfile

`app/pubspec.lock` is tracked (it is an application, not a library), but it can
only be produced by a resolver, so it is not in the repository yet. Get one
either way:

```bash
cd app && flutter pub get     # writes app/pubspec.lock
git add app/pubspec.lock && git commit -m "Pin the resolved dependency set"
```

or download the `pubspec-lock` artifact from any CI run on `main` and commit
that. Until it exists, every build re-resolves — which is how a dependency
once moved a major version underneath us between two CI runs and broke the
build.

## Before you tag

- [ ] `app/pubspec.lock` committed, and regenerated deliberately rather than
      by accident
- [ ] CI green on `main`
- [ ] Version name **and** code bumped
- [ ] Backend deployed and smoke-tested with a real account
- [ ] Polar tested in sandbox end to end
- [ ] Legal pages published and their URLs in the secrets
