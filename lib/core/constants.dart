/// App-wide constants and configuration for the Mental Health Support Chatbot.
///
/// The AI "Response Generator" module (Chapter 3) is powered by Groq,
/// which exposes an OpenAI-compatible REST endpoint.
library;

class AppConfig {
  AppConfig._();

  static const String appName = 'Mindful — Emotional Wellness Companion';

  // ---- Default admin account (seeded into the local database) -------------
  // These credentials are inserted on first run so an administrator can sign
  // in immediately. Change them before any real deployment.
  static const String adminName = 'Administrator';
  static const String adminEmail = 'admin@mindful.app';
  static const String adminPassword = 'Admin@1234';

  // ---- AI API (Groq) -----------------------------------------------------
  // OpenAI-compatible chat-completions endpoint (see https://console.groq.com).
  static const String aiBaseUrl =
      'https://api.groq.com/openai/v1/chat/completions';

  // Default chat model. Groq retires model ids periodically (the old
  // `llama-3.3-70b-*` ids now return 404 `model_not_found`), so verify against
  // `GET https://api.groq.com/openai/v1/models` if replies start failing.
  static const String defaultModel = 'openai/gpt-oss-120b';

  // Tried in order if [defaultModel] is no longer served by the account, so a
  // retired model id degrades to a working one instead of breaking the chat.
  static const List<String> fallbackModels = <String>[
    'openai/gpt-oss-20b',
    'qwen/qwen3.8-27b',
    'groq/compound-mini',
  ];

  // ---- Speech-to-text (Groq Whisper) -------------------------------------
  // The recorded clip is uploaded here and transcribed server-side — more
  // accurate than on-device recognition.
  static const String sttUrl =
      'https://api.groq.com/openai/v1/audio/transcriptions';
  static const String sttModel = 'whisper-large-v3-turbo';

  // ---- Text-to-speech (Groq Orpheus TTS) ---------------------------------
  // Natural-sounding cloud voice, used instead of the robotic on-device TTS.
  // NOTE: the Orpheus TTS model requires a one-time terms acceptance in the
  // Groq console before it can be called.
  static const String ttsUrl = 'https://api.groq.com/openai/v1/audio/speech';
  static const String ttsModel = 'canopylabs/orpheus-v1-english';
  // Voices the user can pick between (lowercase ids; other options: diana,
  // hannah, austin, daniel).
  static const String femaleVoice = 'autumn';
  static const String maleVoice = 'troy';
  // Orpheus has no speed control, so we speed up playback slightly instead
  // (1.0 = normal). ~1.2 gives a livelier, less sluggish delivery.
  static const double ttsPlaybackSpeed = 1.4;
  // Orpheus accepts at most 200 characters per request, so longer replies are
  // split into chunks under this length and played back-to-back.
  static const int ttsMaxChars = 190;

  // Groq API key, supplied at build time so it never lives in source control:
  //
  //   flutter run   --dart-define=GROQ_API_KEY=gsk_your_key_here
  //   flutter build apk --dart-define=GROQ_API_KEY=gsk_your_key_here
  //
  // Get a key from https://console.groq.com -> API Keys. When it is missing the
  // app still runs and the chat explains what to do instead of failing blankly.
  static const String apiKey = String.fromEnvironment('GROQ_API_KEY');

  /// True when no key was baked in at build time.
  static bool get hasApiKey => apiKey.isNotEmpty;

  // ---- Safety ------------------------------------------------------------
  // Shown whenever the local CrisisDetector flags a high-risk message.
  static const String crisisHelplineText =
      'If you are in immediate danger or thinking about harming yourself, '
      'please reach out now:\n\n'
      '• Nigeria — Mentally Aware Nigeria Initiative (MANI): 0809 111 6264\n'
      '• Lagos Suicide Hotline: 0800 800 2000\n'
      '• International (find a local line): https://findahelpline.com\n\n'
      'You deserve support from a real person right now.';
}
