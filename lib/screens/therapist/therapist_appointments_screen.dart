import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/api/services/api_service.dart';
import '../../core/auth/app_permissions.dart';
import '../../core/therapist/therapist_appointment_utils.dart';
import '../../models/rezervacija.dart';
import '../../providers/auth_provider.dart';
import '../../ui/navigation/desktop_nav.dart';
import 'therapist_appointment_detail_dialog.dart';
import 'therapist_portal_scaffold.dart';

abstract final class _ApptUi {
  static const bgTop = Color(0xFF07040F);
  static const bgBottom = Color(0xFF120A24);
  static const textPrimary = Color(0xFFF5F3FA);
  static const textSecondary = Color(0xA6FFFFFF);
  static const purple = Color(0xFF7B4DFF);
  static const lavender = Color(0xFF9D6BFF);
  static const teal = Color(0xFF2DD4BF);
  static const green = Color(0xFF22C55E);
  static const red = Color(0xFFEF4444);
  static const cardRadius = 18.0;
  static const gap = 16.0;
  static const contentPadding = 32.0;
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
      duration: const Duration(milliseconds: 280),
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

  DateTime _dayOnly(DateTime d) => TherapistAppointmentUtils.dayOnly(d);

  List<Rezervacija> _upcoming(List<Rezervacija> all, DateTime now) => all
      .where((r) => r.datumRezervacije.isAfter(now) && !r.isOtkazana)
      .toList()
    ..sort((a, b) => a.datumRezervacije.compareTo(b.datumRezervacije));

  List<Rezervacija> _today(List<Rezervacija> all, DateTime today) =>
      TherapistAppointmentUtils.todayAppointments(all, reference: today);

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
    final today = _dayOnly(now);
    final upcoming = _upcoming(all, now);
    return _ApptMetrics(
      upcoming: upcoming.length,
      today: _today(all, today).length,
      completed: _completed(all, now).length,
      cancelled: _cancelled(all).length,
      nextAppointment: upcoming.isEmpty ? null : upcoming.first,
      tabCounts: {
        'Upcoming': upcoming.length,
        'Today': _today(all, today).length,
        'Completed': _completed(all, now).length,
        'Cancelled': _cancelled(all).length,
      },
    );
  }

  String _formatCardDate(DateTime d) {
    final l = d.toLocal();
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
    final time = TherapistAppointmentUtils.formatTime(l);
    return '${months[l.month - 1]} ${l.day}, ${l.year} · $time';
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
          final nav = context.read<DesktopNav>();

          return FadeTransition(
            opacity: _fadeAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                _ApptUi.contentPadding,
                8,
                _ApptUi.contentPadding,
                40,
              ),
              child: LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth >= 1024;
                  final listPane = _AppointmentListPane(
                    filtered: filtered,
                    formatCardDate: _formatCardDate,
                  );
                  final sidebar = _AppointmentsSidebar(
                    next: metrics.nextAppointment,
                    onOpenDetails: (r) =>
                        showTherapistRezervacijaDetailDialog(context, r),
                    onViewSchedule: () =>
                        nav.goTo(DesktopRouteKey.schedule),
                    onManageAvailability: () =>
                        nav.goTo(DesktopRouteKey.schedule),
                    onMyReviews: () =>
                        nav.goTo(DesktopRouteKey.therapistReviews),
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ApptTabsRow(
                        active: _tab,
                        counts: metrics.tabCounts,
                        onTab: _selectTab,
                      ),
                      const SizedBox(height: 12),
                      _FilterToolbar(
                        statusFilter: _statusFilter,
                        onStatus: (v) => setState(() => _statusFilter = v),
                        onRefresh: _reload,
                      ),
                      const SizedBox(height: 12),
                      _SummaryStrip(metrics: metrics),
                      const SizedBox(height: _ApptUi.gap),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 7, child: listPane),
                            const SizedBox(width: _ApptUi.gap),
                            Expanded(flex: 3, child: sidebar),
                          ],
                        )
                      else ...[
                        listPane,
                        const SizedBox(height: _ApptUi.gap),
                        sidebar,
                      ],
                    ],
                  );
                },
              ),
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
    required this.today,
    required this.completed,
    required this.cancelled,
    required this.tabCounts,
    this.nextAppointment,
  });

  final int upcoming;
  final int today;
  final int completed;
  final int cancelled;
  final Rezervacija? nextAppointment;
  final Map<String, int> tabCounts;
}

