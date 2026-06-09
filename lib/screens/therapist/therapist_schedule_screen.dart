import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/api/services/api_service.dart';
import '../../core/auth/app_permissions.dart';
import '../../core/therapist/therapist_appointment_utils.dart';
import '../../models/rezervacija.dart';
import '../../models/rezervacija_povijest_item.dart';
import '../../models/therapist/therapist_schedule.dart';
import '../../providers/auth_provider.dart';
import '../../ui/navigation/desktop_nav.dart';
import 'therapist_appointment_detail_dialog.dart';

abstract final class _SchedUi {
  static const bgTop = Color(0xFF07040F);
  static const bgBottom = Color(0xFF120A24);
  static const textPrimary = Color(0xFFF5F3FA);
  static const textSecondary = Color(0xA6FFFFFF);
  static const purple = Color(0xFF7B4DFF);
  static const lavender = Color(0xFF9D6BFF);
  static const green = Color(0xFF22C55E);
  static const amber = Color(0xFFF59E0B);
  static const teal = Color(0xFF2DD4BF);
  static const gold = Color(0xFFF5B942);
  static const cardRadius = 18.0;
  static const gap = 16.0;
  static const sidebarWidth = 320.0;
  static const contentPadding = 32.0;
}

const _statusPills = [
  'All',
  'Pending',
  'Confirmed',
  'Cancelled/Past',
];

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String _formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

