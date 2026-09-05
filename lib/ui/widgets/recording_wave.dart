import 'package:flutter/material.dart';

/// A simple live waveform shown in the input area while recording.
/// [levels] is a rolling list of normalised amplitudes (0.0–1.0).
class RecordingWave extends StatelessWidget {
  final List<double> levels;
  const RecordingWave({super.key, required this.levels});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: CustomPaint(
        painter: _WavePainter(levels, color),
        size: Size.infinite,
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final List<double> levels;
  final Color color;
  _WavePainter(this.levels, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    const gap = 6.0;
    final mid = size.height / 2;
    final count = (size.width / gap).floor();
    // Show the most recent `count` bars, right-aligned (newest on the right).
    final shown =
        levels.length > count ? levels.sublist(levels.length - count) : levels;

    for (var i = 0; i < shown.length; i++) {
      final x = i * gap + 2;
      final h = (shown[i].clamp(0.05, 1.0)) * (size.height * 0.9);
      canvas.drawLine(Offset(x, mid - h / 2), Offset(x, mid + h / 2), paint);
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) => true;
}
