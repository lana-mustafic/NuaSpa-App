import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
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
  });

  final ValueChanged<DateTime> onDateChanged;
  final DateTime? selectedDay;
  final int notificationCount;

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

    final roleLabel = auth.isAdmin
        ? 'Administrator'
        : auth.isZaposlenik
        ? 'Therapist'
        : 'Client';

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 18, 28, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isRevenue
                      ? 'Revenue Analytics'
                      : isTherapists
                      ? 'Therapists'
                      : auth.isAdmin
                      ? 'Welcome back, Admin'
                      : 'Welcome back, ${auth.displayName ?? 'NuaSpa'}',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.65,
                    color: const Color(0xFFF5F3FA),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isRevenue
                      ? "Track your spa's financial performance and insights."
                      : isTherapists
                      ? 'Manage your spa therapists, specialties and schedules.'
                      : auth.isAdmin
                      ? 'Here is what is happening at NuaSpa today.'
                      : 'Your calm, polished workspace is ready.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: NuaLuxuryTokens.lavenderWhisper.withValues(
                      alpha: 0.62,
                    ),
                    letterSpacing: 0.05,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 22),
          if (!isRevenue) ...[
            SizedBox(
              width: 340,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.052),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.11),
                        width: 0.85,
                      ),
                    ),
                    child: DeskGlobalSearchBar(
                      hintText: isTherapists
                          ? 'Search therapists…'
                          : 'Search services & treatments (Enter → Services)…',
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
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
            const SizedBox(width: 10),
            InkWell(
              borderRadius: BorderRadius.circular(NuaLuxuryTokens.radiusMd + 6),
              onTap: () => _pickDate(context),
              child: LuxuryGlassPanel(
                blurSigma: 18,
                opacity: 0.28,
                borderRadius: NuaLuxuryTokens.radiusMd + 6,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      size: 20,
                      color: NuaLuxuryTokens.lavenderWhisper.withValues(
                        alpha: 0.9,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _fmtDay(day),
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
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
          const SizedBox(width: 12),
          LuxuryGlassPanel(
            blurSigma: 18,
            opacity: 0.32,
            borderRadius: NuaLuxuryTokens.radiusMd + 8,
            padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 20,
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
                      auth.displayName ?? 'NuaSpa',
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