String _formatTime(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String _formatDateTimeLocal(DateTime d) {
  final l = d.toLocal();
  return '${_formatDate(l)} ${_formatTime(l)}';
}

String _formatLongDate(DateTime d) {
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${weekdays[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}, ${d.year}';
}

/// Therapist daily planner — single schedule API, client-side filters.
class TherapistScheduleScreen extends StatefulWidget {
  const TherapistScheduleScreen({super.key, required this.filterDay});

  final DateTime filterDay;

  @override
  State<TherapistScheduleScreen> createState() =>
      _TherapistScheduleScreenState();
}

class _TherapistScheduleScreenState extends State<TherapistScheduleScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();

  late DateTime _day;
  TherapistSchedule? _data;
  String? _loadError;
  bool _loading = false;
  bool _initialLoad = true;
  String _statusPill = 'All';

  final ScrollController _scrollController = ScrollController();
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;
  int _lastAvailabilityHint = -1;
  int _lastRefreshToken = -1;
  String _lastSearch = '';
  DateTime? _lastFilterDay;
  late DateTime _calendarMonth;

  @override
  void initState() {
    super.initState();
    _day = _onlyDate(widget.filterDay);
    _calendarMonth = DateTime(_day.year, _day.month, 1);
    _lastFilterDay = _day;
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic);
    _reload();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TherapistScheduleScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameDay(oldWidget.filterDay, widget.filterDay)) {
      _day = _onlyDate(widget.filterDay);
      _calendarMonth = DateTime(_day.year, _day.month, 1);
      _lastFilterDay = _day;
      _reload();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nav = context.read<DesktopNav>();
    var needReload = false;

    final refresh = nav.therapistScheduleRefresh;
    if (refresh != _lastRefreshToken) {
      _lastRefreshToken = refresh;
      if (refresh > 0) needReload = true;
    }

    final search = nav.therapistScheduleSearchQuery;
    if (search != _lastSearch) {
      _lastSearch = search;
      setState(() {});
    }

    if (_lastFilterDay == null ||
        !_sameDay(_lastFilterDay!, widget.filterDay)) {
      _day = _onlyDate(widget.filterDay);
      _calendarMonth = DateTime(_day.year, _day.month, 1);
      _lastFilterDay = _day;
      needReload = true;
    }

    if (needReload) _reload();

    final hint = nav.scheduleAvailabilityHint;
    if (hint != _lastAvailabilityHint && hint > 0) {
      _lastAvailabilityHint = hint;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showAvailabilityInfo();
      });
    }
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _onlyDate(DateTime d) => DateTime(d.year, d.month, d.day);

  void _selectDay(DateTime d) {
    final day = _onlyDate(d);
    if (_day == day) return;
    setState(() {
      _day = day;
      _calendarMonth = DateTime(day.year, day.month, 1);
    });
    _reload();
    _fadeCtrl.forward(from: 0);
  }

  void _shiftCalendarMonth(int delta) {
    setState(() {
      _calendarMonth = DateTime(
        _calendarMonth.year,
        _calendarMonth.month + delta,
        1,
      );
    });
    _reload();
  }

  Future<void> _reload() async {
    final auth = context.read<AuthProvider>();
    if (!AppPermissions.of(auth).has(AppPermission.viewOwnTherapistData)) {
      setState(() {
        _loadError = 'You do not have permission to view your schedule.';
        _data = null;
        _loading = false;
        _initialLoad = false;
      });
      return;
    }

    if (!auth.isZaposlenik || auth.zaposlenikId == null) return;

    setState(() {
      _loading = true;
      _loadError = null;
    });

    final (data, error) = await _api.getTherapistSchedule(
      day: _day,
      calendarMonth: _calendarMonth,
    );

    if (!mounted) return;
    setState(() {
      _data = data;
      _loadError = error;
      _loading = false;
      _initialLoad = false;
    });
  }

  void _showAvailabilityInfo() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _SchedUi.bgBottom,
        title: Text(
          'Availability',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            color: _SchedUi.textPrimary,
          ),
        ),
        content: Text(
          'Your working hours and time off are managed by your spa admin. '
          'Contact them to request schedule changes.',
          style: GoogleFonts.inter(color: _SchedUi.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _shiftDay(int delta) {
    final next = _day.add(Duration(days: delta));
    setState(() {
      _day = next;
      if (next.month != _calendarMonth.month ||
          next.year != _calendarMonth.year) {
        _calendarMonth = DateTime(next.year, next.month, 1);
      }
    });
    _reload();
    _fadeCtrl.forward(from: 0);
  }

  void _selectStatusPill(String pill) {
    if (_statusPill == pill) return;
    setState(() => _statusPill = pill);
    _fadeCtrl.forward(from: 0);
  }

  List<Rezervacija> _filterBookings(List<Rezervacija> all) {
    final q = _lastSearch.trim().toLowerCase();
    final now = DateTime.now();
    final filtered = all.where((r) {
      switch (_statusPill) {
        case 'Pending':
          if (r.isOtkazana || r.isPotvrdjena) return false;
        case 'Confirmed':
          if (r.isOtkazana || !r.isPotvrdjena) return false;
        case 'Cancelled/Past':
          if (!r.isOtkazana && !r.datumRezervacije.toLocal().isBefore(now)) {
            return false;
          }
        default:
          break;
      }
      if (q.isNotEmpty) {
        final s = [
          r.uslugaNaziv,
          r.korisnikIme,
          r.zaposlenikIme,
        ].whereType<String>().join(' ').toLowerCase();
        if (!s.contains(q)) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => a.datumRezervacije.compareTo(b.datumRezervacije));
    return filtered;
  }

  _DayStats _dayStats(List<Rezervacija> filtered) {
    final active = filtered.where((r) => !r.isOtkazana).toList();
    final confirmed = active.where((r) => r.isPotvrdjena).length;
    final pending = active.where((r) => !r.isPotvrdjena).length;
    final hoursBooked = active.fold<double>(
      0,
      (s, r) => s + r.uslugaTrajanjeMinuta / 60.0,
    );
    return _DayStats(
      total: active.length,
      confirmed: confirmed,
      pending: pending,
      hoursBooked: hoursBooked,
    );
  }

  Rezervacija? _globalNextAppointment(AuthProvider auth) {
    final next = _data?.nextAppointment;
    if (next == null) return null;
    return next.toRezervacija(zaposlenikId: auth.zaposlenikId ?? 0);
  }

  Future<void> _openBookingDetail(Rezervacija r) async {
    await showTherapistRezervacijaDetailDialog(
      context,
      r,
      onConfirmChanged: (v) => _togglePotvrdaAndReload(r, v),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final zid = auth.zaposlenikId;

    if (!AppPermissions.of(auth).has(AppPermission.viewOwnTherapistData)) {
      return const _ScheduleShell(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'You do not have permission to view your schedule.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _SchedUi.textSecondary),
            ),
          ),
        ),
      );
    }

    if (!auth.isZaposlenik) {
      return const _ScheduleShell(
        child: Center(
          child: Text(
            'Your account does not have the therapist role.',
            style: TextStyle(color: _SchedUi.textSecondary),
          ),
        ),
      );
    }

    if (zid == null) {
      return const _ScheduleShell(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'JWT is missing ZaposlenikId. Ask your administrator to link your user to an employee record.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _SchedUi.textSecondary),
            ),
          ),
        ),
      );
    }

    if (_initialLoad && _loading) {
      return const _ScheduleShell(
        child: Center(
          child: SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_loadError != null && _data == null) {
      return _ScheduleShell(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(_SchedUi.contentPadding),
            child: _SchedGlass(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Could not load schedule.',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      color: _SchedUi.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _loadError!,
                    style: TextStyle(color: Colors.red.shade300),
                  ),
                  const SizedBox(height: 16),
                  _PrimaryGradientButton(
                    label: 'Try again',
                    icon: Icons.refresh_rounded,
                    onTap: _reload,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final schedule = _data;
    final allItems = schedule?.items
            .map((r) => r.toRezervacija(zaposlenikId: zid))
            .toList() ??
        <Rezervacija>[];
    final filtered = _filterBookings(allItems);
    final stats = _dayStats(filtered);
    final nextGlobal = _globalNextAppointment(auth);
    final markerDays = schedule?.monthMarkerDays.toSet() ?? <int>{};
    final longDate = _formatLongDate(_day);

    return _ScheduleShell(
      child: Stack(
        children: [
          RefreshIndicator(
            color: _SchedUi.lavender,
            onRefresh: _reload,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  _SchedUi.contentPadding,
                  8,
                  _SchedUi.contentPadding,
                  40,
                ),
                child: LayoutBuilder(
                  builder: (context, c) {
                    final wide = c.maxWidth >= 1100;
                    final main = _MainScheduleColumn(
                      longDate: longDate,
                      statusPill: _statusPill,
                      filtered: filtered,
                      onPill: _selectStatusPill,
                      onRefresh: _reload,
                      onPrevDay: () => _shiftDay(-1),
                      onNextDay: () => _shiftDay(1),
                      onSelect: _openBookingDetail,
                      onManageAvailability: _showAvailabilityInfo,
                      isRefreshing: _loading,
                    );
                    final sidebar = _ScheduleSidebar(
                      stats: stats,
                      calendarMonth: _calendarMonth,
                      selectedDay: _day,
                      daysWithAppointments: markerDays,
                      nextAppointment: nextGlobal,
                      availability: schedule?.availability,
                      onPrevMonth: () => _shiftCalendarMonth(-1),
                      onNextMonth: () => _shiftCalendarMonth(1),
                      onDaySelected: _selectDay,
                      onOpenDetails: _openBookingDetail,
                      onManageAvailability: _showAvailabilityInfo,
                    );

                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 7, child: main),
                          const SizedBox(width: _SchedUi.gap),
                          SizedBox(
                            width: _SchedUi.sidebarWidth,
                            child: sidebar,
                          ),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        main,
                        const SizedBox(height: _SchedUi.gap),
                        sidebar,
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _togglePotvrdaAndReload(Rezervacija r, bool v) async {
    final ok = await _api.updateRezervacijaPotvrdjena(r.id, v);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Update failed. Please try again.')),
      );
    }
    await _reload();
  }
}

class _DayStats {
  const _DayStats({
    required this.total,
    required this.confirmed,
    required this.pending,
    required this.hoursBooked,
  });

  final int total;
  final int confirmed;
  final int pending;
  final double hoursBooked;
}

class _ScheduleShell extends StatelessWidget {
  const _ScheduleShell({required this.child});

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
              colors: [_SchedUi.bgTop, _SchedUi.bgBottom],
            ),
          ),
        ),
        Positioned(
          top: -60,
          right: 80,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _SchedUi.purple.withValues(alpha: 0.2),
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

class _MainScheduleColumn extends StatelessWidget {
  const _MainScheduleColumn({
    required this.longDate,
    required this.statusPill,
    required this.filtered,
    required this.onPill,
    required this.onRefresh,
    required this.onPrevDay,
    required this.onNextDay,
    required this.onSelect,
    required this.onManageAvailability,
    this.isRefreshing = false,
  });

  final String longDate;
  final String statusPill;
  final List<Rezervacija> filtered;
  final ValueChanged<String> onPill;
  final VoidCallback onRefresh;
  final VoidCallback onPrevDay;
  final VoidCallback onNextDay;
  final ValueChanged<Rezervacija> onSelect;
  final VoidCallback onManageAvailability;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SelectedDayToolbar(
          longDate: longDate,
          onPrev: onPrevDay,
          onNext: onNextDay,
          onRefresh: onRefresh,
          isRefreshing: isRefreshing,
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final p in _statusPills) ...[
                _StatusPillChip(
                  label: p,
                  selected: statusPill == p,
                  onTap: () => onPill(p),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: _SchedUi.gap),
        Text(
          'Schedule for $longDate',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: _SchedUi.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        _MainScheduleCard(
          filtered: filtered,
          onSelect: onSelect,
          onManageAvailability: onManageAvailability,
        ),
      ],
    );
  }
}

class _SelectedDayToolbar extends StatelessWidget {
  const _SelectedDayToolbar({
    required this.longDate,
    required this.onPrev,
    required this.onNext,
    required this.onRefresh,
    this.isRefreshing = false,
  });

  final String longDate;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onRefresh;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    return _SchedGlass(
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          _GlassIconButton(icon: Icons.chevron_left_rounded, onTap: onPrev),
          Expanded(
            child: Text(
              longDate,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _SchedUi.textPrimary,
              ),
            ),
          ),
          _GlassIconButton(icon: Icons.chevron_right_rounded, onTap: onNext),
          const SizedBox(width: 4),
          if (isRefreshing)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          _GlassIconButton(icon: Icons.refresh_rounded, onTap: onRefresh),
        ],
      ),
    );
  }
}

