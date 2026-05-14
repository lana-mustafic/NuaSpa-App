import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../navigation/desktop_nav.dart';
import '../theme/nua_luxury_tokens.dart';

/// Premium glass capsule search — global catalog jump (Linear / Stripe–style).
class DeskGlobalSearchBar extends StatefulWidget {
  const DeskGlobalSearchBar({
    super.key,
    this.hintText = 'Search services & therapies…',
    this.onSubmitted,
    this.onChanged,
    this.showShortcutHint = false,
    this.controller,
    this.compact = false,
  });

  final String hintText;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool showShortcutHint;
  final TextEditingController? controller;
  /// Narrower width / slightly shorter height (e.g. calendar).
  final bool compact;

  @override
  State<DeskGlobalSearchBar> createState() => _DeskGlobalSearchBarState();
}

class _DeskGlobalSearchBarState extends State<DeskGlobalSearchBar> {
  static const _purple = Color(0xFF7B4DFF);
  static const _textPrimary = Color(0xFFF5F3FA);

  final _node = FocusNode();
  bool _hover = false;

  @override
  void initState() {
    super.initState();
    _node.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  bool get _focused => _node.hasFocus;

  double get _height => widget.compact ? 52 : 54;

  TextStyle _bodyStyle() {
    return GoogleFonts.inter(
      fontSize: widget.compact ? 15 : 16,
      fontWeight: FontWeight.w400,
      height: 1.25,
      color: _textPrimary,
    );
  }

  BoxDecoration _decoration() {
    final borderColor = _focused
        ? const Color.fromRGBO(123, 77, 255, 0.45)
        : _hover
            ? const Color.fromRGBO(123, 77, 255, 0.35)
            : const Color.fromRGBO(255, 255, 255, 0.08);

    final glowA = _focused ? 0.18 : (_hover ? 0.18 : 0.12);
    final blurDy = _focused ? 28.0 : (_hover ? 28.0 : 24.0);
    final blurY = _focused ? 6.0 : (_hover ? 6.0 : 4.0);

    return BoxDecoration(
      borderRadius: BorderRadius.circular(999),
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.fromRGBO(255, 255, 255, 0.04),
          Color.fromRGBO(255, 255, 255, 0.02),
        ],
      ),
      border: Border.all(color: borderColor, width: 1),
      boxShadow: [
        BoxShadow(
          color: _purple.withValues(alpha: glowA),
          offset: Offset(0, blurY),
          blurRadius: blurDy,
        ),
        if (_focused)
          BoxShadow(
            color: _purple.withValues(alpha: 0.08),
            blurRadius: 0,
            spreadRadius: 4,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hintAlpha = _focused ? 0.32 : 0.45;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.text,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        height: _height,
        decoration: _decoration(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_outlined,
                    size: widget.compact ? 18 : 20,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _node,
                      textInputAction: TextInputAction.search,
                      textAlignVertical: TextAlignVertical.center,
                      style: _bodyStyle(),
                      cursorColor: NuaLuxuryTokens.softPurpleGlow,
                      onChanged: widget.onChanged,
                      onSubmitted: (q) {
                        if (widget.onSubmitted != null) {
                          widget.onSubmitted!(q);
                          return;
                        }
                        context.read<DesktopNav>().goToCatalogWithSearch(q);
                      },
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: widget.hintText,
                        hintStyle: GoogleFonts.inter(
                          fontSize: widget.compact ? 15 : 16,
                          fontWeight: FontWeight.w400,
                          height: 1.25,
                          color: Colors.white.withValues(alpha: hintAlpha),
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        filled: true,
                        fillColor: Colors.transparent,
                      ),
                    ),
                  ),
                  if (widget.showShortcutHint) ...[
                    const SizedBox(width: 12),
                    _ShortcutBadge(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShortcutBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color.fromRGBO(255, 255, 255, 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color.fromRGBO(255, 255, 255, 0.06),
        ),
      ),
      child: Text(
        '⌘ K',
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 1,
          letterSpacing: 0.2,
          color: NuaLuxuryTokens.lavenderWhisper.withValues(alpha: 0.58),
        ),
      ),
    );
  }
}
