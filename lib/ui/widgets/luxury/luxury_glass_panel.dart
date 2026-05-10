import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/nua_luxury_tokens.dart';

class LuxuryGlassPanel extends StatelessWidget {
  const LuxuryGlassPanel({
    super.key,
    required this.child,
    this.borderRadius = NuaLuxuryTokens.radiusLg,
    this.blurSigma = 22,
    this.opacity = 0.42,
    this.borderOpacity = 0.12,
    this.padding,
  });

  final Widget child;
  final double borderRadius;
  final double blurSigma;
  /// Panel fill alpha over dark base (higher = more opaque card).
  final double opacity;
  final double borderOpacity;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final fill = Color.lerp(
      NuaLuxuryTokens.voidViolet,
      NuaLuxuryTokens.deepIndigo,
      0.35,
    )!
        .withValues(alpha: opacity);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            color: fill,
            border: Border.all(
              color: Colors.white.withValues(alpha: borderOpacity),
              width: 0.85,
            ),
            boxShadow: NuaLuxuryTokens.cardGlow(opacity: 0.08),
          ),
          child: padding != null ? Padding(padding: padding!, child: child) : child,
        ),
      ),
    );
  }
}
