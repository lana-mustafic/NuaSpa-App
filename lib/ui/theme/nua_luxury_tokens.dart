import 'dart:ui';

import 'package:flutter/material.dart';

/// NuaSpa ultra-premium desktop palette (luxury spa × enterprise SaaS).
abstract final class NuaLuxuryTokens {
  static const Color voidViolet = Color(0xFF140B24);
  static const Color deepIndigo = Color(0xFF0D0A18);
  static const Color softPurpleGlow = Color(0xFF7B4DFF);
  static const Color lavenderWhisper = Color(0xFFC8B6E8);
  static const Color champagneGold = Color(0xFFD4AF7A);

  static const double radiusMd = 16;
  static const double radiusLg = 22;
  static const double radiusXl = 28;

  static List<BoxShadow> cardGlow({Color? color, double opacity = 0.14}) => [
        BoxShadow(
          color: (color ?? softPurpleGlow).withValues(alpha: opacity),
          blurRadius: 28,
          spreadRadius: 0,
          offset: const Offset(0, 12),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.45),
          blurRadius: 24,
          offset: const Offset(0, 16),
        ),
      ];

  static ImageFilter sidebarBlur(double sigma) =>
      ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);

  /// Ambient vignette gradient for chrome background.
  static BoxDecoration ambience() => BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.85, -0.9),
          radius: 1.35,
          colors: [
            softPurpleGlow.withValues(alpha: 0.09),
            voidViolet.withValues(alpha: 0.02),
          ],
          stops: const [0.0, 1.0],
        ),
      );
}
