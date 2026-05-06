import 'package:flutter/material.dart';

import '../../ui/theme/mobile_spa_theme.dart';

/// Future wellness bundles / spa packages — visual placeholder only.
class MobilePackagesPlaceholderScreen extends StatelessWidget {
  const MobilePackagesPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_awesome_mosaic_outlined,
              size: 56,
              color: MobileSpaColors.royalPurple.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 20),
            Text(
              'Packages',
              style: tt.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Curated rituals and bundle offers are coming soon. '
              'Explore individual treatments in Services for now.',
              style: tt.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
