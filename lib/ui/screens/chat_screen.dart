import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/chat_controller.dart';
import '../../core/brand.dart';
import '../../data/models/chat_message.dart';
import '../../services/settings_service.dart';
import '../../services/speech_service.dart';
import '../../services/tts_service.dart';
import '../widgets/crisis_banner.dart';
import '../widgets/message_bubble.dart';
import '../widgets/recording_wave.dart';
import 'history_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _speech = SpeechService();
  final _tts = TtsService();

  /// Recording / transcription state for voice input.
  bool _recording = false;
  bool _transcribing = false;
  final List<double> _levels = [];
  StreamSubscription? _ampSub;

  /// True when the current draft came from voice (not typing).
  /// Used to auto-read the AI's reply aloud after a spoken message.
  bool _voiceInput = false;

  /// Chosen voice persona for spoken replies (persisted in settings).
  VoiceGender _voiceGender = VoiceGender.female;

  /// Id of the message currently being read aloud (drives the speaking
  /// animation on its bubble), or null if nothing is speaking.
  int? _speakingId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Reopen the most recent conversation when the screen first opens.
      context.read<ChatController>().loadLastSessionOrStart();
      // Load the saved voice preference.
      final gender = await context.read<SettingsService>().getVoiceGender();
      if (mounted) setState(() => _voiceGender = gender);
    });
  }

  String get _voiceId => context.read<SettingsService>().voiceIdFor(_voiceGender);

  Future<void> _setVoice(VoiceGender gender) async {
    setState(() => _voiceGender = gender);
    await context.read<SettingsService>().setVoiceGender(gender);
  }

  @override
  void dispose() {
    _ampSub?.cancel();
    _speech.dispose();
    _input.dispose();
    _scroll.dispose();
    _tts.dispose();
    super.dispose();
  }

  /// Reads [message] aloud (tap again while speaking to stop), showing the
  /// speaking animation on its bubble until it finishes.
  Future<void> _speak(ChatMessage message) async {
    // Tapping the same message while it's speaking stops playback.
    if (_speakingId == message.id) {
      await _tts.stop();
      if (mounted) setState(() => _speakingId = null);
      return;
    }

    setState(() => _speakingId = message.id);
    try {
      await _tts.speak(message.text, voice: _voiceId);
    } on TtsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      // Anything the audio plugin throws would otherwise fail silently and
      // just look like a dead speaker button.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not play the voice. ($e)')));
      }
    } finally {
      // Clear only if this message is still the active one (a newer playback
      // may have taken over).
      if (mounted && _speakingId == message.id) {
        setState(() => _speakingId = null);
      }
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;

    final controller = context.read<ChatController>();
    final spoken = _voiceInput;

    _input.clear();
    _voiceInput = false;

    await controller.sendMessage(text);
    if (!mounted) return;
    _scrollToBottom();

    // If the user spoke their message, read the AI's reply back to them.
    if (spoken) {
      final messages = controller.messages;
      if (messages.isNotEmpty && messages.last.sender == Sender.bot) {
        await _speak(messages.last);
      }
    }
  }

  /// Start recording the user's voice and feed the waveform from mic levels.
  Future<void> _startRecording() async {
    final ok = await _speech.start();
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Microphone permission is needed to record.')));
      return;
    }
    _levels.clear();
    _ampSub = _speech.amplitude.listen((amp) {
      // amp.current is in dBFS (~-45 quiet .. 0 loud); map to 0..1.
      final norm = ((amp.current + 45) / 45).clamp(0.0, 1.0);
      if (!mounted) return;
      setState(() {
        _levels.add(norm);
        if (_levels.length > 120) _levels.removeAt(0);
      });
    });
    if (mounted) setState(() => _recording = true);
  }

  /// Finish recording (✓): transcribe the clip and drop the text in the box.
  Future<void> _finishRecording() async {
    await _ampSub?.cancel();
    setState(() {
      _recording = false;
      _transcribing = true;
    });
    try {
      final text = await _speech.stopAndTranscribe();
      if (!mounted) return;
      setState(() {
        if (text.isNotEmpty) {
          _input.text = text;
          _voiceInput = true;
        }
        _transcribing = false;
      });
    } on SpeechException catch (e) {
      if (!mounted) return;
      setState(() => _transcribing = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// Cancel recording without transcribing (✕).
  Future<void> _cancelRecording() async {
    await _ampSub?.cancel();
    await _speech.cancel();
    if (mounted) setState(() => _recording = false);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(Brand.logoAsset, width: 28, height: 28),
            const SizedBox(width: 8),
            const Text('Mindful'),
          ],
        ),
        actions: [
          PopupMenuButton<VoiceGender>(
            tooltip: 'Voice',
            icon: Icon(_voiceGender == VoiceGender.male
                ? Icons.record_voice_over
                : Icons.record_voice_over_outlined),
            onSelected: _setVoice,
            itemBuilder: (_) => [
              CheckedPopupMenuItem(
                value: VoiceGender.female,
                checked: _voiceGender == VoiceGender.female,
                child: const Text('Female voice'),
              ),
              CheckedPopupMenuItem(
                value: VoiceGender.male,
                checked: _voiceGender == VoiceGender.male,
                child: const Text('Male voice'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Conversation history',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              );
              if (mounted) _scrollToBottom();
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New chat',
            onPressed: () => context.read<ChatController>().startSession(),
          ),
        ],
      ),
      body: Consumer<ChatController>(
        builder: (context, controller, _) {
          _scrollToBottom();
          return Column(
            children: [
              if (controller.crisisActive)
                CrisisBanner(onDismiss: controller.dismissCrisisBanner),
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: controller.messages.length,
                  itemBuilder: (_, i) {
                    final msg = controller.messages[i];
                    return MessageBubble(
                      message: msg,
                      isSpeaking: _speakingId != null && _speakingId == msg.id,
                      onSpeak: msg.sender == Sender.bot
                          ? () => _speak(msg)
                          : null,
                    );
                  },
                ),
              ),
              if (controller.isSending)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Row(
                    children: [
                      SizedBox(width: 16),
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 10),
                      Text('Mindful is typing…',
                          style: TextStyle(color: Colors.black54)),
                    ],
                  ),
                ),
              if (controller.error != null)
                Container(
                  width: double.infinity,
                  color: const Color(0xFFFFF3CD),
                  padding: const EdgeInsets.all(10),
                  child: Text(controller.error!,
                      style: const TextStyle(
                          color: Color(0xFF856404), fontSize: 13)),
                ),
              _buildInputBar(context),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInputBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Row(
          children: [
            // Leading control: cancel (while recording) or mic (while idle).
            if (_recording)
              IconButton(
                tooltip: 'Cancel',
                icon: Icon(Icons.close, color: scheme.error),
                onPressed: _cancelRecording,
              )
            else
              IconButton(
                tooltip: 'Record voice',
                icon: Icon(Icons.mic_none, color: scheme.primary),
                onPressed: _transcribing ? null : _startRecording,
              ),

            // Middle: waveform / transcribing indicator / text field.
            Expanded(child: _buildInputCenter(scheme)),
            const SizedBox(width: 6),

            // Trailing control: ✓ to finish recording, otherwise send.
            if (_recording)
              FloatingActionButton(
                tooltip: 'Done',
                onPressed: _finishRecording,
                elevation: 0,
                child: const Icon(Icons.check),
              )
            else
              FloatingActionButton(
                onPressed: _transcribing ? null : () => _send(),
                elevation: 0,
                child: const Icon(Icons.send),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCenter(ColorScheme scheme) {
    if (_recording) return RecordingWave(levels: _levels);
    if (_transcribing) {
      return Container(
        height: 44,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text('Transcribing…', style: TextStyle(color: scheme.outline)),
          ],
        ),
      );
    }
    return TextField(
      controller: _input,
      minLines: 1,
      maxLines: 4,
      textInputAction: TextInputAction.send,
      onSubmitted: (_) => _send(),
      // Manual typing means this draft is no longer a voice message.
      onChanged: (_) => _voiceInput = false,
      decoration: InputDecoration(
        hintText: 'Share how you feel…',
        filled: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
