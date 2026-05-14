import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final nav = context.watch<DesktopNav>();
    final theme = Theme.of(context);
    final day = selectedDay ?? DateTime.now();
    final isTherapists = nav.route == DesktopRouteKey.therapists;
    final isRevenue = nav.route == DesktopRouteKey.revenueAnalytics;
    final isAppointments = nav.route == DesktopRouteKey.reservations;
    final isCalendar = nav.route == DesktopRouteKey.adminCalendar;
    final isReviews = nav.route == DesktopRouteKey.reviews;
    final isAdminClients = nav.route == DesktopRouteKey.admin &&
        nav.adminSuiteTarget == AdminSuiteRoute.clients;
    final isAdminPayments = nav.route == DesktopRouteKey.admin &&
        nav.adminSuiteTarget == AdminSuiteRoute.finance;
    final compact = compactChrome ||
        isCalendar ||
        isAdminClients ||
        isAdminPayments;

    final roleLabel = auth.isAdmin
        ? 'Super Admin'
        : auth.isZaposlenik
            ? 'Therapist'
            : 'Client';

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
                      ? 'Revenue Analytics'
                      : isAppointments
                      ? 'Appointments'
                      : isCalendar
                      ? 'Calendar'
                      : isTherapists
                      ? 'Therapists'
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
                      ? "Track your spa's financial performance and insights."
                      : isAppointments
                      ? 'Manage, view and organize all spa appointments.'
                      : isCalendar
                      ? 'Manage your spa schedule and appointments.'
                      : isTherapists
                      ? 'Manage your spa therapists, specialties and schedules.'
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
          if (!isRevenue) ...[
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
                        ? 'Search services & therapies…'
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
          ] else ...[
            _HeaderPill(
              icon: Icons.date_range_outlined,
              label: 'May 12 — Jun 11, 2025',
              onTap: () => _pickDate(context),
            ),
            const SizedBox(width: 10),
            _HeaderPill(
              icon: Icons.tune_rounded,
              label: 'Filters',
              onTap: () {},
            ),
            const SizedBox(width: 14),
          ],
          _HeaderIconGlass(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Notifications — concierge integrations upcoming',
                  ),
                  behavior: SnackBarBehavior.floating,
                  width: 380,
                ),
              );
            },
            child: Badge(
              isLabelVisible: isRevenue || notificationCount > 0,
              label: Text('${isRevenue ? 3 : notificationCount}'),
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
          LuxuryGlassPanel(
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
                  backgroundColor: NuaLuxuryTokens.softPurpleGlow.withValues(
                    alpha: 0.35,
                  ),
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
              ],
            ),
          ),
        ],
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
