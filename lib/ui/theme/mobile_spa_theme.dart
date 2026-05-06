import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Premium NuaSpa palette — zen, glass-friendly light wellness shell.
abstract final class MobileSpaColors {
  static const Color royalPurple = Color(0xFF2A1244);
  static const Color lavender = Color(0xFFC8B6E8);
  static const Color softWhite = Color(0xFFF7F5FA);
  static const Color gold = Color(0xFFD4AF7A);
}

class MobileSpaTheme {
  static ThemeData light() {
    final serifHeadline = GoogleFonts.cormorantGaramond(
      fontWeight: FontWeight.w600,
      color: MobileSpaColors.royalPurple,
    );
    final sans = GoogleFonts.dmSansTextTheme(ThemeData.light().textTheme);

    final scheme = ColorScheme.light(
      primary: MobileSpaColors.royalPurple,
      onPrimary: Colors.white,
      secondary: MobileSpaColors.lavender,
      onSecondary: MobileSpaColors.royalPurple,
      tertiary: MobileSpaColors.gold,
      surface: MobileSpaColors.softWhite,
      onSurface: MobileSpaColors.royalPurple,
      outline: MobileSpaColors.lavender.withValues(alpha: 0.45),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: MobileSpaColors.softWhite,
      textTheme: sans.copyWith(
        headlineLarge: serifHeadline.copyWith(fontSize: 36, height: 1.08),
        headlineMedium: serifHeadline.copyWith(fontSize: 28, height: 1.1),
        headlineSmall: serifHeadline.copyWith(fontSize: 22, height: 1.15),
        titleLarge: GoogleFonts.dmSans(
          fontWeight: FontWeight.w600,
          fontSize: 18,
          color: MobileSpaColors.royalPurple,
        ),
        titleMedium: GoogleFonts.dmSans(
          fontWeight: FontWeight.w600,
          fontSize: 16,
          color: MobileSpaColors.royalPurple,
        ),
        bodyLarge: GoogleFonts.dmSans(
          fontSize: 16,
          height: 1.45,
          color: MobileSpaColors.royalPurple.withValues(alpha: 0.88),
        ),
        bodyMedium: GoogleFonts.dmSans(
          fontSize: 14,
          height: 1.45,
          color: MobileSpaColors.royalPurple.withValues(alpha: 0.78),
        ),
        bodySmall: GoogleFonts.dmSans(
          fontSize: 12,
          height: 1.4,
          color: MobileSpaColors.royalPurple.withValues(alpha: 0.62),
        ),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: MobileSpaColors.royalPurple,
        titleTextStyle: GoogleFonts.dmSans(
          fontWeight: FontWeight.w600,
          fontSize: 18,
          color: MobileSpaColors.royalPurple,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.72),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(
            color: MobileSpaColors.lavender.withValues(alpha: 0.35),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(
            color: MobileSpaColors.lavender.withValues(alpha: 0.28),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: MobileSpaColors.royalPurple, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        hintStyle: GoogleFonts.dmSans(
          color: MobileSpaColors.royalPurple.withValues(alpha: 0.42),
        ),
      ),
    );
  }
}
