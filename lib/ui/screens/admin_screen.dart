import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/models/app_user.dart';
import '../../data/models/chat_message.dart';
import '../../data/repositories/chat_repository.dart';
import '../../services/auth_service.dart';

/// Admin Panel (Chapter 4).
///
/// Everything here reads the LOCAL SQLite database on this device — there is no
/// server, so an admin sees only the users and activity of the install they are
/// signed in to.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Panel'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Users'),
              Tab(text: 'Conversations'),
              Tab(text: 'Logs'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_OverviewTab(), _UsersTab(), _SessionsTab(), _LogsTab()],
        ),
      ),
    );
  }
}

// ---- Overview ---------------------------------------------------------------

class _OverviewTab extends StatefulWidget {
  const _OverviewTab();

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  late Future<_Overview> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final repo = context.read<ChatRepository>();
    final auth = context.read<AuthService>();
    _future = Future(() async => _Overview(
          stats: await repo.getStats(),
          emotions: await repo.getEmotionBreakdown(),
          users: await auth.getAllUsers(),
        ));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<_Overview>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final o = snap.data!;
        final admins = o.users.where((u) => u.isAdmin).length;

        return RefreshIndicator(
          onRefresh: () async => setState(_reload),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.7,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  _StatCard(
                      label: 'Registered users',
                      value: '${o.users.length}',
                      icon: Icons.people_outline),
                  _StatCard(
                      label: 'Admins',
                      value: '$admins',
                      icon: Icons.shield_outlined),
                  _StatCard(
                      label: 'Conversations',
                      value: '${o.stats.sessions}',
                      icon: Icons.forum_outlined),
                  _StatCard(
                      label: 'Messages',
                      value: '${o.stats.messages}',
                      icon: Icons.chat_bubble_outline),
                  _StatCard(
                      label: 'From users',
                      value: '${o.stats.userMessages}',
                      icon: Icons.person_outline),
                  _StatCard(
                    label: 'Crisis flags',
                    value: '${o.stats.crisisFlags}',
                    icon: Icons.warning_amber_outlined,
                    highlight: o.stats.crisisFlags > 0,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text('Detected emotions',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: scheme.onSurface)),
              const SizedBox(height: 8),
              if (o.emotions.isEmpty)
                Text('No emotions detected yet.',
                    style: TextStyle(color: scheme.outline))
              else
                _EmotionBars(emotions: o.emotions),
              const SizedBox(height: 18),
              Card(
                elevation: 0,
                color: scheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const Icon(Icons.schedule),
                  title: const Text('Last activity'),
                  subtitle: Text(o.stats.lastActivity == null
                      ? 'No chatbot activity yet.'
                      : DateFormat('d MMM yyyy, HH:mm')
                          .format(o.stats.lastActivity!)),
                ),
              ),
              const SizedBox(height: 10),
              Card(
                elevation: 0,
                color: scheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: const ListTile(
                  leading: Icon(Icons.phonelink_lock_outlined),
                  title: Text('Local data only'),
                  subtitle: Text(
                      'These figures come from this device\'s database. Other '
                      'installs keep their own separate data.'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Overview {
  final AdminStats stats;
  final Map<String, int> emotions;
  final List<AppUser> users;
  const _Overview(
      {required this.stats, required this.emotions, required this.users});
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool highlight;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = highlight ? scheme.onErrorContainer : scheme.onSurface;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight
            ? scheme.errorContainer
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: highlight ? fg : scheme.outline),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w700, color: fg)),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12,
                  color: highlight ? fg : scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// Simple proportional bars — enough to read the sentiment mix at a glance
/// without pulling in a charting dependency.
class _EmotionBars extends StatelessWidget {
  final Map<String, int> emotions;
  const _EmotionBars({required this.emotions});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final max = emotions.values.reduce((a, b) => a > b ? a : b);

    return Column(
      children: [
        for (final entry in emotions.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 78,
                  child: Text(entry.key,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: entry.value / max,
                      minHeight: 10,
                      backgroundColor: scheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(
                        entry.key == 'crisis' ? scheme.error : scheme.primary,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 34,
                  child: Text('  ${entry.value}',
                      style: TextStyle(fontSize: 12, color: scheme.outline)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ---- Users ------------------------------------------------------------------

class _UsersTab extends StatefulWidget {
  const _UsersTab();

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  late Future<List<AppUser>> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = context.read<AuthService>().getAllUsers();
  }

  /// Runs an admin action and surfaces the guard messages AuthService throws
  /// (last admin, deleting yourself, weak password).
  Future<void> _run(Future<void> Function() action, String success) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(success)));
      if (mounted) setState(_reload);
    } on AuthException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _confirmDelete(AppUser user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete user?'),
        content: Text(
            'This permanently removes ${user.fullName} (${user.email}) from '
            'this device.'),
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
    if (ok != true || !mounted) return;
    await _run(() => context.read<AuthService>().deleteUser(user.id!),
        '${user.fullName} deleted.');
  }

  Future<void> _resetPassword(AppUser user) async {
    final input = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reset password for ${user.fullName}'),
        content: TextField(
          controller: input,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'New password',
            helperText: 'At least 6 characters',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, input.text),
              child: const Text('Reset')),
        ],
      ),
    );
    if (password == null || !mounted) return;
    await _run(
      () => context.read<AuthService>().resetPassword(user.id!, password),
      'Password updated for ${user.fullName}.',
    );
  }

  Future<void> _toggleAdmin(AppUser user) => _run(
        () => context.read<AuthService>().setAdmin(user.id!, !user.isAdmin),
        user.isAdmin
            ? '${user.fullName} is no longer an admin.'
            : '${user.fullName} is now an admin.',
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search name or email',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (v) => setState(() => _query = v.toLowerCase()),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<AppUser>>(
            future: _future,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final users = snap.data!.where((u) {
                if (_query.isEmpty) return true;
                return u.fullName.toLowerCase().contains(_query) ||
                    u.email.toLowerCase().contains(_query);
              }).toList();

              if (users.isEmpty) {
                return Center(
                  child: Text(
                      _query.isEmpty
                          ? 'No registered users.'
                          : 'No users match "$_query".',
                      style: TextStyle(color: scheme.outline)),
                );
              }

              return ListView.separated(
                itemCount: users.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final u = users[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: u.isAdmin
                          ? scheme.primaryContainer
                          : scheme.surfaceContainerHighest,
                      child: Text(
                        u.fullName.isNotEmpty
                            ? u.fullName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                            color: u.isAdmin
                                ? scheme.onPrimaryContainer
                                : scheme.onSurfaceVariant),
                      ),
                    ),
                    title: Row(
                      children: [
                        Flexible(
                            child: Text(u.fullName,
                                overflow: TextOverflow.ellipsis)),
                        if (u.isAdmin)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child:
                                Icon(Icons.shield, size: 14, color: scheme.primary),
                          ),
                      ],
                    ),
                    subtitle: Text(
                      '${u.email}\nJoined ${DateFormat('d MMM yyyy').format(u.createdAt)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      tooltip: 'User actions',
                      onSelected: (v) => switch (v) {
                        'admin' => _toggleAdmin(u),
                        'password' => _resetPassword(u),
                        _ => _confirmDelete(u),
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'admin',
                          child: Text(
                              u.isAdmin ? 'Revoke admin' : 'Make admin'),
                        ),
                        const PopupMenuItem(
                            value: 'password', child: Text('Reset password')),
                        const PopupMenuItem(
                            value: 'delete', child: Text('Delete user')),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---- Conversations ----------------------------------------------------------

class _SessionsTab extends StatefulWidget {
  const _SessionsTab();

  @override
  State<_SessionsTab> createState() => _SessionsTabState();
}

class _SessionsTabState extends State<_SessionsTab> {
  late Future<List<SessionSummary>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = context.read<ChatRepository>().getSessionSummaries();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<List<SessionSummary>>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final sessions = snap.data!;
        if (sessions.isEmpty) {
          return Center(
            child: Text('No conversations yet.',
                style: TextStyle(color: scheme.outline)),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => setState(_reload),
          child: ListView.separated(
            itemCount: sessions.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final s = sessions[i];
              return ListTile(
                leading: Icon(
                  s.hasCrisis ? Icons.warning_amber : Icons.forum_outlined,
                  color: s.hasCrisis ? scheme.error : null,
                ),
                title: Text(s.session.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '${s.messageCount} messages · '
                  '${DateFormat('d MMM yyyy, HH:mm').format(s.lastActivity)}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => _TranscriptScreen(summary: s),
                )),
              );
            },
          ),
        );
      },
    );
  }
}

