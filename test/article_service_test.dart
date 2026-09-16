import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mental_health_chatbot/data/local/database_helper.dart';
import 'package:mental_health_chatbot/services/article_service.dart';

/// Backs DatabaseHelper with a fresh in-memory database holding just the
/// articles cache table.
class _InMemoryDb implements DatabaseHelper {
  Database? _db;

  @override
  Future<Database> get database async =>
      _db ??= await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
          options: OpenDatabaseOptions(
            version: 4,
            onCreate: (db, _) async => db.execute('''
              CREATE TABLE articles (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                summary TEXT NOT NULL,
                link TEXT NOT NULL,
                source TEXT NOT NULL,
                topic TEXT NOT NULL,
                published TEXT NOT NULL,
                fetched_at TEXT NOT NULL)'''),
          ));

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Shape of a real ScienceDaily item.
const _scienceDaily = '''<?xml version="1.0"?>
<rss version="2.0"><channel>
  <title>Anxiety News -- ScienceDaily</title>
  <item>
    <title>Childhood trauma may leave a lasting scar</title>
    <link>https://www.sciencedaily.com/releases/2026/08/260823094151.htm</link>
    <description>Early-life stress may physically alter how DNA is packaged.</description>
    <pubDate>Wed, 26 Aug 2026 03:28:27 EDT</pubDate>
  </item>
  <item>
    <title>Second study</title>
    <link>https://www.sciencedaily.com/releases/2026/08/x.htm</link>
    <description>Another finding.</description>
    <pubDate>Tue, 25 Aug 2026 10:00:00 EDT</pubDate>
  </item>
</channel></rss>''';

/// WordPress shape: CDATA, HTML, and the trailing "The post ..." credit.
const _wordpress = '''<?xml version="1.0"?>
<rss version="2.0"><channel>
  <item>
    <title>The Circuitous Path of a Meditation Teacher</title>
    <link>https://www.mindful.org/unexpected-meditation-teacher/</link>
    <description><![CDATA[<p>Billy shares how he became a champion of meditation &amp; made a movie.</p>
<p>The post <a href="https://www.mindful.org/x/">A Teacher</a> appeared first on <a href="https://www.mindful.org">Mindful</a>.</p>]]></description>
    <pubDate>Tue, 15 Sep 2026 17:16:00 +0000</pubDate>
  </item>
</channel></rss>''';

void main() {
  sqfliteFfiInit();

  const feed =
      FeedSource(topic: 'Anxiety', source: 'ScienceDaily', url: 'https://x/a');

  group('RSS parsing', () {
    test('reads title, link, summary and RFC-822 date', () {
      final out = ArticleService.parseFeed(_scienceDaily, feed);
      expect(out.length, 2);

      final a = out.first;
      expect(a.title, 'Childhood trauma may leave a lasting scar');
      expect(a.link, contains('sciencedaily.com'));
      expect(a.summary, 'Early-life stress may physically alter how DNA is packaged.');
      expect(a.topic, 'Anxiety');
      expect(a.source, 'ScienceDaily');
      expect(a.published, DateTime(2026, 8, 26, 3, 28, 27));
    });

    test('strips HTML, decodes entities, drops WordPress credit line', () {
      final out = ArticleService.parseFeed(_wordpress,
          const FeedSource(topic: 'Mindfulness', source: 'Mindful.org', url: ''));

      final summary = out.single.summary;
      expect(summary, isNot(contains('<')));
      expect(summary, isNot(contains('&amp;')));
      expect(summary, contains('champion of meditation & made a movie'));
      expect(summary.toLowerCase(), isNot(contains('appeared first on')));
    });

    test('skips entries with no title or link', () {
      const broken = '''<?xml version="1.0"?><rss><channel>
        <item><description>orphan</description></item>
        <item><title>Fine</title><link>https://e.com/1</link></item>
      </channel></rss>''';
      final out = ArticleService.parseFeed(broken, feed);
      expect(out.single.title, 'Fine');
    });

    test('falls back to now when pubDate is missing or unparseable', () {
      const noDate = '''<?xml version="1.0"?><rss><channel>
        <item><title>T</title><link>https://e.com/1</link>
        <pubDate>not a date</pubDate></item>
      </channel></rss>''';
      final out = ArticleService.parseFeed(noDate, feed);
      expect(out.single.published.difference(DateTime.now()).inSeconds.abs(),
          lessThan(5));
    });

    test('throws a clear error on malformed XML', () {
      expect(() => ArticleService.parseFeed('<rss><channel>', feed),
          throwsA(isA<ArticleException>()));
    });

    test('caps each feed at perTopicLimit', () {
      final many = StringBuffer('<?xml version="1.0"?><rss><channel>');
      for (var i = 0; i < 60; i++) {
        many.write('<item><title>T$i</title><link>https://e.com/$i</link></item>');
      }
      many.write('</channel></rss>');
      expect(ArticleService.parseFeed(many.toString(), feed).length,
          ArticleService.perTopicLimit);
    });
  });

  group('fetching and caching', () {
    late _InMemoryDb db;
    setUp(() => db = _InMemoryDb());
    tearDown(() async => (await db.database).close());

    test('refresh stores articles, and getArticles serves them from cache',
        () async {
      var calls = 0;
      final service = ArticleService(db, client: MockClient((_) async {
        calls++;
        return http.Response(_scienceDaily, 200);
      }));

      await service.refresh();
      final first = calls;
      expect(first, ArticleService.feeds.length);

      final articles = await service.getArticles();
      expect(articles, isNotEmpty);
      // Fresh cache — no extra network calls.
      expect(calls, first);
      expect(await service.lastFetchedAt(), isNotNull);
    });

    test('filters cached articles by topic', () async {
      final service = ArticleService(db,
          client: MockClient((_) async => http.Response(_scienceDaily, 200)));
      await service.refresh();

      final anxiety = await service.getArticles(topic: 'Anxiety');
      expect(anxiety, isNotEmpty);
      expect(anxiety.every((a) => a.topic == 'Anxiety'), isTrue);
    });

    test('falls back to the cache when the network later fails', () async {
      var online = true;
      final service = ArticleService(db, client: MockClient((_) async {
        if (!online) throw Exception('offline');
        return http.Response(_scienceDaily, 200);
      }));

      await service.refresh();
      final cachedCount = (await service.getArticles()).length;

      online = false;
      final offline = await service.getArticles(forceRefresh: true);

      // Stale, but the screen still has something to show.
      expect(offline.length, cachedCount);
    });

    test('throws when offline with nothing cached', () async {
      final service = ArticleService(db,
          client: MockClient((_) async => throw Exception('offline')));
      expect(() => service.getArticles(), throwsA(isA<ArticleException>()));
    });

    test('one dead feed does not blank the others', () async {
      final service = ArticleService(db, client: MockClient((req) async {
        if (req.url.toString().contains('mindful.org')) {
          return http.Response('gone', 404);
        }
        return http.Response(_scienceDaily, 200);
      }));

      await service.refresh();
      final articles = await service.getArticles();

      expect(articles, isNotEmpty);
      expect(articles.any((a) => a.topic == 'Mindfulness'), isFalse);
      expect(articles.any((a) => a.topic == 'Anxiety'), isTrue);
    });

    test('refresh replaces the cache rather than appending', () async {
      final service = ArticleService(db,
          client: MockClient((_) async => http.Response(_scienceDaily, 200)));

      await service.refresh();
      final afterFirst = (await service.getArticles()).length;
      await service.refresh();
      final afterSecond = (await service.getArticles()).length;

      expect(afterSecond, afterFirst);
    });
  });
}
