import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../widgets/notifications_panel.dart';
import '../../../providers/auth_provider.dart';
import '../../../screens/admin/admin_suite_route.dart';
import '../../navigation/desktop_nav.dart';
import '../desk_global_search_bar.dart';
import '../../theme/nua_luxury_tokens.dart';
import 'luxury_glass_panel.dart';

/// Shared vertical rhythm between shell header and page body (Dashboard baseline).
abstract final class LuxuryPageChrome {
  LuxuryPageChrome._();

  /// Inner padding of the page header row in the shell chrome card.
  static const EdgeInsets headerPadding = EdgeInsets.fromLTRB(28, 18, 28, 12);

  /// Padding for the first scrollable content block below the shell header.
  static const EdgeInsets bodyPadding = EdgeInsets.fromLTRB(28, 20, 28, 36);

  static const double headerRowHeight = 80;
  static const double headerStackedHeight = 118;
  static const double titleBlockHeight = 58;
  static const double titleSubtitleGap = 4;
  static const double stackedSearchGap = 10;
}

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
    BuildContext anchorContext,
  ) {
    return showLuxuryNotificationsDropdown(context, anchorContext);
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
      final serverOk = await context.read<AuthProvider>().logout();
      if (!context.mounted) return;
      if (!serverOk) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Server sign-out failed. Your local session was cleared.',
            ),
            behavior: SnackBarBehavior.floating,
            width: 420,
          ),
        );
      }
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
    final isTherapistDash =
        nav.route == DesktopRouteKey.therapistDashboard;
    final isTherapistAppts =
        nav.route == DesktopRouteKey.therapistAppointments;
    final isTherapistSchedule = nav.route == DesktopRouteKey.schedule &&
        auth.isZaposlenik;
    final isTherapistServices =
        nav.route == DesktopRouteKey.therapistServices;
    final isTherapistReviews =
        nav.route == DesktopRouteKey.therapistReviews;
    final isTherapistProfile =
        nav.route == DesktopRouteKey.therapistProfile;
    final isTherapistPortal = auth.isZaposlenik &&
        (isTherapistDash ||
            isTherapistAppts ||
            isTherapistSchedule ||
            isTherapistServices ||
            isTherapistReviews ||
            isTherapistProfile);
    final isAdminClients = nav.route == DesktopRouteKey.admin &&
        nav.adminSuiteTarget == AdminSuiteRoute.clients;
    final isAdminPayments = nav.route == DesktopRouteKey.admin &&
        nav.adminSuiteTarget == AdminSuiteRoute.finance;
    final isCatalog = nav.route == DesktopRouteKey.catalog;
    final compact = compactChrome;
    final showRangePills = isRevenue || isCommandCenter;

    final roleLabel = auth.isAdmin
        ? 'Administrator'
        : auth.isZaposlenik
            ? 'Therapist'
            : 'Client';

    final badgeCount = notificationCount;

    if (auth.isAdmin) {
      if (isCommandCenter) {
        return _buildSpaciousLuxuryHeader(
          context,
          auth: auth,
          nav: nav,
          day: day,
          notificationCount: badgeCount,
          title: 'Dashboard',
          subtitle: 'Welcome back, Admin. Here is today\'s overview.',
          searchHint: 'Search appointments, clients, services…',
          onSearchSubmitted: nav.performAdminGlobalSearch,
        );
      }
      if (isAppointments) {
        return _buildSpaciousLuxuryHeader(
          context,
          auth: auth,
          nav: nav,
          day: day,
          notificationCount: badgeCount,
          title: 'Appointments',
          subtitle: 'Manage, view and organize all spa appointments.',
          searchHint: 'Search clients, appointments…',
          initialSearchQuery: nav.appointmentSearchQuery,
          onSearchSubmitted: nav.setAppointmentSearchQuery,
          onSearchChanged: nav.setAppointmentSearchQuery,
        );
      }
      if (isCalendar) {
        return _buildSpaciousLuxuryHeader(
          context,
          auth: auth,
          nav: nav,
          day: day,
          notificationCount: badgeCount,
          title: 'Calendar',
          subtitle: 'Manage appointments and schedules.',
          searchHint: 'Search appointments…',
          searchController: nav.calendarSearchController,
          onSearchSubmitted: (_) {},
        );
      }
      if (isTherapists) {
        return _buildSpaciousLuxuryHeader(
          context,
          auth: auth,
          nav: nav,
          day: day,
          notificationCount: badgeCount,
          title: 'Therapists',
          subtitle: 'Manage your spa therapists, specialties and schedules.',
          summaryLine: nav.therapistPageSummary,
          searchHint: 'Search therapists…',
          onSearchSubmitted: nav.setTherapistSearchQuery,
          onSearchChanged: nav.setTherapistSearchQuery,
        );
      }
      if (isAdminClients) {
        return _buildSpaciousLuxuryHeader(
          context,
          auth: auth,
          nav: nav,
          day: day,
          notificationCount: badgeCount,
          title: 'Clients',
          subtitle: 'Manage client profiles and visit history.',
          searchHint: 'Search clients…',
          initialSearchQuery: nav.clientSearchQuery,
          onSearchSubmitted: nav.setClientSearchQuery,
          onSearchChanged: nav.setClientSearchQuery,
        );
      }
      if (isAdminPayments) {
        return _buildSpaciousLuxuryHeader(
          context,
          auth: auth,
          nav: nav,
          day: day,
          notificationCount: badgeCount,
          title: 'Payments',
          subtitle: 'Track revenue, refunds, and payment activity.',
          searchHint: 'Search across NuaSpa...',
          initialSearchQuery: nav.paymentSearchQuery,
          onSearchSubmitted: nav.setPaymentSearchQuery,
          onSearchChanged: nav.setPaymentSearchQuery,
        );
      }
      if (isCatalog) {
        return _buildSpaciousLuxuryHeader(
          context,
          auth: auth,
          nav: nav,
          day: day,
          notificationCount: badgeCount,
          title: 'Services',
          subtitle: 'Manage treatments, pricing and categories.',
          searchHint: 'Search services & treatments…',
          initialSearchQuery: nav.catalogSearchQuery,
          onSearchSubmitted: nav.setCatalogSearchQuery,
          onSearchChanged: nav.setCatalogSearchQuery,
        );
      }
      if (isReviews) {
        return _buildSpaciousLuxuryHeader(
          context,
          auth: auth,
          nav: nav,
          day: day,
          notificationCount: badgeCount,
          title: 'Reviews',
          subtitle: 'Monitor ratings and guest feedback.',
          searchHint: 'Search across NuaSpa...',
          initialSearchQuery: nav.reviewsSearchQuery,
          onSearchSubmitted: nav.setReviewsSearchQuery,
          onSearchChanged: nav.setReviewsSearchQuery,
        );
      }
      if (isSettings) {
        return _buildSpaciousLuxuryHeader(
          context,
          auth: auth,
          nav: nav,
          day: day,
          notificationCount: badgeCount,
          title: 'Settings',
          subtitle:
              'Manage your account, security and workspace preferences.',
          searchHint: 'Search across NuaSpa…',
          onSearchSubmitted: nav.performAdminGlobalSearch,
        );
      }
    }

    if (isTherapistDash && auth.isZaposlenik) {
      return _buildSpaciousLuxuryHeader(
        context,
        auth: auth,
        nav: nav,
        day: day,
        notificationCount: badgeCount,
        title: nav.therapistDashboardTitle ?? "Today's Overview",
        subtitle: nav.therapistDashboardSubtitle ??
            'Your schedule, clients and appointments for today.',
        searchHint: 'Search clients, services…',
        onSearchSubmitted: nav.goToCatalogWithSearch,
      );
    }

    if (isTherapistAppts && auth.isZaposlenik) {
      return _buildSpaciousLuxuryHeader(
        context,
        auth: auth,
        nav: nav,
        day: day,
        notificationCount: badgeCount,
        title: 'My Appointments',
        subtitle: 'Your assigned bookings and daily schedule.',
        searchHint: 'Search clients, services…',
        onSearchSubmitted: nav.goToCatalogWithSearch,
      );
    }

    if (isSettings && auth.isZaposlenik) {
      return _buildSpaciousLuxuryHeader(
        context,
        auth: auth,
        nav: nav,
        day: day,
        notificationCount: badgeCount,
        title: 'Settings',
        subtitle: 'Manage your account, security and workspace preferences.',
        searchHint: 'Search clients, services…',
        onSearchSubmitted: nav.goToCatalogWithSearch,
      );
    }

    if (isSettings) {
      return _buildSpaciousLuxuryHeader(
        context,
        auth: auth,
        nav: nav,
        day: day,
        notificationCount: badgeCount,
        title: 'Settings',
        subtitle: 'Manage your account, security and workspace preferences.',
        searchHint: 'Search services & treatments…',
        onSearchSubmitted: nav.goToCatalogWithSearch,
      );
    }

    return Padding(
      padding: LuxuryPageChrome.headerPadding,
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
                      ? 'Dashboard'
                      : isAppointments
                      ? 'Appointments'
                      : isCalendar
                      ? 'Calendar'
                      : isTherapists
                      ? 'Therapists'
                      : isTherapistDash
                      ? (nav.therapistDashboardTitle ?? "Today's Overview")
                      : isTherapistAppts
                      ? 'My Appointments'
                      : isTherapistSchedule
                      ? 'My Schedule'
                      : isTherapistServices
                      ? 'My Services'
                      : isTherapistReviews
                      ? 'My Reviews'
                      : isTherapistProfile
                      ? 'Profile'
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
                      ? 'Revenue, service popularity and client insights.'
                      : isCommandCenter
                      ? 'Overview of bookings, revenue and business performance.'
                      : isAppointments
                      ? 'Manage, view and organize all spa appointments.'
                      : isCalendar
                      ? 'Manage your spa schedule and appointments.'
                      : isTherapists
                      ? 'Manage your spa therapists, specialties and schedules.'
                      : isTherapistDash
                      ? (nav.therapistDashboardSubtitle ??
                          'Your schedule, clients and appointments for today.')
                      : isTherapistAppts
                      ? 'Your assigned bookings and daily schedule.'
                      : isTherapistSchedule
                      ? 'Manage your daily bookings and availability.'
                      : isTherapistServices
                      ? 'View treatments you are certified to perform at NuaSpa.'
                      : isTherapistReviews
                      ? 'Client feedback from appointments you performed.'
                      : isTherapistProfile
                      ? 'Manage your therapist profile, contact details, and professional identity.'
                      : isSettings
                      ? 'Manage your account, security and workspace preferences.'
                      : auth.isAdmin
                      ? 'Here is what is happening at NuaSpa today.'
                      : 'Your calm, polished workspace is ready.',
                  maxLines: 1,
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
                hintText: isTherapistPortal
                    ? 'Search clients, services…'
                    : isTherapists
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
                                        ? 'Search across NuaSpa...'
                                        : 'Search services & treatments (Enter → Services)…',
                onChanged: isTherapists
                    ? (q) =>
                        context.read<DesktopNav>().setTherapistSearchQuery(q)
                    : isAppointments
                        ? (q) => context
                            .read<DesktopNav>()
                            .setAppointmentSearchQuery(q)
                        : isReviews
                            ? (q) => context
                                .read<DesktopNav>()
                                .setReviewsSearchQuery(q)
                            : null,
                onSubmitted: isTherapists
                    ? (q) =>
                        context.read<DesktopNav>().setTherapistSearchQuery(q)
                    : isAppointments
                        ? (q) => context
                            .read<DesktopNav>()
                            .setAppointmentSearchQuery(q)
                        : isReviews
                            ? (q) => context
                                .read<DesktopNav>()
                                .setReviewsSearchQuery(q)
                            : isCalendar
                                ? (_) {}
                                : null,
              ),
            ),
            SizedBox(width: compact ? 10 : 14),
          ] else if (showRangePills && !isCommandCenter) ...[
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
            if (isRevenue) ...[
              const SizedBox(width: 10),
              _ReportsPdfExportButton(
                exporting: nav.reportsPdfExporting,
                onExport: nav.reportsPdfExport,
              ),
            ],
            const SizedBox(width: 14),
          ],
          Builder(
            builder: (bellCtx) => _HeaderIconGlass(
              onTap: () => _showNotifications(context, bellCtx),
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
                            (auth.isZaposlenik
                                ? 'TH'
                                : (auth.displayName != null &&
                                        auth.displayName!.isNotEmpty
                                    ? auth.displayName![0].toUpperCase()
                                    : null)) ??
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
                          auth.isAdmin
                              ? 'Admin'
                              : (auth.isZaposlenik
                                  ? (auth.displayName ?? 'therapist')
                                  : (auth.displayName ?? 'NuaSpa')),
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

  Widget _buildSpaciousLuxuryHeader(
    BuildContext context, {
    required AuthProvider auth,
    required DesktopNav nav,
    required DateTime day,
    required int notificationCount,
    required String title,
    required String subtitle,
    required String searchHint,
    required ValueChanged<String> onSearchSubmitted,
    ValueChanged<String>? onSearchChanged,
    String? initialSearchQuery,
    TextEditingController? searchController,
    String? summaryLine,
  }) {
    return _SpaciousLuxuryPageHeader(
      title: title,
      subtitle: subtitle,
      summaryLine: summaryLine,
      searchHint: searchHint,
      onSearchSubmitted: onSearchSubmitted,
      onSearchChanged: onSearchChanged,
      initialSearchQuery: initialSearchQuery,
      searchController: searchController,
      auth: auth,
      day: day,
      notificationCount: notificationCount,
      fmtDay: _fmtDay,
      onPickDate: () => _pickDate(context),
      onNotifications: (bellCtx) => _showNotifications(context, bellCtx),
      onProfile: (ctx) => _showProfileMenu(ctx, auth, nav),
    );
  }
}

class _FocusDashboardSearchIntent extends Intent {
  const _FocusDashboardSearchIntent();
}

/// Spacious enterprise header — Dashboard, Appointments, and matching admin routes.
class _SpaciousLuxuryPageHeader extends StatefulWidget {
  const _SpaciousLuxuryPageHeader({
    required this.title,
    required this.subtitle,
    this.summaryLine,
    required this.searchHint,
    required this.onSearchSubmitted,
    required this.auth,
    required this.day,
    required this.notificationCount,
    required this.fmtDay,
    required this.onPickDate,
    required this.onNotifications,
    required this.onProfile,
    this.onSearchChanged,
    this.initialSearchQuery,
    this.searchController,
  });

  final String title;
  final String subtitle;
  final String? summaryLine;
  final String searchHint;
  final ValueChanged<String> onSearchSubmitted;
  final ValueChanged<String>? onSearchChanged;
  final String? initialSearchQuery;
  final TextEditingController? searchController;
  final AuthProvider auth;
  final DateTime day;
  final int notificationCount;
  final String Function(DateTime) fmtDay;
  final VoidCallback onPickDate;
  final void Function(BuildContext anchorContext) onNotifications;
  final void Function(BuildContext) onProfile;

  @override
  State<_SpaciousLuxuryPageHeader> createState() =>
      _SpaciousLuxuryPageHeaderState();
}

class _SpaciousLuxuryPageHeaderState extends State<_SpaciousLuxuryPageHeader> {
  final _searchFocus = FocusNode();
  late final TextEditingController _searchController;
  late final bool _ownsSearchController;

  static const _gap = 16.0;
  static const _wideBreakpoint = 1100.0;

  @override
  void initState() {
    super.initState();
    final external = widget.searchController;
    if (external != null) {
      _searchController = external;
      _ownsSearchController = false;
    } else {
      _searchController = TextEditingController(
        text: widget.initialSearchQuery ?? '',
      );
      _ownsSearchController = true;
    }
  }

  @override
  void didUpdateWidget(covariant _SpaciousLuxuryPageHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.initialSearchQuery ?? '';
    if (next != oldWidget.initialSearchQuery &&
        next != _searchController.text) {
      _searchController.text = next;
    }
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    if (_ownsSearchController) {
      _searchController.dispose();
    }
    super.dispose();
  }

  AuthProvider get auth => widget.auth;

  DateTime get day => widget.day;

  int get notificationCount => widget.notificationCount;

  String fmtDay(DateTime d) => widget.fmtDay(d);

  VoidCallback get onPickDate => widget.onPickDate;

  void Function(BuildContext anchorContext) get onNotifications =>
      widget.onNotifications;

  void Function(BuildContext) get onProfile => widget.onProfile;

  Widget _titleBlock() {
    final summary = widget.summaryLine?.trim();
    final hasSummary = summary != null && summary.isNotEmpty;
    return SizedBox(
      height: hasSummary ? 78 : LuxuryPageChrome.titleBlockHeight,
      child: ClipRect(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                height: 1.05,
                color: const Color(0xFFF5F3FA),
              ),
            ),
            SizedBox(height: LuxuryPageChrome.titleSubtitleGap),
            Text(
              widget.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.2,
                color: NuaLuxuryTokens.lavenderWhisper.withValues(alpha: 0.72),
              ),
            ),
            if (hasSummary) ...[
              const SizedBox(height: 6),
              Text(
                summary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  color: NuaLuxuryTokens.lavenderWhisper.withValues(alpha: 0.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _dateButton() {
    return _DashboardHeaderControl(
      onTap: onPickDate,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_month_outlined,
            size: 20,
            color: NuaLuxuryTokens.lavenderWhisper.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 10),
          Text(
            fmtDay(day),
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFF5F3FA),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.expand_more_rounded,
            size: 20,
            color: Colors.white.withValues(alpha: 0.45),
          ),
        ],
      ),
    );
  }

  Widget _profilePill({required bool showDetails}) {
    final initials = auth.userInitials ??
        (auth.displayName != null && auth.displayName!.length >= 2
            ? auth.displayName!.substring(0, 2).toUpperCase()
            : 'AD');

    return Builder(
      builder: (profileContext) => _DashboardHeaderControl(
        onTap: () => onProfile(profileContext),
        padding: EdgeInsets.fromLTRB(
          showDetails ? 8 : 6,
          6,
          showDetails ? 14 : 8,
          6,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: showDetails ? 20 : 18,
              backgroundColor:
                  NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.35),
              child: Text(
                initials,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: const Color(0xFFF5F3FA),
                ),
              ),
            ),
            if (showDetails) ...[
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    auth.isAdmin ? 'Admin' : (auth.displayName ?? 'NuaSpa'),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFF5F3FA),
                    ),
                  ),
                  Text(
                    auth.isAdmin
                        ? 'Administrator'
                        : auth.isZaposlenik
                            ? 'Therapist'
                            : 'Client',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: NuaLuxuryTokens.champagneGold.withValues(
                        alpha: 0.92,
                      ),
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
          ],
        ),
      ),
    );
  }

  Widget _controlsRow({required bool showProfileDetails}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Builder(
          builder: (bellCtx) => SizedBox(
            height: 50,
            width: 50,
            child: _HeaderIconGlass(
              onTap: () => onNotifications(bellCtx),
              borderRadius: 18,
              child: Badge(
                isLabelVisible: notificationCount > 0,
                label: Text('$notificationCount'),
                backgroundColor: NuaLuxuryTokens.softPurpleGlow,
                child: Icon(
                  Icons.notifications_none_rounded,
                  color: Colors.white.withValues(alpha: 0.88),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: _gap),
        _dateButton(),
        const SizedBox(width: _gap),
        _profilePill(showDetails: showProfileDetails),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _FocusDashboardSearchIntent(),
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            _FocusDashboardSearchIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _FocusDashboardSearchIntent: CallbackAction<_FocusDashboardSearchIntent>(
            onInvoke: (_) {
              _searchFocus.requestFocus();
              return null;
            },
          ),
        },
        child: Padding(
      padding: LuxuryPageChrome.headerPadding,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final showSearch = w >= 720;
          final showProfileDetails = w >= 980;
          final useWideRow = w >= _wideBreakpoint && showSearch;
          final contentHeight = useWideRow
              ? LuxuryPageChrome.headerRowHeight
              : (showSearch
                  ? LuxuryPageChrome.headerStackedHeight
                  : LuxuryPageChrome.headerRowHeight);

          const searchMaxW = 400.0;

          final search = DeskGlobalSearchBar(
            dashboardStyle: true,
            showShortcutHint: true,
            maxWidth: searchMaxW,
            focusNode: _searchFocus,
            controller: _searchController,
            hintText: widget.searchHint,
            onSubmitted: widget.onSearchSubmitted,
            onChanged: widget.onSearchChanged,
          );

          Widget content;
          if (useWideRow) {
            content = Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: _titleBlock(),
                    ),
                  ),
                ),
                const SizedBox(width: _gap),
                search,
                const Spacer(),
                _controlsRow(showProfileDetails: showProfileDetails),
              ],
            );
          } else {
            content = ClipRect(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: _titleBlock()),
                      _controlsRow(showProfileDetails: showProfileDetails),
                    ],
                  ),
                  if (showSearch) ...[
                    SizedBox(height: LuxuryPageChrome.stackedSearchGap),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: search,
                    ),
                  ],
                ],
              ),
            );
          }

          return SizedBox(
            height: contentHeight,
            child: Align(
              alignment: Alignment.centerLeft,
              child: content,
            ),
          );
        },
      ),
        ),
      ),
    );
  }
}