class _ApptShell extends StatelessWidget {
  const _ApptShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_ApptUi.bgTop, _ApptUi.bgBottom],
        ),
      ),
      child: child,
    );
  }
}

class _ApptTabsRow extends StatelessWidget {
  const _ApptTabsRow({
    required this.active,
    required this.counts,
    required this.onTab,
  });

  final String active;
  final Map<String, int> counts;
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
              count: counts[t] ?? 0,
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
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
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
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(right: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected
                ? _ApptUi.purple.withValues(alpha: 0.18)
                : (_hover
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.transparent),
            border: Border.all(
              color: selected
                  ? _ApptUi.purple.withValues(alpha: 0.45)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Text(
            '${widget.label} (${widget.count})',
            style: GoogleFonts.inter(
              fontSize: 13,
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

class _FilterToolbar extends StatelessWidget {
  const _FilterToolbar({
    required this.statusFilter,
    required this.onStatus,
    required this.onRefresh,
  });

  final String statusFilter;
  final ValueChanged<String> onStatus;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ApptGlass(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          radius: 12,
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
                DropdownMenuItem(value: 'All Status', child: Text('All Status')),
                DropdownMenuItem(value: 'Confirmed', child: Text('Confirmed')),
                DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                DropdownMenuItem(value: 'Cancelled', child: Text('Cancelled')),
              ],
              onChanged: (v) {
                if (v != null) onStatus(v);
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        _IconGlassButton(
          icon: Icons.refresh_rounded,
          tooltip: 'Refresh',
          onTap: onRefresh,
        ),
      ],
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.metrics});

  final _ApptMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        color: Colors.white.withValues(alpha: 0.035),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _SummaryItem(
              label: 'Upcoming',
              value: metrics.upcoming,
              color: _ApptUi.lavender,
            ),
            _SummaryDot(),
            _SummaryItem(
              label: 'Today',
              value: metrics.today,
              color: _ApptUi.teal,
            ),
            _SummaryDot(),
            _SummaryItem(
              label: 'Completed',
              value: metrics.completed,
              color: _ApptUi.green,
            ),
            _SummaryDot(),
            _SummaryItem(
              label: 'Cancelled',
              value: metrics.cancelled,
              color: _ApptUi.red,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text(
        '•',
        style: GoogleFonts.inter(
          color: Colors.white.withValues(alpha: 0.25),
          fontSize: 14,
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
        children: [
          TextSpan(
            text: '$label: ',
            style: TextStyle(color: color),
          ),
          TextSpan(
            text: '$value',
            style: const TextStyle(color: _ApptUi.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _AppointmentListPane extends StatelessWidget {
  const _AppointmentListPane({
    required this.filtered,
    required this.formatCardDate,
  });

  final List<Rezervacija> filtered;
  final String Function(DateTime) formatCardDate;

  @override
  Widget build(BuildContext context) {
    if (filtered.isEmpty) {
      return const _CompactListEmpty();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < filtered.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _AppointmentCard(
            r: filtered[i],
            formatCardDate: formatCardDate,
          ),
        ],
      ],
    );
  }
}

class _CompactListEmpty extends StatelessWidget {
  const _CompactListEmpty();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_ApptUi.cardRadius),
        color: Colors.white.withValues(alpha: 0.03),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'No appointments in this view.',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _ApptUi.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try another filter or date.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: _ApptUi.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.r,
    required this.formatCardDate,
  });

  final Rezervacija r;
  final String Function(DateTime) formatCardDate;

  @override
  Widget build(BuildContext context) {
    final status = TherapistAppointmentUtils.statusOfRezervacija(r);
    final hasNotes =
        r.napomenaZaTerapeuta != null && r.napomenaZaTerapeuta!.trim().isNotEmpty;

    return _ApptGlass(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.korisnikIme ?? 'Client',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: _ApptUi.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${r.uslugaNaziv ?? 'Service'} · ${r.uslugaTrajanjeMinuta} min',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: _ApptUi.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            formatCardDate(r.datumRezervacije),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _ApptUi.lavender.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                        if (hasNotes) ...[
                          const SizedBox(width: 6),
                          Tooltip(
                            message: r.napomenaZaTerapeuta!.trim(),
                            child: Icon(
                              Icons.sticky_note_2_outlined,
                              size: 14,
                              color: _ApptUi.lavender.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _StatusChip(label: status.label, color: status.color),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () =>
                  showTherapistRezervacijaDetailDialog(context, r),
              style: TextButton.styleFrom(
                foregroundColor: _ApptUi.lavender,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'View Details',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppointmentsSidebar extends StatelessWidget {
  const _AppointmentsSidebar({
    required this.next,
    required this.onOpenDetails,
    required this.onViewSchedule,
    required this.onManageAvailability,
    required this.onMyReviews,
  });

  final Rezervacija? next;
  final void Function(Rezervacija) onOpenDetails;
  final VoidCallback onViewSchedule;
  final VoidCallback onManageAvailability;
  final VoidCallback onMyReviews;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _NextAppointmentCard(
          next: next,
          onOpenDetails: onOpenDetails,
        ),
        const SizedBox(height: _ApptUi.gap),
        _CompactQuickActions(
          onViewSchedule: onViewSchedule,
          onManageAvailability: onManageAvailability,
          onMyReviews: onMyReviews,
        ),
      ],
    );
  }
}

class _NextAppointmentCard extends StatelessWidget {
  const _NextAppointmentCard({
    required this.next,
    required this.onOpenDetails,
  });

  final Rezervacija? next;
  final void Function(Rezervacija) onOpenDetails;

  @override
  Widget build(BuildContext context) {
    return _ApptGlass(
      padding: const EdgeInsets.all(18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 220),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Next Appointment',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: _ApptUi.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            if (next == null)
              Text(
                'No upcoming appointments.\nYou\'re all clear.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.45,
                  color: _ApptUi.textSecondary,
                ),
              )
            else ...[
              Text(
                TherapistAppointmentUtils.formatUpcomingDateTime(
                  next!.datumRezervacije,
                ),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _ApptUi.lavender,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                next!.korisnikIme ?? 'Client',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _ApptUi.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${next!.uslugaNaziv ?? 'Service'} · ${next!.uslugaTrajanjeMinuta} min',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: _ApptUi.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              _StatusChip(
                label: TherapistAppointmentUtils.statusOfRezervacija(next!).label,
                color: TherapistAppointmentUtils.statusOfRezervacija(next!).color,
              ),
              const SizedBox(height: 12),
              _CompactOutlineButton(
                label: 'Open Details',
                onTap: () => onOpenDetails(next!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CompactQuickActions extends StatelessWidget {
  const _CompactQuickActions({
    required this.onViewSchedule,
    required this.onManageAvailability,
    required this.onMyReviews,
  });

  final VoidCallback onViewSchedule;
  final VoidCallback onManageAvailability;
  final VoidCallback onMyReviews;

  @override
  Widget build(BuildContext context) {
    return _ApptGlass(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Quick Actions',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _ApptUi.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          _QuickActionButton(
            icon: Icons.view_timeline_rounded,
            label: 'View Schedule',
            onTap: onViewSchedule,
          ),
          const SizedBox(height: 8),
          _QuickActionButton(
            icon: Icons.event_available_outlined,
            label: 'Manage Availability',
            onTap: onManageAvailability,
          ),
          const SizedBox(height: 8),
          _QuickActionButton(
            icon: Icons.reviews_outlined,
            label: 'My Reviews',
            onTap: onMyReviews,
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
                color: _ApptUi.purple.withValues(alpha: _hover ? 0.35 : 0.18),
              ),
            ),
            child: Row(
              children: [
                Icon(widget.icon, size: 16, color: _ApptUi.lavender),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.label,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _ApptUi.textPrimary,
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

class _CompactOutlineButton extends StatefulWidget {
  const _CompactOutlineButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  State<_CompactOutlineButton> createState() => _CompactOutlineButtonState();
}

class _CompactOutlineButtonState extends State<_CompactOutlineButton> {
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
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _ApptUi.purple.withValues(alpha: _hover ? 0.5 : 0.28),
              ),
              color: _ApptUi.purple.withValues(alpha: _hover ? 0.1 : 0.05),
            ),
            child: Text(
              widget.label,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: _ApptUi.textPrimary,
              ),
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
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white.withValues(alpha: _hover ? 0.08 : 0.04),
                border: Border.all(
                  color: Colors.white.withValues(alpha: _hover ? 0.18 : 0.1),
                ),
              ),
              child: Icon(
                widget.icon,
                size: 20,
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
        padding: padding ?? const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
