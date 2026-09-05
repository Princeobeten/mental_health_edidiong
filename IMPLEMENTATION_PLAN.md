# Implementation Plan — Mental Health Support Chatbot (Prototype)

**Project:** Design and Implementation of a Mental Health Support Chatbot using
Natural Language Processing for Emotional Wellness Assistance
**Framework:** Flutter (Dart) — cross-platform (Android, iOS, macOS/desktop)
**AI / Response Generator:** Groq — `https://api.groq.com` (console.groq.com)
**Database:** Local SQLite (on-device) via `sqflite`
**Methodology:** Object-Oriented Analysis and Design (OOADM) — per Chapter 3

---

## 1. How the prototype maps to your Chapters 1–3

Your chapters propose **Gemini + Firebase Firestore**. The prototype keeps the
*architecture* identical but swaps two providers, as you requested:

| Chapter design | Prototype | Justification you can defend |
|---|---|---|
| Gemini API (LLM) | **Groq** (Llama 3.3) | Both are transformer LLMs serving the OOADM "Response Generator" module. The provider is a swappable implementation detail (inheritance/polymorphism — your §3 "plug-and-play" point); the OpenAI-compatible interface means it can be re-pointed to Gemini/xAI/OpenAI by changing one URL + model. |
| Firebase Firestore (cloud) | **Local SQLite** | Directly realises your privacy objective (§1.5: "no personal data beyond each chat session is stored"). Data never leaves the device. |

Everything else — NLP pipeline, sentiment/intent detection, crisis escalation,
cross-platform Flutter UI, OOADM modularity — is implemented as written.

## 2. System architecture (OOADM objects → Dart classes)

```
┌─────────────────────────────────────────────────────────────┐
│                     Flutter UI (Material 3)                  │
│   ChatScreen · SettingsScreen · MessageBubble · CrisisBanner │
└───────────────────────────┬─────────────────────────────────┘
                            │  (Provider state)
                ┌───────────▼────────────┐
                │   ChatController        │  ← Dialogue Manager
                │   (orchestrates pipeline)│
                └───┬──────┬───────┬──────┘
        ┌───────────┘      │       └────────────┐
        ▼                  ▼                    ▼
┌──────────────┐  ┌─────────────────┐  ┌────────────────┐
│ CrisisDetector│  │  AiService      │  │ ChatRepository │
│ (local NLP,   │  │ (Response Gen,  │  │  (persistence) │
│  offline)     │  │  sentiment+gen) │  └───────┬────────┘
└──────────────┘  └───────┬─────────┘          ▼
                          │             ┌────────────────┐
                          ▼             │ SQLite (sqflite)│
                  api.groq.com (HTTPS)  │ sessions/messages│
                                        └────────────────┘
```

**Module responsibilities (encapsulation — your §3 "robustness" point):**
- `CrisisDetector` — offline, lexicon/rule-based screening for self-harm /
  suicidal language. Runs **first**, before any network call, so safety never
  depends on connectivity or the API.
- `AiService` — the Response Generator. Sends conversation context to the AI
  provider (Groq) and receives a structured JSON reply `{emotion, reply}`
  (sentiment analysis + intent detection + generation in one call).
- `ChatRepository` / `DatabaseHelper` — hide SQLite behind a clean interface.
- `ChatController` — the Dialogue Manager that wires the pipeline together and
  exposes UI state.

## 3. Data flow (matches your Fig. 3.3 / 3.7)

1. User types a message in `ChatScreen`.
2. `ChatController` runs `CrisisDetector` locally → if high-risk, raise the
   `CrisisBanner` with helpline resources (escalation path, §3.7).
3. User message saved to SQLite and rendered.
4. `AiService` sends recent context + message to Groq → `{emotion, reply}`.
5. Bot reply (with detected emotion tag) saved to SQLite and rendered.

## 4. Technology choices

| Concern | Choice | Package |
|---|---|---|
| UI / cross-platform | Flutter Material 3 | (sdk) |
| State management | Provider | `provider` |
| HTTP to AI provider | REST (OpenAI-compatible) | `http` |
| Local DB | SQLite | `sqflite` + `sqflite_common_ffi` (desktop) |
| API-key storage | On-device key/value | `shared_preferences` |
| Paths / timestamps | — | `path`, `path_provider`, `intl` |

## 5. Project structure

```
lib/
├── core/constants.dart            # config, AI endpoint, crisis helplines
├── data/
│   ├── models/                    # ChatMessage, ChatSession (OOADM objects)
│   ├── local/database_helper.dart # SQLite schema + connection
│   └── repositories/              # ChatRepository
├── services/
│   ├── crisis_detector.dart       # offline crisis NLP
│   ├── ai_service.dart            # Groq (Response Generator)
│   ├── speech_service.dart        # voice input  (record + Groq Whisper STT)
│   ├── tts_service.dart           # voice output (Groq Orpheus TTS + audioplayers)
│   └── settings_service.dart      # supplies built-in API key / model
├── controllers/chat_controller.dart  # Dialogue Manager
└── ui/
    ├── screens/                   # SplashScreen, ChatScreen
    └── widgets/                   # MessageBubble, CrisisBanner
```

**Voice (accessibility):** the chat screen has a microphone button. Tapping it
**records** the user's voice (`record` package) while a live waveform animates in
the input area; tapping **✓** uploads the clip to **Groq Whisper**
(`whisper-large-v3-turbo`) for accurate transcription, and the resulting text is
placed in the input box for the user to review before sending. Each AI message
has a speaker button that reads the reply aloud using **Groq's Orpheus TTS**
(natural cloud voice, played with `audioplayers`); when the user sends a spoken
message, the reply is read back automatically. The app opens on a brief
`SplashScreen` before the chat. The conversation persists in SQLite and is
reopened on launch; a "+" button starts a new session. The API key is built into
`AppConfig` so there is no settings screen / setup step.

## 6. Build phases (how it was/should be staged for the report)

1. **Phase 1 — Scaffolding & data layer:** Flutter project, SQLite schema,
   models, repository. ✅
2. **Phase 2 — NLP & AI services:** local CrisisDetector + AiService. ✅
3. **Phase 3 — Dialogue Manager & state:** ChatController + Provider wiring. ✅
4. **Phase 4 — UI:** chat screen, message bubbles, settings, crisis banner. ✅
5. **Phase 5 — Safety & privacy hardening:** offline-first crisis check,
   session-scoped storage, local-only API key. ✅
6. **Phase 6 — Testing & evaluation:** unit tests (CrisisDetector), manual
   conversation testing, usability evaluation for Chapter 4/5. ⬜ (extend here)

## 7. Suggested evaluation for Chapters 4–5

- **Functional testing:** table of test cases (greeting, sad input, anxious
  input, crisis input → banner shown, offline behaviour).
- **Sentiment accuracy:** sample N messages, compare the AI's `emotion` label to
  human judgement, report accuracy.
- **Usability:** short questionnaire (SUS) with a handful of test users.
- **Limitations** (already in §1.5): English-only, no diagnosis, no long-term
  personalisation, prototype crisis lexicon is keyword-based.

## 8. Future work (good viva talking points)

- Replace the keyword crisis lexicon with an on-device ML classifier.
- Add an on-device embedding model for a private knowledge base (RAG of
  coping/self-help content) — keeps the privacy guarantee.
- Multi-session history browser; export/delete-all for data control.
- Web/desktop polish and accessibility (screen-reader labels).
