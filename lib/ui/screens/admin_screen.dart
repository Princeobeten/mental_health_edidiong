import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/models/app_user.dart';
import '../../data/models/chat_message.dart';
import '../../data/repositories/chat_repository.dart';
import '../../services/auth_service.dart';

/// Admin Panel (Chapter 4): manage users and monitor chatbot logs.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Panel'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Users'),
              Tab(text: 'Chatbot Logs'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_UsersTab(), _LogsTab()],
        ),
      ),
    );
  }
}

class _UsersTab extends StatefulWidget {
  const _UsersTab();

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  late Future<List<AppUser>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = context.read<AuthService>().getAllUsers();
  }

  Future<void> _delete(AppUser user) async {
    await context.read<AuthService>().deleteUser(user.id!);
    setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AppUser>>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final users = snap.data!;
        if (users.isEmpty) {
          return const Center(child: Text('No registered users.'));
        }
        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (_, i) {
            final u = users[i];
            return ListTile(
              leading: CircleAvatar(
                child: Text(
                    u.fullName.isNotEmpty ? u.fullName[0].toUpperCase() : '?'),
              ),
              title: Row(
                children: [
                  Flexible(child: Text(u.fullName)),
                  if (u.isAdmin)
                    const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(Icons.shield, size: 14),
                    ),
                ],
              ),
              subtitle: Text(u.email),
              trailing: u.isAdmin
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Delete user',
                      onPressed: () => _delete(u),
                    ),
            );
          },
        );
      },
    );
  }
}

class _LogsTab extends StatelessWidget {
  const _LogsTab();

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ChatRepository>();
    return FutureBuilder<List<ChatMessage>>(
      future: repo.getRecentMessages(limit: 200),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final logs = snap.data!;
        if (logs.isEmpty) {
          return const Center(child: Text('No chatbot activity yet.'));
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
                color: m.isCrisis ? Colors.red : null,
              ),
              title: Text(m.text, maxLines: 2, overflow: TextOverflow.ellipsis),
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
    );
  }
}
