import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/api/services/api_service.dart';
import '../../core/auth/app_permissions.dart';
import '../../core/therapist/therapist_appointment_utils.dart';
import '../../models/admin/therapist_admin_profile.dart';
import '../../models/therapist/therapist_dashboard.dart';
import '../../providers/auth_provider.dart';
import '../../ui/navigation/desktop_nav.dart';
import 'therapist_appointment_detail_dialog.dart';
import 'therapist_portal_scaffold.dart';

abstract final class _TdUi {
  static const bgTop = Color(0xFF07040F);
  static const bgBottom = Color(0xFF120A24);
  static const textPrimary = Color(0xFFF5F3FA);
  static const textSecondary = Color(0xA6FFFFFF);
  static const purple = Color(0xFF7B4DFF);
  static const lavender = Color(0xFF9D6BFF);
  static const teal = Color(0xFF2DD4BF);
  static const gold = Color(0xFFF5B942);
  static const cardRadius = 18.0;
  static const kpiHeight = 112.0;
  static const gap = 20.0;
  static const contentPadding = 32.0;
  static const sidebarWidth = 300.0;
}

String _greetingFor(String name) {
  final hour = DateTime.now().hour;
  final salutation = hour < 12
      ? 'Good morning'
      : hour < 18
      ? 'Good afternoon'
      : 'Good evening';
  return '$salutation, $name';
}

String _subtitleFor(int todayCount) {
  if (todayCount == 0) {
    return 'No appointments scheduled today.';
  }
  if (todayCount == 1) {
    return 'You have 1 appointment scheduled today.';
  }
  return 'You have $todayCount appointments scheduled today.';
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
  int _lastRefreshToken = -1;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final token = context.read<DesktopNav>().therapistDashboardRefresh;
    if (token != _lastRefreshToken) {
      _lastRefreshToken = token;
      if (token > 0) _reload();
    }
  }

  void _reload() {
    final auth = context.read<AuthProvider>();
    if (!AppPermissions.of(auth).has(AppPermission.viewOwnTherapistData)) {
      setState(() {
        _loadError = 'You do not have permission to view this dashboard.';
        _future = Future.value(null);
      });
      return;
    }
    setState(() {
      _loadError = null;
      _future = _loadDashboard();
    });
  }

  Future<TherapistDashboard?> _loadDashboard() async {
    final data = await _api.getTherapistDashboard(day: DateTime.now());
    if (!mounted || data == null) return data;

    context.read<DesktopNav>().setTherapistDashboardHeader(
      title: _greetingFor(data.therapistIme),
      subtitle: _subtitleFor(data.todayAppointments),
    );
    return data;
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
                  Text(
                    _loadError ?? 'Could not load dashboard.',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _TdUi.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _CompactActionButton(
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
    final revenueLabel = '${data.revenueThisMonth.toStringAsFixed(0)} KM';

    return LayoutBuilder(
      builder: (context, c) {
        final stack = c.maxWidth < 1024;

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
                    title: 'Today',
                    value: '${data.todayAppointments}',
                    helper: 'Appointments today',
                    icon: Icons.calendar_today_rounded,
                    accent: _TdUi.purple,
                  ),
                  _TherapistKpiSpec(
                    title: 'Upcoming',
                    value: '${data.upcomingAppointments}',
                    helper: 'Next 7 days',
                    icon: Icons.upcoming_rounded,
                    accent: _TdUi.teal,
                  ),
                  _TherapistKpiSpec(
                    title: 'Rating',
                    value: ratingLabel,
                    helper: 'All-time average',
                    icon: Icons.star_rounded,
                    accent: _TdUi.gold,
                  ),
                  _TherapistKpiSpec(
                    title: 'Revenue',
                    value: revenueLabel,
                    helper: 'Collected this month',
                    icon: Icons.account_balance_wallet_rounded,
                    accent: _TdUi.lavender,
                  ),
                ],
              ),
              const SizedBox(height: _TdUi.gap),
              if (stack)
                Column(
                  children: [
                    _TodayScheduleCard(appointments: data.todaySchedule),
                    const SizedBox(height: _TdUi.gap),
                    _DashboardSidebar(upcoming: data.upcomingSchedule),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _TodayScheduleCard(appointments: data.todaySchedule),
                    ),
                    const SizedBox(width: _TdUi.gap),
                    SizedBox(
                      width: _TdUi.sidebarWidth,
                      child: _DashboardSidebar(upcoming: data.upcomingSchedule),
                    ),
                  ],
                ),
              const SizedBox(height: _TdUi.gap),
              _MyReviewsCard(
                latestReview: data.latestReview,
                averageRating: rating,
                reviewCount: data.reviewCount,
                completedThisMonth: data.completedThisMonth,
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
    required this.title,
    required this.value,
    required this.helper,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String value;
  final String helper;
  final IconData icon;
  final Color accent;
}

class _TherapistKpiRow extends StatelessWidget {
  const _TherapistKpiRow({required this.cards});

  final List<_TherapistKpiSpec> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 1100
            ? 4
            : c.maxWidth >= 560
            ? 2
            : 1;
        final w = (c.maxWidth - 14 * (cols - 1)) / cols;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final card in cards)
              SizedBox(
                width: w.clamp(150, c.maxWidth),
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
        duration: const Duration(milliseconds: 180),
        transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
        child: _TherapistDashGlass(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: s.accent.withValues(alpha: 0.14),
                      border: Border.all(
                        color: s.accent.withValues(alpha: 0.32),
                      ),
                    ),
                    child: Icon(s.icon, color: s.accent, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    s.title,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _TdUi.textSecondary,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                s.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _TdUi.textPrimary,
                  letterSpacing: -0.5,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                s.helper,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: _TdUi.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardSidebar extends StatelessWidget {
  const _DashboardSidebar({required this.upcoming});

  final List<TherapistDashboardAppointmentRow> upcoming;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _QuickActionsCard(),
        const SizedBox(height: _TdUi.gap),
        _UpcomingAppointmentsCard(upcoming: upcoming),
      ],
    );
  }
}

