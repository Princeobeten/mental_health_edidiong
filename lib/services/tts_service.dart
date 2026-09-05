import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../core/constants.dart';

class TtsException implements Exception {
  final String message;
  TtsException(this.message);
  @override
  String toString() => message;
}

/// Voice output. Sends the AI's reply to Groq's Orpheus text-to-speech model and
/// plays the natural-sounding audio it returns. Replies longer than Orpheus's
/// 200-character limit are split into chunks and played one after another.
class TtsService {
  final http.Client _client;
  final AudioPlayer _player = AudioPlayer();

  /// Increments on every new speak() so a stale playback loop can bail out.
  int _token = 0;

  /// Completed when the currently playing chunk finishes (or is superseded).
  Completer<void>? _chunkDone;

  TtsService({http.Client? client}) : _client = client ?? http.Client() {
    _player.onPlayerComplete.listen((_) => _finishChunk());
  }

  /// Synthesises [text] with Groq TTS and plays it, using [voice] (defaults to
  /// the configured female voice). Throws [TtsException] on failure.
  Future<void> speak(String text, {String voice = AppConfig.femaleVoice}) async {
    final clean = text.trim();
    if (clean.isEmpty) return;
    if (!AppConfig.hasApiKey) {
      throw TtsException(
          'No Groq API key was built into this app, so the voice is '
          'unavailable. See the README for --dart-define=GROQ_API_KEY.');
    }

    final myToken = ++_token;
    await _player.stop();
    // Release any previous speak() loop that may still be awaiting a chunk.
    _finishChunk();

    final chunks = _chunkText(clean, AppConfig.ttsMaxChars);
    for (var i = 0; i < chunks.length; i++) {
      if (myToken != _token) return; // superseded by a newer speak()
      final bytes = await _synthesize(chunks[i], voice);
      if (myToken != _token) return;

      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/tts_${myToken}_$i.wav';
      await File(path).writeAsBytes(_repairWavHeader(bytes));

      final done = Completer<void>();
      _chunkDone = done;
      try {
        await _player.play(DeviceFileSource(path));
        // Rate must be set once the source is loaded; a platform that refuses
        // the call should still play at normal speed rather than go silent.
        try {
          await _player.setPlaybackRate(AppConfig.ttsPlaybackSpeed);
        } catch (_) {}
      } catch (e) {
        _chunkDone = null;
        throw TtsException('Could not play the voice audio. ($e)');
      }

      // Wait for the chunk, but never hang forever if the completion event is
      // missed — cap the wait at a generous multiple of the audio's duration.
      await done.future.timeout(
        _estimateDuration(bytes) + const Duration(seconds: 10),
        onTimeout: () {},
      );
    }
  }

  /// Groq streams its WAV responses, so the `RIFF` and `data` chunk sizes come
  /// back as the placeholder 0xFFFFFFFF instead of the real byte counts.
  /// Android's MediaPlayer rejects a `data` size larger than the file and plays
  /// nothing, so the sizes are rewritten to match what actually arrived.
  Uint8List _repairWavHeader(List<int> raw) {
    final bytes = Uint8List.fromList(raw);
    if (bytes.length < 44) return bytes;

    final view = ByteData.sublistView(bytes);
    bool tagAt(int offset, String tag) {
      for (var i = 0; i < tag.length; i++) {
        if (bytes[offset + i] != tag.codeUnitAt(i)) return false;
      }
      return true;
    }

    if (!tagAt(0, 'RIFF') || !tagAt(8, 'WAVE')) return bytes;
    view.setUint32(4, bytes.length - 8, Endian.little);

    // Walk the chunk list to the audio payload, fixing its declared length.
    var pos = 12;
    while (pos + 8 <= bytes.length) {
      final size = view.getUint32(pos + 4, Endian.little);
      final available = bytes.length - (pos + 8);
      if (tagAt(pos, 'data')) {
        if (size > available) view.setUint32(pos + 4, available, Endian.little);
        break;
      }
      if (size > available) break; // malformed chunk — leave the rest alone
      pos += 8 + size + (size.isOdd ? 1 : 0);
    }
    return bytes;
  }

  /// Rough playback length from the PCM byte count, used only to bound the wait
  /// for a chunk to finish. Assumes the 24 kHz mono 16-bit audio Orpheus emits.
  Duration _estimateDuration(List<int> bytes) {
    const bytesPerSecond = 24000 * 2;
    final seconds = bytes.length / bytesPerSecond / AppConfig.ttsPlaybackSpeed;
    return Duration(milliseconds: (seconds * 1000).ceil());
  }

  Future<List<int>> _synthesize(String text, String voice) async {
    late http.Response res;
    try {
      res = await _client
          .post(
            Uri.parse(AppConfig.ttsUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${AppConfig.apiKey}',
            },
            body: jsonEncode({
              'model': AppConfig.ttsModel,
              'voice': voice,
              'input': text,
              'response_format': 'wav',
            }),
          )
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      throw TtsException('Could not reach the voice service. ($e)');
    }

    if (res.statusCode == 200) return res.bodyBytes;
    throw TtsException('Voice service error ${res.statusCode}: ${res.body}');
  }

  /// Splits [text] into pieces no longer than [maxLen], preferring sentence
  /// boundaries and falling back to word boundaries for very long sentences.
  List<String> _chunkText(String text, int maxLen) {
    if (text.length <= maxLen) return [text];

    final sentences = text.split(RegExp(r'(?<=[.!?])\s+'));
    final chunks = <String>[];
    var current = '';

    void flush() {
      if (current.trim().isNotEmpty) chunks.add(current.trim());
      current = '';
    }

    for (final sentence in sentences) {
      if (sentence.length > maxLen) {
        flush();
        var part = '';
        for (final word in sentence.split(' ')) {
          final candidate = part.isEmpty ? word : '$part $word';
          if (candidate.length > maxLen) {
            if (part.isNotEmpty) chunks.add(part);
            part = word;
          } else {
            part = candidate;
          }
        }
        current = part;
      } else {
        final candidate = current.isEmpty ? sentence : '$current $sentence';
        if (candidate.length > maxLen) {
          flush();
          current = sentence;
        } else {
          current = candidate;
        }
      }
    }
    flush();
    return chunks;
  }

  /// Releases whoever is awaiting the current chunk, exactly once.
  void _finishChunk() {
    final done = _chunkDone;
    _chunkDone = null;
    if (done != null && !done.isCompleted) done.complete();
  }

  Future<void> stop() async {
    _token++; // invalidate any running loop
    _finishChunk();
    await _player.stop();
  }

  void dispose() => _player.dispose();
}
