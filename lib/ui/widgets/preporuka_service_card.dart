import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/preporucena_usluga.dart';
import '../theme/mobile_spa_theme.dart';

/// Kartica preporučene usluge s kratkim objašnjenjem (razlogTekst).
class PreporukaServiceCard extends StatelessWidget {
  const PreporukaServiceCard({
    super.key,
    required this.item,
    required this.onTap,
    this.width = 180,
    this.compact = false,
  });

  final PreporucenaUsluga item;
  final VoidCallback onTap;
  final double width;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final u = item.usluga;
    final theme = Theme.of(context);

    return SizedBox(
      width: width,
      child: Material(
        color: compact
            ? Colors.white.withValues(alpha: 0.75)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(compact ? 22 : 16),
          side: BorderSide(
            color: compact
                ? MobileSpaColors.lavender.withValues(alpha: 0.3)
                : theme.dividerColor.withValues(alpha: 0.2),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Image.network(
                  u.slikaUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => ColoredBox(
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    child: Icon(
                      Icons.spa_outlined,
                      color: theme.colorScheme.primary.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      u.naziv,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 14 : 13,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      u.cijenaKm,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.tips_and_updates_outlined,
                          size: 14,
                          color: theme.colorScheme.secondary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item.razlogTekst,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              height: 1.35,
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
