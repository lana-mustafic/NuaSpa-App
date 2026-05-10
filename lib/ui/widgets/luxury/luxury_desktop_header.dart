import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
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
    const w = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${w[d.weekday - 1]} · ${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
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
    final theme = Theme.of(context);
    final day = selectedDay ?? DateTime.now();

    final roleLabel = auth.isAdmin
        ? 'Administrator'
        : auth.isZaposlenik
            ? 'Therapist'
            : 'Client';

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 18, 28, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius:
                  BorderRadius.circular(NuaLuxuryTokens.radiusMd + 4),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.045),
                    borderRadius:
                        BorderRadius.circular(NuaLuxuryTokens.radiusMd + 4),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 0.85,
                    ),
                  ),
                  child: const DeskGlobalSearchBar(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          _HeaderIconGlass(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('Notifications — concierge integrations upcoming'),
                      behavior: SnackBarBehavior.floating,
                      width: 380,
                    ),
                  );
                },
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
          const SizedBox(width: 10),
          InkWell(
                borderRadius:
                    BorderRadius.circular(NuaLuxuryTokens.radiusMd + 6),
                onTap: () => _pickDate(context),
                child: LuxuryGlassPanel(
                  blurSigma: 18,
                  opacity: 0.28,
                  borderRadius: NuaLuxuryTokens.radiusMd + 6,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_month_outlined,
                        size: 20,
                        color: NuaLuxuryTokens.lavenderWhisper
                            .withValues(alpha: 0.9),
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
                          auth.displayName ?? 'NuaSpa',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          roleLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: NuaLuxuryTokens.champagneGold
                                .withValues(alpha: 0.9),
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
