import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/api/services/api_service.dart';
import '../../core/auth/app_permissions.dart';
import '../../models/therapist/therapist_dashboard.dart';
import '../../providers/auth_provider.dart';
import '../../ui/navigation/desktop_nav.dart';
import '../../ui/widgets/luxury/luxury_mini_sparkline.dart';
import 'therapist_portal_scaffold.dart';

abstract final class _TdUi {
  static const bgTop = Color(0xFF07040F);
  static const bgBottom = Color(0xFF120A24);
  static const textPrimary = Color(0xFFF5F3FA);
  static const textSecondary = Color(0xA6FFFFFF);
  static const purple = Color(0xFF7B4DFF);
  static const lavender = Color(0xFF9D6BFF);
  static const green = Color(0xFF22C55E);
  static const gold = Color(0xFFF5B942);
  static const pink = Color(0xFFEC4899);
  static const cardRadius = 24.0;
  static const kpiHeight = 180.0;
  static const gap = 24.0;
  static const contentPadding = 32.0;
}

List<double> _sparkFrom(num value, {int points = 7}) {
  final v = value.toDouble();
  if (v <= 0) return List<double>.filled(points, 0);
  return List.generate(points, (i) => v * (0.55 + 0.45 * (i / (points - 1))));
}

class TherapistDashboardScreen extends StatefulWidget {
  const TherapistDashboardScreen({super.key});

  @override
  State<TherapistDashboardScreen> createState() =>
      _TherapistDashboardScreenState();
}

class _TherapistDashboardScreenState extends State<TherapistDashboardScreen> {
  final _api = ApiService();
  Future<TherapistDashboard?>? _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final auth = context.read<AuthProvider>();
    if (!AppPermissions.of(auth).has(AppPermission.viewOwnTherapistData)) {
      return;
    }
    setState(() {
      _future = _api.getTherapistDashboard(day: DateTime.now());
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isZaposlenik || auth.zaposlenikId == null) {
      return const _TherapistDashShell(
        child: TherapistEmptyState(
          message: 'Contact your spa administrator to link your login.',
        ),
      );
    }

    return _TherapistDashShell(
      child: FutureBuilder<TherapistDashboard?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          final d = snap.data;
          if (d == null) {
            return _TherapistDashGlass(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Could not load dashboard.',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _TdUi.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _TherapistGradientButton(
                    label: 'Try again',
                    icon: Icons.refresh_rounded,
                    onTap: _reload,
                  ),
                ],
              ),
            );
          }
          return _TherapistDashboardBody(data: d);
        },
      ),
    );
  }
}

class _TherapistDashShell extends StatelessWidget {
  const _TherapistDashShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_TdUi.bgTop, _TdUi.bgBottom],
        ),
      ),
      child: child,
    );
  }
}

class _TherapistDashboardBody extends StatelessWidget {
  const _TherapistDashboardBody({required this.data});

  final TherapistDashboard data;

  @override
  Widget build(BuildContext context) {
    final rating = data.prosjecnaOcjena;
    final ratingLabel = rating > 0 ? rating.toStringAsFixed(1) : '—';
    final satisfaction = rating > 0
        ? '${(rating / 5 * 100).round()}%'
        : '0%';

    return LayoutBuilder(
      builder: (context, c) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            _TdUi.contentPadding,
            8,
            _TdUi.contentPadding,
            40,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TherapistKpiRow(
                cards: [
                  _TherapistKpiSpec(
                    label: "Today's Appointments",
                    value: '${data.todayAppointments}',
                    trend: '0% vs yesterday',
                    icon: Icons.calendar_today_rounded,
                    accent: _TdUi.purple,
                    sparkline: _sparkFrom(data.todayAppointments),
                  ),
                  _TherapistKpiSpec(
                    label: 'Upcoming Appointments',
                    value: '${data.upcomingAppointments}',
                    trend: '0% vs yesterday',
                    icon: Icons.check_circle_rounded,
                    accent: _TdUi.green,
                    sparkline: _sparkFrom(data.upcomingAppointments),
                  ),
                  _TherapistKpiSpec(
                    label: 'Average Rating',
                    value: ratingLabel,
                    trend: '0% vs last month',
                    icon: Icons.star_rounded,
                    accent: _TdUi.gold,
                    sparkline: _sparkFrom(rating > 0 ? rating : 5),
                  ),
                  _TherapistKpiSpec(
                    label: 'Revenue (Month)',
                    value: '€${data.revenueThisMonth.toStringAsFixed(0)}',
                    trend: '0% vs last month',
                    icon: Icons.account_balance_wallet_rounded,
                    accent: _TdUi.pink,
                    sparkline: _sparkFrom(data.revenueThisMonth),
                  ),
                ],
              ),
              const SizedBox(height: _TdUi.gap),
              LayoutBuilder(
                builder: (context, mc) {
                  final stack = mc.maxWidth < 960;
                  final todayCard = _TodayScheduleCard(
                    count: data.todayAppointments,
                  );
                  final upcomingCard = _UpcomingAppointmentsCard(
                    count: data.upcomingAppointments,
                  );
                  if (stack) {
                    return Column(
                      children: [
                        todayCard,
                        const SizedBox(height: _TdUi.gap),
                        upcomingCard,
                      ],
                    );
                  }
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: todayCard),
                        const SizedBox(width: _TdUi.gap),
                        Expanded(child: upcomingCard),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: _TdUi.gap),
              _PerformanceOverviewCard(
                completed: data.completedThisMonth,
                reviewCount: data.reviewCount,
                satisfaction: satisfaction,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TherapistKpiSpec {
  const _TherapistKpiSpec({
    required this.label,
    required this.value,
    required this.trend,
    required this.icon,
    required this.accent,
    required this.sparkline,
  });

  final String label;
  final String value;
  final String trend;
  final IconData icon;
  final Color accent;
  final List<double> sparkline;
}

class _TherapistKpiRow extends StatelessWidget {
  const _TherapistKpiRow({required this.cards});

  final List<_TherapistKpiSpec> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 1280
            ? 4
            : c.maxWidth >= 640
            ? 2
            : 1;
        final w = (c.maxWidth - 18 * (cols - 1)) / cols;
        return Wrap(
          spacing: 18,
          runSpacing: 18,
          children: [
            for (final card in cards)
              SizedBox(
                width: w.clamp(220, c.maxWidth),
                height: _TdUi.kpiHeight,
                child: _TherapistKpiCard(spec: card),
              ),
          ],
        );
      },
    );
  }
}

class _TherapistKpiCard extends StatefulWidget {
  const _TherapistKpiCard({required this.spec});

