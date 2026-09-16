import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mental_health_chatbot/data/local/database_helper.dart';
import 'package:mental_health_chatbot/data/models/chat_message.dart';
import 'package:mental_health_chatbot/data/repositories/chat_repository.dart';
import 'package:mental_health_chatbot/services/auth_service.dart';

/// Backs DatabaseHelper with a fresh in-memory SQLite database per test.
class _InMemoryDb implements DatabaseHelper {
  Database? _db;

  @override
  Future<Database> get database async => _db ??= await databaseFactoryFfi
      .openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(
        version: 4,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE sessions (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT NOT NULL,
              created_at TEXT NOT NULL)''');
          await db.execute('''
            CREATE TABLE messages (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              session_id INTEGER NOT NULL,
              sender TEXT NOT NULL,
              text TEXT NOT NULL,
              emotion TEXT,
              is_crisis INTEGER NOT NULL DEFAULT 0,
              created_at TEXT NOT NULL)''');
          await db.execute('''
            CREATE TABLE app_settings (
              key TEXT PRIMARY KEY, value TEXT NOT NULL)''');
          await db.execute('''
            CREATE TABLE users (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              full_name TEXT NOT NULL,
              email TEXT NOT NULL UNIQUE,
              password_hash TEXT NOT NULL,
              salt TEXT NOT NULL,
              is_admin INTEGER NOT NULL DEFAULT 0,
              created_at TEXT NOT NULL)''');
        },
      ));

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  sqfliteFfiInit();

  late _InMemoryDb db;
  late AuthService auth;
  late ChatRepository repo;

  setUp(() {
    db = _InMemoryDb();
    auth = AuthService(db);
    repo = ChatRepository(db);
  });

  tearDown(() async => (await db.database).close());

  group('AuthService admin guards', () {
    test('seedDefaultAdmin is idempotent', () async {
      await auth.seedDefaultAdmin();
      await auth.seedDefaultAdmin();
      expect((await auth.getAllUsers()).length, 1);
      expect(await auth.countAdmins(), 1);
    });

    test('seeded admin can log in with the documented credentials', () async {
      await auth.seedDefaultAdmin();
      final user = await auth.login('admin@mindful.app', 'Admin@1234');
      expect(user.isAdmin, isTrue);
    });

    test('login rejects a wrong password', () async {
      await auth.seedDefaultAdmin();
      expect(() => auth.login('admin@mindful.app', 'wrong'),
          throwsA(isA<AuthException>()));
    });

    test('cannot revoke admin from the only admin', () async {
      await auth.seedDefaultAdmin();
      final admin = (await auth.getAllUsers()).first;
      expect(() => auth.setAdmin(admin.id!, false),
          throwsA(isA<AuthException>()));
      expect(await auth.countAdmins(), 1);
    });

    test('cannot delete the only admin', () async {
      await auth.seedDefaultAdmin();
      final admin = (await auth.getAllUsers()).first;
      expect(() => auth.deleteUser(admin.id!), throwsA(isA<AuthException>()));
      expect((await auth.getAllUsers()).length, 1);
    });

    test('cannot delete the account you are signed in as', () async {
      await auth.seedDefaultAdmin();
      final me = await auth.register(
          fullName: 'Ada', email: 'ada@example.com', password: 'secret1');
      // register() signs the new user in.
      expect(() => auth.deleteUser(me.id!), throwsA(isA<AuthException>()));
    });

    test('promoting a second admin then revoking the first is allowed',
        () async {
      await auth.seedDefaultAdmin();
      final other = await auth.register(
          fullName: 'Ada', email: 'ada@example.com', password: 'secret1');
      final admin = (await auth.getAllUsers())
          .firstWhere((u) => u.email == 'admin@mindful.app');

      await auth.setAdmin(other.id!, true);
      await auth.setAdmin(admin.id!, false);

      expect(await auth.countAdmins(), 1);
      expect((await auth.getUser(other.id!))!.isAdmin, isTrue);
    });

    test('resetPassword re-salts and the new password works', () async {
      await auth.seedDefaultAdmin();
      final admin = (await auth.getAllUsers()).first;

      await auth.resetPassword(admin.id!, 'BrandNew1');
      final loggedIn = await auth.login('admin@mindful.app', 'BrandNew1');

      expect(loggedIn.id, admin.id);
      expect(() => auth.login('admin@mindful.app', 'Admin@1234'),
          throwsA(isA<AuthException>()));
    });

    test('resetPassword rejects a short password', () async {
      await auth.seedDefaultAdmin();
      final admin = (await auth.getAllUsers()).first;
      expect(() => auth.resetPassword(admin.id!, 'abc'),
          throwsA(isA<AuthException>()));
    });
  });

  group('ChatRepository history and analytics', () {
    Future<void> seedConversation({
      required String title,
      required List<(Sender, String, bool)> messages,
    }) async {
      final session = await repo.createSession(title);
      var t = DateTime(2026, 9, 1, 10);
      for (final (sender, text, crisis) in messages) {
        await repo.addMessage(ChatMessage(
          sessionId: session.id!,
          sender: sender,
          text: text,
          emotion: sender == Sender.bot ? (crisis ? 'crisis' : 'anxious') : null,
          isCrisis: crisis,
          createdAt: t = t.add(const Duration(minutes: 1)),
        ));
      }
    }

    test('getSessionSummaries reports counts, preview and crisis flag',
        () async {
      await seedConversation(title: 'Exams', messages: [
        (Sender.bot, 'Hello, I am Mindful.', false),
        (Sender.user, 'I am anxious about exams', false),
        (Sender.bot, 'That sounds hard.', false),
      ]);
      await seedConversation(title: 'Rough night', messages: [
        (Sender.user, 'I want to die', true),
      ]);

      final summaries = await repo.getSessionSummaries();
      expect(summaries.length, 2);

      final exams = summaries.firstWhere((s) => s.session.title == 'Exams');
      expect(exams.messageCount, 3);
      // Preview is the first USER message, not the bot greeting.
      expect(exams.preview, 'I am anxious about exams');
      expect(exams.hasCrisis, isFalse);

      final rough =
          summaries.firstWhere((s) => s.session.title == 'Rough night');
      expect(rough.hasCrisis, isTrue);
    });

    test('a session with no messages still appears', () async {
      await repo.createSession('Empty');
      final summaries = await repo.getSessionSummaries();
      expect(summaries.single.messageCount, 0);
      expect(summaries.single.preview, isNull);
    });

    test('renameSession persists', () async {
      final s = await repo.createSession('New conversation');
      await repo.renameSession(s.id!, 'Exam worries');
      expect((await repo.getSession(s.id!))!.title, 'Exam worries');
    });

    test('deleteSession removes its messages too', () async {
      await seedConversation(title: 'Gone', messages: [
        (Sender.user, 'hello', false),
        (Sender.bot, 'hi', false),
      ]);
      final id = (await repo.getSessionSummaries()).single.session.id!;

      await repo.deleteSession(id);

      expect(await repo.getSessionSummaries(), isEmpty);
      expect(await repo.getMessages(id), isEmpty);
      expect((await repo.getStats()).messages, 0);
    });

    test('getStats counts sessions, messages and crisis flags', () async {
      await seedConversation(title: 'A', messages: [
        (Sender.user, 'hi', false),
        (Sender.bot, 'hello', false),
      ]);
      await seedConversation(title: 'B', messages: [
        (Sender.user, 'I want to die', true),
        (Sender.bot, 'Please reach out', true),
      ]);

      final stats = await repo.getStats();
      expect(stats.sessions, 2);
      expect(stats.messages, 4);
      expect(stats.userMessages, 2);
      expect(stats.crisisFlags, 2);
      expect(stats.lastActivity, isNotNull);
    });

    test('getStats on an empty database returns zeros, not null', () async {
      final stats = await repo.getStats();
      expect(stats.sessions, 0);
      expect(stats.messages, 0);
      expect(stats.lastActivity, isNull);
    });

    test('getEmotionBreakdown groups and orders by frequency', () async {
      await seedConversation(title: 'A', messages: [
        (Sender.bot, 'a', false),
        (Sender.bot, 'b', false),
        (Sender.bot, 'c', true),
      ]);
      final emotions = await repo.getEmotionBreakdown();
      expect(emotions['anxious'], 2);
      expect(emotions['crisis'], 1);
      expect(emotions.keys.first, 'anxious'); // most frequent first
    });

    test('log filters narrow by crisis, sender and text', () async {
      await seedConversation(title: 'A', messages: [
        (Sender.user, 'exam stress is bad', false),
        (Sender.bot, 'tell me more about exams', false),
        (Sender.user, 'I want to die', true),
      ]);

      expect((await repo.getRecentMessages()).length, 3);
      expect((await repo.getRecentMessages(crisisOnly: true)).length, 1);
      expect((await repo.getRecentMessages(sender: Sender.user)).length, 2);
      expect((await repo.getRecentMessages(query: 'exam')).length, 2);
      expect(
        (await repo.getRecentMessages(sender: Sender.user, query: 'exam'))
            .length,
        1,
      );
    });
  });
}
