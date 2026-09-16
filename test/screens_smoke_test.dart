import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mental_health_chatbot/controllers/chat_controller.dart';
import 'package:mental_health_chatbot/data/local/database_helper.dart';
import 'package:mental_health_chatbot/data/models/chat_message.dart';
import 'package:mental_health_chatbot/data/repositories/chat_repository.dart';
import 'package:mental_health_chatbot/services/ai_service.dart';
import 'package:mental_health_chatbot/services/article_service.dart';
import 'package:mental_health_chatbot/services/auth_service.dart';
import 'package:mental_health_chatbot/services/crisis_detector.dart';
import 'package:mental_health_chatbot/services/settings_service.dart';
import 'package:mental_health_chatbot/ui/screens/admin_screen.dart';
import 'package:mental_health_chatbot/ui/screens/history_screen.dart';
import 'package:mental_health_chatbot/ui/screens/resources_screen.dart';

/// Full schema, in memory — mirrors DatabaseHelper's v4 tables.
class _InMemoryDb implements DatabaseHelper {
  Database? _db;

  @override
  Future<Database> get database async =>
      // No-isolate factory: inside testWidgets' binding, the isolate-backed
      // factory never completes its futures, so pumpAndSettle spins forever.
      _db ??= await databaseFactoryFfiNoIsolate.openDatabase(
          inMemoryDatabasePath,
          options: OpenDatabaseOptions(
            version: 4,
            onCreate: (db, _) async {
              await db.execute('''CREATE TABLE sessions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL, created_at TEXT NOT NULL)''');
              await db.execute('''CREATE TABLE messages (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                session_id INTEGER NOT NULL, sender TEXT NOT NULL,
                text TEXT NOT NULL, emotion TEXT,
                is_crisis INTEGER NOT NULL DEFAULT 0,
                created_at TEXT NOT NULL)''');
              await db.execute('''CREATE TABLE app_settings (
                key TEXT PRIMARY KEY, value TEXT NOT NULL)''');
              await db.execute('''CREATE TABLE users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                full_name TEXT NOT NULL, email TEXT NOT NULL UNIQUE,
                password_hash TEXT NOT NULL, salt TEXT NOT NULL,
                is_admin INTEGER NOT NULL DEFAULT 0,
                created_at TEXT NOT NULL)''');
              await db.execute('''CREATE TABLE articles (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL, summary TEXT NOT NULL,
                link TEXT NOT NULL, source TEXT NOT NULL,
                topic TEXT NOT NULL, published TEXT NOT NULL,
                fetched_at TEXT NOT NULL)''');
            },
          ));

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _feedXml = '''<?xml version="1.0"?><rss version="2.0"><channel>
  <item><title>A study about worry</title>
    <link>https://example.com/1</link>
    <description>Researchers looked at worry.</description>
    <pubDate>Wed, 26 Aug 2026 03:28:27 EDT</pubDate></item>
</channel></rss>''';

void main() {
  sqfliteFfiInit();

  late _InMemoryDb db;
  late ChatRepository repo;
  late AuthService auth;
  late ChatController controller;

  setUp(() {
    db = _InMemoryDb();
    repo = ChatRepository(db);
    auth = AuthService(db);
    controller = ChatController(
        repo, AiService(), CrisisDetector(), SettingsService(db));
  });

  tearDown(() async => (await db.database).close());

  Widget wrap(Widget child, {ArticleService? articles}) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: controller),
          Provider.value(value: repo),
          Provider.value(value: auth),
          Provider.value(
              value: articles ??
                  ArticleService(db,
                      client: MockClient(
                          (_) async => http.Response(_feedXml, 200)))),
        ],
        child: MaterialApp(home: child),
      );

  Future<void> seed() async {
    await auth.seedDefaultAdmin();
    final s = await repo.createSession('Exam worries');
    await repo.addMessage(ChatMessage(
        sessionId: s.id!,
        sender: Sender.user,
        text: 'I am anxious about exams',
        createdAt: DateTime(2026, 9, 1, 10)));
    await repo.addMessage(ChatMessage(
        sessionId: s.id!,
        sender: Sender.bot,
        text: 'That sounds hard.',
        emotion: 'anxious',
        createdAt: DateTime(2026, 9, 1, 10, 1)));
  }

  testWidgets('AdminScreen renders every tab against a real database',
      (tester) async {
    // Tall viewport so the whole Overview tab builds without scrolling.
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await seed();
    await tester.pumpWidget(wrap(const AdminScreen()));
    await tester.pumpAndSettle();

    // Overview: stat cards plus the sentiment breakdown.
    expect(find.text('Registered users'), findsOneWidget);
    expect(find.text('Conversations'), findsWidgets);
    expect(find.text('Detected emotions'), findsOneWidget);
    expect(find.text('anxious'), findsOneWidget);
    expect(tester.takeException(), isNull);

    for (final tab in ['Users', 'Conversations', 'Logs']) {
      await tester.tap(find.widgetWithText(Tab, tab));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$tab tab threw');
    }

    // Logs tab is showing; both messages should be listed.
    expect(find.textContaining('I am anxious about exams'), findsOneWidget);
  });

  testWidgets('admin Users tab lists the seeded admin', (tester) async {
    await seed();
    await tester.pumpWidget(wrap(const AdminScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Users'));
    await tester.pumpAndSettle();

    expect(find.text('Administrator'), findsOneWidget);
    expect(find.textContaining('admin@mindful.app'), findsOneWidget);
  });

  testWidgets('HistoryScreen lists past conversations and can reopen one',
      (tester) async {
    await seed();
    await tester.pumpWidget(wrap(const HistoryScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Exam worries'), findsOneWidget);
    expect(find.textContaining('2 messages'), findsOneWidget);
    expect(find.textContaining('I am anxious about exams'), findsOneWidget);

    await tester.tap(find.text('Exam worries'));
    await tester.pumpAndSettle();

    // Reopening loads that conversation into the controller.
    expect(controller.messages.length, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('HistoryScreen shows an empty state with no conversations',
      (tester) async {
    await tester.pumpWidget(wrap(const HistoryScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('No conversations yet'), findsOneWidget);
  });

  testWidgets('deleting the open conversation recovers instead of stranding it',
      (tester) async {
    await seed();
    // Open the seeded conversation, as the chat screen would have.
    await controller.loadLastSessionOrStart();
    final openId = controller.sessionId;
    expect(openId, isNotNull);

    await tester.pumpWidget(wrap(const HistoryScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    // The row is gone, and the controller moved to a fresh session rather than
    // holding messages that no longer exist.
    expect(find.text('Exam worries'), findsNothing);
    expect(controller.sessionId, isNot(openId));
    expect(await repo.getMessages(openId!), isEmpty);
    expect(controller.messages, isNotEmpty); // a greeting in the new session
    expect(tester.takeException(), isNull);
  });

  testWidgets('renaming a conversation persists and re-renders', (tester) async {
    await seed();
    await tester.pumpWidget(wrap(const HistoryScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'Before my exam');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Before my exam'), findsOneWidget);
    expect(find.text('Exam worries'), findsNothing);
  });

  testWidgets('ResourcesScreen shows guides offline and live articles',
      (tester) async {
    await tester.pumpWidget(wrap(const ResourcesScreen()));
    await tester.pumpAndSettle();

    // Guides tab: curated content, no network involved.
    expect(find.text('Understanding Anxiety'), findsOneWidget);

    await tester.tap(find.widgetWithText(Tab, 'Latest'));
    await tester.pumpAndSettle();

    expect(find.text('A study about worry'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Latest tab degrades to an error state when offline',
      (tester) async {
    final offline = ArticleService(db,
        client: MockClient((_) async => throw Exception('no network')));
    await tester.pumpWidget(wrap(const ResourcesScreen(), articles: offline));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(Tab, 'Latest'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not load articles'), findsOneWidget);
    // The offline-safe guides are still reachable.
    expect(find.textContaining('Guides tab works offline'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
