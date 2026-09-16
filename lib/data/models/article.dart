/// One article fetched from an external RSS feed and cached on-device.
///
/// These sit alongside the curated guides in [kResources]: the guides are
/// human-written, always offline, and safe to show anywhere; articles are live
/// third-party content, so they always carry their source and link out.
class Article {
  final int? id;
  final String title;
  final String summary;
  final String link;
  final String source; // e.g. "ScienceDaily"
  final String topic; // one of resourceTopics
  final DateTime published;
  final DateTime fetchedAt;

  const Article({
    this.id,
    required this.title,
    required this.summary,
    required this.link,
    required this.source,
    required this.topic,
    required this.published,
    required this.fetchedAt,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'summary': summary,
        'link': link,
        'source': source,
        'topic': topic,
        'published': published.toIso8601String(),
        'fetched_at': fetchedAt.toIso8601String(),
      };

  factory Article.fromMap(Map<String, Object?> map) => Article(
        id: map['id'] as int?,
        title: map['title'] as String,
        summary: map['summary'] as String,
        link: map['link'] as String,
        source: map['source'] as String,
        topic: map['topic'] as String,
        published: DateTime.parse(map['published'] as String),
        fetchedAt: DateTime.parse(map['fetched_at'] as String),
      );
}
