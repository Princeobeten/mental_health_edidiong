import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/article.dart';
import '../../data/resources_data.dart';
import '../../services/article_service.dart';
import 'resource_detail_screen.dart';

/// Browse Resources (Chapter 4). Two tabs:
///   Guides  — curated, human-written self-help content that always works
///             offline (see resources_data.dart).
///   Latest  — live articles pulled from public health/research RSS feeds,
///             cached on-device so the tab still shows something offline.
class ResourcesScreen extends StatelessWidget {
  const ResourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Resources'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Guides'),
              Tab(text: 'Latest'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_GuidesTab(), _LatestTab()],
        ),
      ),
    );
  }
}

/// Horizontal topic filter shared by both tabs.
class _TopicChips extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;
  const _TopicChips({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          for (final t in ['All', ...resourceTopics])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(t),
                selected: selected == t,
                onSelected: (_) => onSelected(t),
              ),
            ),
        ],
      ),
    );
  }
}

// ---- Guides -----------------------------------------------------------------

class _GuidesTab extends StatefulWidget {
  const _GuidesTab();

  @override
  State<_GuidesTab> createState() => _GuidesTabState();
}

class _GuidesTabState extends State<_GuidesTab> {
  String _topic = 'All';

  @override
  Widget build(BuildContext context) {
    final filtered = _topic == 'All'
        ? kResources
        : kResources.where((r) => r.topic == _topic).toList();

    return Column(
      children: [
        _TopicChips(
          selected: _topic,
          onSelected: (t) => setState(() => _topic = t),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _GuideCard(resource: filtered[i]),
          ),
        ),
      ],
    );
  }
}

class _GuideCard extends StatelessWidget {
  final MentalHealthResource resource;
  const _GuideCard({required this.resource});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final badge = ResourceDetailScreen.badgeFor(resource.format);
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Icon(badge.icon, color: scheme.onPrimaryContainer),
        ),
        title: Text(resource.title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${resource.topic} · ${badge.label}',
                  style: TextStyle(color: scheme.outline, fontSize: 12)),
              const SizedBox(height: 6),
              Text(resource.summary,
                  style: const TextStyle(fontSize: 13, height: 1.35)),
            ],
          ),
        ),
        trailing: Icon(Icons.chevron_right, color: scheme.outline),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ResourceDetailScreen(resource: resource),
          ),
        ),
      ),
    );
  }
}

// ---- Latest (live feeds) ----------------------------------------------------

class _LatestTab extends StatefulWidget {
  const _LatestTab();

  @override
  State<_LatestTab> createState() => _LatestTabState();
}

class _LatestTabState extends State<_LatestTab> {
  String _topic = 'All';
  late Future<List<Article>> _future;
  DateTime? _lastFetched;
  String? _warning;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Article>> _load({bool forceRefresh = false}) async {
    final service = context.read<ArticleService>();
    try {
      final articles = await service.getArticles(forceRefresh: forceRefresh);
      _lastFetched = await service.lastFetchedAt();
      final stale = _lastFetched != null &&
          DateTime.now().difference(_lastFetched!) > ArticleService.cacheTtl;
      _warning = stale ? 'Showing saved articles — could not refresh.' : null;
      return articles;
    } on ArticleException catch (e) {
      _warning = e.message;
      rethrow;
    }
  }

  Future<void> _refresh() async {
    final future = _load(forceRefresh: true);
    setState(() => _future = future);
    // Swallow here so pull-to-refresh does not surface an unhandled error; the
    // FutureBuilder below renders the failure state instead.
    await future.catchError((_) => <Article>[]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TopicChips(
          selected: _topic,
          onSelected: (t) => setState(() => _topic = t),
        ),
        Expanded(
          child: FutureBuilder<List<Article>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError && !snap.hasData) {
                return _ErrorState(
                  message: _warning ?? 'Could not load articles.',
                  onRetry: _refresh,
                );
              }

              final all = snap.data ?? const <Article>[];
              final items = _topic == 'All'
                  ? all
                  : all.where((a) => a.topic == _topic).toList();

              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  children: [
                    if (_warning != null) _StaleBanner(message: _warning!),
                    if (items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: Center(
                            child: Text('No articles for this topic yet.')),
                      )
                    else ...[
                      for (final a in items) ...[
                        _ArticleCard(article: a),
                        const SizedBox(height: 10),
                      ],
                      _SourcesFooter(lastFetched: _lastFetched),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ArticleCard extends StatelessWidget {
  final Article article;
  const _ArticleCard({required this.article});

  Future<void> _open(BuildContext context) async {
    final uri = Uri.parse(article.link);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open ${article.link}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(article.topic,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: scheme.onPrimaryContainer,
                        )),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${article.source} · '
                      '${DateFormat('d MMM yyyy').format(article.published)}',
                      style: TextStyle(fontSize: 11, color: scheme.outline),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.open_in_new, size: 14, color: scheme.outline),
                ],
              ),
              const SizedBox(height: 10),
              Text(article.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15, height: 1.3)),
              if (article.summary.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(article.summary,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: scheme.onSurfaceVariant)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StaleBanner extends StatelessWidget {
  final String message;
  const _StaleBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined,
              size: 18, color: scheme.onTertiaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(
                    fontSize: 13, color: scheme.onTertiaryContainer)),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 44, color: scheme.outline),
            const SizedBox(height: 14),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Text(
              'The Guides tab works offline in the meantime.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: scheme.outline),
            ),
            const SizedBox(height: 18),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Attribution for the third-party feeds, plus when they were last pulled.
class _SourcesFooter extends StatelessWidget {
  final DateTime? lastFetched;
  const _SourcesFooter({this.lastFetched});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sources =
        ArticleService.feeds.map((f) => f.source).toSet().join(', ');
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(
        children: [
          Text('Articles from $sources.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: scheme.outline)),
          if (lastFetched != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Updated ${DateFormat('d MMM, HH:mm').format(lastFetched!)} · pull down to refresh',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: scheme.outline),
              ),
            ),
        ],
      ),
    );
  }
}
