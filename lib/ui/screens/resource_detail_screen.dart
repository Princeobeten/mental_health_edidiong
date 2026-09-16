import 'package:flutter/material.dart';

import '../../data/resources_data.dart';

/// Full reading view for one resource. The bodies run to several hundred words,
/// so this is a scrollable screen rather than the bottom sheet the cards used
/// to open.
class ResourceDetailScreen extends StatelessWidget {
  final MentalHealthResource resource;
  const ResourceDetailScreen({super.key, required this.resource});

  static ({IconData icon, String label}) badgeFor(ResourceFormat format) =>
      switch (format) {
        ResourceFormat.article => (icon: Icons.article_outlined, label: 'Article'),
        ResourceFormat.video => (icon: Icons.play_circle_outline, label: 'Video'),
        ResourceFormat.audio => (icon: Icons.headphones_outlined, label: 'Audio'),
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final badge = badgeFor(resource.format);

    return Scaffold(
      appBar: AppBar(title: Text(resource.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          Row(
            children: [
              Icon(badge.icon, size: 16, color: scheme.outline),
              const SizedBox(width: 6),
              Text('${resource.topic} · ${badge.label}',
                  style: TextStyle(color: scheme.outline, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          Text(resource.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          if (resource.subtitle != null) ...[
            const SizedBox(height: 6),
            Text(resource.subtitle!,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.4,
                  color: scheme.primary,
                  fontWeight: FontWeight.w500,
                )),
          ],
          const SizedBox(height: 20),
          for (final block in resource.body) _Block(block: block),
          const SizedBox(height: 28),
          _SupportNote(scheme: scheme),
        ],
      ),
    );
  }
}

class _Block extends StatelessWidget {
  final ResourceBlock block;
  const _Block({required this.block});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return switch (block.kind) {
      BlockKind.paragraph => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(block.text!,
              style: const TextStyle(fontSize: 15, height: 1.55)),
        ),
      BlockKind.bullets => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final item in block.items)
                _ListRow(marker: '•', text: item, scheme: scheme),
            ],
          ),
        ),
      BlockKind.steps => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, item) in block.items.indexed)
                _ListRow(marker: '${i + 1}.', text: item, scheme: scheme),
            ],
          ),
        ),
      BlockKind.callout => Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(color: scheme.primary, width: 3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(block.label!,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: scheme.onPrimaryContainer,
                  )),
              const SizedBox(height: 4),
              Text(block.text!,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: scheme.onPrimaryContainer,
                  )),
            ],
          ),
        ),
    };
  }
}

/// One bullet or numbered entry, with the marker hanging beside wrapped text.
class _ListRow extends StatelessWidget {
  final String marker;
  final String text;
  final ColorScheme scheme;
  const _ListRow({
    required this.marker,
    required this.text,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Text(marker,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                )),
          ),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 15, height: 1.5)),
          ),
        ],
      ),
    );
  }
}

/// Closing reminder that this is self-help material, not clinical advice.
class _SupportNote extends StatelessWidget {
  final ColorScheme scheme;
  const _SupportNote({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.favorite_outline, size: 18, color: scheme.outline),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'This is general self-help information, not medical advice. If '
              'these feelings persist or affect your daily life, please talk '
              'to someone you trust or a qualified mental-health professional.',
              style: TextStyle(
                  fontSize: 13, height: 1.5, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
