import 'package:flutter/material.dart';

/// A small animated "equalizer" shown on a message bubble while it is being
/// read aloud, to signal that the assistant is speaking.
class SpeakingIndicator extends StatefulWidget {
  final Color color;
  final double height;
  const SpeakingIndicator({super.key, required this.color, this.height = 16});

  @override
  State<SpeakingIndicator> createState() => _SpeakingIndicatorState();
}

class _SpeakingIndicatorState extends State<SpeakingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  static const _bars = 4;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(_bars, (i) {
            // Each bar is phase-shifted to create a wave-like bounce.
            final phase = (_c.value + i / _bars) % 1.0;
            final t = (0.5 - (phase - 0.5).abs()) * 2; // 0 → 1 → 0
            final h = widget.height * (0.3 + 0.7 * t);
            return Container(
              width: 2.5,
              height: h,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        ),
      ),
    );
  }
}
