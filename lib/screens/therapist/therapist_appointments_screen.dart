import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/api/services/api_service.dart';
import '../../core/auth/app_permissions.dart';
import '../../models/rezervacija.dart';
import '../../providers/auth_provider.dart';
import '../../ui/navigation/desktop_nav.dart';
import '../../ui/widgets/luxury/luxury_mini_sparkline.dart';
import 'therapist_portal_scaffold.dart';

abstract final class _ApptUi {
  static const bgTop = Color(0xFF07040F);
  static const bgBottom = Color(0xFF120A24);
  static const textPrimary = Color(0xFFF5F3FA);
  static const textSecondary = Color(0xA6FFFFFF);
  static const purple = Color(0xFF7B4DFF);
  static const lavender = Color(0xFF9D6BFF);
  static const green = Color(0xFF22C55E);
  static const orange = Color(0xFFF97316);
  static const pink = Color(0xFFEC4899);
  static const cardRadius = 24.0;
  static const heroRadius = 30.0;
  static const kpiHeight = 190.0;
  static const gap = 24.0;
  static const sidebarWidth = 340.0;
  static const contentPadding = 32.0;
}

List<double> _sparkFrom(num value, {int points = 7}) {
  final v = value.toDouble();
  if (v <= 0) return List<double>.filled(points, 0);
  return List.generate(points, (i) => v * (0.55 + 0.45 * (i / (points - 1))));
}

class TherapistAppointmentsScreen extends StatefulWidget {
  const TherapistAppointmentsScreen({super.key});

  @override
  State<TherapistAppointmentsScreen> createState() =>
      _TherapistAppointmentsScreenState();
}

