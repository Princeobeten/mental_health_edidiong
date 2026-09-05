import 'package:sqflite/sqflite.dart';

import '../core/constants.dart';
import '../data/local/database_helper.dart';

/// Which voice persona reads the AI's replies aloud.
enum VoiceGender { female, male }

/// Provides the AI API key/model (built into [AppConfig]) and stores small user
/// preferences (like the chosen voice) locally in SQLite.
class SettingsService {
  final DatabaseHelper _dbHelper;
  SettingsService(this._dbHelper);

  static const _voiceKey = 'voice_gender';

  Future<String> getApiKey() async => AppConfig.apiKey;
  Future<String> getModel() async => AppConfig.defaultModel;

  Future<VoiceGender> getVoiceGender() async {
    final db = await _dbHelper.database;
    final rows = await db.query('app_settings',
        where: 'key = ?', whereArgs: [_voiceKey], limit: 1);
    if (rows.isEmpty) return VoiceGender.female;
    return rows.first['value'] == 'male' ? VoiceGender.male : VoiceGender.female;
  }

  Future<void> setVoiceGender(VoiceGender gender) async {
    final db = await _dbHelper.database;
    await db.insert(
      'app_settings',
      {'key': _voiceKey, 'value': gender.name},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// The Groq voice id for the given gender.
  String voiceIdFor(VoiceGender gender) =>
      gender == VoiceGender.male ? AppConfig.maleVoice : AppConfig.femaleVoice;
}