class _StatusPillChip extends StatefulWidget {
  const _StatusPillChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_StatusPillChip> createState() => _StatusPillChipState();
}

class _StatusPillChipState extends State<_StatusPillChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: widget.selected
                ? _SchedUi.purple.withValues(alpha: 0.18)
                : (_hover
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.transparent),
            border: Border.all(
              color: widget.selected
                  ? _SchedUi.purple.withValues(alpha: 0.45)
                  : Colors.white.withValues(alpha: _hover ? 0.14 : 0.08),
            ),
          ),
          child: Text(
            widget.label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: widget.selected ? FontWeight.w800 : FontWeight.w600,
              color: widget.selected
                  ? _SchedUi.textPrimary
                  : _SchedUi.lavender.withValues(alpha: _hover ? 0.9 : 0.55),
            ),
          ),
        ),
      ),
    );
  }
}

class _MainScheduleCard extends StatelessWidget {
  const _MainScheduleCard({
    required this.filtered,
    required this.onSelect,
    required this.onManageAvailability,
  });

  final List<Rezervacija> filtered;
  final ValueChanged<Rezervacija> onSelect;
  final VoidCallback onManageAvailability;

  @override
  Widget build(BuildContext context) {
    if (filtered.isEmpty) {
      return _ScheduleEmptyState(onManageAvailability: onManageAvailability);
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _ScheduleAppointmentCard(
        r: filtered[i],
        onTap: () => onSelect(filtered[i]),
      ),
    );
  }
}

