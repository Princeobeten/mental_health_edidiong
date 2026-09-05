import 'package:flutter/material.dart';

import '../../core/constants.dart';

/// Shown when the local CrisisDetector flags a high-risk message — the
/// escalation path described in Chapter 3.7 ("escalate to support services").
class CrisisBanner extends StatelessWidget {
  final VoidCallback onDismiss;
  const CrisisBanner({super.key, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFDEBEC),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.health_and_safety, color: Color(0xFFC62828)),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                AppConfig.crisisHelplineText,
                style: TextStyle(fontSize: 13, color: Color(0xFF7A1B1B)),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              color: const Color(0xFFC62828),
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}