class _TherapistAppointmentsScreenState extends State<TherapistAppointmentsScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  Future<List<Rezervacija>>? _future;
  String _tab = 'Upcoming';
  String _statusFilter = 'All Status';
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  static const _tabs = ['Upcoming', 'Today', 'Completed', 'Cancelled'];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic);
    _reload();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = _api.getRezervacije();
    });
  }

  void _selectTab(String tab) {
    if (_tab == tab) return;
    setState(() => _tab = tab);
    _fadeCtrl.forward(from: 0);
  }

  DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _isThisMonth(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month;
  }

  List<Rezervacija> _upcoming(List<Rezervacija> all, DateTime now) => all
      .where((r) => r.datumRezervacije.isAfter(now) && !r.isOtkazana)
      .toList()
    ..sort((a, b) => a.datumRezervacije.compareTo(b.datumRezervacije));

  List<Rezervacija> _today(List<Rezervacija> all, DateTime today) => all
      .where((r) {
        final d = _dayOnly(r.datumRezervacije.toLocal());
        return d == today && !r.isOtkazana;
      })
      .toList()
    ..sort((a, b) => a.datumRezervacije.compareTo(b.datumRezervacije));

  List<Rezervacija> _completed(List<Rezervacija> all, DateTime now) => all
      .where((r) => r.datumRezervacije.isBefore(now) && !r.isOtkazana)
      .toList()
    ..sort((a, b) => b.datumRezervacije.compareTo(a.datumRezervacije));

  List<Rezervacija> _cancelled(List<Rezervacija> all) => all
      .where((r) => r.isOtkazana)
      .toList()
    ..sort((a, b) => b.datumRezervacije.compareTo(a.datumRezervacije));

  List<Rezervacija> _applyTab(List<Rezervacija> all) {
    final now = DateTime.now();
    final today = _dayOnly(now);
    switch (_tab) {
      case 'Today':
        return _today(all, today);
      case 'Completed':
        return _completed(all, now);
      case 'Cancelled':
        return _cancelled(all);
      default:
        return _upcoming(all, now);
    }
  }

  List<Rezervacija> _applyStatus(List<Rezervacija> list) {
    switch (_statusFilter) {
      case 'Confirmed':
        return list.where((r) => r.isPotvrdjena && !r.isOtkazana).toList();
      case 'Pending':
        return list.where((r) => !r.isPotvrdjena && !r.isOtkazana).toList();
      case 'Cancelled':
        return list.where((r) => r.isOtkazana).toList();
      default:
        return list;
    }
  }

  _ApptMetrics _metrics(List<Rezervacija> all) {
    final now = DateTime.now();
    final upcoming = _upcoming(all, now);
    final completed = _completed(all, now);
    final cancelled = _cancelled(all);
    final monthTotal =
        all.where((r) => _isThisMonth(r.datumRezervacije.toLocal())).length;
    final monthCompleted = completed
        .where((r) => _isThisMonth(r.datumRezervacije.toLocal()))
        .length;
    return _ApptMetrics(
      upcoming: upcoming.length,
      completed: completed.length,
      cancelled: cancelled.length,
      monthTotal: monthTotal,
      monthCompleted: monthCompleted,
      upcomingList: upcoming.take(5).toList(),
    );
  }

  String _formatDt(DateTime d) {
    final l = d.toLocal();
    return '${l.day.toString().padLeft(2, '0')}.${l.month.toString().padLeft(2, '0')}.${l.year} '
        '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        width: 420,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!AppPermissions.of(auth).has(AppPermission.manageOwnAppointments)) {
      return const _ApptShell(
        child: TherapistEmptyState(message: 'Therapist login required.'),
      );
    }

    return _ApptShell(
      child: FutureBuilder<List<Rezervacija>>(
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

          final all = snap.data ?? [];
          final metrics = _metrics(all);
          final filtered = _applyStatus(_applyTab(all));

          return FadeTransition(
            opacity: _fadeAnim,
            child: LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 1100;
                final main = _MainColumn(
                  tab: _tab,
                  statusFilter: _statusFilter,
                  metrics: metrics,
                  filtered: filtered,
                  onTab: _selectTab,
                  onStatus: (v) => setState(() => _statusFilter = v),
                  onRefresh: _reload,
                  onNewAppointment: () {
                    _snack(
                      'New bookings are created by your spa admin. Open My Schedule to review your day.',
                    );
                  },
                  formatDt: _formatDt,
                );
                final sidebar = _RightSidebar(
                  upcoming: metrics.upcomingList,
                  onViewCalendar: () =>
                      context.read<DesktopNav>().goTo(DesktopRouteKey.schedule),
                  onNewAppointment: () {
                    _snack(
                      'Contact your spa administrator to book a new appointment.',
                    );
                  },
                  onBlockTime: () {
                    _snack('Use My Schedule to review and manage your day.');
                    context.read<DesktopNav>().goTo(DesktopRouteKey.schedule);
                  },
                  onViewSchedule: () =>
                      context.read<DesktopNav>().goTo(DesktopRouteKey.schedule),
                );

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    _ApptUi.contentPadding,
                    8,
                    _ApptUi.contentPadding,
                    40,
                  ),
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: main),
                            const SizedBox(width: _ApptUi.gap),
                            SizedBox(width: _ApptUi.sidebarWidth, child: sidebar),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            main,
                            const SizedBox(height: _ApptUi.gap),
                            sidebar,
                          ],
                        ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ApptMetrics {
  const _ApptMetrics({
    required this.upcoming,
    required this.completed,
    required this.cancelled,
    required this.monthTotal,
    required this.monthCompleted,
    required this.upcomingList,
  });

  final int upcoming;
  final int completed;
  final int cancelled;
  final int monthTotal;
  final int monthCompleted;
  final List<Rezervacija> upcomingList;
}

class _ApptShell extends StatelessWidget {
  const _ApptShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_ApptUi.bgTop, _ApptUi.bgBottom],
            ),
          ),
        ),
        Positioned(
          top: -80,
          left: -40,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _ApptUi.purple.withValues(alpha: 0.22),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 60,
          right: -60,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _ApptUi.lavender.withValues(alpha: 0.14),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _MainColumn extends StatelessWidget {
  const _MainColumn({
    required this.tab,
    required this.statusFilter,
    required this.metrics,
    required this.filtered,
    required this.onTab,
    required this.onStatus,
    required this.onRefresh,
    required this.onNewAppointment,
    required this.formatDt,
  });

  final String tab;
  final String statusFilter;
  final _ApptMetrics metrics;
  final List<Rezervacija> filtered;
  final ValueChanged<String> onTab;
  final ValueChanged<String> onStatus;
  final VoidCallback onRefresh;
  final VoidCallback onNewAppointment;
  final String Function(DateTime) formatDt;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ToolbarRow(
          tab: tab,
          statusFilter: statusFilter,
          onTab: onTab,
          onStatus: onStatus,
          onRefresh: onRefresh,
          onNewAppointment: onNewAppointment,
        ),
        const SizedBox(height: _ApptUi.gap),
        _KpiRow(metrics: metrics),
        const SizedBox(height: _ApptUi.gap),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          child: filtered.isEmpty
              ? _MainEmptyState(
                  key: ValueKey('empty_$tab'),
                  tab: tab,
                  onViewSchedule: () => context
                      .read<DesktopNav>()
                      .goTo(DesktopRouteKey.schedule),
                )
              : _AppointmentList(
                  key: ValueKey('list_${tab}_$statusFilter'),
                  items: filtered,
                  formatDt: formatDt,
                ),
        ),
      ],
    );
  }
}

