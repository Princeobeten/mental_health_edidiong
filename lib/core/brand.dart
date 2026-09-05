import 'package:flutter/material.dart';

/// Brand palette derived from assets/logo.png (a blue → teal/mint gradient).
class Brand {
  Brand._();

  static const Color blue = Color(0xFF77ACF4);
  static const Color teal = Color(0xFF7DCCCD);

  /// Seed used to build the Material 3 colour scheme.
  static const Color seed = Color(0xFF4FA9CE);

  /// Diagonal brand gradient (used on the splash screen).
  static const LinearGradient gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [blue, teal],
  );

  static const String logoAsset = 'assets/logo.png';
}
