import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../admin/admin_dashboard_screen.dart';
import '../reservations/reservation_list_screen.dart';
import '../favorites/favorites_screen.dart';
import '../../ui/theme/mobile_spa_theme.dart';

class MobileProfileScreen extends StatelessWidget {
  const MobileProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final tt = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
      children: [
        Text('Profile', style: tt.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'Account and quick links',
          style: tt.bodySmall,
        ),
        const SizedBox(height: 28),
        _GlassTile(
          icon: Icons.event_available_outlined,
          label: 'My reservations',
          onTap: () {
            Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const ReservationListScreen(),
              ),
            );
          },
          visible: !auth.isZaposlenik,
        ),
        _GlassTile(
          icon: Icons.favorite_outline,
          label: 'Favorites',
          onTap: () {
            Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const FavoritesScreen(),
              ),
            );
          },
          visible: !auth.isZaposlenik,
        ),
        _GlassTile(
          icon: Icons.admin_panel_settings_outlined,
          label: 'Admin',
          onTap: () {
            Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const AdminDashboardScreen(),
              ),
            );
          },
          visible: auth.isAdmin,
        ),
        const SizedBox(height: 32),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: MobileSpaColors.royalPurple,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          onPressed: () => context.read<AuthProvider>().logout(),
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Sign out'),
        ),
      ],
    );
  }
}

class _GlassTile extends StatelessWidget {
  const _GlassTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.visible = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white.withValues(alpha: 0.55),
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: MobileSpaColors.lavender.withValues(alpha: 0.35),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                Icon(icon, color: MobileSpaColors.royalPurple),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: MobileSpaColors.royalPurple.withValues(alpha: 0.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
