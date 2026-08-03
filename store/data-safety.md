# Data safety / privacy label answers

Pre-filled answers for **Google Play → Data safety** and **App Store Connect →
App Privacy**. They are derived from what the code actually does, not from what
would be convenient to declare — a mismatch here is one of the most common
reasons a submission is rejected or an app is pulled later.

Verify each line against the code before submitting. The relevant places are
`supabase/functions/analyze-toy/index.ts`, `chat-toy/index.ts`,
`delete-account/index.ts`, `polar-billing/index.ts`, and
`app/lib/features/reminders/`.

---

## Google Play — Data safety

### Overall

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **Yes** |
| Is all user data encrypted in transit? | **Yes** |
| Do you provide a way for users to request data deletion? | **Yes** — in-app: Parents panel → Account → Delete account |
| Has your data collection been independently reviewed? | **No** |
| Does your app target children? | **No** — it is for parents; see the Families section below |

### Data types

| Type | Collected | Shared | Optional? | Purpose |
|---|---|---|---|---|
| **Email address** | Yes | No | Required | Account management |
| **Name** *(child's first name)* | Yes | No | Required to add a child | App functionality — age-appropriate advice |
| **Other personal info** *(child's date of birth)* | Yes | No | **Optional** | App functionality |
| **Photos** | Yes | **Yes** | Required to scan | App functionality — the photo is sent to the AI provider to be analyzed |
| **Purchase history** | Yes | No | Required to subscribe | App functionality — unlocking premium |
| **App activity** *(in-app actions: missions completed, favourites)* | Yes | No | Required | App functionality |
| **Messages** *(chat questions and answers)* | Yes | **Yes** | Optional — premium feature | App functionality — the conversation is sent to the AI provider to be answered |

Everything above is **collected** (sent to our servers) rather than only
processed on-device, and none of it is used for advertising, analytics,
personalisation or fraud prevention.

### Not collected — declare explicitly

Location, contacts, calendar, SMS, call logs, health and fitness, financial info
(card details never reach us — Polar's hosted checkout handles them), files and
docs, audio, device or advertising IDs, installed apps, web browsing history.

### Why "shared" is Yes for photos and messages

Play counts a transfer to a third-party **processor** as sharing when the data
leaves your control to another company. The toy photo goes to Anthropic to be
analyzed, and chat text goes there to be answered. Nothing goes anywhere else,
nothing is sold, and there is no advertising or analytics SDK in the app.

### Families / Designed for Families

Do **not** opt in. The app is for parents and carers, is not directed at
children, and does not target the child audience. It does hold a child's first
name and optional date of birth — entered by the parent — which the listing and
privacy policy state plainly.

---

## Apple — App Privacy

### Data Used to Track You

**None.** There is no tracking, no advertising identifier, no third-party
analytics, no data broker.

### Data Linked to You

| Category | Data | Purposes |
|---|---|---|
| Contact Info | Email address | App Functionality |
| User Content | Photos, other user content *(child name, date of birth)*, customer support | App Functionality |
| User Content | Emails or text messages *(chat with the assistant)* | App Functionality |
| Purchases | Purchase history | App Functionality |
| Usage Data | Product interaction | App Functionality |
| Identifiers | User ID | App Functionality |

### Data Not Linked to You

None.

### Notes for the reviewer / third parties

- **Anthropic (Claude API)** — receives the toy photo, the child's age in
  months, and chat text, to produce the analysis and answers.
- **Supabase** — hosting, authentication, database and private file storage.
- **Polar Software Inc.** — merchant of record for subscriptions.

### Account deletion (App Store guideline 5.1.1(v))

The app supports account creation, so in-app deletion is mandatory and is
implemented: **Parents panel → Account → Delete account**. It deletes the auth
user, every table that references it, and every uploaded photo. Point the
reviewer at this path in the review notes.

### Permissions and their purpose strings

| Permission | When it is asked | String |
|---|---|---|
| Camera | First time the user taps "Take photo" | "DollChecker uses the camera to photograph a toy for analysis." |
| Photo library | First time the user taps "Choose from gallery" | "DollChecker reads a photo of a toy so it can be analyzed." |
| Notifications | Only when the reminder switch is turned on — never at launch | System default |

The strings live in `tool/configure_platform.py` and are applied to
`Info.plist`; change them there, not by hand, or the next `flutter create` loses
them.
