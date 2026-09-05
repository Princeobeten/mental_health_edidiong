/// Domain model for a single chat message (an OOADM "object" — Chapter 3).
enum Sender { user, bot }

class ChatMessage {
  final int? id;
  final int sessionId;
  final Sender sender;
  final String text;

  /// Detected emotional tone for this message (sentiment analysis result).
  /// e.g. "negative", "neutral", "positive", or a finer label like "anxious".
  final String? emotion;

  /// True when the local CrisisDetector flagged this message as high-risk.
  final bool isCrisis;

  final DateTime createdAt;

  ChatMessage({
    this.id,
    required this.sessionId,
    required this.sender,
    required this.text,
    this.emotion,
    this.isCrisis = false,
    required this.createdAt,
  });

  ChatMessage copyWith({int? id}) => ChatMessage(
        id: id ?? this.id,
        sessionId: sessionId,
        sender: sender,
        text: text,
        emotion: emotion,
        isCrisis: isCrisis,
        createdAt: createdAt,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'session_id': sessionId,
        'sender': sender.name,
        'text': text,
        'emotion': emotion,
        'is_crisis': isCrisis ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };

  factory ChatMessage.fromMap(Map<String, Object?> map) => ChatMessage(
        id: map['id'] as int?,
        sessionId: map['session_id'] as int,
        sender: Sender.values.firstWhere((s) => s.name == map['sender']),
        text: map['text'] as String,
        emotion: map['emotion'] as String?,
        isCrisis: (map['is_crisis'] as int? ?? 0) == 1,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
