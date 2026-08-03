# DollChecker — Privacy Policy

**Last updated: 3 August 2026**

> **Before publishing:** replace every `{{PLACEHOLDER}}` with your real details,
> and have a lawyer read this. It is written to match exactly what the app does
> — nothing is aspirational — but it is not legal advice, and the entity,
> jurisdiction and contact details are things only you can fill in.

DollChecker ("the app", "we") helps parents evaluate children's toys. This
policy explains what the app collects, why, who else sees it, and how to get rid
of it.

**Controller:** {{LEGAL_ENTITY_NAME}}, {{REGISTERED_ADDRESS}}
**Contact:** {{SUPPORT_EMAIL}}

---

## 1. What we collect

We only collect what the app needs to work. There is no advertising, no
tracking, and no third-party analytics SDK in the app.

| Data | Why | Provided by |
|---|---|---|
| Email address and password | To create and sign in to your account | You |
| Child's first name and (optional) date of birth | Age-appropriate safety and development advice | You |
| Photographs of toys | To analyze the toy | You |
| Analysis results — identification, safety verdict, development scores, play ideas | The collection, dashboard and missions | Generated for you |
| Play activity — missions completed or skipped, streaks | The daily missions and streak features | Your use of the app |
| Questions you ask in chat, and the answers | To continue the conversation about a toy | You |
| Subscription status and billing identifiers | To unlock premium features | Our payment provider |
| Reminder time and on/off state | The daily notification | You — **stored only on your device**, never sent to us |

We do **not** collect location, contacts, advertising identifiers, or your
device's photo library beyond the single image you choose for each scan.

## 2. Photographs

A photo you scan is sent to our server, stored in a private bucket that only
your account can read, and passed to our AI provider for analysis. It is not
public, is not used to train any model (see §4), and is deleted when you delete
your account.

Please photograph the toy, not your child. The app never asks for a photo of a
person and does not need one.

## 3. Children's data

DollChecker is a tool **for parents and carers**. It is not directed at children
and children are not intended to use it or create accounts.

You may enter a child's first name and date of birth. That is the only
information about a child the app holds, it is optional (the app works without a
date of birth, with less precise advice), and it is used solely to tailor
age-appropriate guidance. It is never used for advertising or profiling, and is
deleted with your account.

## 4. Who else processes your data

| Processor | What they receive | Purpose |
|---|---|---|
| **Supabase** ({{SUPABASE_REGION}}) | Everything stored: account, children, scans, photos, chat | Database, authentication, file storage, server functions |
| **Anthropic** (Claude API) | The toy photo, the child's age in months, your chat questions and the stored analysis of the toy being discussed | Producing the analysis and chat answers |
| **Polar Software Inc.** (merchant of record) | Your email and payment details | Taking payment, invoicing, tax |

We do not sell your data, and we do not share it with anyone else.

Anthropic processes API inputs to return a response. Under the Anthropic
commercial terms in force at the time of writing, inputs and outputs submitted
through the API are **not used to train their models**. If that ever changes,
this policy will be updated before the change takes effect.

Card details never reach us: payment happens entirely on Polar's hosted
checkout.

## 5. Where data is stored

Data is hosted by Supabase in **{{SUPABASE_REGION}}**. Anthropic and Polar
process data in the United States. Where data leaves the UK/EEA, transfers rely
on the processors' Standard Contractual Clauses.

## 6. How long we keep it

- **Your content** — scans, photos, collection, missions, chat — for as long as
  your account exists.
- **After deletion** — removed immediately, including the photos in storage.
  Backups roll off within {{BACKUP_WINDOW}} days.
- **Billing records** — kept by Polar for as long as tax law requires,
  independently of your account.

## 7. Deleting your account

In the app: **Parents panel → Account → Delete account**. It is permanent and
immediate: the account, every child profile, every scan, the collection, the
missions, the chat and all uploaded photos are deleted. There is no recovery.

You can also email {{SUPPORT_EMAIL}} and ask us to do it.

## 8. Your rights

Depending on where you live, you have the right to access, correct, export or
delete your data, to object to or restrict processing, and to complain to a
supervisory authority (in the UK, the ICO; in the EU, your national DPA).

Most of these you can exercise in the app directly. For anything else, email
{{SUPPORT_EMAIL}} and we will respond within 30 days.

**California residents:** we do not sell or share personal information as those
terms are defined by the CCPA/CPRA, and we do not process it for cross-context
behavioural advertising.

## 9. Security

Data is protected in transit (TLS) and at rest by our hosting provider. Every
table enforces row-level security keyed to your account, so one account cannot
read another's data. Our AI and payment credentials live only on the server and
never ship inside the app.

No system is perfectly secure. If a breach affects your data, we will notify you
and the relevant authority as the law requires.

## 10. Legal basis (UK/EU)

- **Contract** — running your account, storing your scans, delivering the
  subscription you bought.
- **Legitimate interests** — keeping the service secure and working.
- **Consent** — notifications, camera and photo access, each asked for
  separately and withdrawable in your device settings at any time.

## 11. Changes

We will post any change here and update the date at the top. Material changes
will be announced in the app before they take effect.

## 12. Contact

{{LEGAL_ENTITY_NAME}}
{{REGISTERED_ADDRESS}}
{{SUPPORT_EMAIL}}
