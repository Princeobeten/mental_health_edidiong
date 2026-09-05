import '../local/database_helper.dart';
import '../models/chat_message.dart';
import '../models/chat_session.dart';

/// Repository that hides SQLite behind a clean interface (OOADM encapsulation).
/// The controller talks to this, never to the raw database.
class ChatRepository {
  final DatabaseHelper _dbHelper;
  ChatRepository(this._dbHelper);

  // ---- Sessions ----------------------------------------------------------
  Future<ChatSession> createSession(String title) async {
    final db = await _dbHelper.database;
    final session = ChatSession(title: title, createdAt: DateTime.now());
    final id = await db.insert('sessions', session.toMap()..remove('id'));
    return ChatSession(id: id, title: title, createdAt: session.createdAt);
  }

  Future<List<ChatSession>> getSessions() async {
    final db = await _dbHelper.database;
    final rows = await db.query('sessions', orderBy: 'created_at DESC');
    return rows.map(ChatSession.fromMap).toList();
  }

  Future<void> deleteSession(int sessionId) async {
    final db = await _dbHelper.database;
    await db.delete('messages', where: 'session_id = ?', whereArgs: [sessionId]);
    await db.delete('sessions', where: 'id = ?', whereArgs: [sessionId]);
  }

  // ---- Messages ----------------------------------------------------------
  Future<ChatMessage> addMessage(ChatMessage message) async {
    final db = await _dbHelper.database;
    final id = await db.insert('messages', message.toMap()..remove('id'));
    return message.copyWith(id: id);
  }

  Future<List<ChatMessage>> getMessages(int sessionId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'messages',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at ASC',
    );
    return rows.map(ChatMessage.fromMap).toList();
  }

  /// Most recent messages across all sessions (for the Admin chatbot-logs view).
  Future<List<ChatMessage>> getRecentMessages({int limit = 100}) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'messages',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(ChatMessage.fromMap).toList();
  }
}
