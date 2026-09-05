/// Local, offline crisis-detection module (Chapter 3.4: addressing the
/// "lack of crisis handling" weakness of existing systems).
///
/// This is a deliberately simple, rule/lexicon-based NLP component. It runs
/// BEFORE any network call so that high-risk messages are caught even if the
/// device is offline or the AI API is unreachable. It does not diagnose; it
/// only decides whether to surface emergency helpline resources.
class CrisisDetector {
  // Phrases that strongly indicate self-harm / suicidal ideation.
  static const List<String> _highRiskPhrases = [
    'kill myself',
    'killing myself',
    'end my life',
    'ending my life',
    'want to die',
    'wanna die',
    'better off dead',
    'suicide',
    'suicidal',
    'hurt myself',
    'harm myself',
    'self harm',
    'self-harm',
    'cut myself',
    'no reason to live',
    'no point in living',
    'take my own life',
    "can't go on",
    'cannot go on',
  ];

  /// Returns true if the text contains a high-risk indicator.
  bool isCrisis(String text) {
    final normalized = text.toLowerCase();
    return _highRiskPhrases.any(normalized.contains);
  }
}
