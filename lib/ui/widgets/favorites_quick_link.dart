import 'package:flutter/material.dart';

import '../../screens/favorites/favorites_screen.dart';
import '../theme/mobile_spa_theme.dart';

/// Kratki link prema ekranu favorita (mobile).
class FavoritesQuickLink extends StatelessWidget {
  const FavoritesQuickLink({
    super.key,
    required this.count,
    this.compact = false,
  });

  final int count;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    final tt = Theme.of(context).textTheme;
    final label = compact
        ? '$count favorite${count == 1 ? '' : 's'}'
        : 'View your $count favorite service${count == 1 ? '' : 's'}';

    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 20 : 24, compact ? 8 : 12, compact ? 20 : 24, 0),
      child: Material(
        color: MobileSpaColors.lavender.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(compact ? 16 : 20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const FavoritesScreen(),
              ),
            );
          },
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 14 : 18,
              vertical: compact ? 10 : 14,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.favorite_rounded,
                  color: MobileSpaColors.royalPurple,
                  size: compact ? 20 : 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: tt.titleSmall?.copyWith(
                      color: MobileSpaColors.royalPurple,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: MobileSpaColors.royalPurple.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