class _ScheduleAppointmentCard extends StatelessWidget {
  const _ScheduleAppointmentCard({
    required this.r,
    required this.onTap,
  });

  final Rezervacija r;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = TherapistAppointmentUtils.statusOfRezervacija(r);
    final timeRange = TherapistAppointmentUtils.formatTimeRange(
      start: r.datumRezervacije,
      durationMinutes: r.uslugaTrajanjeMinuta,
    );
    final hasNotes =
        r.napomenaZaTerapeuta != null && r.napomenaZaTerapeuta!.trim().isNotEmpty;
    final room = r.prostorijaNaziv?.trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_SchedUi.cardRadius),
        child: _SchedGlass(
          radius: _SchedUi.cardRadius,
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      timeRange,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _SchedUi.lavender,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      r.korisnikIme ?? 'Client',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _SchedUi.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${r.uslugaNaziv ?? 'Service'} · ${r.uslugaTrajanjeMinuta} min',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: _SchedUi.textSecondary,
                      ),
                    ),
                    if (room != null && room.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.meeting_room_outlined,
                            size: 13,
                            color: _SchedUi.lavender.withValues(alpha: 0.75),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              room,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _SchedUi.lavender.withValues(alpha: 0.75),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (hasNotes) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.sticky_note_2_outlined,
                            size: 13,
                            color: _SchedUi.amber.withValues(alpha: 0.9),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Client notes',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _SchedUi.amber.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (r.isVip || r.premiumKlijent) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (r.isVip)
                            _StatusBadge(
                              label: 'VIP',
                              color: _SchedUi.gold,
                            ),
                          if (r.isVip && r.premiumKlijent)
                            const SizedBox(width: 6),
                          if (r.premiumKlijent)
                            _StatusBadge(
                              label: 'Premium',
                              color: _SchedUi.teal,
                            ),
                        ],
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

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