class _ToolbarRow extends StatelessWidget {
  const _ToolbarRow({
    required this.tab,
    required this.statusFilter,
    required this.onTab,
    required this.onStatus,
    required this.onRefresh,
    required this.onNewAppointment,
  });

  final String tab;
  final String statusFilter;
  final ValueChanged<String> onTab;
  final ValueChanged<String> onStatus;
  final VoidCallback onRefresh;
  final VoidCallback onNewAppointment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final stack = c.maxWidth < 900;
        final tabs = _ApptTabsRow(active: tab, onTab: onTab);
        final actions = _ToolbarActions(
          statusFilter: statusFilter,
          onStatus: onStatus,
          onRefresh: onRefresh,
          onNewAppointment: onNewAppointment,
        );
        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              tabs,
              const SizedBox(height: 14),
              actions,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: tabs),
            const SizedBox(width: 16),
            actions,
          ],
        );
      },
    );
  }
}

class _ApptTabsRow extends StatelessWidget {
  const _ApptTabsRow({required this.active, required this.onTab});

  final String active;
  final ValueChanged<String> onTab;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final t in _TherapistAppointmentsScreenState._tabs)
            _ApptTab(
              label: t,
              selected: active == t,
              onTap: () => onTab(t),
            ),
        ],
      ),
    );
  }
}

class _ApptTab extends StatefulWidget {
  const _ApptTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_ApptTab> createState() => _ApptTabState();
}

class _ApptTabState extends State<_ApptTab> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(right: 28),
          padding: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected
                    ? _ApptUi.purple
                    : (_hover
                        ? _ApptUi.lavender.withValues(alpha: 0.35)
                        : Colors.transparent),
                width: selected ? 2.5 : 1,
              ),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: _ApptUi.purple.withValues(alpha: 0.45),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Text(
            widget.label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected
                  ? _ApptUi.textPrimary
                  : _ApptUi.lavender.withValues(alpha: _hover ? 0.9 : 0.55),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolbarActions extends StatelessWidget {
  const _ToolbarActions({
    required this.statusFilter,
    required this.onStatus,
    required this.onRefresh,
    required this.onNewAppointment,
  });

  final String statusFilter;
  final ValueChanged<String> onStatus;
  final VoidCallback onRefresh;
  final VoidCallback onNewAppointment;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _ApptGlass(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          radius: 14,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: statusFilter,
              dropdownColor: _ApptUi.bgBottom,
              style: GoogleFonts.inter(
                color: _ApptUi.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              items: const [
                DropdownMenuItem(
                  value: 'All Status',
                  child: Text('All Status'),
                ),
                DropdownMenuItem(
                  value: 'Confirmed',
                  child: Text('Confirmed'),
                ),
                DropdownMenuItem(
                  value: 'Pending',
                  child: Text('Pending'),
                ),
                DropdownMenuItem(
                  value: 'Cancelled',
                  child: Text('Cancelled'),
                ),
              ],
              onChanged: (v) {
                if (v != null) onStatus(v);
              },
            ),
          ),
        ),
        _IconGlassButton(
          icon: Icons.refresh_rounded,
          tooltip: 'Refresh',
          onTap: onRefresh,
        ),
        _PrimaryGradientButton(
          label: '+ New Appointment',
          icon: Icons.add_rounded,
          onTap: onNewAppointment,
        ),
      ],
    );
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.metrics});

  final _ApptMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _KpiSpec(
        label: 'Upcoming',
        value: '${metrics.upcoming}',
        suffix: ' appointments',
        trend: '0% vs yesterday',
        icon: Icons.upcoming_rounded,
        accent: _ApptUi.purple,
        sparkline: _sparkFrom(metrics.upcoming),
      ),
      _KpiSpec(
        label: 'Completed',
        value: '${metrics.completed}',
        suffix: '',
        trend: '0% vs last month',
        icon: Icons.check_circle_rounded,
        accent: _ApptUi.green,
        sparkline: _sparkFrom(metrics.completed),
      ),
      _KpiSpec(
        label: 'Cancelled',
        value: '${metrics.cancelled}',
        suffix: '',
        trend: '0% vs last month',
        icon: Icons.cancel_rounded,
        accent: _ApptUi.orange,
        sparkline: _sparkFrom(metrics.cancelled),
      ),
      _KpiSpec(
        label: 'Total This Month',
        value: '${metrics.monthTotal}',
        suffix: ' appointments',
        trend: '0% vs last month',
        icon: Icons.calendar_month_rounded,
        accent: _ApptUi.pink,
        sparkline: _sparkFrom(metrics.monthTotal),
      ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 1200
            ? 4
            : c.maxWidth >= 600
            ? 2
            : 1;
        final w = (c.maxWidth - 18 * (cols - 1)) / cols;
        return Wrap(
          spacing: 18,
          runSpacing: 18,
          children: [
            for (final card in cards)
              SizedBox(
                width: w.clamp(200, c.maxWidth),
                height: _ApptUi.kpiHeight,
                child: _KpiCard(spec: card),
              ),
          ],
        );
      },
    );
  }
}