  final _TherapistKpiSpec spec;

  @override
  State<_TherapistKpiCard> createState() => _TherapistKpiCardState();
}

class _TherapistKpiCardState extends State<_TherapistKpiCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.spec;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: double.infinity,
        transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
        child: _TherapistDashGlass(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: s.accent.withValues(alpha: 0.14),
                  border: Border.all(
                    color: s.accent.withValues(alpha: 0.38),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: s.accent.withValues(alpha: _hover ? 0.5 : 0.28),
                      blurRadius: 20,
                      spreadRadius: 0.5,
                    ),
                  ],
                ),
                child: Icon(s.icon, color: s.accent, size: 20),
              ),
              const SizedBox(height: 10),
              Text(
                s.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _TdUi.textSecondary,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                s.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: _TdUi.textPrimary,
                  letterSpacing: -0.6,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                s.trend,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _TdUi.textSecondary,
                  height: 1.2,
                ),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: LuxuryMiniSparkline(
                    values: s.sparkline,
                    height: 28,
                    accentColor: s.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayScheduleCard extends StatelessWidget {
  const _TodayScheduleCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final nav = context.read<DesktopNav>();
    return _TherapistDashGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle(
            title: "Today's Schedule",
            icon: Icons.calendar_month_rounded,
            iconColor: _TdUi.purple,
          ),
          const SizedBox(height: 20),
          if (count > 0)
            _AppointmentsSummary(
              count: count,
              noun: 'appointment',
              onOpen: () => nav.goTo(DesktopRouteKey.therapistAppointments),
            )
          else
            _EmptyPanel(
              icon: Icons.event_available_rounded,
              iconColor: _TdUi.purple,
              title: 'No appointments scheduled for today',
              subtitle: 'You\'re all clear! Enjoy your day.',
              actionLabel: 'View Full Schedule',
              onAction: () => nav.goTo(DesktopRouteKey.schedule),
            ),
        ],
      ),
    );
  }
}

class _UpcomingAppointmentsCard extends StatelessWidget {
  const _UpcomingAppointmentsCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final nav = context.read<DesktopNav>();
    return _TherapistDashGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: _SectionTitle(
                  title: 'Upcoming Appointments',
                  icon: Icons.upcoming_rounded,
                  iconColor: _TdUi.green,
                ),
              ),
              TextButton(
                onPressed: () =>
                    nav.goTo(DesktopRouteKey.therapistAppointments),
                style: TextButton.styleFrom(
                  foregroundColor: _TdUi.lavender,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: Text(
                  'View all',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (count > 0)
            _AppointmentsSummary(
              count: count,
              noun: 'upcoming appointment',
              onOpen: () => nav.goTo(DesktopRouteKey.therapistAppointments),
            )
          else
            _EmptyPanel(
              icon: Icons.assignment_turned_in_outlined,
              iconColor: _TdUi.green,
              title: 'No upcoming appointments',
              subtitle: 'You have no upcoming appointments.',
              actionLabel: 'View Calendar',
              onAction: () => nav.goTo(DesktopRouteKey.schedule),
            ),
        ],
      ),
    );
  }
}

