import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:xml/xml.dart';

import '../data/local/database_helper.dart';
import '../data/models/article.dart';

class ArticleException implements Exception {
  final String message;
  ArticleException(this.message);
  @override
  String toString() => message;
}

/// One external RSS feed mapped onto a Resources topic.
class FeedSource {
  final String topic;
  final String source;
  final String url;
  const FeedSource(
      {required this.topic, required this.source, required this.url});
}

/// Fetches live articles from public health/research RSS feeds and caches them
/// on-device, so the Resources screen keeps working offline.
///
/// The curated guides in `resources_data.dart` are deliberately NOT replaced by
/// this: those are reviewed self-help instructions, while these are third-party
/// news items shown with attribution and a link out to the publisher.
class ArticleService {
  final DatabaseHelper _dbHelper;
  final http.Client _client;

  ArticleService(this._dbHelper, {http.Client? client})
      : _client = client ?? http.Client();

  /// Feeds verified to return RSS 2.0 with title/link/description/pubDate.
  static const List<FeedSource> feeds = [
    FeedSource(
      topic: 'Anxiety',
      source: 'ScienceDaily',
      url: 'https://www.sciencedaily.com/rss/mind_brain/anxiety.xml',
    ),
    FeedSource(
      topic: 'Stress',
      source: 'ScienceDaily',
      url: 'https://www.sciencedaily.com/rss/mind_brain/stress.xml',
    ),
    FeedSource(
      topic: 'Depression',
      source: 'ScienceDaily',
      url: 'https://www.sciencedaily.com/rss/mind_brain/depression.xml',
    ),
    FeedSource(
      topic: 'Sleep',
      source: 'ScienceDaily',
      url: 'https://www.sciencedaily.com/rss/mind_brain/sleep_disorders.xml',
    ),
    FeedSource(
      topic: 'Mindfulness',
      source: 'Mindful.org',
      url: 'https://www.mindful.org/feed/',
    ),
  ];

  /// How many items to keep per topic — feeds return up to 60, which is far
  /// more than anyone scrolls and bloats the cache.
  static const int perTopicLimit = 15;

  /// Cached articles are considered fresh for this long.
  static const Duration cacheTtl = Duration(hours: 6);

  // ---- Public API ---------------------------------------------------------

  /// Returns cached articles immediately if they are still fresh, otherwise
  /// refetches. Falls back to stale cache when the network is unavailable, so
  /// the screen degrades to "old but useful" rather than empty.
  Future<List<Article>> getArticles({
    String? topic,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && !await _isStale()) {
      return _readCache(topic: topic);
    }

    try {
      await refresh();
    } on ArticleException {
      final cached = await _readCache(topic: topic);
      if (cached.isEmpty) rethrow; // nothing to show and no way to get it
      return cached; // stale, but better than an empty screen
    }
    return _readCache(topic: topic);
  }

  /// Fetches every feed and replaces the cache. Succeeds if at least one feed
  /// responds, so one dead publisher does not blank the whole screen.
  Future<void> refresh() async {
    final fetched = <Article>[];
    final failures = <String>[];

    await Future.wait(feeds.map((feed) async {
      try {
        fetched.addAll(await _fetchFeed(feed));
      } catch (e) {
        failures.add('${feed.source} (${feed.topic})');
      }
    }));

    if (fetched.isEmpty) {
      throw ArticleException(
          'Could not load articles. Check your connection and try again.');
    }
    await _writeCache(fetched);
  }

  /// When the cache was last written, or null if it never has been.
  Future<DateTime?> lastFetchedAt() async {
    final db = await _dbHelper.database;
    final rows = await db.query('articles',
        columns: ['fetched_at'], orderBy: 'fetched_at DESC', limit: 1);
    if (rows.isEmpty) return null;
    return DateTime.parse(rows.first['fetched_at'] as String);
  }

  // ---- Fetching / parsing -------------------------------------------------