/// Read-only transcript of one conversation.
class _TranscriptScreen extends StatelessWidget {
  final SessionSummary summary;
  const _TranscriptScreen({required this.summary});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(summary.session.title)),
      body: FutureBuilder<List<ChatMessage>>(
        future: context.read<ChatRepository>().getMessages(summary.session.id!),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final messages = snap.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: messages.length,
            itemBuilder: (_, i) {
              final m = messages[i];
              final isUser = m.sender == Sender.user;
              return Align(
                alignment:
                    isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.78),
                  decoration: BoxDecoration(
                    color: m.isCrisis
                        ? scheme.errorContainer
                        : isUser
                            ? scheme.primaryContainer
                            : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.text, style: const TextStyle(height: 1.4)),
                      const SizedBox(height: 4),
                      Text(
                        '${isUser ? 'User' : 'Bot'}'
                        '${m.emotion != null ? ' · ${m.emotion}' : ''}'
                        ' · ${DateFormat('HH:mm').format(m.createdAt)}',
                        style:
                            TextStyle(fontSize: 10, color: scheme.outline),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ---- Logs -------------------------------------------------------------------

class _LogsTab extends StatefulWidget {
  const _LogsTab();

  @override
  State<_LogsTab> createState() => _LogsTabState();
}

class _LogsTabState extends State<_LogsTab> {
  late Future<List<ChatMessage>> _future;
  String _filter = 'All';
  String _query = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = context.read<ChatRepository>().getRecentMessages(
          limit: 300,
          crisisOnly: _filter == 'Crisis',
          sender: switch (_filter) {
            'User' => Sender.user,
            'Bot' => Sender.bot,
            _ => null,
          },
          query: _query,
        );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search message text',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (v) => setState(() {
              _query = v;
              _reload();
            }),
          ),
        ),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              for (final f in ['All', 'Crisis', 'User', 'Bot'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f),
                    selected: _filter == f,
                    onSelected: (_) => setState(() {
                      _filter = f;
                      _reload();
                    }),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<ChatMessage>>(
            future: _future,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final logs = snap.data!;
              if (logs.isEmpty) {
                return Center(
                  child: Text('No matching activity.',
                      style: TextStyle(color: scheme.outline)),
                );
              }
              return ListView.separated(
                itemCount: logs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final m = logs[i];
                  final isUser = m.sender == Sender.user;
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      isUser ? Icons.person : Icons.smart_toy_outlined,
                      color: m.isCrisis ? scheme.error : null,
                    ),
                    title: Text(m.text,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      '${isUser ? 'User' : 'Bot'}'
                      '${m.emotion != null ? ' · ${m.emotion}' : ''}'
                      '${m.isCrisis ? ' · ⚠ crisis' : ''}'
                      ' · ${DateFormat('dd MMM, HH:mm').format(m.createdAt)}',
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