class _ScheduleEmptyState extends StatelessWidget {
  const _ScheduleEmptyState({required this.onManageAvailability});

  final VoidCallback onManageAvailability;

  @override
  Widget build(BuildContext context) {
    return _SchedGlass(
      radius: _SchedUi.cardRadius,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
            Text(
              'No appointments scheduled for this date.',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _SchedUi.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Try another date or update your availability.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: _SchedUi.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            _OutlinedGlowButton(
              label: 'Manage Availability',
              icon: Icons.event_available_outlined,
              onTap: onManageAvailability,
            ),
        ],
      ),
    );
  }
}

class _ScheduleSidebar extends StatelessWidget {
  const _ScheduleSidebar({
    required this.stats,
    required this.calendarMonth,
    required this.selectedDay,
    required this.daysWithAppointments,
    required this.nextAppointment,
    this.availability,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onDaySelected,
    required this.onOpenDetails,
    required this.onManageAvailability,
  });

  final _DayStats stats;
  final DateTime calendarMonth;
  final DateTime selectedDay;
  final Set<int> daysWithAppointments;
  final Rezervacija? nextAppointment;
  final TherapistScheduleAvailabilitySummary? availability;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<Rezervacija> onOpenDetails;
  final VoidCallback onManageAvailability;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TodayOverviewCard(
          stats: stats,
          isToday: selectedDay.year == DateTime.now().year &&
              selectedDay.month == DateTime.now().month &&
              selectedDay.day == DateTime.now().day,
        ),
        const SizedBox(height: _SchedUi.gap),
        _MiniCalendarCard(
          month: calendarMonth,
          selectedDay: selectedDay,
          daysWithAppointments: daysWithAppointments,
          onPrevMonth: onPrevMonth,
          onNextMonth: onNextMonth,
          onDaySelected: onDaySelected,
        ),
        const SizedBox(height: _SchedUi.gap),
        _NextAppointmentCard(
          next: nextAppointment,
          onOpenDetails: onOpenDetails,
        ),
        if (availability != null &&
            availability!.availableSlotCount > 0) ...[
          const SizedBox(height: _SchedUi.gap),
          _AvailabilitySummaryCard(availability: availability!),
        ],
      ],
    );
  }
}

class _TodayOverviewCard extends StatelessWidget {
  const _TodayOverviewCard({
    required this.stats,
    required this.isToday,
  });

  final _DayStats stats;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final hoursLabel = stats.hoursBooked == stats.hoursBooked.roundToDouble()
        ? '${stats.hoursBooked.round()}h'
        : '${stats.hoursBooked.toStringAsFixed(1)}h';

    return _SchedGlass(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isToday ? 'Today Overview' : 'Day Overview',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _SchedUi.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          _OverviewStat(
            label: isToday ? 'Appointments Today' : 'Appointments',
            value: '${stats.total}',
            color: _SchedUi.purple,
          ),
          const SizedBox(height: 8),
          _OverviewStat(
            label: 'Confirmed',
            value: '${stats.confirmed}',
            color: _SchedUi.green,
          ),
          const SizedBox(height: 8),
          _OverviewStat(
            label: 'Pending',
            value: '${stats.pending}',
            color: _SchedUi.amber,
          ),
          const SizedBox(height: 8),
          _OverviewStat(
            label: 'Hours Booked',
            value: hoursLabel,
            color: _SchedUi.lavender,
          ),
        ],
      ),
    );
  }
}

