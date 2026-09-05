import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../core/constants.dart';

class SpeechException implements Exception {
  final String message;
  SpeechException(this.message);
  @override
  String toString() => message;
}

/// Voice input. Records the user's speech to an audio file, then transcribes it
/// with Groq's Whisper model (more accurate than on-device recognition).
class SpeechService {
  final AudioRecorder _recorder = AudioRecorder();
  String? _path;

  /// Live microphone level, for drawing the recording waveform.
  Stream<Amplitude> get amplitude =>
      _recorder.onAmplitudeChanged(const Duration(milliseconds: 120));

  Future<bool> hasPermission() => _recorder.hasPermission();

  /// Begins recording. Returns false if microphone permission was denied.
  Future<bool> start() async {
    if (!await _recorder.hasPermission()) return false;
    final dir = await getTemporaryDirectory();
    _path = '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.wav';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.wav, numChannels: 1),
      path: _path!,
    );
    return true;
  }

  /// Stops recording and returns the transcribed text from Groq Whisper.
  Future<String> stopAndTranscribe() async {
    final path = await _recorder.stop();
    if (path == null) throw SpeechException('Recording failed.');
    return _transcribe(path);
  }

  /// Stops and discards the recording (no transcription).
  Future<void> cancel() async {
    if (await _recorder.isRecording()) await _recorder.stop();
  }

  Future<String> _transcribe(String path) async {
    if (!AppConfig.hasApiKey) {
      throw SpeechException(
          'No Groq API key was built into this app, so voice input is '
          'unavailable. See the README for --dart-define=GROQ_API_KEY.');
    }
    http.StreamedResponse streamed;
    try {
      final req = http.MultipartRequest('POST', Uri.parse(AppConfig.sttUrl))
        ..headers['Authorization'] = 'Bearer ${AppConfig.apiKey}'
        ..fields['model'] = AppConfig.sttModel
        ..fields['response_format'] = 'json'
        ..fields['language'] = 'en'
        ..files.add(await http.MultipartFile.fromPath('file', path));
      streamed = await req.send().timeout(const Duration(seconds: 45));
    } catch (e) {
      throw SpeechException('Could not reach the transcription service. ($e)');
    }

    final res = await http.Response.fromStream(streamed);
    if (res.statusCode != 200) {
      throw SpeechException('Transcription error ${res.statusCode}: ${res.body}');
    }
    final obj = jsonDecode(res.body) as Map<String, dynamic>;
    return (obj['text'] as String? ?? '').trim();
  }

  Future<void> dispose() => _recorder.dispose();
}
