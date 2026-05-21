import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api/services/api_service.dart';
import '../../../models/admin/admin_activity_feed_item.dart';
import '../../../providers/auth_provider.dart';
import '../../../screens/admin/admin_suite_route.dart';
import '../../navigation/desktop_nav.dart';
import '../desk_global_search_bar.dart';
import '../../theme/nua_luxury_tokens.dart';
import 'luxury_glass_panel.dart';

/// Premium top chrome — glass search (global catalog jump), alerts, calendar, profile.
class LuxuryDesktopHeader extends StatelessWidget {
  const LuxuryDesktopHeader({
    super.key,
    required this.onDateChanged,
    this.selectedDay,
    this.notificationCount = 0,
    this.compactChrome = false,
  });

  final ValueChanged<DateTime> onDateChanged;
  final DateTime? selectedDay;
  final int notificationCount;
  /// Tighter header + narrower search (Calendar screen).
  final bool compactChrome;

  String _fmtDay(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _fmtRange(DateTimeRange r) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    String part(DateTime d) => '${months[d.month - 1]} ${d.day}';
    final y1 = r.start.year;
    final y2 = r.end.year;
    if (y1 == y2) {
      return '${part(r.start)} — ${part(r.end)}, $y2';
    }
    return '${part(r.start)}, $y1 — ${part(r.end)}, $y2';
  }