class _OverviewStat extends StatelessWidget {
  const _OverviewStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _SchedUi.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _MiniCalendarCard extends StatelessWidget {
  const _MiniCalendarCard({
    required this.month,
    required this.selectedDay,
    required this.daysWithAppointments,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onDaySelected,
  });

  final DateTime month;
  final DateTime selectedDay;
  final Set<int> daysWithAppointments;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstWeekday = DateTime(month.year, month.month, 1).weekday;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = firstWeekday - 1;

    return _SchedGlass(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_monthNames[month.month - 1]} ${month.year}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _SchedUi.textPrimary,
                  ),
                ),
              ),
              _GlassIconButton(
                icon: Icons.chevron_left_rounded,
                onTap: onPrevMonth,
                size: 32,
              ),
              const SizedBox(width: 4),
              _GlassIconButton(
                icon: Icons.chevron_right_rounded,
                onTap: onNextMonth,
                size: 32,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final d in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _SchedUi.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: leading + daysInMonth,
            itemBuilder: (context, index) {
              if (index < leading) return const SizedBox.shrink();
              final dayNum = index - leading + 1;
              final date = DateTime(month.year, month.month, dayNum);
              final isSelected = selectedDay.year == date.year &&
                  selectedDay.month == date.month &&
                  selectedDay.day == date.day;
              final isToday = today == date;
              final hasAppt = daysWithAppointments.contains(dayNum);

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onDaySelected(date),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: isSelected
                          ? _SchedUi.purple.withValues(alpha: 0.22)
                          : (isToday
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.transparent),
                      border: Border.all(
                        color: isSelected
                            ? _SchedUi.purple.withValues(alpha: 0.5)
                            : (isToday
                                ? Colors.white.withValues(alpha: 0.14)
                                : Colors.transparent),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$dayNum',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: isSelected || isToday
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: isSelected
                                ? _SchedUi.textPrimary
                                : _SchedUi.lavender.withValues(alpha: 0.8),
                          ),
                        ),
                        if (hasAppt)
                          Container(
                            width: 4,
                            height: 4,
                            margin: const EdgeInsets.only(top: 2),
                            decoration: const BoxDecoration(
                              color: _SchedUi.teal,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AvailabilitySummaryCard extends StatelessWidget {
  const _AvailabilitySummaryCard({required this.availability});

  final TherapistScheduleAvailabilitySummary availability;

  @override
  Widget build(BuildContext context) {
    final label = availability.workingHoursLabel?.trim();
    return _SchedGlass(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Open slots',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _SchedUi.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${availability.availableSlotCount} available',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _SchedUi.teal,
            ),
          ),
          if (label != null && label.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: _SchedUi.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NextAppointmentCard extends StatelessWidget {
  const _NextAppointmentCard({
    required this.next,
    required this.onOpenDetails,
  });

  final Rezervacija? next;
  final ValueChanged<Rezervacija> onOpenDetails;

  @override
  Widget build(BuildContext context) {
    return _SchedGlass(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Next Appointment',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _SchedUi.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (next == null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No upcoming appointments.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _SchedUi.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'You\'re all clear.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: _SchedUi.textSecondary,
                  ),
                ),
              ],
            )
          else ...[
            Text(
              TherapistAppointmentUtils.formatUpcomingDateTime(
                next!.datumRezervacije,
              ),
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _SchedUi.lavender,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              next!.korisnikIme ?? 'Client',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _SchedUi.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${next!.uslugaNaziv ?? 'Service'} · ${next!.uslugaTrajanjeMinuta} min',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: _SchedUi.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            _StatusBadge(
              label: TherapistAppointmentUtils.statusOfRezervacija(next!).label,
              color: TherapistAppointmentUtils.statusOfRezervacija(next!).color,
            ),
            const SizedBox(height: 12),
            _OutlinedGlowButton(
              label: 'View Details',
              icon: Icons.visibility_outlined,
              onTap: () => onOpenDetails(next!),
            ),
          ],
        ],
      ),
    );
  }
}

class _SlotsSection extends StatelessWidget {
  const _SlotsSection({required this.slotovi});