class _KpiSpec {
  const _KpiSpec({
    required this.label,
    required this.value,
    required this.suffix,
    required this.trend,
    required this.icon,
    required this.accent,
    required this.sparkline,
  });

  final String label;
  final String value;
  final String suffix;
  final String trend;
  final IconData icon;
  final Color accent;
  final List<double> sparkline;
}

class _KpiCard extends StatefulWidget {
  const _KpiCard({required this.spec});

  final _KpiSpec spec;

  @override
  State<_KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<_KpiCard> {
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
        transform: Matrix4.translationValues(0, _hover ? -4 : 0, 0),
        child: _ApptGlass(
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
                  border: Border.all(color: s.accent.withValues(alpha: 0.38)),
                  boxShadow: [
                    BoxShadow(
                      color: s.accent.withValues(alpha: _hover ? 0.5 : 0.28),
                      blurRadius: 18,
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
                  color: _ApptUi.textSecondary,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              RichText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: _ApptUi.textPrimary,
                    height: 1.0,
                  ),
                  children: [
                    TextSpan(text: s.value),
                    if (s.suffix.isNotEmpty)
                      TextSpan(
                        text: s.suffix,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _ApptUi.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                s.trend,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _ApptUi.textSecondary,
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

class _MainEmptyState extends StatelessWidget {
  const _MainEmptyState({
    super.key,
    required this.tab,
    required this.onViewSchedule,
  });

  final String tab;
  final VoidCallback onViewSchedule;

  @override
  Widget build(BuildContext context) {
    return _ApptGlass(
      radius: _ApptUi.heroRadius,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 420),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ...List.generate(6, (i) {
              final angle = i * math.pi / 3;
              return Positioned(
                left: 120 + 140 * math.cos(angle),
                top: 80 + 90 * math.sin(angle),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _ApptUi.lavender.withValues(alpha: 0.35),
                    boxShadow: [
                      BoxShadow(
                        color: _ApptUi.purple.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              );
            }),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _ApptUi.purple.withValues(alpha: 0.35),
                        _ApptUi.lavender.withValues(alpha: 0.15),
                      ],
                    ),
                    border: Border.all(
                      color: _ApptUi.purple.withValues(alpha: 0.45),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _ApptUi.purple.withValues(alpha: 0.4),
                        blurRadius: 40,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    size: 56,
                    color: _ApptUi.lavender,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  tab == 'Cancelled'
                      ? 'No cancelled appointments'
                      : 'No appointments yet',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _ApptUi.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  tab == 'Cancelled'
                      ? 'Cancelled bookings assigned to you will appear here.'
                      : 'You have no upcoming appointments.\n'
                          'Appointments assigned to you will appear here.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.5,
                    color: _ApptUi.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 28),
                _OutlinedGlowButton(
                  label: 'View Full Schedule',
                  icon: Icons.calendar_month_outlined,
                  onTap: onViewSchedule,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AppointmentList extends StatelessWidget {
  const _AppointmentList({
    super.key,
    required this.items,
    required this.formatDt,
  });

  final List<Rezervacija> items;
  final String Function(DateTime) formatDt;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _AppointmentCard(r: items[i], formatDt: formatDt),
        ],
      ],
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({required this.r, required this.formatDt});

  final Rezervacija r;
  final String Function(DateTime) formatDt;

  @override
  Widget build(BuildContext context) {
    final status = r.isOtkazana
        ? ('Cancelled', _ApptUi.orange)
        : r.isPotvrdjena
        ? ('Confirmed', _ApptUi.green)
        : ('Pending', _ApptUi.lavender);

    return _ApptGlass(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: _ApptUi.purple.withValues(alpha: 0.14),
              border: Border.all(color: _ApptUi.purple.withValues(alpha: 0.3)),
            ),
            child: const Icon(
              Icons.spa_outlined,
              color: _ApptUi.lavender,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.uslugaNaziv ?? 'Service',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: _ApptUi.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  r.korisnikIme ?? 'Client',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: _ApptUi.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatDt(r.datumRezervacije),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _ApptUi.lavender.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          _StatusChip(label: status.$1, color: status.$2),
        ],
      ),
    );
  }
}

class _RightSidebar extends StatelessWidget {
  const _RightSidebar({
    required this.upcoming,
    required this.onViewCalendar,
    required this.onNewAppointment,
    required this.onBlockTime,
    required this.onViewSchedule,
  });

  final List<Rezervacija> upcoming;
  final VoidCallback onViewCalendar;
  final VoidCallback onNewAppointment;
  final VoidCallback onBlockTime;
  final VoidCallback onViewSchedule;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _UpcomingOverviewCard(
          upcoming: upcoming,
          onViewCalendar: onViewCalendar,
        ),
        const SizedBox(height: 18),
        _QuickActionsCard(
          onNewAppointment: onNewAppointment,
          onBlockTime: onBlockTime,
          onViewSchedule: onViewSchedule,
        ),
      ],
    );
  }
}

class _UpcomingOverviewCard extends StatelessWidget {
  const _UpcomingOverviewCard({
    required this.upcoming,
    required this.onViewCalendar,
  });

  final List<Rezervacija> upcoming;
  final VoidCallback onViewCalendar;

  @override
  Widget build(BuildContext context) {
    return _ApptGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Upcoming Overview',
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _ApptUi.textPrimary,
            ),
          ),
          const SizedBox(height: 18),
          if (upcoming.isEmpty)
            _SidebarEmpty(
              icon: Icons.event_available_rounded,
              title: 'No upcoming appointments',
              subtitle: 'You\'re all clear!',
              buttonLabel: 'View Calendar',
              onTap: onViewCalendar,
            )
          else
            Column(
              children: [
                for (var i = 0; i < upcoming.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _MiniBookingTile(r: upcoming[i]),
                ],
                const SizedBox(height: 14),
                _OutlinedGlowButton(
                  label: 'View Calendar',
                  icon: Icons.calendar_month_outlined,
                  onTap: onViewCalendar,
                  compact: true,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _MiniBookingTile extends StatelessWidget {
  const _MiniBookingTile({required this.r});

  final Rezervacija r;

  @override
  Widget build(BuildContext context) {
    final l = r.datumRezervacije.toLocal();
    final time =
        '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Text(
            time,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: _ApptUi.lavender,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.uslugaNaziv ?? 'Service',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: _ApptUi.textPrimary,
                  ),
                ),
                Text(
                  r.korisnikIme ?? 'Client',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: _ApptUi.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard({
    required this.onNewAppointment,
    required this.onBlockTime,
    required this.onViewSchedule,
  });

  final VoidCallback onNewAppointment;
  final VoidCallback onBlockTime;
  final VoidCallback onViewSchedule;

  @override
  Widget build(BuildContext context) {
    return _ApptGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Quick Actions',
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _ApptUi.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          _QuickActionTile(
            icon: Icons.add_circle_outline_rounded,
            label: 'New Appointment',
            onTap: onNewAppointment,
          ),
          const SizedBox(height: 10),
          _QuickActionTile(
            icon: Icons.block_rounded,
            label: 'Block Time',
            onTap: onBlockTime,
          ),
          const SizedBox(height: 10),
          _QuickActionTile(
            icon: Icons.calendar_month_outlined,
            label: 'View My Schedule',
            onTap: onViewSchedule,
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatefulWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<_QuickActionTile> {
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
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Colors.white.withValues(alpha: _hover ? 0.08 : 0.04),
              border: Border.all(
                color: _ApptUi.purple.withValues(alpha: _hover ? 0.45 : 0.2),
              ),
              boxShadow: _hover
                  ? [
                      BoxShadow(
                        color: _ApptUi.purple.withValues(alpha: 0.25),
                        blurRadius: 16,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Icon(widget.icon, color: _ApptUi.lavender, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.label,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: _ApptUi.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Colors.white.withValues(alpha: _hover ? 0.7 : 0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarEmpty extends StatelessWidget {
  const _SidebarEmpty({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _ApptUi.purple.withValues(alpha: 0.12),
              border: Border.all(color: _ApptUi.purple.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: _ApptUi.lavender, size: 32),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: _ApptUi.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: _ApptUi.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          _OutlinedGlowButton(
            label: buttonLabel,
            icon: Icons.calendar_month_outlined,
            onTap: onTap,
            compact: true,
          ),
        ],
      ),
    );
  }
}

class _PrimaryGradientButton extends StatefulWidget {
  const _PrimaryGradientButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_PrimaryGradientButton> createState() => _PrimaryGradientButtonState();
}

class _PrimaryGradientButtonState extends State<_PrimaryGradientButton> {
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
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  _ApptUi.purple.withValues(alpha: _hover ? 1 : 0.92),
                  _ApptUi.lavender.withValues(alpha: _hover ? 1 : 0.92),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: _ApptUi.purple.withValues(alpha: _hover ? 0.55 : 0.38),
                  blurRadius: _hover ? 22 : 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
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

class _OutlinedGlowButton extends StatefulWidget {
  const _OutlinedGlowButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool compact;

  @override
  State<_OutlinedGlowButton> createState() => _OutlinedGlowButtonState();
}

class _OutlinedGlowButtonState extends State<_OutlinedGlowButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final h = widget.compact ? 48.0 : 58.0;
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
            height: h,
            padding: EdgeInsets.symmetric(horizontal: widget.compact ? 18 : 28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _ApptUi.purple.withValues(alpha: _hover ? 0.75 : 0.45),
                width: 1.5,
              ),
              color: _ApptUi.purple.withValues(alpha: _hover ? 0.12 : 0.06),
              boxShadow: _hover
                  ? [
                      BoxShadow(
                        color: _ApptUi.purple.withValues(alpha: 0.35),
                        blurRadius: 20,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, color: _ApptUi.lavender, size: 20),
                const SizedBox(width: 10),
                Text(
                  widget.label,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: widget.compact ? 13 : 15,
                    color: _ApptUi.textPrimary,
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

class _IconGlassButton extends StatefulWidget {
  const _IconGlassButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  State<_IconGlassButton> createState() => _IconGlassButtonState();
}

class _IconGlassButtonState extends State<_IconGlassButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.white.withValues(alpha: _hover ? 0.08 : 0.04),
                border: Border.all(
                  color: Colors.white.withValues(alpha: _hover ? 0.18 : 0.1),
                ),
              ),
              child: Icon(
                widget.icon,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ApptGlass extends StatelessWidget {
  const _ApptGlass({
    required this.child,
    this.padding,
    this.radius = _ApptUi.cardRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        padding: padding ?? const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: _ApptUi.purple.withValues(alpha: 0.1),
              blurRadius: 40,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