class _AppointmentsSummary extends StatelessWidget {
  const _AppointmentsSummary({
    required this.count,
    required this.noun,
    required this.onOpen,
  });

  final int count;
  final String noun;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final label = count == 1 ? noun : '${noun}s';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Text(
            '$count $label',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _TdUi.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Open My Appointments for details.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: _TdUi.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          _TherapistGradientButton(
            label: 'View appointments',
            icon: Icons.arrow_forward_rounded,
            onTap: onOpen,
          ),
        ],
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withValues(alpha: 0.12),
              border: Border.all(color: iconColor.withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(
                  color: iconColor.withValues(alpha: 0.35),
                  blurRadius: 32,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(icon, size: 44, color: iconColor),
          ),
          const SizedBox(height: 22),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _TdUi.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _TdUi.textSecondary,
            ),
          ),
          const SizedBox(height: 22),
          _TherapistGradientButton(
            label: actionLabel,
            onTap: onAction,
          ),
        ],
      ),
    );
  }
}

class _PerformanceOverviewCard extends StatelessWidget {
  const _PerformanceOverviewCard({
    required this.completed,
    required this.reviewCount,
    required this.satisfaction,
  });

  final int completed;
  final int reviewCount;
  final String satisfaction;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _PerfMetricSpec(
        label: 'Completed Appointments',
        value: '$completed',
        icon: Icons.check_circle_outline_rounded,
        accent: _TdUi.green,
      ),
      _PerfMetricSpec(
        label: 'Cancelled Appointments',
        value: '0',
        icon: Icons.cancel_outlined,
        accent: _TdUi.pink,
      ),
      _PerfMetricSpec(
        label: 'New Reviews',
        value: '$reviewCount',
        icon: Icons.rate_review_outlined,
        accent: _TdUi.lavender,
        onTap: (context) =>
            context.read<DesktopNav>().goTo(DesktopRouteKey.therapistReviews),
      ),
      _PerfMetricSpec(
        label: 'Repeat Clients',
        value: '0',
        icon: Icons.people_outline_rounded,
        accent: _TdUi.purple,
      ),
      _PerfMetricSpec(
        label: 'Client Satisfaction',
        value: satisfaction,
        icon: Icons.sentiment_satisfied_alt_rounded,
        accent: _TdUi.gold,
      ),
    ];

    return _TherapistDashGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Performance Overview (This Month)',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _TdUi.textPrimary,
            ),
          ),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, c) {
              if (c.maxWidth < 900) {
                return Column(
                  children: [
                    for (var i = 0; i < metrics.length; i++) ...[
                      _PerfMetricTile(spec: metrics[i]),
                      if (i < metrics.length - 1)
                        Divider(
                          height: 28,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                    ],
                  ],
                );
              }
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < metrics.length; i++) ...[
                      if (i > 0)
                        VerticalDivider(
                          width: 1,
                          thickness: 1,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      Expanded(child: _PerfMetricTile(spec: metrics[i])),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PerfMetricSpec {
  const _PerfMetricSpec({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final void Function(BuildContext context)? onTap;
}

class _PerfMetricTile extends StatelessWidget {
  const _PerfMetricTile({required this.spec});

  final _PerfMetricSpec spec;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: spec.accent.withValues(alpha: 0.14),
              border: Border.all(color: spec.accent.withValues(alpha: 0.32)),
              boxShadow: [
                BoxShadow(
                  color: spec.accent.withValues(alpha: 0.25),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Icon(spec.icon, size: 18, color: spec.accent),
          ),
          const SizedBox(height: 12),
          Text(
            spec.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _TdUi.textSecondary,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            spec.value,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _TdUi.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '0% vs last month',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: _TdUi.textSecondary,
            ),
          ),
        ],
      ),
    );

    if (spec.onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => spec.onTap!(context),
        borderRadius: BorderRadius.circular(12),
        child: content,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.icon,
    required this.iconColor,
  });

  final String title;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 22, color: iconColor),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _TdUi.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _TherapistDashGlass extends StatelessWidget {
  const _TherapistDashGlass({
    required this.child,
    this.padding,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_TdUi.cardRadius),
      child: Container(
        padding: padding ?? const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(_TdUi.cardRadius),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: _TdUi.purple.withValues(alpha: 0.12),
              blurRadius: 48,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class _TherapistGradientButton extends StatefulWidget {
  const _TherapistGradientButton({
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  State<_TherapistGradientButton> createState() =>
      _TherapistGradientButtonState();
}

class _TherapistGradientButtonState extends State<_TherapistGradientButton> {
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
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  _TdUi.purple.withValues(alpha: _hover ? 1 : 0.92),
                  _TdUi.lavender.withValues(alpha: _hover ? 1 : 0.92),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: _TdUi.purple.withValues(alpha: _hover ? 0.55 : 0.35),
                  blurRadius: _hover ? 24 : 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                ],
                Text(
                  widget.label,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