  final List<DateTime> slotovi;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Available slots (${slotovi.length})',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _SchedUi.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        if (slotovi.isEmpty)
          Text(
            'No open slots for this day.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: _SchedUi.textSecondary,
            ),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: slotovi
                .map(
                  (t) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: _SchedUi.green.withValues(alpha: 0.12),
                      border: Border.all(
                        color: _SchedUi.green.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      _formatTime(t.toLocal()),
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        color: _SchedUi.green,
                        fontSize: 11,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

class _SchedGlass extends StatelessWidget {
  const _SchedGlass({
    required this.child,
    this.padding,
    this.radius = _SchedUi.cardRadius,
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
              color: _SchedUi.purple.withValues(alpha: 0.1),
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

class _GlassIconButton extends StatefulWidget {
  const _GlassIconButton({
    required this.icon,
    required this.onTap,
    this.size = 48,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;

  @override
  State<_GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<_GlassIconButton> {
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
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white.withValues(alpha: _hover ? 0.1 : 0.05),
              border: Border.all(
                color: Colors.white.withValues(alpha: _hover ? 0.2 : 0.1),
              ),
              boxShadow: _hover
                  ? [
                      BoxShadow(
                        color: _SchedUi.purple.withValues(alpha: 0.25),
                        blurRadius: 12,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              widget.icon,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassActionButton extends StatefulWidget {
  const _GlassActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_GlassActionButton> createState() => _GlassActionButtonState();
}

class _GlassActionButtonState extends State<_GlassActionButton> {
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
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white.withValues(alpha: _hover ? 0.1 : 0.05),
              border: Border.all(
                color: Colors.white.withValues(alpha: _hover ? 0.22 : 0.12),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 18, color: _SchedUi.lavender),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: _SchedUi.textPrimary,
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

class _PrimaryGradientButton extends StatefulWidget {
  const _PrimaryGradientButton({
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
            height: widget.compact ? 52 : 56,
            padding: EdgeInsets.symmetric(
              horizontal: widget.compact ? 16 : 22,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  _SchedUi.purple.withValues(alpha: _hover ? 1 : 0.92),
                  _SchedUi.lavender.withValues(alpha: _hover ? 1 : 0.92),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: _SchedUi.purple.withValues(alpha: _hover ? 0.5 : 0.35),
                  blurRadius: _hover ? 20 : 14,
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
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_OutlinedGlowButton> createState() => _OutlinedGlowButtonState();
}

class _OutlinedGlowButtonState extends State<_OutlinedGlowButton> {
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
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _SchedUi.purple.withValues(alpha: _hover ? 0.7 : 0.45),
                width: 1.5,
              ),
              color: _SchedUi.purple.withValues(alpha: _hover ? 0.12 : 0.06),
              boxShadow: _hover
                  ? [
                      BoxShadow(
                        color: _SchedUi.purple.withValues(alpha: 0.35),
                        blurRadius: 18,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, color: _SchedUi.lavender, size: 20),
                const SizedBox(width: 10),
                Text(
                  widget.label,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: _SchedUi.textPrimary,
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

class _TherapistClientDrawerContent extends StatefulWidget {
  const _TherapistClientDrawerContent({
    required this.api,
    required this.rezervacija,
    required this.onClose,
    required this.slotoviFuture,
    required this.onPotvrdiToggled,
  });

  final ApiService api;
  final Rezervacija rezervacija;
  final VoidCallback onClose;
  final Future<List<DateTime>> Function() slotoviFuture;
  final Future<void> Function(Rezervacija r, bool potvrdi) onPotvrdiToggled;

  @override
  State<_TherapistClientDrawerContent> createState() =>
      _TherapistClientDrawerContentState();
}

class _TherapistClientDrawerContentState
    extends State<_TherapistClientDrawerContent> {
  late Future<List<DateTime>> _slots;
  late Future<List<RezervacijaPovijestItem>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _slots = widget.slotoviFuture();
    final kid = widget.rezervacija.korisnikId;
    _historyFuture = kid > 0
        ? widget.api.getRezervacijaPovijestZaKlijenta(
            korisnikId: kid,
            excludeRezervacijaId: widget.rezervacija.id,
            take: 20,
          )
        : Future.value(const <RezervacijaPovijestItem>[]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = widget.rezervacija;
    final dt = r.datumRezervacije.toLocal();
    final isPast = dt.isBefore(DateTime.now());

    final premiumSegment = r.premiumKlijent || (r.isPotvrdjena && r.isPlacena);
    final napomena = r.napomenaZaTerapeuta?.trim();

    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
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
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          transitionBuilder: (child, anim) =>
                              FadeTransition(opacity: anim, child: child),
                          child: Align(
                            key: ValueKey(r.id),
                            alignment: Alignment.centerLeft,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Client context',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    letterSpacing: 0.15,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.65),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  r.korisnikIme ?? 'Unknown client',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (r.korisnikTelefon?.trim().isNotEmpty ??
                                    false) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    r.korisnikTelefon!.trim(),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                                if (premiumSegment) ...[
                                  const SizedBox(height: 8),
                                  Chip(
                                    avatar: Icon(
                                      Icons.workspace_premium_outlined,
                                      size: 18,
                                      color: _SchedUi.gold,
                                    ),
                                    label: Text(
                                      r.premiumKlijent
                                          ? 'Premium client (VIP)'
                                          : 'Confirmed and paid',
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close panel',
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                color: Colors.amber.shade900.withValues(alpha: 0.22),
                child: ListTile(
                  leading: const Icon(Icons.health_and_safety_outlined),
                  title: const Text('Treatment notes'),
                  subtitle: Text(
                    napomena == null || napomena.isEmpty
                        ? 'No notes entered (allergies, contraindications…).'
                        : napomena,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _formatDateTimeLocal(dt),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${r.uslugaNaziv ?? 'Service'}\n'
                'You only see your own appointments.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: widget.onClose,
                icon: const Icon(Icons.keyboard_return),
                label: const Text('Hide panel'),
              ),
              const Divider(height: 32),
              Text(
                'Treatment history',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              FutureBuilder<List<RezervacijaPovijestItem>>(
                future: _historyFuture,
                builder: (context, histSnap) {
                  if (histSnap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }
                  final items = histSnap.data ?? const [];
                  if (items.isEmpty) {
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.history_rounded),
                      title: Text(
                        r.korisnikId <= 0
                            ? 'Client ID not available'
                            : 'No additional appointments',
                      ),
                      subtitle: Text(
                        r.korisnikId <= 0
                            ? 'Contact your administrator (API).'
                            : 'Only shared appointments with you are shown.',
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final h in items)
                        ListTile(
                          dense: true,
                          leading: Icon(
                            h.isOtkazana
                                ? Icons.event_busy_rounded
                                : Icons.event_rounded,
                          ),
                          title: Text(h.uslugaNaziv ?? 'Service'),
                          subtitle: Text(
                            '${_formatDateTimeLocal(h.datumRezervacije)} · '
                            '${h.isPotvrdjena ? 'confirmed' : 'pending'} · '
                            '${h.isPlacena ? 'paid' : 'unpaid'}'
                            '${h.isOtkazana ? ' · cancelled' : ''}',
                          ),
                        ),
                    ],
                  );
                },
              ),
              const Divider(height: 24),
              Text(
                'Booking',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Chip(
                    label: Text(r.isPotvrdjena ? 'Confirmed' : 'Pending'),
                  ),
                  Chip(label: Text(r.isPlacena ? 'Paid' : 'Unpaid')),
                ],
              ),
              const SizedBox(height: 12),
              if (isPast)
                Text(
                  'This appointment is in the past.',
                  style: TextStyle(color: Colors.grey.shade500),
                )
              else if (!r.isPotvrdjena)
                FilledButton.icon(
                  onPressed: () => widget.onPotvrdiToggled(r, true),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Confirm booking'),
                )
              else
                OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Move back to pending?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Confirm'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true && context.mounted) {
                      await widget.onPotvrdiToggled(r, false);
                    }
                  },
                  icon: const Icon(Icons.schedule),
                  label: const Text('Mark as pending'),
                ),
              const SizedBox(height: 18),
              FutureBuilder<List<DateTime>>(
                future: _slots,
                builder: (context, s) => _SlotsSection(slotovi: s.data ?? []),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
