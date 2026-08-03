# Publishing the legal pages

Both stores refuse a submission without a **publicly reachable privacy policy
URL**, and Polar will not activate an organization without a refund policy.
These three documents exist so you are not writing them the night before you
submit.

## The fastest way to get URLs: GitHub Pages

1. Fill in every `{{PLACEHOLDER}}` in the three files here.
2. Repository → **Settings → Pages** → Source: *Deploy from a branch* →
   Branch: `main`, folder: `/docs` → **Save**.
3. A minute later the pages are live:

   ```
   https://<owner>.github.io/<repo>/legal/privacy-policy.html
   https://<owner>.github.io/<repo>/legal/terms-of-service.html
   https://<owner>.github.io/<repo>/legal/refund-policy.html
   ```

4. Put the first two in `app/.env`:

   ```
   PRIVACY_URL=https://<owner>.github.io/<repo>/legal/privacy-policy.html
   TERMS_URL=https://<owner>.github.io/<repo>/legal/terms-of-service.html
   SUPPORT_EMAIL=support@yourdomain
   ```

   The parents panel shows each row only once its URL is set, so they appear as
   soon as you rebuild.

This is enough to submit. Move them to your own domain later if you want — the
`.env` values are the only thing that has to change.

## Before you publish

- [ ] Every `{{PLACEHOLDER}}` replaced — grep for `{{` to be sure
- [ ] `{{SUPABASE_REGION}}` matches the region you actually created the project in
- [ ] A lawyer has read them. These are drafts written to match what the code
      does; that is the hard half, but it is not legal advice
- [ ] The dates at the top updated if you changed anything of substance

## Why the wording is careful

The app answers safety questions about children's toys from a photograph. The
terms say plainly what that can and cannot do — no inspection, no certification,
no recall check, and a green verdict is not a promise of safety. That framing
also runs through the app itself and through the model's own instructions, so
the documents, the interface and the AI all say the same thing.

Weakening it would misrepresent the product. Strengthening it into "this app
tells you whether a toy is safe" would be worse.
