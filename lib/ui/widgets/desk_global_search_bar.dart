import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../navigation/desktop_nav.dart';
import '../theme/nua_luxury_tokens.dart';

/// Premium glass search — global catalog jump (Linear / Stripe–style).
class DeskGlobalSearchBar extends StatefulWidget {
  const DeskGlobalSearchBar({
    super.key,
    this.hintText = 'Search services & therapies…',
    this.onSubmitted,
    this.onChanged,
    this.showShortcutHint = false,
    this.controller,
    this.focusNode,
    this.compact = false,
    this.dashboardStyle = false,
    this.maxWidth,
  });

  final String hintText;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool showShortcutHint;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool compact;
  final bool dashboardStyle;
  final double? maxWidth;

  @override
  State<DeskGlobalSearchBar> createState() => _DeskGlobalSearchBarState();
}

class _DeskGlobalSearchBarState extends State<DeskGlobalSearchBar> {
  static const _purple = Color(0xFF7B4DFF);
  static const _textPrimary = Color(0xFFF5F3FA);

  late final FocusNode _focusNode;
  late final TextEditingController _controller;
  bool _ownsFocusNode = false;
  bool _ownsController = false;
  bool _hover = false;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
    } else {
      _focusNode = FocusNode();
      _ownsFocusNode = true;
    }
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = TextEditingController();
      _ownsController = true;
    }
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() => setState(() {});

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (_ownsFocusNode) _focusNode.dispose();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  bool get _focused => _focusNode.hasFocus;

  double get _height {
    if (widget.dashboardStyle) return 48;
    return widget.compact ? 52 : 54;
  }

  double get _radius => widget.dashboardStyle ? 18 : 999;

  TextStyle _textStyle({required bool hint, double? hintAlpha}) {
    return GoogleFonts.inter(
      fontSize: widget.dashboardStyle ? 14 : (widget.compact ? 15 : 16),
      fontWeight: FontWeight.w400,
      height: 1.2,
      color: hint
          ? Colors.white.withValues(alpha: hintAlpha ?? 0.58)
          : _textPrimary,
    );
  }

  double get _iconSize => widget.dashboardStyle ? 20 : (widget.compact ? 18 : 20);

  void _submit(String raw) {
    final q = raw.trim();
    if (widget.onSubmitted != null) {
      widget.onSubmitted!(q);
      return;
    }
    if (q.isEmpty) return;
    context.read<DesktopNav>().goToCatalogWithSearch(q);
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
      borderRadius: BorderRadius.circular(_radius),
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
    final hintAlpha = _focused ? 0.5 : 0.58;
    final hPad = widget.dashboardStyle ? 14.0 : 18.0;

    final bar = Shortcuts(
      shortcuts: widget.dashboardStyle
          ? <ShortcutActivator, Intent>{
              const SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
            }
          : const {},
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: SystemMouseCursors.text,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _focusNode.requestFocus(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            height: _height,
            decoration: _decoration(),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_radius),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_outlined,
                        size: _iconSize,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                      SizedBox(width: widget.dashboardStyle ? 10 : 13),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          textInputAction: TextInputAction.search,
                          style: _textStyle(hint: false),
                          cursorColor: NuaLuxuryTokens.softPurpleGlow,
                          onChanged: widget.onChanged,
                          onSubmitted: _submit,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: widget.hintText,
                            hintStyle: _textStyle(
                              hint: true,
                              hintAlpha: hintAlpha,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                      if (widget.showShortcutHint) ...[
                        const SizedBox(width: 10),
                        _ShortcutBadge(
                          dashboardStyle: widget.dashboardStyle,
                          onTap: () => _focusNode.requestFocus(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.maxWidth != null) {
      return SizedBox(width: widget.maxWidth, child: bar);
    }
    return bar;
  }
}

class _ShortcutBadge extends StatelessWidget {
  const _ShortcutBadge({
    this.dashboardStyle = false,
    this.onTap,
  });

  final bool dashboardStyle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = dashboardStyle
        ? (defaultTargetPlatform == TargetPlatform.macOS ? '⌘ K' : 'Ctrl K')
        : '⌘ K';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color.fromRGBO(255, 255, 255, 0.04),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color.fromRGBO(255, 255, 255, 0.06),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              height: 1,
              letterSpacing: 0.2,
              color: NuaLuxuryTokens.lavenderWhisper.withValues(alpha: 0.58),
            ),
          ),
        ),
      ),
    );
  }
}
