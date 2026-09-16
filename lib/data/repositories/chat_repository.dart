import 'package:sqflite/sqflite.dart';

import '../local/database_helper.dart';
import '../models/chat_message.dart';
import '../models/chat_session.dart';

/// A conversation plus the counts the history and admin screens need, so those
/// lists do not have to load every message just to render a row.
class SessionSummary {
  final ChatSession session;
  final int messageCount;

  /// First thing the user actually said, used as the row's preview.
  final String? preview;
  final DateTime lastActivity;
  final bool hasCrisis;

  const SessionSummary({
    required this.session,
    required this.messageCount,
    required this.preview,
    required this.lastActivity,
    required this.hasCrisis,
  });
}

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

  Future<ChatSession?> getSession(int sessionId) async {
    final db = await _dbHelper.database;
    final rows = await db
        .query('sessions', where: 'id = ?', whereArgs: [sessionId], limit: 1);
    return rows.isEmpty ? null : ChatSession.fromMap(rows.first);
  }

  Future<void> renameSession(int sessionId, String title) async {
    final db = await _dbHelper.database;
    await db.update('sessions', {'title': title},
        where: 'id = ?', whereArgs: [sessionId]);
  }

  /// Every conversation with its message count, first user message, and last
  /// activity — one query rather than N+1 lookups per row.
  Future<List<SessionSummary>> getSessionSummaries() async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT s.id, s.title, s.created_at,
             COUNT(m.id)                        AS message_count,
             MAX(m.created_at)                  AS last_activity,
             MAX(COALESCE(m.is_crisis, 0))      AS has_crisis,
             (SELECT text FROM messages
               WHERE session_id = s.id AND sender = 'user'
               ORDER BY created_at ASC LIMIT 1) AS preview
      FROM sessions s
      LEFT JOIN messages m ON m.session_id = s.id
      GROUP BY s.id
      ORDER BY COALESCE(MAX(m.created_at), s.created_at) DESC
    ''');

    return rows.map((r) {
      final created = DateTime.parse(r['created_at'] as String);
      final last = r['last_activity'] as String?;
      return SessionSummary(
        session: ChatSession(
          id: r['id'] as int,
          title: r['title'] as String,
          createdAt: created,
        ),
        messageCount: (r['message_count'] as int?) ?? 0,
        preview: r['preview'] as String?,
        lastActivity: last == null ? created : DateTime.parse(last),
        hasCrisis: ((r['has_crisis'] as int?) ?? 0) == 1,
      );
    }).toList();
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
  /// [crisisOnly] and [sender] narrow the view; [query] matches message text.
  Future<List<ChatMessage>> getRecentMessages({
    int limit = 100,
    bool crisisOnly = false,
    Sender? sender,
    String? query,
  }) async {
    final db = await _dbHelper.database;

    final clauses = <String>[];
    final args = <Object?>[];
    if (crisisOnly) clauses.add('is_crisis = 1');
    if (sender != null) {
      clauses.add('sender = ?');
      args.add(sender.name);
    }
    if (query != null && query.trim().isNotEmpty) {
      clauses.add('text LIKE ?');
      args.add('%${query.trim()}%');
    }

    final rows = await db.query(
      'messages',
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(ChatMessage.fromMap).toList();
  }

  // ---- Admin analytics ----------------------------------------------------

  /// Headline counts for the admin Overview tab, in one round trip each.
  Future<AdminStats> getStats() async {
    final db = await _dbHelper.database;

    Future<int> count(String sql) async =>
        Sqflite.firstIntValue(await db.rawQuery(sql)) ?? 0;

    final lastRows = await db.query('messages',
        columns: ['created_at'], orderBy: 'created_at DESC', limit: 1);

    return AdminStats(
      sessions: await count('SELECT COUNT(*) FROM sessions'),
      messages: await count('SELECT COUNT(*) FROM messages'),
      userMessages:
          await count("SELECT COUNT(*) FROM messages WHERE sender = 'user'"),
      crisisFlags: await count('SELECT COUNT(*) FROM messages WHERE is_crisis = 1'),
      lastActivity: lastRows.isEmpty
          ? null
          : DateTime.parse(lastRows.first['created_at'] as String),
    );
  }

  /// How often each emotion was detected, most frequent first. Drives the
  /// sentiment breakdown on the Overview tab.
  Future<Map<String, int>> getEmotionBreakdown() async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT emotion, COUNT(*) AS n
      FROM messages
      WHERE emotion IS NOT NULL AND emotion != ''
      GROUP BY emotion
      ORDER BY n DESC
    ''');
    return {
      for (final r in rows) r['emotion'] as String: r['n'] as int,
    };
  }
}

/// Aggregate counts shown on the admin Overview tab.
class AdminStats {
  final int sessions;
  final int messages;
  final int userMessages;
  final int crisisFlags;
  final DateTime? lastActivity;

  const AdminStats({
    required this.sessions,
    required this.messages,
    required this.userMessages,
    required this.crisisFlags,
    required this.lastActivity,
  });
}
