import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/app_user.dart';
import '../../services/auth_service.dart';
import 'admin_screen.dart';
import 'auth/login_screen.dart';

/// Profile (Chapter 4): account details, access to the Admin Panel for admins,
/// and logout.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<AppUser?> _userFuture;

  @override
  void initState() {
    super.initState();
    _userFuture = context.read<AuthService>().currentUser();
  }

  Future<void> _logout() async {
    await context.read<AuthService>().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: FutureBuilder<AppUser?>(
        future: _userFuture,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final user = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 8),
              Center(
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: scheme.primaryContainer,
                  child: Text(
                    user.fullName.isNotEmpty
                        ? user.fullName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                        fontSize: 34,
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(user.fullName,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700)),
              ),
              Center(
                child: Text(user.email,
                    style: TextStyle(color: scheme.outline)),
              ),
              if (user.isAdmin)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Chip(
                      label: const Text('Admin'),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: scheme.tertiaryContainer,
                    ),
                  ),
                ),
              const SizedBox(height: 28),
              if (user.isAdmin)
                Card(
                  elevation: 0,
                  color: scheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  child: ListTile(
                    leading: const Icon(Icons.admin_panel_settings_outlined),
                    title: const Text('Admin Panel'),
                    subtitle: const Text(
                        'Stats, users, conversations and logs on this device'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AdminScreen()),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                color: scheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: const ListTile(
                  leading: Icon(Icons.privacy_tip_outlined),
                  title: Text('Privacy'),
                  subtitle: Text(
                      'Your conversations are stored only on this device.'),
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: const Text('Log out'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
