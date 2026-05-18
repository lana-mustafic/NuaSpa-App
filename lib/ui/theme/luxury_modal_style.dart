import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared palette for NuaSpa luxury desktop modals.
abstract final class LuxuryModalStyle {
  static const Color bgDeep = Color(0xFF0B0717);
  static const Color bgMid = Color(0xFF120A24);
  static const Color textPrimary = Color(0xFFF5F5F7);
  static const Color textMuted = Color(0xFFA7A1BC);
  static const Color accentPurple = Color(0xFF7B4DFF);
  static const Color accentLavender = Color(0xFFC8B6E8);
  static const Color accentGold = Color(0xFFD4AF7A);
  static const Color fieldBg = Color(0xFF1A102E);

  static const double modalRadius = 30;
  static const double fieldRadius = 18;
  static const double fieldHeight = 56;

  static TextStyle titleStyle(BuildContext context, {double size = 24}) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: textPrimary,
        height: 1.15,
      );

  static TextStyle subtitleStyle(BuildContext context) => GoogleFonts.inter(
        fontSize: 13.5,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: textMuted,
      );

  static TextStyle labelStyle(BuildContext context) => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: textMuted,
        letterSpacing: 0.1,
      );

  static TextStyle fieldStyle(BuildContext context) => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: textPrimary,
      );

  static TextStyle hintTextStyle() => GoogleFonts.inter(
        fontSize: 15,
        color: textMuted.withValues(alpha: 0.85),
      );

  static List<BoxShadow> modalGlow = [
    BoxShadow(
      color: accentPurple.withValues(alpha: 0.3),
      blurRadius: 52,
      spreadRadius: 2,
      offset: const Offset(0, 22),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.58),
      blurRadius: 44,
      offset: const Offset(0, 26),
    ),
  ];

  static InputDecoration fieldDecoration({
    required String hint,
    Widget? prefixIcon,
    EdgeInsetsGeometry? contentPadding,
  }) {
    OutlineInputBorder border(Color color, {double width = 1}) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(fieldRadius),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      hintText: hint,
      hintStyle: hintTextStyle(),
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: fieldBg.withValues(alpha: 0.72),
      contentPadding: contentPadding ??
          const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      enabledBorder: border(Colors.white.withValues(alpha: 0.08)),
      focusedBorder: border(accentPurple.withValues(alpha: 0.65), width: 1.2),
      border: border(Colors.white.withValues(alpha: 0.08)),
    );
  }
}
