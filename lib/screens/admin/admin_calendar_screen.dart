import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../../models/admin/rezervacija_calendar_item.dart';
import '../../models/usluga.dart';
import '../../models/zaposlenik.dart';
import '../../ui/navigation/desktop_nav.dart';
import '../../ui/theme/nua_luxury_tokens.dart';

enum _CalViewMode { day, week, month }

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime _mondayOf(DateTime d) {
  final day = _dateOnly(d);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

bool _sameDay(DateTime a, DateTime b) {
  final x = a.toLocal();
  final y = b.toLocal();
  return x.year == y.year && x.month == y.month && x.day == y.day;
}

List<RezervacijaCalendarItem> _calendarPassThrough(
  List<RezervacijaCalendarItem> xs,
) =>
    xs;

String _hm(DateTime d) {
  final l = d.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

String _weekdayShort(DateTime d) {
  const n = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return n[(d.weekday - 1).clamp(0, 6)];
}

/// High-fidelity admin calendar (dark mockup palette).
abstract final class _CalUi {
  static const Color bg = Color(0xFF0B0E14);
  static const Color surface = Color(0xFF161922);
  static const Color surfaceCard = Color(0xFF1B1D2D);
  static const Color accent = Color(0xFF6C5CE7);
  static const Color border = Color(0xFF2A2D3E);
}

String _monthLong(int m) {
  const n = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return n[(m - 1).clamp(0, 11)];
}

String _rangeCaption(_CalViewMode view, DateTime anchor, ({DateTime from, DateTime to}) range) {
  switch (view) {
    case _CalViewMode.day:
      final d = _dateOnly(anchor);
      return '${_monthLong(d.month)} ${d.day}, ${d.year}';
    case _CalViewMode.week:
      final a = _dateOnly(range.from);
      final b = _dateOnly(range.to);
      if (a.month == b.month && a.year == b.year) {
        return '${_monthLong(a.month)} ${a.day} – ${b.day}, ${a.year}';
      }
      return '${_monthLong(a.month)} ${a.day} – ${_monthLong(b.month)} ${b.day}, ${b.year}';
    case _CalViewMode.month:
      return '${_monthLong(anchor.month)} ${anchor.year}';
  }
}

/// Admin calendar — week timeline + filteri (terapeuti, otkazani, auto-refresh, pretraga).
class AdminCalendarScreen extends StatefulWidget {
  const AdminCalendarScreen({super.key});

  @override
  State<AdminCalendarScreen> createState() => _AdminCalendarScreenState();
}

class _AdminCalendarScreenState extends State<AdminCalendarScreen> {
  static const int _startHour = 8;
  static const int _endHour = 19;
  static const double _pxPerMinute = 1.35;

  final ApiService _api = ApiService();

  DateTime _anchor = _dateOnly(DateTime.now());
  _CalViewMode _view = _CalViewMode.week;
  /// Month shown in the right-rail mini calendar (can differ while browsing).
  DateTime _miniDisplayMonth = DateTime(DateTime.now().year, DateTime.now().month);

  int? _filterZaposlenikId;
  int? _filterUslugaId;
  final TextEditingController _searchCtrl = TextEditingController();

  bool _includeCancelled = false;
  bool _autoRefresh = true;
  Timer? _timer;
  Timer? _searchDebounce;

  List<Zaposlenik> _therapists = [];
  List<Usluga> _usluge = [];

  Future<List<RezervacijaCalendarItem>>? _calendarFuture;

  RezervacijaCalendarItem? _selected;

  @override
  void initState() {
    super.initState();
    _miniDisplayMonth = DateTime(_anchor.year, _anchor.month);
    _bootstrapLists();
    _searchCtrl.addListener(_onSearchChanged);
    _reloadCalendar();
    _startTimer();
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchDebounce?.cancel();
    _timer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      _reloadCalendar();
    });
  }

  Future<void> _bootstrapLists() async {
    final t = await _api.getZaposlenici();
    final u = await _api.getUsluge();
    if (!mounted) return;
    setState(() {
      _therapists = t;
      _usluge = u;
    });
  }

  void _startTimer() {
    _timer?.cancel();
    if (!_autoRefresh) return;
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted || !_autoRefresh) return;
      _reloadCalendar();
    });
  }

  ({DateTime from, DateTime to}) _visibleRange() {
    switch (_view) {
      case _CalViewMode.day:
        final d = _dateOnly(_anchor);
        return (
          from: d,
          to: d.add(const Duration(days: 1)).subtract(const Duration(seconds: 1)),
        );
      case _CalViewMode.week:
        final m = _mondayOf(_anchor);
        return (
          from: m,
          to: m.add(const Duration(days: 7)).subtract(const Duration(seconds: 1)),
        );
      case _CalViewMode.month:
        final first = DateTime(_anchor.year, _anchor.month);
        final next = DateTime(_anchor.year, _anchor.month + 1);
        return (
          from: first,
          to: next.subtract(const Duration(seconds: 1)),
        );
    }
  }

  List<DateTime> _headerDays() {
    switch (_view) {
      case _CalViewMode.day:
        return [_dateOnly(_anchor)];
      case _CalViewMode.week:
        final m = _mondayOf(_anchor);
        return List.generate(7, (i) => m.add(Duration(days: i)));
      case _CalViewMode.month:
        final m = _mondayOf(_anchor);
        return List.generate(7, (i) => m.add(Duration(days: i)));
    }
  }

  void _reloadCalendar() {
    final r = _visibleRange();
    final qq = _searchCtrl.text.trim();
    setState(() {
      _calendarFuture = _api.getRezervacijeCalendar(
        from: r.from,
        to: r.to,
        zaposlenikId: _filterZaposlenikId,
        uslugaId: _filterUslugaId,
        q: qq.isEmpty ? null : qq,
        includeOtkazane: _includeCancelled,
      );
    });
  }

  DateTime _summaryDay() {
    final now = _dateOnly(DateTime.now());
    final r = _visibleRange();
    final from = _dateOnly(r.from);
    final to = _dateOnly(r.to);
    if (!now.isBefore(from) && !now.isAfter(to)) return now;
    return from;
  }

  void _shiftPeriod(int delta) {
    setState(() {
      switch (_view) {
        case _CalViewMode.day:
          _anchor = _dateOnly(_anchor).add(Duration(days: delta));
        case _CalViewMode.week:
          _anchor = _mondayOf(_anchor).add(Duration(days: 7 * delta));
        case _CalViewMode.month:
          _anchor = DateTime(_anchor.year, _anchor.month + delta);
      }
      _selected = null;
      _miniDisplayMonth = DateTime(_anchor.year, _anchor.month);
    });
    _reloadCalendar();
  }

  void _goToday() {
    setState(() {
      _anchor = _dateOnly(DateTime.now());
      _selected = null;
      _miniDisplayMonth = DateTime(_anchor.year, _anchor.month);
    });
    _reloadCalendar();
  }

  @override
  Widget build(BuildContext context) {
    final range = _visibleRange();
    final rangeLabel = _rangeCaption(_view, _anchor, range);
    final auth = context.watch<AuthProvider>();
    final displayName = auth.displayName ?? 'Admin';
    final roleLabel = auth.isAdmin ? 'Super Admin' : 'Staff';
    final initials = auth.userInitials ?? 'A';

    final weekStart = switch (_view) {
      _CalViewMode.week => _mondayOf(_anchor),
      _CalViewMode.day => _dateOnly(_anchor),
      _CalViewMode.month => _mondayOf(_anchor),
    };

    return DecoratedBox(
      decoration: const BoxDecoration(color: _CalUi.bg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Calendar',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage your spa schedule and appointments.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.52),
                            ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 340,
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search appointments...',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.38),
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                      isDense: true,
                      filled: true,
                      fillColor: _CalUi.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _CalUi.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _CalUi.accent, width: 1.4),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      tooltip: 'Notifications',
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Notifications — uskoro.')),
                        );
                      },
                      icon: Icon(
                        Icons.notifications_none_rounded,
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                    Positioned(
                      right: 6,
                      top: 6,
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: _CalUi.accent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            '3',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: _CalUi.accent.withValues(alpha: 0.35),
                      child: Text(
                        initials.length > 2 ? initials.substring(0, 2) : initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          roleLabel,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Toolbar(
                        rangeLabel: rangeLabel,
                        view: _view,
                        onView: (v) {
                          setState(() {
                            _view = v;
                            _miniDisplayMonth = DateTime(_anchor.year, _anchor.month);
                          });
                          _reloadCalendar();
                        },
                        includeCancelled: _includeCancelled,
                        onToggleCancelled: (v) {
                          setState(() => _includeCancelled = v);
                          _reloadCalendar();
                        },
                        autoRefresh: _autoRefresh,
                        onToggleAuto: (v) {
                          setState(() => _autoRefresh = v);
                          _startTimer();
                          if (v) _reloadCalendar();
                        },
                        therapists: _therapists,
                        usluge: _usluge,
                        filterZaposlenikId: _filterZaposlenikId,
                        onTherapist: (id) {
                          setState(() => _filterZaposlenikId = id);
                          _reloadCalendar();
                        },
                        filterUslugaId: _filterUslugaId,
                        onUsluga: (id) {
                          setState(() => _filterUslugaId = id);
                          _reloadCalendar();
                        },
                        onPrev: () => _shiftPeriod(-1),
                        onNext: () => _shiftPeriod(1),
                        onToday: _goToday,
                        onAddAppointment: () {
                          context.read<DesktopNav>().requestAppointmentCreate(
                                zaposlenikId: _filterZaposlenikId,
                              );
                        },
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: _CalUi.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _CalUi.border.withValues(alpha: 0.85),
                              ),
                            ),
                            child: _view == _CalViewMode.month
                                ? _MonthOverview(
                                    anchor: _anchor,
                                    itemsFuture: _calendarFuture,
                                    onPickDay: (d) {
                                      setState(() {
                                        _anchor = d;
                                        _view = _CalViewMode.week;
                                        _miniDisplayMonth = DateTime(d.year, d.month);
                                      });
                                      _reloadCalendar();
                                    },
                                    filterFn: _calendarPassThrough,
                                  )
                                : _WeekTimeline(
                                    days: _headerDays(),
                                    itemsFuture: _calendarFuture,
                                    filterFn: _calendarPassThrough,
                                    selected: _selected,
                                    onSelect: (e) => setState(() => _selected = e),
                                    startHour: _startHour,
                                    endHour: _endHour,
                                    pxPerMinute: _pxPerMinute,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 300,
                  child: _RightRail(
                    selected: _selected,
                    itemsFuture: _calendarFuture,
                    filterFn: _calendarPassThrough,
                    summaryDay: _summaryDay(),
                    miniDisplayMonth: _miniDisplayMonth,
                    weekStartMonday: weekStart,
                    onPrevMiniMonth: () {
                      setState(() {
                        _miniDisplayMonth = DateTime(
                          _miniDisplayMonth.year,
                          _miniDisplayMonth.month - 1,
                        );
                      });
                    },
                    onNextMiniMonth: () {
                      setState(() {
                        _miniDisplayMonth = DateTime(
                          _miniDisplayMonth.year,
                          _miniDisplayMonth.month + 1,
                        );
                      });
                    },
                    onPickMiniDay: (d) {
                      setState(() {
                        _anchor = _dateOnly(d);
                        _view = _CalViewMode.week;
                        _miniDisplayMonth = DateTime(d.year, d.month);
                        _selected = null;
                      });
                      _reloadCalendar();
                    },
                    onViewFullSchedule: _goToday,
                    onNew: () {
                      context.read<DesktopNav>().requestAppointmentCreate(
                            zaposlenikId: _filterZaposlenikId,
                          );
                    },
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

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.rangeLabel,
    required this.view,
    required this.onView,
    required this.includeCancelled,
    required this.onToggleCancelled,
    required this.autoRefresh,
    required this.onToggleAuto,
    required this.therapists,
    required this.usluge,
    required this.filterZaposlenikId,
    required this.onTherapist,
    required this.filterUslugaId,
    required this.onUsluga,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
    required this.onAddAppointment,
  });

  final String rangeLabel;
  final _CalViewMode view;
  final ValueChanged<_CalViewMode> onView;
  final bool includeCancelled;
  final ValueChanged<bool> onToggleCancelled;
  final bool autoRefresh;
  final ValueChanged<bool> onToggleAuto;
  final List<Zaposlenik> therapists;
  final List<Usluga> usluge;
  final int? filterZaposlenikId;
  final ValueChanged<int?> onTherapist;
  final int? filterUslugaId;
  final ValueChanged<int?> onUsluga;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final VoidCallback onAddAppointment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: _CalUi.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _CalUi.border.withValues(alpha: 0.75)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              TextButton(
                onPressed: onToday,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: const Text('Today', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              IconButton(
                tooltip: 'Previous',
                onPressed: onPrev,
                icon: const Icon(Icons.chevron_left_rounded, size: 26),
                color: Colors.white.withValues(alpha: 0.85),
              ),
              Expanded(
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          rangeLabel,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Colors.white.withValues(alpha: 0.92),
                          ),
                        ),
                      ),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white.withValues(alpha: 0.35),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Next',
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right_rounded, size: 26),
                color: Colors.white.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 4),
              SegmentedButton<_CalViewMode>(
                showSelectedIcon: false,
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: WidgetStateProperty.resolveWith((s) {
                    if (s.contains(WidgetState.selected)) {
                      return Colors.white;
                    }
                    return Colors.white.withValues(alpha: 0.65);
                  }),
                  backgroundColor: WidgetStateProperty.resolveWith((s) {
                    if (s.contains(WidgetState.selected)) {
                      return _CalUi.accent;
                    }
                    return _CalUi.surface;
                  }),
                  side: WidgetStateProperty.all(
                    const BorderSide(color: _CalUi.border),
                  ),
                ),
                segments: const [
                  ButtonSegment(value: _CalViewMode.day, label: Text('Day')),
                  ButtonSegment(value: _CalViewMode.week, label: Text('Week')),
                  ButtonSegment(value: _CalViewMode.month, label: Text('Month')),
                ],
                selected: {view},
                onSelectionChanged: (s) => onView(s.first),
              ),
              const SizedBox(width: 6),
              PopupMenuButton<String>(
                tooltip: 'More',
                icon: Icon(Icons.more_horiz_rounded, color: Colors.white.withValues(alpha: 0.65)),
                color: _CalUi.surfaceCard,
                onSelected: (id) {
                  if (id == 'c') onToggleCancelled(!includeCancelled);
                  if (id == 'a') onToggleAuto(!autoRefresh);
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'c',
                    child: Text(
                      includeCancelled ? '✓ Include cancelled' : 'Include cancelled',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'a',
                    child: Text(
                      autoRefresh ? '✓ Auto refresh (20s)' : 'Auto refresh (20s)',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _CalUi.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: onAddAppointment,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text(
                  'Add Appointment',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int?>(
                  value: filterZaposlenikId,
                  isExpanded: true,
                  dropdownColor: _CalUi.surfaceCard,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: _dropDecoration('Therapist'),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('All therapists'),
                    ),
                    ...therapists.map(
                      (t) => DropdownMenuItem(
                        value: t.id,
                        child: Text(
                          '${t.ime} ${t.prezime}'.trim(),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: onTherapist,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<int?>(
                  value: filterUslugaId,
                  isExpanded: true,
                  dropdownColor: _CalUi.surfaceCard,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: _dropDecoration('Service'),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('All services'),
                    ),
                    ...usluge.map(
                      (u) => DropdownMenuItem(
                        value: u.id,
                        child: Text(u.naziv, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: onUsluga,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _dropDecoration(String hint) => InputDecoration(
        isDense: true,
        labelText: hint,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
        filled: true,
        fillColor: _CalUi.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _CalUi.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _CalUi.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _CalUi.accent, width: 1.2),
        ),
      );
}

class _WeekTimeline extends StatelessWidget {
  const _WeekTimeline({
    required this.days,
    required this.itemsFuture,
    required this.filterFn,
    required this.selected,
    required this.onSelect,
    required this.startHour,
    required this.endHour,
    required this.pxPerMinute,
  });

  final List<DateTime> days;
  final Future<List<RezervacijaCalendarItem>>? itemsFuture;
  final List<RezervacijaCalendarItem> Function(List<RezervacijaCalendarItem>) filterFn;
  final RezervacijaCalendarItem? selected;
  final ValueChanged<RezervacijaCalendarItem?> onSelect;
  final int startHour;
  final int endHour;
  final double pxPerMinute;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return FutureBuilder<List<RezervacijaCalendarItem>>(
      future: itemsFuture,
      builder: (context, snap) {
        final raw = snap.data ?? const <RezervacijaCalendarItem>[];
        final items = filterFn(raw);
        return LayoutBuilder(
          builder: (context, constraints) {
            const headerH = 40.0;
            final maxBody = constraints.maxHeight - headerH;
            final bodyCap = (maxBody - 2).clamp(32.0, double.infinity);
            final slotMinutes = (endHour - startHour) * 60.0;
            final naturalH = slotMinutes * pxPerMinute;
            final scale = naturalH > bodyCap
                ? (bodyCap / naturalH).clamp(0.18, 1.0)
                : 1.0;
            final effectivePx = pxPerMinute * scale;
            final totalH = slotMinutes * effectivePx;

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 72.0 + days.length * 148.0,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TimeRuler(
                      startHour: startHour,
                      endHour: endHour,
                      height: totalH,
                      pxPerMinute: effectivePx,
                    ),
                    for (final day in days)
                      SizedBox(
                        width: 148,
                        child: _DayColumn(
                          day: day,
                          items: () {
                            final d = items
                                .where((e) => _sameDay(e.datumRezervacije, day))
                                .toList();
                            d.sort(
                              (a, b) => a.datumRezervacije
                                  .compareTo(b.datumRezervacije),
                            );
                            return d;
                          }(),
                          height: totalH,
                          startHour: startHour,
                          endHour: endHour,
                          pxPerMinute: effectivePx,
                          now: now,
                          selected: selected,
                          onSelect: onSelect,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _TimeRuler extends StatelessWidget {
  const _TimeRuler({
    required this.startHour,
    required this.endHour,
    required this.height,
    required this.pxPerMinute,
  });

  final int startHour;
  final int endHour;
  final double height;
  final double pxPerMinute;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 72,
      height: height + 40,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const SizedBox(height: 40),
          SizedBox(
            height: height,
            child: Stack(
              children: [
                for (var h = startHour; h < endHour; h++)
                  Positioned(
                    top: (h - startHour) * 60 * pxPerMinute,
                    left: 0,
                    right: 6,
                    child: Text(
                      '${h.toString().padLeft(2, '0')}:00',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontWeight: FontWeight.w700,
                      ),
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

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.day,
    required this.items,
    required this.height,
    required this.startHour,
    required this.endHour,
    required this.pxPerMinute,
    required this.now,
    required this.selected,
    required this.onSelect,
  });

  final DateTime day;
  final List<RezervacijaCalendarItem> items;
  final double height;
  final int startHour;
  final int endHour;
  final double pxPerMinute;
  final DateTime now;
  final RezervacijaCalendarItem? selected;
  final ValueChanged<RezervacijaCalendarItem?> onSelect;

  double _minutes(DateTime d) {
    final l = d.toLocal();
    return l.hour * 60.0 + l.minute + l.second / 60.0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isToday = _sameDay(day, now);
    final startM = startHour * 60.0;
    final endM = endHour * 60.0;

    double topFor(RezervacijaCalendarItem e) {
      final m = _minutes(e.datumRezervacije);
      return (m - startM) * pxPerMinute;
    }

    double hFor(RezervacijaCalendarItem e) {
      final d = e.uslugaTrajanjeMinuta <= 0 ? 60 : e.uslugaTrajanjeMinuta;
      return d * pxPerMinute;
    }

    double? nowTop;
    if (isToday) {
      final nm = _minutes(now);
      if (nm >= startM && nm <= endM) {
        nowTop = (nm - startM) * pxPerMinute;
      }
    }

    return Column(
      children: [
        Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
            ),
            color: isToday ? _CalUi.accent.withValues(alpha: 0.08) : null,
          ),
          child: isToday
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _CalUi.accent, width: 2),
                    color: _CalUi.accent.withValues(alpha: 0.15),
                  ),
                  child: Text(
                    '${_weekdayShort(day)} ${day.day}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                )
              : Text(
                  '${_weekdayShort(day)} ${day.day}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Colors.white.withValues(alpha: 0.88),
                  ),
                ),
        ),
        SizedBox(
          height: height,
          child: ClipRRect(
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _HourGridPainter(
                      startHour: startHour,
                      endHour: endHour,
                      pxPerMinute: pxPerMinute,
                    ),
                  ),
                ),
                if (nowTop != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: nowTop,
                    child: Container(
                      height: 2,
                      color: _CalUi.accent.withValues(alpha: 0.85),
                    ),
                  ),
                for (final e in items)
                  Positioned(
                    left: 4,
                    right: 4,
                    top: topFor(e).clamp(0, height - 24),
                    height: hFor(e).clamp(28, height),
                    child: _ApptCard(
                      item: e,
                      selected: selected?.id == e.id,
                      onTap: () => onSelect(selected?.id == e.id ? null : e),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HourGridPainter extends CustomPainter {
  _HourGridPainter({
    required this.startHour,
    required this.endHour,
    required this.pxPerMinute,
  });

  final int startHour;
  final int endHour;
  final double pxPerMinute;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (var h = startHour; h < endHour; h++) {
      final y = (h - startHour) * 60 * pxPerMinute;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
  }

  @override
  bool shouldRepaint(covariant _HourGridPainter oldDelegate) =>
      oldDelegate.startHour != startHour ||
      oldDelegate.endHour != endHour ||
      oldDelegate.pxPerMinute != pxPerMinute;
}

class _ApptCard extends StatelessWidget {
  const _ApptCard({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final RezervacijaCalendarItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final end = item.datumRezervacije.add(
      Duration(minutes: item.uslugaTrajanjeMinuta <= 0 ? 60 : item.uslugaTrajanjeMinuta),
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _CalUi.surfaceCard,
              border: Border.all(
                color: selected
                    ? _CalUi.accent.withValues(alpha: 0.95)
                    : _CalUi.border.withValues(alpha: 0.65),
                width: selected ? 2 : 1,
              ),
              boxShadow: item.isOtkazana
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_hm(item.datumRezervacije)} – ${_hm(end)}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.uslugaNaziv ?? 'Service',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.zaposlenikIme ?? 'Therapist',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.52),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: item.isOtkazana
                            ? Colors.redAccent.withValues(alpha: 0.7)
                            : _CalUi.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthOverview extends StatelessWidget {
  const _MonthOverview({
    required this.anchor,
    required this.itemsFuture,
    required this.onPickDay,
    required this.filterFn,
  });

  final DateTime anchor;
  final Future<List<RezervacijaCalendarItem>>? itemsFuture;
  final void Function(DateTime day) onPickDay;
  final List<RezervacijaCalendarItem> Function(List<RezervacijaCalendarItem>) filterFn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = DateTime(anchor.year, anchor.month);
    final daysInMonth = DateTime(anchor.year, anchor.month + 1, 0).day;
    final lead = first.weekday - 1;

    return FutureBuilder<List<RezervacijaCalendarItem>>(
      future: itemsFuture,
      builder: (context, snap) {
        final items = filterFn(snap.data ?? const []);
        final counts = <int, int>{};
        for (final e in items) {
          final d = e.datumRezervacije.toLocal().day;
          counts[d] = (counts[d] ?? 0) + 1;
        }
        final cells = lead + daysInMonth;
        final rows = (cells / 7).ceil();
        final totalCells = rows * 7;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  for (final w in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'])
                    Expanded(
                      child: Center(
                        child: Text(
                          w,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 1.1,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                  ),
                  itemCount: totalCells,
                  itemBuilder: (_, i) {
                    final dayNum = i - lead + 1;
                    if (i < lead || dayNum < 1 || dayNum > daysInMonth) {
                      return const SizedBox.shrink();
                    }
                    final c = counts[dayNum] ?? 0;
                    final day = DateTime(anchor.year, anchor.month, dayNum);
                    return InkWell(
                      onTap: () => onPickDay(day),
                      borderRadius: BorderRadius.circular(12),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white.withValues(alpha: c == 0 ? 0.03 : 0.07),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$dayNum',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (c > 0)
                              Text(
                                '$c appts',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: NuaLuxuryTokens.lavenderWhisper.withValues(alpha: 0.75),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RightRail extends StatelessWidget {
  const _RightRail({
    required this.selected,
    required this.itemsFuture,
    required this.filterFn,
    required this.summaryDay,
    required this.miniDisplayMonth,
    required this.weekStartMonday,
    required this.onPrevMiniMonth,
    required this.onNextMiniMonth,
    required this.onPickMiniDay,
    required this.onViewFullSchedule,
    required this.onNew,
  });

  final RezervacijaCalendarItem? selected;
  final Future<List<RezervacijaCalendarItem>>? itemsFuture;
  final List<RezervacijaCalendarItem> Function(List<RezervacijaCalendarItem>) filterFn;
  final DateTime summaryDay;
  final DateTime miniDisplayMonth;
  final DateTime weekStartMonday;
  final VoidCallback onPrevMiniMonth;
  final VoidCallback onNextMiniMonth;
  final ValueChanged<DateTime> onPickMiniDay;
  final VoidCallback onViewFullSchedule;
  final VoidCallback onNew;

  bool _inCurrentWeek(DateTime d) {
    for (var i = 0; i < 7; i++) {
      if (_sameDay(d, weekStartMonday.add(Duration(days: i)))) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.only(right: 2, bottom: 24),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _CalUi.surfaceCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _CalUi.border.withValues(alpha: 0.75)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: onPrevMiniMonth,
                    icon: Icon(Icons.chevron_left_rounded, color: Colors.white.withValues(alpha: 0.75)),
                  ),
                  Expanded(
                    child: Text(
                      '${_monthLong(miniDisplayMonth.month)} ${miniDisplayMonth.year}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: onNextMiniMonth,
                    icon: Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.75)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _MiniMonthGrid(
                month: miniDisplayMonth,
                summaryDay: summaryDay,
                weekStartMonday: weekStartMonday,
                inCurrentWeek: _inCurrentWeek,
                onPickDay: onPickMiniDay,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (selected != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _CalUi.surfaceCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _CalUi.accent.withValues(alpha: 0.45)),
            ),
            child: _DetailCard(item: selected!),
          ),
          const SizedBox(height: 14),
        ],
        Text(
          'Upcoming appointments',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: Colors.white.withValues(alpha: 0.92),
          ),
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<RezervacijaCalendarItem>>(
          future: itemsFuture,
          builder: (context, snap) {
            final list = filterFn(snap.data ?? const []);
            final dayItems = list.where((e) => _sameDay(e.datumRezervacije, summaryDay)).toList()
              ..sort((a, b) => a.datumRezervacije.compareTo(b.datumRezervacije));
            if (dayItems.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No appointments this day.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              );
            }
            return Column(
              children: [
                for (final e in dayItems.take(12))
                  _UpcomingRow(item: e),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: _CalUi.border),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: onViewFullSchedule,
          icon: const Icon(Icons.calendar_month_outlined, size: 20),
          label: const Text('View Full Schedule', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: onNew,
          icon: Icon(Icons.add_rounded, color: _CalUi.accent.withValues(alpha: 0.95)),
          label: Text(
            'Quick add',
            style: TextStyle(color: _CalUi.accent.withValues(alpha: 0.95), fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _MiniMonthGrid extends StatelessWidget {
  const _MiniMonthGrid({
    required this.month,
    required this.summaryDay,
    required this.weekStartMonday,
    required this.inCurrentWeek,
    required this.onPickDay,
  });

  final DateTime month;
  final DateTime summaryDay;
  final DateTime weekStartMonday;
  final bool Function(DateTime d) inCurrentWeek;
  final ValueChanged<DateTime> onPickDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final lead = first.weekday - 1;
    const wd = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Column(
      children: [
        Row(
          children: [
            for (final w in wd)
              Expanded(
                child: Center(
                  child: Text(
                    w,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.38),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var row = 0; row < 6; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(
                    child: _MiniDayCell(
                      index: row * 7 + col,
                      lead: lead,
                      daysInMonth: daysInMonth,
                      monthYear: month,
                      summaryDay: summaryDay,
                      inWeek: inCurrentWeek,
                      onPick: onPickDay,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MiniDayCell extends StatelessWidget {
  const _MiniDayCell({
    required this.index,
    required this.lead,
    required this.daysInMonth,
    required this.monthYear,
    required this.summaryDay,
    required this.inWeek,
    required this.onPick,
  });

  final int index;
  final int lead;
  final int daysInMonth;
  final DateTime monthYear;
  final DateTime summaryDay;
  final bool Function(DateTime d) inWeek;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dayNum = index - lead + 1;
    if (index < lead || dayNum < 1 || dayNum > daysInMonth) {
      return const SizedBox(height: 30);
    }
    final d = DateTime(monthYear.year, monthYear.month, dayNum);
    final isSummary = _sameDay(d, summaryDay);
    final isToday = _sameDay(d, DateTime.now());
    final weekTint = inWeek(d);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onPick(d),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: weekTint ? _CalUi.accent.withValues(alpha: 0.18) : Colors.transparent,
            border: Border.all(
              color: isSummary
                  ? _CalUi.accent
                  : (isToday ? Colors.white.withValues(alpha: 0.55) : Colors.transparent),
              width: isSummary || isToday ? 1.5 : 0,
            ),
          ),
          child: Text(
            '$dayNum',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: isSummary ? Colors.white : Colors.white.withValues(alpha: 0.82),
            ),
          ),
        ),
      ),
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({required this.item});
  final RezervacijaCalendarItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Text(
              _hm(item.datumRezervacije),
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: Colors.white.withValues(alpha: 0.88),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 8),
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: _CalUi.accent,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.uslugaNaziv ?? 'Service',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  item.zaposlenikIme ?? 'Therapist',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
                Text(
                  item.korisnikIme ?? 'Guest',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.42),
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

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.item});
  final RezervacijaCalendarItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = (item.korisnikIme ?? 'G').trim();
    final letter = initials.isNotEmpty ? initials[0].toUpperCase() : 'G';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.35),
              child: Text(letter, style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.korisnikIme ?? 'Guest',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (item.korisnikTelefon != null)
                    Text(
                      item.korisnikTelefon!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  if (item.korisnikEmail != null)
                    Text(
                      item.korisnikEmail!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _DetailLine(Icons.event_rounded, 'When', _hm(item.datumRezervacije)),
        _DetailLine(Icons.spa_rounded, 'Service', item.uslugaNaziv ?? '—'),
        _DetailLine(Icons.person_outline, 'Therapist', item.zaposlenikIme ?? '—'),
        _DetailLine(
          Icons.timer_outlined,
          'Duration',
          '${item.uslugaTrajanjeMinuta <= 0 ? 60 : item.uslugaTrajanjeMinuta} min',
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Tag(
              label: item.isPotvrdjena ? 'Confirmed' : 'Pending',
              color: NuaLuxuryTokens.softPurpleGlow,
            ),
            _Tag(
              label: item.isPlacena ? 'Paid' : 'Unpaid',
              color: item.isPlacena ? const Color(0xFF4ADE80) : Colors.white54,
            ),
            if (item.isOtkazana)
              const _Tag(label: 'Cancelled', color: Colors.redAccent),
          ],
        ),
      ],
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine(this.icon, this.k, this.v);
  final IconData icon;
  final String k;
  final String v;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.45)),
          const SizedBox(width: 8),
          SizedBox(
            width: 86,
            child: Text(
              k,
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: Colors.white.withValues(alpha: 0.92),
            ),
      ),
    );
  }
}
