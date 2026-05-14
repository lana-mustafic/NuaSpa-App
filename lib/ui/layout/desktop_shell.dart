import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../screens/admin/admin_appointments_management_screen.dart';
import '../../screens/admin/admin_calendar_screen.dart';
import '../../screens/admin/admin_command_center_screen.dart';
import '../../screens/admin/admin_revenue_analytics_screen.dart';
import '../../screens/admin/admin_suite_screen.dart';
import '../../screens/admin/admin_suite_route.dart';
import '../../screens/admin/admin_therapist_roster_screen.dart';
import '../../screens/catalog/service_catalog_screen.dart';
import '../../screens/desktop/luxury_placeholder_screen.dart';
import '../../screens/desktop/luxury_reviews_dashboard_screen.dart';
import '../../screens/desktop/luxury_settings_screen.dart';
import '../../screens/favorites/favorites_screen.dart';
import '../../screens/reservations/reservation_list_screen.dart';
import '../../screens/therapist/therapist_schedule_screen.dart';
import '../navigation/desktop_nav.dart';
import '../theme/nua_luxury_tokens.dart';
import '../widgets/luxury/luxury_desktop_header.dart';

class LuxurySideItem {
  const LuxurySideItem({
    required this.route,
    required this.label,
    required this.icon,
    this.suite,
    this.purpleGradientNav = false,
  });

  final DesktopRouteKey route;
  final String label;
  final IconData icon;

  /// When set together with [route] == admin, selects inner Admin Suite tab/view.
  final AdminSuiteRoute? suite;

  /// Premium purple gradient when this item is selected (e.g. Reviews hub).
  final bool purpleGradientNav;
}

class DesktopShell extends StatefulWidget {
  const DesktopShell({super.key, required this.home});

