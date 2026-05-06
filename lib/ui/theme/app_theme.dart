import 'package:flutter/material.dart';
import '../navigation/page_transitions.dart';

class AppTheme {
  static const _bg = Color(0xFF0E141B); // tamna teget/siva (ne čista crna)
  static const _surface = Color(0xFF121B24);
  static const _surface2 = Color(0xFF172332);
  static const _border = Color(0x33FFFFFF);
  static const _accent = Color(0xFF48C9A7); // spa mint
  static const _accent2 = Color(0xFFE8C87A); // suptilno zlato

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _accent,
      brightness: Brightness.dark,
      surface: _surface,
    ).copyWith(
      primary: _accent,
      secondary: _accent2,
      surface: _surface,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: _bg,
    );

    return base.copyWith(
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.windows: FadeSlidePageTransitionsBuilder(),
        },
      ),
      textTheme: base.textTheme.copyWith(
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
          height: 1.15,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          height: 1.15,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          height: 1.25,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.35),
      ),
      cardTheme: CardThemeData(
        color: _surface2,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _border, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surface2,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _border, width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.2),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: _border,
        thickness: 0.5,
        space: 1,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbVisibility: const WidgetStatePropertyAll(true),
        thickness: const WidgetStatePropertyAll(10),
        radius: const Radius.circular(10),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) return Colors.white54;
          return Colors.white38;
        }),
        trackColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      splashFactory: InkSparkle.splashFactory,
    );
  }
}

