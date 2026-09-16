import 'package:flutter/foundation.dart';

import '../data/models/chat_message.dart';
import '../data/models/chat_session.dart';
import '../data/repositories/chat_repository.dart';
import '../services/ai_service.dart';
import '../services/crisis_detector.dart';
import '../services/settings_service.dart';

/// The Dialogue Manager (Chapter 3). Orchestrates the pipeline:
///   user input -> CrisisDetector -> AiService -> persist to SQLite -> UI.
class ChatController extends ChangeNotifier {
  final ChatRepository _repo;
  final AiService _ai;
  final CrisisDetector _crisis;
  final SettingsService _settings;

  ChatController(this._repo, this._ai, this._crisis, this._settings);

  final List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  ChatSession? _session;
  ChatSession? get session => _session;
  int? get sessionId => _session?.id;

  bool _isSending = false;
  bool get isSending => _isSending;

  bool _crisisActive = false;
  bool get crisisActive => _crisisActive;

  String? _error;
  String? get error => _error;

  /// Called on app launch: reopen the most recent conversation (so it survives
  /// hot restarts / app restarts and is reused as AI context). Starts a fresh
  /// session only if none exists yet.
  Future<void> loadLastSessionOrStart() async {
    final sessions = await _repo.getSessions();
    if (sessions.isEmpty) {
      await startSession();
      return;
    }
    _session = sessions.first; // getSessions() is ordered newest-first
    final history = await _repo.getMessages(_session!.id!);
    _messages
      ..clear()
      ..addAll(history);
    _crisisActive = false;
    _error = null;

    // A session that somehow has no messages still needs a greeting.
    if (_messages.isEmpty) await _addGreeting();
    notifyListeners();
  }

  /// Starts a brand-new conversation with a warm greeting (the "+" button).
  Future<void> startSession() async {
    _session = await _repo.createSession(_untitled);
    _messages.clear();
    _crisisActive = false;
    _error = null;
    await _addGreeting();
    notifyListeners();
  }

  /// Placeholder title until the user's first message names the conversation.
  static const String _untitled = 'New conversation';

  /// Reopens an earlier conversation from the history screen.
  Future<void> openSession(ChatSession session) async {
    _session = session;
    final history = await _repo.getMessages(session.id!);
    _messages
      ..clear()
      ..addAll(history);
    _crisisActive = _messages.any((m) => m.isCrisis);
    _error = null;
    if (_messages.isEmpty) await _addGreeting();
    notifyListeners();
  }

  /// Names an untitled conversation after the user's opening message, so the
  /// history list reads as content rather than as timestamps.
  Future<void> _titleFromFirstMessage(String text) async {
    if (_session == null || _session!.title != _untitled) return;
    var title = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (title.length > 48) title = '${title.substring(0, 45)}...';
    await _repo.renameSession(_session!.id!, title);
    _session = ChatSession(
      id: _session!.id,
      title: title,
      createdAt: _session!.createdAt,
    );
  }

  Future<void> _addGreeting() async {
    final greeting = ChatMessage(
      sessionId: _session!.id!,
      sender: Sender.bot,
      text: "Hello, I'm Mindful. I'm here to support your mental health and "
          "emotional wellness. How are you feeling today?",
      createdAt: DateTime.now(),
    );
    final saved = await _repo.addMessage(greeting);
    _messages.add(saved);
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isSending || _session == null) return;

    _error = null;
    _isSending = true;

    // 1) Local crisis screening (offline, runs first).
    final crisis = _crisis.isCrisis(trimmed);
    if (crisis) _crisisActive = true;

    // 2) Persist + show the user's message.
    final userMsg = await _repo.addMessage(ChatMessage(
      sessionId: _session!.id!,
      sender: Sender.user,
      text: trimmed,
      isCrisis: crisis,
      createdAt: DateTime.now(),
    ));
    _messages.add(userMsg);
    await _titleFromFirstMessage(trimmed);
    notifyListeners();

    // 3) Ask the AI for an empathetic reply + detected emotion.
    try {
      final apiKey = await _settings.getApiKey();
      final model = await _settings.getModel();
      final result = await _ai.generateReply(
        apiKey: apiKey,
        model: model,
        history: _messages,
        userMessage: trimmed,
      );

      final botMsg = await _repo.addMessage(ChatMessage(
        sessionId: _session!.id!,
        sender: Sender.bot,
        text: result.reply,
        emotion: result.emotion,
        isCrisis: result.emotion == 'crisis',
        createdAt: DateTime.now(),
      ));
      _messages.add(botMsg);
    } on AiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Something went wrong: $e';
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  void dismissCrisisBanner() {
    _crisisActive = false;
    notifyListeners();
  }
}
