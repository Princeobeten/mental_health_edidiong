import 'package:flutter/material.dart';

import '../../data/resources_data.dart';

/// Browse Resources (Chapter 4): a list of mental-health resources, filterable
/// by topic.
class ResourcesScreen extends StatefulWidget {
  const ResourcesScreen({super.key});

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> {
  String _topic = 'All';

  @override
  Widget build(BuildContext context) {
    final filtered = _topic == 'All'
        ? kResources
        : kResources.where((r) => r.topic == _topic).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Resources')),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _chip('All'),
                for (final t in resourceTopics) _chip(t),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _ResourceCard(resource: filtered[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label) {
    final selected = _topic == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _topic = label),
      ),
    );
  }
}

class _ResourceCard extends StatelessWidget {
  final MentalHealthResource resource;
  const _ResourceCard({required this.resource});

  ({IconData icon, String label}) get _formatBadge => switch (resource.format) {
        ResourceFormat.article => (icon: Icons.article_outlined, label: 'Article'),
        ResourceFormat.video => (icon: Icons.play_circle_outline, label: 'Video'),
        ResourceFormat.audio => (icon: Icons.headphones_outlined, label: 'Audio'),
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final badge = _formatBadge;
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
          child: Text('${resource.topic} · ${badge.label}',
              style: TextStyle(color: scheme.outline, fontSize: 12)),
        ),
        onTap: () => showModalBottomSheet(
          context: context,
          showDragHandle: true,
          builder: (_) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(resource.title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('${resource.topic} · ${badge.label}',
                    style: TextStyle(color: scheme.outline)),
                const SizedBox(height: 14),
                Text(resource.summary, style: const TextStyle(height: 1.4)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