  Future<DateTimeRange?> _pickDateRange(
    BuildContext context,
    DateTimeRange initial,
  ) async {
    final now = DateTime.now();
    return showDateRangePicker(
      context: context,
      initialDateRange: initial,
      firstDate: now.subtract(const Duration(days: 365 * 2)),
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Select report range',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: NuaLuxuryTokens.softPurpleGlow,
              surface: NuaLuxuryTokens.voidViolet,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final initial = selectedDay ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 365 * 2)),
      lastDate: now.add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: NuaLuxuryTokens.softPurpleGlow,
              surface: NuaLuxuryTokens.voidViolet,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) onDateChanged(picked);
  }

  void _onFiltersTap(BuildContext context, DesktopNav nav) {
    nav.pulseHeaderFilters();
    final route = nav.route;
    if (route == DesktopRouteKey.commandCenter) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Dashboard shows today\'s live KPIs. Use the date picker for a specific day, or open Reports for a custom range.',
          ),
          behavior: SnackBarBehavior.floating,
          width: 440,
        ),
      );
    } else if (route == DesktopRouteKey.revenueAnalytics) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Use 7 / 30 / 90 day chips below, or pick a custom range with the date-range control.',
          ),
          behavior: SnackBarBehavior.floating,
          width: 420,
        ),
      );
    }
  }

  Future<void> _showNotifications(
    BuildContext context,
    AuthProvider auth,
    DateTime day,
  ) async {
    if (!auth.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notifications are available for admin accounts.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: NuaLuxuryTokens.voidViolet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFF5F3FA),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _fmtDay(day),
                      style: TextStyle(
                        fontSize: 12,
                        color: NuaLuxuryTokens.lavenderWhisper.withValues(
                          alpha: 0.65,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Recent activity from bookings, payments, and reviews.',
                  style: TextStyle(
                    fontSize: 13,
                    color: NuaLuxuryTokens.lavenderWhisper.withValues(
                      alpha: 0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 320,
                  child: FutureBuilder<List<AdminActivityFeedItem>>(
                    future: ApiService().getAdminActivityFeed(day: day, take: 12),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }
                      final items = snap.data ?? [];
                      if (items.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No activity for this day.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        );
                      }
                      return ListView.separated(
                        shrinkWrap: true,
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final item = items[i];
                          final icon = switch (item.tip) {
                            'payment' => Icons.payments_outlined,
                            'review' => Icons.reviews_outlined,
                            'client' => Icons.person_outline,
                            _ => Icons.event_note_outlined,
                          };
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              icon,
                              color: NuaLuxuryTokens.champagneGold,
                            ),
                            title: Text(
                              item.naslov,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFF5F3FA),
                              ),
                            ),
                            subtitle: item.podnaslov != null
                                ? Text(
                                    item.podnaslov!,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                  )
                                : null,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NuaLuxuryTokens.voidViolet,
        title: const Text(
          'Sign out?',
          style: TextStyle(color: Color(0xFFF5F3FA), fontWeight: FontWeight.w800),
        ),
        content: Text(
          'You will return to the sign-in screen.',
          style: TextStyle(
            color: NuaLuxuryTokens.lavenderWhisper.withValues(alpha: 0.75),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEC4899),
            ),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<AuthProvider>().logout();
    }
  }

  void _showProfileMenu(
    BuildContext anchorContext,
    AuthProvider auth,
    DesktopNav nav,
  ) {
    final button = anchorContext.findRenderObject() as RenderBox?;
    if (button == null || !button.hasSize) return;
    final overlay = Navigator.of(anchorContext).overlay!.context.findRenderObject() as RenderBox;
    final topLeft = button.localToGlobal(Offset.zero, ancestor: overlay);
    final bottomRight = button.localToGlobal(
      button.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );
    final rect = Rect.fromPoints(topLeft, bottomRight);

    showMenu<String>(
      context: anchorContext,
      color: NuaLuxuryTokens.voidViolet,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      position: RelativeRect.fromRect(rect, Offset.zero & overlay.size),
      items: [
        if (nav.route != DesktopRouteKey.settings)
          const PopupMenuItem(
            value: 'settings',
            child: _ProfileMenuRow(
              icon: Icons.tune_rounded,
              label: 'Settings',
            ),
          ),
        if (auth.isAdmin && nav.route != DesktopRouteKey.commandCenter)
          const PopupMenuItem(
            value: 'dashboard',
            child: _ProfileMenuRow(
              icon: Icons.space_dashboard_outlined,
              label: 'Command Center',
            ),
          ),
        if (auth.isAdmin)
          const PopupMenuItem(
            value: 'reports',
            child: _ProfileMenuRow(
              icon: Icons.area_chart_rounded,
              label: 'Reports',
            ),
          ),
        if (auth.isAdmin)
          const PopupMenuItem(
            value: 'appointments',
            child: _ProfileMenuRow(
              icon: Icons.event_note_outlined,
              label: 'Appointments',
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'logout',
          child: _ProfileMenuRow(
            icon: Icons.logout_rounded,
            label: 'Sign out',
            danger: true,
          ),
        ),
      ],
    ).then((value) {
      if (!anchorContext.mounted || value == null) return;
      switch (value) {
        case 'settings':
          nav.goTo(DesktopRouteKey.settings);
        case 'dashboard':
          nav.goTo(DesktopRouteKey.commandCenter);
        case 'reports':
          nav.goTo(DesktopRouteKey.revenueAnalytics);
        case 'appointments':
          nav.goTo(DesktopRouteKey.reservations);
        case 'logout':
          _confirmSignOut(anchorContext);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final nav = context.watch<DesktopNav>();
    final theme = Theme.of(context);
    final day = selectedDay ?? DateTime.now();
    final range = nav.headerDateRange;
    final isCommandCenter = nav.route == DesktopRouteKey.commandCenter;
    final isTherapists = nav.route == DesktopRouteKey.therapists;
    final isRevenue = nav.route == DesktopRouteKey.revenueAnalytics;
    final isAppointments = nav.route == DesktopRouteKey.reservations;
    final isCalendar = nav.route == DesktopRouteKey.adminCalendar;
    final isReviews = nav.route == DesktopRouteKey.reviews;
    final isSettings = nav.route == DesktopRouteKey.settings;
    final isAdminClients = nav.route == DesktopRouteKey.admin &&
        nav.adminSuiteTarget == AdminSuiteRoute.clients;
    final isAdminPayments = nav.route == DesktopRouteKey.admin &&
        nav.adminSuiteTarget == AdminSuiteRoute.finance;
    final compact = compactChrome ||
        isCalendar ||
        isAdminClients ||
        isAdminPayments;
    final showRangePills =
        isRevenue || isCommandCenter || isSettings;

    final roleLabel = auth.isAdmin
        ? 'Super Admin'
        : auth.isZaposlenik
            ? 'Therapist'
            : 'Client';

    final badgeCount = notificationCount > 0
        ? notificationCount
        : (auth.isAdmin ? 1 : 0);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 16 : 28,
        compact ? 8 : 18,
        compact ? 16 : 28,
        compact ? 4 : 8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isRevenue
                      ? 'Reports & Analytics'
                      : isCommandCenter
                      ? 'Good morning, Admin!'
                      : isAppointments
                      ? 'Appointments'
                      : isCalendar
                      ? 'Calendar'
                      : isTherapists
                      ? 'Therapists'
                      : isSettings
                      ? 'Settings'
                      : auth.isAdmin
                      ? 'Welcome back, Admin'
                      : 'Welcome back, ${auth.displayName ?? 'NuaSpa'}',
                  style: (compact
                          ? theme.textTheme.titleLarge
                          : theme.textTheme.headlineMedium)
                      ?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: compact ? -0.4 : -0.65,
                    color: const Color(0xFFF5F3FA),
                  ),
                ),
                SizedBox(height: compact ? 2 : 4),
                Text(
                  isRevenue
                      ? 'Revenue, service popularity, and top clients — live data from the NuaSpa backend.'
                      : isCommandCenter
                      ? "Here's what's happening at NuaSpa today."
                      : isAppointments
                      ? 'Manage, view and organize all spa appointments.'
                      : isCalendar
                      ? 'Manage your spa schedule and appointments.'
                      : isTherapists
                      ? 'Manage your spa therapists, specialties and schedules.'
                      : isSettings
                      ? 'Account, session, workspace shortcuts, and application details.'
                      : auth.isAdmin
                      ? 'Here is what is happening at NuaSpa today.'
                      : 'Your calm, polished workspace is ready.',
                  maxLines: compact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: compact ? 12.5 : null,
                    color: NuaLuxuryTokens.lavenderWhisper.withValues(
                      alpha: compact ? 0.55 : 0.62,
                    ),
                    letterSpacing: 0.05,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: compact ? 12 : 22),
          if (!isRevenue && !isCommandCenter && !isSettings) ...[
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: compact ? 340 : 380,
              ),
              child: DeskGlobalSearchBar(
                compact: compact,
                showShortcutHint: auth.isAdmin,
                controller: isCalendar ? nav.calendarSearchController : null,
                hintText: isTherapists
                    ? 'Search therapists…'
                    : isAdminClients
                        ? 'Search clients…'
                        : isAppointments
                            ? 'Search clients, appointments…'
                            : isCalendar
                                ? 'Search appointments…'
                                : isReviews
                                    ? 'Search reviews, clients, services…'
                                    : isAdminPayments
                                        ? 'Search payments, invoices, clients…'
                                        : 'Search services & treatments (Enter → Services)…',
                onChanged: isTherapists
                    ? (q) =>
                        context.read<DesktopNav>().setTherapistSearchQuery(q)
                    : isAppointments
                        ? (q) => context
                            .read<DesktopNav>()
                            .setAppointmentSearchQuery(q)
                        : null,
                onSubmitted: isTherapists
                    ? (q) =>
                        context.read<DesktopNav>().setTherapistSearchQuery(q)
                    : isAppointments
                        ? (q) => context
                            .read<DesktopNav>()
                            .setAppointmentSearchQuery(q)
                        : isCalendar
                            ? (_) {}
                            : null,
              ),
            ),
            SizedBox(width: compact ? 10 : 14),
          ] else if (showRangePills) ...[
            _HeaderPill(
              icon: Icons.date_range_outlined,
              label: _fmtRange(range),
              onTap: () async {
                final picked = await _pickDateRange(context, range);
                if (picked == null || !context.mounted) return;
                nav.setHeaderDateRange(picked);
                if (isSettings) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Range set to ${_fmtRange(picked)}. Open Reports to load analytics for this period.',
                      ),
                      behavior: SnackBarBehavior.floating,
                      width: 440,
                      action: SnackBarAction(
                        label: 'Reports',
                        onPressed: () =>
                            nav.goTo(DesktopRouteKey.revenueAnalytics),
                      ),
                    ),
                  );
                } else if (isCommandCenter) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Range saved (${_fmtRange(picked)}). Dashboard still focuses on the selected day — open Reports for range analytics.',
                      ),
                      behavior: SnackBarBehavior.floating,
                      width: 440,
                    ),
                  );
                }
              },
            ),
            const SizedBox(width: 10),
            _HeaderPill(
              icon: Icons.tune_rounded,
              label: 'Filters',
              onTap: () => _onFiltersTap(context, nav),
            ),
            const SizedBox(width: 14),
          ],
          _HeaderIconGlass(
            onTap: () => _showNotifications(context, auth, day),
            child: Badge(
              isLabelVisible: badgeCount > 0,
              label: Text('$badgeCount'),
              backgroundColor: NuaLuxuryTokens.softPurpleGlow,
              child: Icon(
                Icons.notifications_none_rounded,
                color: Colors.white.withValues(alpha: 0.88),
              ),
            ),
          ),
          if (!isRevenue) ...[
            SizedBox(width: compact ? 8 : 10),
            InkWell(
              borderRadius: BorderRadius.circular(NuaLuxuryTokens.radiusMd + 6),
              onTap: () => _pickDate(context),
              child: LuxuryGlassPanel(
                blurSigma: 18,
                opacity: 0.28,
                borderRadius: NuaLuxuryTokens.radiusMd + 6,
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 12 : 16,
                  vertical: compact ? 8 : 12,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      size: compact ? 18 : 20,
                      color: NuaLuxuryTokens.lavenderWhisper.withValues(
                        alpha: 0.9,
                      ),
                    ),
                    SizedBox(width: compact ? 6 : 10),
                    Text(
                      _fmtDay(day),
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: compact ? 12.5 : null,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.expand_more_rounded,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ),
            ),
          ],
          SizedBox(width: compact ? 8 : 12),
          Builder(
            builder: (profileContext) => InkWell(
              borderRadius: BorderRadius.circular(NuaLuxuryTokens.radiusMd + 8),
              onTap: () => _showProfileMenu(profileContext, auth, nav),
              child: LuxuryGlassPanel(
                blurSigma: 18,
                opacity: 0.32,
                borderRadius: NuaLuxuryTokens.radiusMd + 8,
                padding: EdgeInsets.fromLTRB(
                  compact ? 6 : 8,
                  compact ? 4 : 6,
                  compact ? 12 : 16,
                  compact ? 4 : 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: compact ? 17 : 20,
                      backgroundColor:
                          NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.35),
                      child: Text(
                        auth.userInitials ??
                            (auth.displayName != null &&
                                    auth.displayName!.isNotEmpty
                                ? auth.displayName![0].toUpperCase()
                                : null) ??
                            '•',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          auth.isAdmin ? 'Admin' : (auth.displayName ?? 'NuaSpa'),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          roleLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: NuaLuxuryTokens.champagneGold.withValues(
                              alpha: 0.9,
                            ),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.expand_more_rounded,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileMenuRow extends StatelessWidget {
  const _ProfileMenuRow({
    required this.icon,
    required this.label,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? const Color(0xFFEC4899)
        : const Color(0xFFF5F3FA);
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _HeaderPill extends StatelessWidget {
  const _HeaderPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(NuaLuxuryTokens.radiusMd + 6),
      onTap: onTap,
      child: LuxuryGlassPanel(
        blurSigma: 18,
        opacity: 0.28,
        borderRadius: NuaLuxuryTokens.radiusMd + 6,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: NuaLuxuryTokens.lavenderWhisper.withValues(alpha: 0.9),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFFF5F3FA),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.expand_more_rounded,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIconGlass extends StatelessWidget {
  const _HeaderIconGlass({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: LuxuryGlassPanel(
          blurSigma: 18,
          opacity: 0.26,
          borderRadius: 14,
          padding: const EdgeInsets.all(12),
          child: child,
        ),
      ),
    );
  }
}