class _TodayScheduleCard extends StatelessWidget {
  const _TodayScheduleCard({required this.appointments});

  final List<TherapistDashboardAppointmentRow> appointments;

  @override
  Widget build(BuildContext context) {
    final nav = context.read<DesktopNav>();
    return _TherapistDashGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionTitle(
            title: "Today's Schedule",
            icon: Icons.calendar_month_rounded,
            iconColor: _TdUi.purple,
          ),
          const SizedBox(height: 16),
          if (appointments.isEmpty)
            _CompactEmptyState(
              title: 'No appointments scheduled today.',
              subtitle:
                  'Enjoy your free day or update your availability.',
              actionLabel: 'Manage Schedule',
              onAction: () => nav.goTo(DesktopRouteKey.schedule),
            )
          else
            Builder(
              builder: (context) {
                final now = DateTime.now();
                var nextIndex = -1;
                for (var i = 0; i < appointments.length; i++) {
                  final row = appointments[i];
                  final end = row.datumRezervacije.add(
                    Duration(minutes: row.uslugaTrajanjeMinuta),
                  );
                  if (end.isAfter(now)) {
                    nextIndex = i;
                    break;
                  }
                }
                return Column(
                  children: [
                    for (var i = 0; i < appointments.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      _ScheduleAppointmentRow(
                        row: appointments[i],
                        highlightNext: i == nextIndex,
                      ),
                    ],
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ScheduleAppointmentRow extends StatelessWidget {
  const _ScheduleAppointmentRow({
    required this.row,
    this.highlightNext = false,
  });

  final TherapistDashboardAppointmentRow row;
  final bool highlightNext;

  @override
  Widget build(BuildContext context) {
    final status = TherapistAppointmentUtils.statusOfDashboardRow(row);
    final notes = row.napomenaZaTerapeuta?.trim();
    final hasNotes = notes != null && notes.isNotEmpty;
    final room = row.prostorijaNaziv?.trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => showTherapistAppointmentDetailDialog(context, row),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: highlightNext
                ? _TdUi.purple.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.04),
            border: Border.all(
              color: highlightNext
                  ? _TdUi.purple.withValues(alpha: 0.28)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 108,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (highlightNext)
                      Text(
                        'Next',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _TdUi.lavender,
                          letterSpacing: 0.4,
                        ),
                      ),
                    Text(
                      TherapistAppointmentUtils.formatTimeRange(
                        start: row.datumRezervacije,
                        durationMinutes: row.uslugaTrajanjeMinuta,
                      ),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _TdUi.lavender,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.korisnikIme ?? 'Client',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _TdUi.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${row.uslugaNaziv ?? 'Service'} · ${row.uslugaTrajanjeMinuta} min',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: _TdUi.textSecondary,
                            ),
                          ),
                        ),
                        if (hasNotes) ...[
                          const SizedBox(width: 6),
                          Tooltip(
                            message: notes,
                            child: Icon(
                              Icons.sticky_note_2_outlined,
                              size: 14,
                              color: _TdUi.gold.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (room != null && room.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        room,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: _TdUi.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _StatusBadge(label: status.label, color: status.color),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpcomingAppointmentsCard extends StatelessWidget {
  const _UpcomingAppointmentsCard({required this.upcoming});

  final List<TherapistDashboardAppointmentRow> upcoming;

  @override
  Widget build(BuildContext context) {
    final nav = context.read<DesktopNav>();

    return _TherapistDashGlass(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: _SectionTitle(
                  title: 'Upcoming Appointments',
                  icon: Icons.upcoming_rounded,
                  iconColor: _TdUi.teal,
                  compact: true,
                ),
              ),
              TextButton(
                onPressed: () =>
                    nav.goTo(DesktopRouteKey.therapistAppointments),
                style: TextButton.styleFrom(
                  foregroundColor: _TdUi.lavender,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'View all',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (upcoming.isEmpty)
            Text(
              'No upcoming appointments.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: _TdUi.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            )
          else
            Column(
              children: [
                for (var i = 0; i < upcoming.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _UpcomingRow(row: upcoming[i]),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({required this.row});

  final TherapistDashboardAppointmentRow row;

  @override
  Widget build(BuildContext context) {
    final status = TherapistAppointmentUtils.statusOfDashboardRow(row);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => showTherapistAppointmentDetailDialog(context, row),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white.withValues(alpha: 0.03),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      TherapistAppointmentUtils.formatUpcomingDateTime(
                        row.datumRezervacije,
                      ),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _TdUi.lavender,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      row.korisnikIme ?? 'Client',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _TdUi.textPrimary,
                      ),
                    ),
                    Text(
                      row.uslugaNaziv ?? 'Service',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: _TdUi.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(
                label: status.label,
                color: status.color,
                compact: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final nav = context.read<DesktopNav>();
    return _TherapistDashGlass(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Quick Actions',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _TdUi.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _QuickActionButton(
            icon: Icons.view_timeline_rounded,
            label: 'View Schedule',
            onTap: () => nav.goTo(DesktopRouteKey.schedule),
          ),
          const SizedBox(height: 8),
          _QuickActionButton(
            icon: Icons.event_available_outlined,
            label: 'Manage Availability',
            onTap: () => nav.goTo(DesktopRouteKey.schedule),
          ),
          const SizedBox(height: 8),
          _QuickActionButton(
            icon: Icons.spa_outlined,
            label: 'My Services',
            onTap: () => nav.goTo(DesktopRouteKey.therapistServices),
          ),
          const SizedBox(height: 8),
          _QuickActionButton(
            icon: Icons.reviews_outlined,
            label: 'My Reviews',
            onTap: () => nav.goTo(DesktopRouteKey.therapistReviews),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatefulWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<_QuickActionButton> {
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
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white.withValues(alpha: _hover ? 0.07 : 0.035),
              border: Border.all(
                color: _TdUi.purple.withValues(alpha: _hover ? 0.35 : 0.18),
              ),
            ),
            child: Row(
              children: [
                Icon(widget.icon, size: 16, color: _TdUi.lavender),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.label,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _TdUi.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: Colors.white.withValues(alpha: _hover ? 0.6 : 0.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MyReviewsCard extends StatelessWidget {
  const _MyReviewsCard({
    required this.latestReview,
    required this.averageRating,
    required this.reviewCount,
    required this.completedThisMonth,
  });

  final TherapistReviewRow? latestReview;
  final double averageRating;
  final int reviewCount;
  final int completedThisMonth;

  @override
  Widget build(BuildContext context) {
    final nav = context.read<DesktopNav>();
    final hasReviews = reviewCount > 0 && latestReview != null;
    final ratingLabel =
        averageRating > 0 ? averageRating.toStringAsFixed(1) : '—';

    return _TherapistDashGlass(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: _SectionTitle(
                  title: 'My Reviews',
                  icon: Icons.star_outline_rounded,
                  iconColor: _TdUi.gold,
                  compact: true,
                ),
              ),
              if (hasReviews)
                TextButton(
                  onPressed: () =>
                      nav.goTo(DesktopRouteKey.therapistReviews),
                  style: TextButton.styleFrom(
                    foregroundColor: _TdUi.lavender,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'View all',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (!hasReviews)
            Text(
              'No reviews yet.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: _TdUi.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: _TdUi.gold.withValues(alpha: 0.1),
                    border: Border.all(
                      color: _TdUi.gold.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        ratingLabel,
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: _TdUi.gold,
                        ),
                      ),
                      Text(
                        'Average',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _TdUi.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Latest review',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _TdUi.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        latestReview!.komentar.trim().isNotEmpty
                            ? latestReview!.komentar.trim()
                            : 'No comment provided.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: _TdUi.textPrimary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${latestReview!.korisnikIme} · ${latestReview!.uslugaNaziv}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: _TdUi.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          Text(
            '$completedThisMonth completed appointments this month',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _TdUi.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactEmptyState extends StatelessWidget {
  const _CompactEmptyState({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 200),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withValues(alpha: 0.03),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _TdUi.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: _TdUi.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            _CompactActionButton(
              label: actionLabel,
              onTap: onAction,
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactActionButton extends StatefulWidget {
  const _CompactActionButton({
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  State<_CompactActionButton> createState() => _CompactActionButtonState();
}

class _CompactActionButtonState extends State<_CompactActionButton> {
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
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [
                  _TdUi.purple.withValues(alpha: _hover ? 1 : 0.9),
                  _TdUi.lavender.withValues(alpha: _hover ? 1 : 0.9),
                ],
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                ],
                Text(
                  widget.label,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
    this.compact = false,
  });

  final String label;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.icon,
    required this.iconColor,
    this.compact = false,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: compact ? 18 : 20, color: iconColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: compact ? 15 : 17,
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
        padding: padding ?? const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(_TdUi.cardRadius),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: _TdUi.purple.withValues(alpha: 0.1),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}