class _DashboardHeaderControl extends StatefulWidget {
  const _DashboardHeaderControl({
    required this.child,
    required this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  final Widget child;
  final VoidCallback onTap;
  final EdgeInsetsGeometry padding;

  @override
  State<_DashboardHeaderControl> createState() => _DashboardHeaderControlState();
}

class _DashboardHeaderControlState extends State<_DashboardHeaderControl> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minHeight: 50),
            padding: widget.padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: const Color.fromRGBO(255, 255, 255, 0.04),
              border: Border.all(
                color: Color.fromRGBO(
                  255,
                  255,
                  255,
                  _hover ? 0.12 : 0.08,
                ),
              ),
              boxShadow: _hover
                  ? [
                      BoxShadow(
                        color: NuaLuxuryTokens.softPurpleGlow.withValues(
                          alpha: 0.14,
                        ),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: widget.child,
          ),
        ),
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

class _ReportsPdfExportButton extends StatelessWidget {
  const _ReportsPdfExportButton({
    required this.exporting,
    required this.onExport,
  });

  final bool exporting;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: exporting || onExport == null ? null : onExport,
      icon: exporting
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            )
          : Icon(
              Icons.picture_as_pdf_outlined,
              size: 17,
              color: Colors.white.withValues(alpha: 0.7),
            ),
      label: Text(exporting ? 'Exporting...' : 'PDF Report'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white.withValues(alpha: 0.82),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
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
  const _HeaderIconGlass({
    required this.child,
    required this.onTap,
    this.borderRadius = 14,
  });

  final Widget child;
  final VoidCallback onTap;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: onTap,
        child: LuxuryGlassPanel(
          blurSigma: 18,
          opacity: 0.26,
          borderRadius: borderRadius,
          padding: const EdgeInsets.all(12),
          child: child,
        ),
      ),
    );
  }
}
