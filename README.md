# Mindful — Mental Health Support Chatbot (Prototype)

A cross-platform Flutter chatbot that offers **first-line emotional wellness
support** using NLP. It uses **Groq** as the conversational AI provider and a
**local SQLite database** so conversation data stays on the device.

> ⚠️ This is a final-year project prototype for emotional *support*, not a
> medical or therapy service. It does not diagnose. In a crisis it surfaces
> helpline resources and encourages contacting a real person.

See [`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md) for the full design and
how it maps to Chapters 1–3.

## Features
- Empathetic, context-aware chat powered by Groq.
- **Voice input** — tap the mic to record (with a live waveform), tap ✓, and the
  clip is transcribed by Groq Whisper into the message box to review and send.
- **Voice output** — a natural cloud voice (Groq Orpheus TTS) reads AI replies
  aloud; tap the speaker on any message, and spoken messages are auto-read.
- Per-message **emotion / sentiment** tags returned by the model.
- **Conversation history** — every chat is saved and can be reopened, renamed,
  searched, or deleted from the history screen (🕘 in the chat app bar).
  Conversations are auto-titled from your first message.
- **Resources** — curated self-help *Guides* that always work offline, plus a
  *Latest* tab of live articles pulled from public health/research RSS feeds and
  cached on-device.
- **Admin Panel** — an on-device dashboard with usage stats, sentiment
  breakdown, user management, conversation transcripts, and filterable logs.
- **Offline crisis detection** — local keyword screening runs before any network
  call and shows emergency helpline resources.
- **Privacy-first** — all chat data is stored locally in SQLite.
- No setup screen — the API key is supplied once at build time.
- Cross-platform: Android, iOS, macOS/desktop from one codebase.

## Prerequisites
- Flutter 3.32+ (`flutter --version`)
- A **Groq API key** from <https://console.groq.com> → *API Keys* (`gsk_...`).

## Setup & run

The Groq key is passed in with `--dart-define` so it never has to be committed
to the repository. Substitute your own key in the commands below.

```bash
flutter pub get

# Run on the desktop (quickest for testing):
flutter run -d macos --dart-define=GROQ_API_KEY=gsk_your_key_here

# …or an Android emulator / iOS simulator / device:
flutter run --dart-define=GROQ_API_KEY=gsk_your_key_here

# Release build:
flutter build apk --dart-define=GROQ_API_KEY=gsk_your_key_here
```

To avoid retyping the key, put it in a git-ignored `env.json`:

```json
{ "GROQ_API_KEY": "gsk_your_key_here" }
```

```bash
flutter run --dart-define-from-file=env.json
```

Without a key the app still launches, and the chat, voice input, and voice
output each explain that the key is missing rather than failing silently.

The model is configured in code (`AppConfig.defaultModel`, default
`openai/gpt-oss-120b`); check the Groq console for current model ids. Groq
retires model ids periodically — if replies start returning 404
`model_not_found`, list the ids your account can reach with:

```bash
curl https://api.groq.com/openai/v1/models -H "Authorization: Bearer $GROQ_API_KEY"
```

## Run the tests
```bash
flutter test       # includes CrisisDetector unit tests
flutter analyze    # static analysis (should report no issues)
```

## Configuration notes
- The AI endpoint and default model live in
  [`lib/core/constants.dart`](lib/core/constants.dart).
- Groq exposes an **OpenAI-compatible** chat-completions API, so the request
  format in `lib/services/ai_service.dart` mirrors the OpenAI schema. Because of
  that, switching providers later (e.g. to xAI Grok or OpenAI) only means
  changing `aiBaseUrl` + `defaultModel` and using that provider's key.
- Crisis helpline numbers in `constants.dart` are Nigeria-focused placeholders —
  update them for your region before any real demo.

## Admin Panel

**The admin dashboard is local, not remote.** There is no server: it reads the
SQLite database on the device it is running on, so an admin sees only the users
and activity of that install. Two phones running this app keep entirely separate
data and never sync.

Sign in with the default admin account, seeded into the local database on first
launch (`AuthService.seedDefaultAdmin`):

| Field    | Value                |
|----------|----------------------|
| Email    | `admin@mindful.app`  |
| Password | `Admin@1234`         |

The **first account to register** on a device also becomes an admin. Change
`adminEmail` / `adminPassword` in
[`lib/core/constants.dart`](lib/core/constants.dart) before any real deployment —
these defaults are public in this repository.

Open it from **Profile → Admin Panel** (only visible to admins). Tabs:

- **Overview** — users, admins, conversations, messages, crisis flags, a
  detected-emotion breakdown, and last activity.
- **Users** — search, promote/revoke admin, reset a password, delete an account.
  Guard rails prevent removing the last admin or deleting the account you are
  signed in as.
- **Conversations** — browse every conversation and read its full transcript.
- **Logs** — recent messages, filterable by crisis / user / bot and searchable.

## Live articles

The Resources screen's **Latest** tab fetches from public RSS feeds, defined in
`ArticleService.feeds` ([`lib/services/article_service.dart`](lib/services/article_service.dart)):

| Topic       | Source                                    |
|-------------|-------------------------------------------|
| Anxiety     | ScienceDaily — Anxiety News                |
| Stress      | ScienceDaily — Stress News                 |
| Depression  | ScienceDaily — Depression News             |
| Sleep       | ScienceDaily — Sleep Disorder News         |
| Mindfulness | Mindful.org                                |

Results are cached in SQLite for 6 hours and the tab falls back to the cached
copy when offline. If every feed fails and nothing is cached, the tab shows an
error and points the user at the offline **Guides** tab. To change sources, edit
the `feeds` list — one dead feed does not blank the others.

## Project layout
See [`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md) §5.
