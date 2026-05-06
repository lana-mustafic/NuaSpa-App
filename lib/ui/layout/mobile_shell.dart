import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/mobile_nav_provider.dart';
import '../../screens/admin/admin_dashboard_screen.dart';
import '../../screens/catalog/mobile_service_catalog_screen.dart';
import '../../screens/favorites/favorites_screen.dart';
import '../../screens/mobile/mobile_home_screen.dart';
import '../../screens/mobile/mobile_packages_placeholder_screen.dart';
import '../../screens/mobile/mobile_profile_screen.dart';
import '../../screens/reservations/reservation_create_screen.dart';
import '../../screens/reservations/reservation_list_screen.dart';
import '../../screens/therapist/therapist_schedule_screen.dart';
import '../theme/mobile_spa_theme.dart';

/// Floating glass bottom navigation with a raised center "Book Now" action.
class MobileShell extends StatefulWidget {
  const MobileShell({super.key});

  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<MobileNavProvider>();
    final auth = context.watch<AuthProvider>();
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      key: _scaffoldKey,
      extendBody: true,
      drawer: _MobileDrawer(
        auth: auth,
        onClose: () => Navigator.of(context).maybePop(),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: IndexedStack(
              index: nav.tabIndex,
              children: [
                const MobileHomeScreen(),
                MobileServiceCatalogScreen(
                  onOpenMenu: () => _scaffoldKey.currentState?.openDrawer(),
                ),
                const MobilePackagesPlaceholderScreen(),
                const MobileProfileScreen(),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 12 + bottomPad * 0.25,
            child: _GlassBottomBar(
              tabIndex: nav.tabIndex,
              onSelect: nav.setTab,
              onBook: () {
                if (auth.isZaposlenik) {
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const TherapistScheduleScreen(),
                    ),
                  );
                } else {
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const ReservationCreateScreen(),
                    ),
                  );
                }
              },
              bookLabel: auth.isZaposlenik ? 'Schedule' : 'Book',
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassBottomBar extends StatelessWidget {
  const _GlassBottomBar({
    required this.tabIndex,
    required this.onSelect,
    required this.onBook,
    required this.bookLabel,
  });

  final int tabIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onBook;
  final String bookLabel;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 78,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: MobileSpaColors.lavender.withValues(alpha: 0.45),
            ),
            boxShadow: [
              BoxShadow(
                color: MobileSpaColors.royalPurple.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              _NavSide(
                icon: Icons.home_rounded,
                label: 'Home',
                selected: tabIndex == 0,
                onTap: () => onSelect(0),
              ),
              _NavSide(
                icon: Icons.spa_outlined,
                label: 'Services',
                selected: tabIndex == 1,
                onTap: () => onSelect(1),
              ),
              _CenterFab(label: bookLabel, onTap: onBook),
              _NavSide(
                icon: Icons.auto_awesome_outlined,
                label: 'Packages',
                selected: tabIndex == 2,
                onTap: () => onSelect(2),
              ),
              _NavSide(
                icon: Icons.person_outline_rounded,
                label: 'Profile',
                selected: tabIndex == 3,
                onTap: () => onSelect(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavSide extends StatelessWidget {
  const _NavSide({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = selected
        ? MobileSpaColors.royalPurple
        : MobileSpaColors.royalPurple.withValues(alpha: 0.38);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: c),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: c,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenterFab extends StatelessWidget {
  const _CenterFab({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Material(
            elevation: 8,
            shadowColor: MobileSpaColors.royalPurple.withValues(alpha: 0.35),
            shape: const CircleBorder(),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    MobileSpaColors.royalPurple,
                    MobileSpaColors.royalPurple.withValues(alpha: 0.82),
                    MobileSpaColors.lavender.withValues(alpha: 0.65),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: MobileSpaColors.royalPurple.withValues(alpha: 0.35),
                    blurRadius: 16,
                    spreadRadius: 0,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: const Icon(
                  Icons.spa_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: MobileSpaColors.royalPurple.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileDrawer extends StatelessWidget {
  const _MobileDrawer({required this.auth, required this.onClose});

  final AuthProvider auth;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Drawer(
      backgroundColor: MobileSpaColors.softWhite,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 8),
              child: Row(
                children: [
                  Text(
                    'NuaSpa',
                    style: tt.headlineSmall,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (!auth.isZaposlenik)
              ListTile(
                leading: const Icon(Icons.event_note_outlined),
                title: const Text('Reservations'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const ReservationListScreen(),
                    ),
                  );
                },
              ),
            if (!auth.isZaposlenik)
              ListTile(
                leading: const Icon(Icons.favorite_border),
                title: const Text('Favorites'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const FavoritesScreen(),
                    ),
                  );
                },
              ),
            if (auth.isZaposlenik)
              ListTile(
                leading: const Icon(Icons.calendar_month_outlined),
                title: const Text('Therapist schedule'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const TherapistScheduleScreen(),
                    ),
                  );
                },
              ),
            if (auth.isAdmin)
              ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: const Text('Admin'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const AdminDashboardScreen(),
                    ),
                  );
                },
              ),
            const Spacer(),
            ListTile(
              leading: Icon(Icons.logout, color: MobileSpaColors.royalPurple.withValues(alpha: 0.75)),
              title: const Text('Sign out'),
              onTap: () {
                Navigator.pop(context);
                context.read<AuthProvider>().logout();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
