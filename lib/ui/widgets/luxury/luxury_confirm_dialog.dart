import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/luxury_modal_style.dart';

/// Premium confirmation dialog aligned with NuaSpa luxury modal styling.
Future<bool> showLuxuryConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  IconData icon = Icons.info_outline_rounded,
  bool destructive = false,
}) {
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return _LuxuryConfirmDialogOverlay(
        animation: animation,
        child: _LuxuryConfirmDialog(
          title: title,
          message: message,
          confirmLabel: confirmLabel,
          cancelLabel: cancelLabel,
          icon: icon,
          destructive: destructive,
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  ).then((value) => value ?? false);
}

class _LuxuryConfirmDialogOverlay extends StatelessWidget {
  const _LuxuryConfirmDialogOverlay({
    required this.animation,
    required this.child,
  });

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: const SizedBox.expand(),
        ),
        FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
              child: child,
            ),
          ),
        ),
      ],
    );
  }
}

class _LuxuryConfirmDialog extends StatelessWidget {
  const _LuxuryConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.icon,
    required this.destructive,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final IconData icon;
  final bool destructive;

  static const _radius = 20.0;
  static const _maxWidth = 420.0;

  @override
  Widget build(BuildContext context) {
    final accentStart = destructive
        ? const Color(0xFFEC4899)
        : LuxuryModalStyle.accentPurple;
    final accentEnd = destructive
        ? const Color(0xFFF472B6)
        : const Color(0xFF9D6BFF);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _maxWidth, minWidth: 320),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xEB120A24),
              borderRadius: BorderRadius.circular(_radius),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: LuxuryModalStyle.modalGlow,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            colors: [accentStart, accentEnd],
                          ),
                        ),
                        child: Icon(icon, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: LuxuryModalStyle.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              message,
                              style: LuxuryModalStyle.subtitleStyle(context),
                            ),
                          ],
                        ),
                      ),
                      _LuxuryConfirmCloseButton(
                        onPressed: () => Navigator.pop(context, false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _LuxuryConfirmCancelButton(
                        label: cancelLabel,
                        onPressed: () => Navigator.pop(context, false),
                      ),
                      const SizedBox(width: 12),
                      _LuxuryConfirmActionButton(
                        label: confirmLabel,
                        destructive: destructive,
                        onPressed: () => Navigator.pop(context, true),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LuxuryConfirmCloseButton extends StatefulWidget {
  const _LuxuryConfirmCloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_LuxuryConfirmCloseButton> createState() =>
      _LuxuryConfirmCloseButtonState();
}

class _LuxuryConfirmCloseButtonState extends State<_LuxuryConfirmCloseButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: _hover ? 0.1 : 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Icon(
              Icons.close_rounded,
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
        ),
      ),
    );
  }
}

class _LuxuryConfirmCancelButton extends StatefulWidget {
  const _LuxuryConfirmCancelButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  State<_LuxuryConfirmCancelButton> createState() =>
      _LuxuryConfirmCancelButtonState();
}

class _LuxuryConfirmCancelButtonState extends State<_LuxuryConfirmCancelButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: _hover ? 0.08 : 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Text(
              widget.label,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LuxuryConfirmActionButton extends StatefulWidget {
  const _LuxuryConfirmActionButton({
    required this.label,
    required this.destructive,
    required this.onPressed,
  });

  final String label;
  final bool destructive;
  final VoidCallback onPressed;

  @override
  State<_LuxuryConfirmActionButton> createState() =>
      _LuxuryConfirmActionButtonState();
}

class _LuxuryConfirmActionButtonState extends State<_LuxuryConfirmActionButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final start = widget.destructive
        ? const Color(0xFFEC4899)
        : LuxuryModalStyle.accentPurple;
    final end = widget.destructive
        ? const Color(0xFFF472B6)
        : const Color(0xFF9D6BFF);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(colors: [start, end]),
              boxShadow: [
                BoxShadow(
                  color: start.withValues(alpha: _hover ? 0.55 : 0.38),
                  blurRadius: _hover ? 32 : 22,
                  offset: Offset(0, _hover ? 10 : 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.label,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
