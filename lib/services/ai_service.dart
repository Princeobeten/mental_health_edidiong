import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../data/models/chat_message.dart';

/// Result of one AI call: the empathetic reply plus the detected emotion
/// (sentiment analysis + intent + generation in a single structured call).
class AiResult {
  final String reply;
  final String? emotion;
  const AiResult(this.reply, this.emotion);
}

class AiException implements Exception {
  final String message;
  AiException(this.message);
  @override
  String toString() => message;
}

/// The "Response Generator" module (Chapter 3), backed by Groq.
/// Uses the OpenAI-compatible chat-completions endpoint.
class AiService {
  final http.Client _client;
  AiService({http.Client? client}) : _client = client ?? http.Client();

  static const String _systemPrompt = '''
You are "Mindful", a warm, empathetic mental-health support companion for a
first-line emotional wellness app. You are NOT a therapist and must NOT give
medical diagnoses. Your goals:
- Listen with genuine warmth and validate the user's feelings.
- Reflect back what you hear and ask gentle, open questions.
- Offer simple, evidence-informed coping ideas (breathing, grounding,
  journaling, reaching out to someone) when appropriate.
- If the user expresses thoughts of self-harm or suicide, gently encourage
  them to contact a crisis line or a trusted person immediately.
Keep replies concise (2-5 sentences), kind, and non-judgmental.

Respond ONLY with a JSON object of the form:
{"emotion": "<one of: positive, neutral, anxious, sad, angry, stressed, crisis>",
 "reply": "<your supportive message to the user>"}
Do not include any text outside the JSON object.''';

  Future<AiResult> generateReply({
    required String apiKey,
    required String model,
    required List<ChatMessage> history,
    required String userMessage,
  }) async {
    if (apiKey.isEmpty) {
      throw AiException(
          'No Groq API key was built into this app. Rebuild it with '
          '--dart-define=GROQ_API_KEY=your_key (see the README).');
    }

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': _systemPrompt},
      // Recent context (last 10 turns) for coherent, contextual replies.
      for (final m in history.take(10))
        {
          'role': m.sender == Sender.user ? 'user' : 'assistant',
          'content': m.text,
        },
      {'role': 'user', 'content': userMessage},
    ];

    // Groq retires model ids from time to time; if the configured one is gone
    // (404 `model_not_found`) fall through to the next known-good id rather
    // than showing the user a raw API error.
    final candidates = <String>[
      model,
      ...AppConfig.fallbackModels.where((m) => m != model),
    ];

    AiException? lastMissing;
    for (final candidate in candidates) {
      final res = await _post(apiKey: apiKey, model: candidate, messages: messages);

      if (res.statusCode == 401) {
        throw AiException(
            'Groq rejected the API key (401). Rebuild with a valid '
            '--dart-define=GROQ_API_KEY (see the README).');
      }
      if (res.statusCode == 404 && res.body.contains('model_not_found')) {
        lastMissing = AiException(
            'The model "$candidate" is no longer available on this Groq '
            'account. Update AppConfig.defaultModel with a current model id '
            'from https://console.groq.com.');
        continue;
      }
      if (res.statusCode != 200) {
        throw AiException('AI service error ${res.statusCode}: ${res.body}');
      }

      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final content = decoded['choices']?[0]?['message']?['content'] as String?;
      if (content == null || content.trim().isEmpty) {
        throw AiException('The AI service returned an empty response.');
      }

      return _parseContent(content);
    }

    throw lastMissing ??
        AiException('No usable AI model is configured for this account.');
  }

  /// One chat-completions request for a specific model id.
  Future<http.Response> _post({
    required String apiKey,
    required String model,
    required List<Map<String, String>> messages,
  }) async {
    final payload = <String, dynamic>{
      'model': model,
      'messages': messages,
      'temperature': 0.7,
      'response_format': {'type': 'json_object'},
      // The gpt-oss models reason before answering; keeping that budget low
      // keeps replies fast and stops reasoning tokens from crowding out the
      // actual message. Other model families reject the parameter.
      if (model.contains('gpt-oss')) 'reasoning_effort': 'low',
    };

    try {
      return await _client
          .post(
            Uri.parse(AppConfig.aiBaseUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 45));
    } catch (e) {
      throw AiException(
          'Could not reach the AI service. Check your connection. ($e)');
    }
  }

  /// Parses the model's JSON reply, with a graceful fallback if the model
  /// returns plain text instead of JSON.
  AiResult _parseContent(String content) {
    try {
      final obj = jsonDecode(content) as Map<String, dynamic>;
      final reply = (obj['reply'] as String?)?.trim();
      final emotion = (obj['emotion'] as String?)?.trim();
      if (reply != null && reply.isNotEmpty) {
        return AiResult(reply, emotion);
      }
    } catch (_) {
      // Not valid JSON — fall through and treat the whole content as the reply.
    }
    return AiResult(content.trim(), null);
  }
}