  final Widget home;

  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell> {
  DateTime _filterDay = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final nav = context.watch<DesktopNav>();

    nav.seedAdminLandingIfNeeded(auth.isAdmin);

    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 1100;
    final isCalendar = nav.route == DesktopRouteKey.adminCalendar;
    final railExpandedW = width < 1450 ? 224.0 : 236.0;

    final adminItems = <LuxurySideItem>[
      LuxurySideItem(
        route: DesktopRouteKey.commandCenter,
        label: 'Dashboard',
        icon: Icons.space_dashboard_outlined,
      ),
      LuxurySideItem(
        route: DesktopRouteKey.reservations,
        label: 'Appointments',
        icon: Icons.calendar_today_outlined,
      ),
      LuxurySideItem(
        route: DesktopRouteKey.adminCalendar,
        label: 'Calendar',
        icon: Icons.date_range_rounded,
      ),
      LuxurySideItem(
        route: DesktopRouteKey.admin,
        suite: AdminSuiteRoute.clients,
        label: 'Clients',
        icon: Icons.people_outline,
      ),
      LuxurySideItem(
        route: DesktopRouteKey.therapists,
        label: 'Therapists',
        icon: Icons.spa_outlined,
      ),
      LuxurySideItem(
        route: DesktopRouteKey.catalog,
        label: 'Services',
        icon: Icons.diamond_outlined,
      ),
      LuxurySideItem(
        route: DesktopRouteKey.reviews,
        label: 'Reviews',
        icon: Icons.reviews_outlined,
        purpleGradientNav: true,
      ),
      LuxurySideItem(
        route: DesktopRouteKey.admin,
        suite: AdminSuiteRoute.finance,
        label: 'Payments',
        icon: Icons.payments_outlined,
      ),
      LuxurySideItem(
        route: DesktopRouteKey.revenueAnalytics,
        label: 'Reports',
        icon: Icons.area_chart_rounded,
      ),
      LuxurySideItem(
        route: DesktopRouteKey.settings,
        label: 'Settings',
        icon: Icons.tune_rounded,
      ),
    ];

    final therapistItems = <LuxurySideItem>[
      LuxurySideItem(
        route: DesktopRouteKey.home,
        label: 'Pulse',
        icon: Icons.home_outlined,
      ),
      LuxurySideItem(
        route: DesktopRouteKey.schedule,
        label: 'Schedule',
        icon: Icons.view_timeline_rounded,
      ),
    ];

    final clientItems = <LuxurySideItem>[
      LuxurySideItem(
        route: DesktopRouteKey.home,
        label: 'Home',
        icon: Icons.home_outlined,
      ),
      LuxurySideItem(
        route: DesktopRouteKey.catalog,
        label: 'Services',
        icon: Icons.grid_view_rounded,
      ),
      LuxurySideItem(
        route: DesktopRouteKey.reservations,
        label: 'Bookings',
        icon: Icons.event_note_outlined,
      ),
      LuxurySideItem(
        route: DesktopRouteKey.favorites,
        label: 'Favorites',
        icon: Icons.favorite_border,
      ),
      LuxurySideItem(
        route: DesktopRouteKey.settings,
        label: 'Settings',
        icon: Icons.tune_rounded,
      ),
    ];

    final items = auth.isAdmin
        ? adminItems
        : auth.isZaposlenik
        ? therapistItems
        : clientItems;

    Widget buildPage() {
      switch (nav.route) {
        case DesktopRouteKey.commandCenter:
          if (!auth.isAdmin) return widget.home;
          return AdminCommandCenterScreen(filterDay: _filterDay);
        case DesktopRouteKey.therapists:
          return auth.isAdmin
              ? const AdminTherapistRosterScreen()
              : widget.home;
        case DesktopRouteKey.revenueAnalytics:
          return auth.isAdmin
              ? const AdminRevenueAnalyticsScreen()
              : widget.home;
        case DesktopRouteKey.reviews:
          return auth.isAdmin
              ? const LuxuryReviewsDashboardScreen()
              : widget.home;
        case DesktopRouteKey.marketing:
          return auth.isAdmin
              ? const LuxuryPlaceholderScreen(
                  title: 'Marketing orchestration',
                  subtitle:
                      'Campaign playbooks, loyalty rituals, gifting, and concierge CRM moments.',
                  icon: Icons.auto_graph_rounded,
                )
              : widget.home;
        case DesktopRouteKey.settings:
          return const LuxurySettingsScreen();
        case DesktopRouteKey.home:
          return widget.home;
        case DesktopRouteKey.catalog:
          return const ServiceCatalogScreen();
        case DesktopRouteKey.reservations:
          return auth.isAdmin
              ? const AdminAppointmentsManagementScreen()
              : const ReservationListScreen();
        case DesktopRouteKey.adminCalendar:
          return auth.isAdmin ? const AdminCalendarScreen() : widget.home;
        case DesktopRouteKey.favorites:
          return const FavoritesScreen();
        case DesktopRouteKey.schedule:
          return const TherapistScheduleScreen();
        case DesktopRouteKey.admin:
          return auth.isAdmin
              ? AdminSuiteScreen(initialRoute: nav.adminSuiteTarget)
              : widget.home;
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(color: NuaLuxuryTokens.deepIndigo),
          ),
          DecoratedBox(decoration: NuaLuxuryTokens.ambience()),
          SafeArea(
            child: Padding(
              padding: isCalendar
                  ? const EdgeInsets.fromLTRB(10, 8, 12, 10)
                  : const EdgeInsets.fromLTRB(22, 20, 28, 24),
              child: Row(
                children: [
                  _LuxuryRail(
                    expanded: isWide,
                    expandedWidth: railExpandedW,
                    compact: isCalendar,
                    items: items,
                    onPick: (it) {
                      if (auth.isAdmin &&
                          it.suite != null &&
                          it.route == DesktopRouteKey.admin) {
                        nav.goToAdminSuite(it.suite!);
                      } else {
                        nav.goTo(it.route);
                      }
                    },
                  ),
                  SizedBox(width: isCalendar ? 10 : 16),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: NuaLuxuryTokens.voidViolet.withValues(
                            alpha: 0.22,
                          ),
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.088),
                          ),
                          boxShadow: NuaLuxuryTokens.cardGlow(opacity: 0.05),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            LuxuryDesktopHeader(
                              selectedDay: _filterDay,
                              onDateChanged: (d) =>
                                  setState(() => _filterDay = d),
                              notificationCount:
                                  nav.route == DesktopRouteKey.adminCalendar ||
                                          nav.route == DesktopRouteKey.reviews
                                      ? 3
                                      : 0,
                            ),
                            Expanded(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 280),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                transitionBuilder: (child, anim) =>
                                    FadeTransition(
                                      opacity: anim,
                                      child: SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(0.01, 0.015),
                                          end: Offset.zero,
                                        ).animate(anim),
                                        child: child,
                                      ),
                                    ),
                                child: KeyedSubtree(
                                  key: ValueKey(
                                    '${nav.route.name}'
                                    '${auth.isAdmin ? '_${nav.adminSuiteMount}_${nav.route == DesktopRouteKey.admin ? nav.adminSuiteTarget.name : ''}' : ''}'
                                    '${nav.route == DesktopRouteKey.adminCalendar ? '_cal' : ''}',
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: buildPage(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LuxuryRail extends StatelessWidget {
  const _LuxuryRail({
    required this.expanded,
    required this.expandedWidth,
    this.compact = false,
    required this.items,
    required this.onPick,
  });

  final bool expanded;
  final double expandedWidth;
  final bool compact;
  final List<LuxurySideItem> items;
  final void Function(LuxurySideItem it) onPick;

  bool _selected(DesktopNav nav, LuxurySideItem it) {
    if (it.suite != null && it.route == DesktopRouteKey.admin) {
      return nav.route == DesktopRouteKey.admin &&
          nav.adminSuiteTarget == it.suite;
    }
    return nav.route == it.route;
  }

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<DesktopNav>();

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 38, sigmaY: 38),
        child: Container(
          width: expanded ? expandedWidth : 86,
          padding: EdgeInsets.fromLTRB(
            expanded ? (compact ? 10 : 14) : 8,
            compact ? 14 : 20,
            expanded ? (compact ? 10 : 14) : 8,
            compact ? 10 : 16,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.055),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.09),
              width: 0.9,
            ),
            boxShadow: [
              BoxShadow(
                color: NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.07),
                blurRadius: 36,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: expanded
                ? CrossAxisAlignment.stretch
                : CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: expanded
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(compact ? 8 : 10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          NuaLuxuryTokens.softPurpleGlow.withValues(
                            alpha: 0.55,
                          ),
                          NuaLuxuryTokens.deepIndigo.withValues(alpha: 0),
                        ],
                      ),
                    ),
                    child: Icon(
                      Icons.spa_rounded,
                      size: expanded ? (compact ? 22 : 24) : 20,
                      color: NuaLuxuryTokens.champagneGold,
                    ),
                  ),
                  if (expanded) ...[
                    const SizedBox(width: 11),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NuaSpa',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                              ),
                        ),
                        Text(
                          'ADMIN PANEL',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: NuaLuxuryTokens.champagneGold.withValues(
                                  alpha: 0.84,
                                ),
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.4,
                              ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              SizedBox(height: compact ? 12 : 18),
              Divider(
                color: Colors.white.withValues(alpha: 0.08),
                thickness: 0.5,
              ),
              SizedBox(height: compact ? 6 : 10),
              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: items.length,
                  separatorBuilder: (_, _) => SizedBox(height: compact ? 2 : 4),
                  itemBuilder: (_, i) {
                    final it = items[i];
                    final sel = _selected(nav, it);
                    return _SidebarTile(
                      expanded: expanded,
                      compact: compact,
                      label: it.label,
                      icon: it.icon,
                      selected: sel,
                      purpleGradientNav: it.purpleGradientNav,
                      onTap: () => onPick(it),
                    );
                  },
                ),
              ),
              Divider(
                color: Colors.white.withValues(alpha: 0.08),
                thickness: 0.5,
              ),
              _SidebarTile(
                expanded: expanded,
                compact: compact,
                label: 'Sign out',
                icon: Icons.logout_rounded,
                selected: false,
                danger: true,
                onTap: () => context.read<AuthProvider>().logout(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarTile extends StatefulWidget {
  const _SidebarTile({
    required this.expanded,
    this.compact = false,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.danger = false,
    this.purpleGradientNav = false,
  });

  final bool expanded;
  final bool compact;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final bool danger;
  final bool purpleGradientNav;

  @override
  State<_SidebarTile> createState() => _SidebarTileState();
}

class _SidebarTileState extends State<_SidebarTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(17);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: borderRadius,
          splashColor: NuaLuxuryTokens.champagneGold.withValues(alpha: 0.08),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
              horizontal: widget.expanded ? (widget.compact ? 10 : 14) : 10,
              vertical: widget.compact ? 8 : 13,
            ),
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              gradient: widget.selected && widget.purpleGradientNav
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.52),
                        const Color(0xFF9D6BFF).withValues(alpha: 0.38),
                        NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.22),
                      ],
                    )
                  : null,
              color: widget.selected && widget.purpleGradientNav
                  ? null
                  : widget.selected
                  ? Colors.white.withValues(alpha: 0.11)
                  : _hover
                  ? Colors.white.withValues(alpha: 0.058)
                  : Colors.transparent,
              border: Border.all(
                color: widget.selected
                    ? NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.82)
                    : Colors.white.withValues(alpha: _hover ? 0.1 : 0.035),
              ),
              boxShadow: widget.selected
                  ? [
                      BoxShadow(
                        color: NuaLuxuryTokens.softPurpleGlow.withValues(
                          alpha: widget.purpleGradientNav ? 0.42 : 0.32,
                        ),
                        blurRadius: widget.purpleGradientNav ? 26 : 22,
                        spreadRadius: -2,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: widget.expanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Icon(
                  widget.icon,
                  size: widget.compact ? 20 : 22,
                  color: widget.danger
                      ? const Color(0xFFFF8A80)
                      : widget.selected || _hover
                      ? NuaLuxuryTokens.lavenderWhisper.withValues(alpha: 0.98)
                      : Colors.white.withValues(alpha: 0.62),
                ),
                if (widget.expanded) ...[
                  SizedBox(width: widget.compact ? 10 : 13),
                  Expanded(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.06,
                        fontSize: widget.compact ? 12.5 : null,
                        color: widget.danger
                            ? const Color(0xFFFF8A80)
                            : Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
