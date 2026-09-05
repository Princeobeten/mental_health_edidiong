/// A conversation session. Privacy-by-design (Chapter 1.5): a session groups
/// messages but stores no personally identifying user profile.
class ChatSession {
  final int? id;
  final String title;
  final DateTime createdAt;

  ChatSession({this.id, required this.title, required this.createdAt});

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'created_at': createdAt.toIso8601String(),
      };

  factory ChatSession.fromMap(Map<String, Object?> map) => ChatSession(
        id: map['id'] as int?,
        title: map['title'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
