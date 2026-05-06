import 'package:flutter/material.dart';

class HoverCard extends StatefulWidget {
  const HoverCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.cardTheme.shape as RoundedRectangleBorder?;
    final borderRadiusGeo = base?.borderRadius ?? BorderRadius.circular(16);
    final borderRadius = borderRadiusGeo is BorderRadius
        ? borderRadiusGeo
        : BorderRadius.circular(16);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: [
            if (_hover)
              BoxShadow(
                blurRadius: 18,
                spreadRadius: 0,
                offset: const Offset(0, 8),
                color: theme.colorScheme.primary.withValues(alpha: 0.14),
              )
            else
              BoxShadow(
                blurRadius: 16,
                spreadRadius: 0,
                offset: const Offset(0, 10),
                color: Colors.black.withValues(alpha: 0.18),
              ),
          ],
        ),
        child: Card(
          margin: EdgeInsets.zero,
          child: InkWell(
            borderRadius: borderRadius,
            onTap: widget.onTap,
            child: Padding(
              padding: widget.padding ?? const EdgeInsets.all(16),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

