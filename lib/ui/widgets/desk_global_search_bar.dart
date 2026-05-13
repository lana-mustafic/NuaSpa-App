import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../navigation/desktop_nav.dart';

/// Brza pretraga usluga: šalje upit u katalog pri navigaciji.
class DeskGlobalSearchBar extends StatefulWidget {
  final TextEditingController? controller;
  const DeskGlobalSearchBar({
    super.key,
    this.hintText = 'Search services & treatments (Enter → Services)…',
    this.onSubmitted,
    this.onChanged,
    this.showShortcutHint = false,
    this.controller,
  });

  static const desktopHorizontalPadding = 32.0;

  final String hintText;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  /// Premium header: subtle ⌘ K affordance (decorative on Windows).
  final bool showShortcutHint;

  @override
  State<DeskGlobalSearchBar> createState() => _DeskGlobalSearchBarState();
}

class _DeskGlobalSearchBarState extends State<DeskGlobalSearchBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _focusCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final Animation<double> _scale = CurvedAnimation(
    parent: _focusCtrl,
    curve: Curves.easeOutCubic,
  );
  final _node = FocusNode();

  @override
  void initState() {
    super.initState();
    _node.addListener(() {
      if (_node.hasFocus) {
        _focusCtrl.forward();
      } else {
        _focusCtrl.reverse();
      }
    });
  }

  @override
  void dispose() {
    _focusCtrl.dispose();
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DeskGlobalSearchBar.desktopHorizontalPadding,
        12,
        DeskGlobalSearchBar.desktopHorizontalPadding,
        8,
      ),
      child: ScaleTransition(
        scale: Tween<double>(begin: 1, end: 1.01).animate(_scale),
        child: Material(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.55,
          ),
          borderRadius: BorderRadius.circular(14),
          child: TextField(
            controller: widget.controller,
            focusNode: _node,
            textInputAction: TextInputAction.search,
            onChanged: widget.onChanged,
            onSubmitted: (q) {
              if (widget.onSubmitted != null) {
                widget.onSubmitted!(q);
                return;
              }
              context.read<DesktopNav>().goToCatalogWithSearch(q);
            },
            decoration: InputDecoration(
              hintText: widget.hintText,
              prefixIcon: const Icon(Icons.search_rounded, size: 22),
              suffixIcon: widget.showShortcutHint
                  ? Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Center(
                        widthFactor: 1,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.white.withValues(alpha: 0.06),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Text(
                            '⌘ K',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: Colors.white.withValues(alpha: 0.45),
                            ),
                          ),
                        ),
                      ),
                    )
                  : null,
              border: InputBorder.none,
              filled: true,
              fillColor: Colors.transparent,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
