import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/brand.dart';
import '../../data/models/app_user.dart';
import '../../services/auth_service.dart';

/// Home / Dashboard (Chapter 4): greeting, mental-health tips, and quick access
/// to the chatbot and resources.
class HomeScreen extends StatelessWidget {
  /// Switches the bottom-nav tab (0 Home, 1 Chat, 2 Resources, 3 Profile).
  final void Function(int index) onNavigate;

  const HomeScreen({super.key, required this.onNavigate});

  static const _tips = [
    'Take three slow, deep breaths — in for 4, hold for 4, out for 6.',
    'Name one thing you are grateful for today.',
    'A short walk can lift your mood and clear your mind.',
    'It is okay to rest. Resting is productive too.',
    'Reach out to someone you trust — connection helps.',
  ];

  @override
  Widget build(BuildContext context) {
    // Pick a tip based on the day so it feels fresh but is deterministic.
    final tip = _tips[DateTime.now().day % _tips.length];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(Brand.logoAsset, width: 26, height: 26),
            const SizedBox(width: 8),
            const Text('Mindful'),
          ],
        ),
      ),
      body: FutureBuilder<AppUser?>(
        future: context.read<AuthService>().currentUser(),
        builder: (context, snap) {
          final name = snap.data?.fullName.split(' ').first ?? 'there';
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Hi, $name 👋',
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('How are you feeling today?',
                  style: TextStyle(
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.outline)),
              const SizedBox(height: 20),

              // Tip of the day
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: Brand.gradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.lightbulb_outline, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Tip of the day',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(tip,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 15, height: 1.3)),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              const Text('Quick access',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              _QuickCard(
                icon: Icons.chat_bubble_outline,
                title: 'Talk to Mindful',
                subtitle: 'Start a supportive conversation',
                onTap: () => onNavigate(1),
              ),
              const SizedBox(height: 12),
              _QuickCard(
                icon: Icons.menu_book_outlined,
                title: 'Browse Resources',
                subtitle: 'Articles & tips on anxiety, stress and more',
                onTap: () => onNavigate(2),
              ),
              const SizedBox(height: 12),
              _QuickCard(
                icon: Icons.person_outline,
                title: 'Your Profile',
                subtitle: 'Account, voice settings and more',
                onTap: () => onNavigate(3),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHighest,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: scheme.primary,
          child: Icon(icon, color: scheme.onPrimary),
        ),
        title:
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
