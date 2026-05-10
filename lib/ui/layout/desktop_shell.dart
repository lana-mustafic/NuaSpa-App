import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../screens/admin/admin_suite_screen.dart';
import '../../screens/catalog/service_catalog_screen.dart';
import '../../screens/favorites/favorites_screen.dart';
import '../../screens/reservations/reservation_list_screen.dart';
import '../../screens/therapist/therapist_schedule_screen.dart';
import '../widgets/glass_sidebar.dart';
import '../widgets/desk_global_search_bar.dart';
import '../navigation/desktop_nav.dart';

class DesktopShell extends StatefulWidget {
  const DesktopShell({super.key, required this.home});

  final Widget home;

  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

class _NavItem {
  const _NavItem({
    required this.key,
    required this.label,
    required this.icon,
    required this.builder,
    this.visible = true,
  });

  final DesktopRouteKey key;
  final String label;
  final IconData icon;
  final Widget Function() builder;
  final bool visible;
}

class _DesktopShellState extends State<DesktopShell> {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final nav = context.watch<DesktopNav>();

    final items = <_NavItem>[
      _NavItem(
        key: DesktopRouteKey.home,
        label: 'Home',
        icon: Icons.home_outlined,
        builder: () => widget.home,
      ),
      _NavItem(
        key: DesktopRouteKey.catalog,
        label: 'Katalog',
        icon: Icons.grid_view_rounded,
        builder: () => const ServiceCatalogScreen(),
      ),
      _NavItem(
        key: DesktopRouteKey.reservations,
        label: 'Rezervacije',
        icon: Icons.event_note_rounded,
        builder: () => const ReservationListScreen(),
        visible: !auth.isZaposlenik,
      ),
      _NavItem(
        key: DesktopRouteKey.favorites,
        label: 'Favoriti',
        icon: Icons.favorite_border,
        builder: () => const FavoritesScreen(),
        visible: !auth.isZaposlenik,
      ),
      _NavItem(
        key: DesktopRouteKey.schedule,
        label: 'Raspored',
        icon: Icons.calendar_month_outlined,
        builder: () => const TherapistScheduleScreen(),
        visible: auth.isZaposlenik,
      ),
      _NavItem(
        key: DesktopRouteKey.admin,
        label: 'Admin',
        icon: Icons.admin_panel_settings_outlined,
        builder: () => const AdminSuiteScreen(),
        visible: auth.isAdmin,
      ),
    ].where((e) => e.visible).toList();

    final idx = items.indexWhere((it) => it.key == nav.route);
    final safeIndex = idx < 0 ? 0 : idx;
    final currentItem = items.isEmpty ? null : items[safeIndex];
    if (currentItem == null) {
      return const SizedBox.shrink();
    }

    final page = currentItem.builder();
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 980;

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 12, 24),
              child: SizedBox(
                width: isWide ? 260 : 88,
                child: GlassSidebar(
                  child: Column(
                    children: [
                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            const Icon(Icons.spa_outlined, size: 22),
                            if (isWide) ...[
                              const SizedBox(width: 10),
                              Text(
                                'NuaSpa',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Divider(height: 1),
                      Expanded(
                        child: NavigationRail(
                          backgroundColor: Colors.transparent,
                          extended: isWide,
                          selectedIndex: safeIndex,
                          onDestinationSelected: (i) =>
                              context.read<DesktopNav>().goTo(items[i].key),
                          labelType: isWide
                              ? null
                              : NavigationRailLabelType.all,
                          minExtendedWidth: 260,
                          destinations: [
                            for (final it in items)
                              NavigationRailDestination(
                                icon: Icon(it.icon),
                                selectedIcon: Icon(
                                  it.icon,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                label: Text(it.label),
                              ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () =>
                                context.read<AuthProvider>().logout(),
                            icon: const Icon(Icons.logout),
                            label: Text(isWide ? 'Odjava' : ''),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 24, 32, 32),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Material(
                    color: Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: 0.45),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const DeskGlobalSearchBar(),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 240),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, anim) {
                              return FadeTransition(
                                opacity: anim,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0.018, 0),
                                    end: Offset.zero,
                                  ).animate(anim),
                                  child: child,
                                ),
                              );
                            },
                            child: KeyedSubtree(
                              key: ValueKey(
                                '${currentItem.label}-${currentItem.key.name}',
                              ),
                              child: page,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
