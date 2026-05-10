import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../navigation/page_transitions.dart';
import 'nua_luxury_tokens.dart';

class AppTheme {
  static const Color _surface = Color(0xFF161026);
  static const Color _surface2 = Color(0xFF1C1530);
  static const Color _border = Color(0x22FFFFFF);

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: NuaLuxuryTokens.softPurpleGlow,
      brightness: Brightness.dark,
      surface: _surface,
    ).copyWith(
      primary: NuaLuxuryTokens.softPurpleGlow,
      secondary: NuaLuxuryTokens.champagneGold,
      tertiary: NuaLuxuryTokens.lavenderWhisper,
      surface: _surface,
      onSurface: const Color(0xFFF4F1FA),
      onPrimary: Colors.white,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: NuaLuxuryTokens.deepIndigo,
    );

    final textTheme =
        GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: scheme.onSurface.withValues(alpha: 0.92),
      displayColor: scheme.onSurface,
    );

    return base.copyWith(
      textTheme: textTheme.copyWith(
        headlineLarge: textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
          height: 1.1,
        ),
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          height: 1.12,
        ),
        headlineSmall: textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          height: 1.15,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          height: 1.15,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          height: 1.25,
        ),
        titleSmall: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        bodyMedium: textTheme.bodyMedium?.copyWith(height: 1.42),
        bodySmall: textTheme.bodySmall?.copyWith(height: 1.38),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.windows: FadeSlidePageTransitionsBuilder(),
        },
      ),
      cardTheme: CardThemeData(
        color: _surface2.withValues(alpha: 0.55),
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NuaLuxuryTokens.radiusLg),
          side: const BorderSide(color: _border, width: 0.6),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surface2.withValues(alpha: 0.65),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NuaLuxuryTokens.radiusMd),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NuaLuxuryTokens.radiusMd),
          borderSide: const BorderSide(color: _border, width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NuaLuxuryTokens.radiusMd),
          borderSide: BorderSide(
            color: NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.85),
            width: 1.2,
          ),
        ),
        hintStyle: TextStyle(
          color: scheme.onSurface.withValues(alpha: 0.45),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: _border,
        thickness: 0.5,
        space: 1,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbVisibility: const WidgetStatePropertyAll(true),
        thickness: const WidgetStatePropertyAll(8),
        radius: const Radius.circular(8),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return Colors.white.withValues(alpha: 0.35);
          }
          return Colors.white.withValues(alpha: 0.22);
        }),
        trackColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      splashFactory: InkSparkle.splashFactory,
    );
  }
}