  Future<List<Article>> _fetchFeed(FeedSource feed) async {
    late http.Response res;
    try {
      res = await _client.get(
        Uri.parse(feed.url),
        // Some publishers reject requests without a browser-ish agent.
        headers: {'User-Agent': 'Mozilla/5.0 (compatible; MindfulApp/1.0)'},
      ).timeout(const Duration(seconds: 20));
    } catch (e) {
      throw ArticleException('Could not reach ${feed.source}. ($e)');
    }

    if (res.statusCode != 200) {
      throw ArticleException('${feed.source} returned ${res.statusCode}.');
    }
    return parseFeed(res.body, feed);
  }

  /// Parses an RSS 2.0 document into articles. Exposed for testing.
  static List<Article> parseFeed(String xmlBody, FeedSource feed) {
    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(xmlBody);
    } on XmlException catch (e) {
      throw ArticleException('${feed.source} returned malformed XML. ($e)');
    }

    final now = DateTime.now();
    final articles = <Article>[];

    for (final item in doc.findAllElements('item')) {
      final title = _clean(_tagText(item, 'title'));
      final link = _tagText(item, 'link').trim();
      if (title.isEmpty || link.isEmpty) continue; // unusable entry

      articles.add(Article(
        title: title,
        summary: _clean(_tagText(item, 'description')),
        link: link,
        source: feed.source,
        topic: feed.topic,
        published: _parseDate(_tagText(item, 'pubDate')) ?? now,
        fetchedAt: now,
      ));
      if (articles.length >= perTopicLimit) break;
    }
    return articles;
  }

  static String _tagText(XmlElement item, String tag) {
    final el = item.findElements(tag).firstOrNull;
    return el?.innerText ?? '';
  }

  /// Feed descriptions arrive as HTML inside CDATA. Strips tags, decodes the
  /// entities that survive, and drops WordPress's trailing "The post … appeared
  /// first on …" credit line.
  static String _clean(String raw) {
    var text = raw.replaceAll(RegExp(r'<[^>]*>'), ' ');
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#8217;', '’')
        .replaceAll('&#8216;', '‘')
        .replaceAll('&#8220;', '“')
        .replaceAll('&#8221;', '”')
        .replaceAll('&#039;', "'")
        .replaceAll('&apos;', "'");
    text = text.replaceAll(RegExp(r'The post\s+.*?appeared first on.*$',
        dotAll: true, caseSensitive: false), '');
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// RFC-822 dates as used by RSS, e.g. "Wed, 26 Aug 2026 03:28:27 EDT".
  static DateTime? _parseDate(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;

    final match = RegExp(
            r'(\d{1,2})\s+(\w{3})\s+(\d{4})(?:\s+(\d{2}):(\d{2})(?::(\d{2}))?)?')
        .firstMatch(text);
    if (match == null) return DateTime.tryParse(text);

    const months = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
    };
    final month = months[match.group(2)!.toLowerCase()];
    if (month == null) return null;

    return DateTime(
      int.parse(match.group(3)!),
      month,
      int.parse(match.group(1)!),
      int.parse(match.group(4) ?? '0'),
      int.parse(match.group(5) ?? '0'),
      int.parse(match.group(6) ?? '0'),
    );
  }

  // ---- Cache --------------------------------------------------------------

  Future<bool> _isStale() async {
    final last = await lastFetchedAt();
    if (last == null) return true;
    return DateTime.now().difference(last) > cacheTtl;
  }

  Future<void> _writeCache(List<Article> articles) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete('articles');
      final batch = txn.batch();
      for (final a in articles) {
        batch.insert('articles', a.toMap()..remove('id'),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<Article>> _readCache({String? topic}) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'articles',
      where: topic == null ? null : 'topic = ?',
      whereArgs: topic == null ? null : [topic],
      orderBy: 'published DESC',
    );
    return rows.map(Article.fromMap).toList();
  }
}
