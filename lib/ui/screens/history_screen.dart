import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/chat_controller.dart';
import '../../data/repositories/chat_repository.dart';

/// Conversation history. Until this existed, starting a new chat stranded the
/// previous one — it stayed in the database but nothing in the UI could reach
/// it again. Tapping a row reopens that conversation in the chat screen.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<SessionSummary>> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = context.read<ChatRepository>().getSessionSummaries();
  }

  Future<void> _open(SessionSummary summary) async {
    await context.read<ChatController>().openSession(summary.session);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _delete(SessionSummary summary) async {
    final controller = context.read<ChatController>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete conversation?'),
        content: Text(
          'This permanently removes "${summary.session.title}" and its '
          '${summary.messageCount} messages from this device.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await context.read<ChatRepository>().deleteSession(summary.session.id!);

    // Deleting the conversation that is currently open would leave the chat
    // screen showing messages that no longer exist.
    if (controller.sessionId == summary.session.id) {
      await controller.loadLastSessionOrStart();
    }
    if (mounted) setState(_reload);
  }

  Future<void> _rename(SessionSummary summary) async {
    final input = TextEditingController(text: summary.session.title);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename conversation'),
        content: TextField(
          controller: input,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Title'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, input.text),
              child: const Text('Save')),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty || !mounted) return;

    await context
        .read<ChatRepository>()
        .renameSession(summary.session.id!, name.trim());
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    final activeId = context.watch<ChatController>().sessionId;

    return Scaffold(
      appBar: AppBar(title: const Text('Your conversations')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search conversations',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<SessionSummary>>(
              future: _future,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final all = snap.data!;
                final items = _query.isEmpty
                    ? all
                    : all.where((s) {
                        final title = s.session.title.toLowerCase();
                        final preview = (s.preview ?? '').toLowerCase();
                        return title.contains(_query) ||
                            preview.contains(_query);
                      }).toList();

                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        all.isEmpty
                            ? 'No conversations yet.\nAnything you share will appear here.'
                            : 'No conversations match "$_query".',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.outline),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _SessionTile(
                    summary: items[i],
                    isActive: items[i].session.id == activeId,
                    onOpen: () => _open(items[i]),
                    onRename: () => _rename(items[i]),
                    onDelete: () => _delete(items[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final SessionSummary summary;
  final bool isActive;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _SessionTile({
    required this.summary,
    required this.isActive,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
  });

  /// "Today 14:05" / "Yesterday 09:12" / "3 Sep, 18:40".
  String get _when {
    final now = DateTime.now();
    final d = summary.lastActivity;
    final sameDay = d.year == now.year && d.month == now.month && d.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday =
        d.year == yesterday.year && d.month == yesterday.month && d.day == yesterday.day;

    if (sameDay) return 'Today ${DateFormat('HH:mm').format(d)}';
    if (isYesterday) return 'Yesterday ${DateFormat('HH:mm').format(d)}';
    return DateFormat('d MMM, HH:mm').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: isActive ? scheme.primaryContainer : scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: isActive
            ? BorderSide(color: scheme.primary, width: 1.5)
            : BorderSide.none,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        onTap: onOpen,
        leading: CircleAvatar(
          backgroundColor:
              isActive ? scheme.primary : scheme.primaryContainer,
          child: Icon(
            summary.hasCrisis ? Icons.favorite : Icons.chat_bubble_outline,
            size: 18,
            color: isActive ? scheme.onPrimary : scheme.onPrimaryContainer,
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(summary.session.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            if (isActive)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text('· current',
                    style: TextStyle(fontSize: 11, color: scheme.primary)),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (summary.preview != null)
                Text(summary.preview!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 3),
              Text('$_when · ${summary.messageCount} messages',
                  style: TextStyle(fontSize: 11, color: scheme.outline)),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          tooltip: 'Conversation options',
          onSelected: (v) => v == 'rename' ? onRename() : onDelete(),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'rename', child: Text('Rename')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }
}
