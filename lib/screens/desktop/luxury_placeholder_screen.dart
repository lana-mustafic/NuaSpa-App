import 'package:flutter/material.dart';

import '../../ui/theme/nua_luxury_tokens.dart';
import '../../ui/widgets/luxury/luxury_glass_panel.dart';

/// Placeholder for roadmap modules (Marketing, extended Settings, etc.).
class LuxuryPlaceholderScreen extends StatelessWidget {
  const LuxuryPlaceholderScreen({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.auto_awesome_outlined,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: LuxuryGlassPanel(
          blurSigma: 30,
          opacity: 0.45,
          borderRadius: NuaLuxuryTokens.radiusXl + 6,
          padding: const EdgeInsets.fromLTRB(44, 56, 44, 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: NuaLuxuryTokens.champagneGold),
              const SizedBox(height: 22),
              Text(
                title,
                textAlign: TextAlign.center,
                style: t.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: t.textTheme.bodyLarge?.copyWith(
                  color: t.colorScheme.onSurface.withValues(alpha: 0.55),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
