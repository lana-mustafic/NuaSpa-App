import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../navigation/desktop_nav.dart';

/// Brza pretraga usluga: šalje upit u katalog pri navigaciji.
class DeskGlobalSearchBar extends StatefulWidget {
  const DeskGlobalSearchBar({super.key});

  static const desktopHorizontalPadding = 32.0;

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
            focusNode: _node,
            textInputAction: TextInputAction.search,
            onSubmitted: (q) {
              context.read<DesktopNav>().goToCatalogWithSearch(q);
            },
            decoration: InputDecoration(
              hintText: 'Brza pretraga usluga (Enter → Katalog)…',
              prefixIcon: const Icon(Icons.search_rounded, size: 22),
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
