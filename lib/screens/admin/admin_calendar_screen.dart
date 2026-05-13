import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/api/services/api_service.dart';
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
  /// Natural timeline scale (scroll vertically when viewport is shorter).
  static const double _pxPerMinute = 1.55;

  final ApiService _api = ApiService();

  DateTime _anchor = _dateOnly(DateTime.now());
  _CalViewMode _view = _CalViewMode.week;

  int? _filterZaposlenikId;
  int? _filterUslugaId;

  late final DesktopNav _nav;

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
    _nav = context.read<DesktopNav>();
    _nav.calendarSearchController.addListener(_onSearchChanged);
    _bootstrapLists();
    _reloadCalendar();
    _startTimer();
  }

  @override
  void dispose() {
    _nav.calendarSearchController.removeListener(_onSearchChanged);
    _searchDebounce?.cancel();
    _timer?.cancel();
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
    final qq = _nav.calendarSearchController.text.trim();
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
    });
    _reloadCalendar();
  }

  void _goToday() {
    setState(() {
      _anchor = _dateOnly(DateTime.now());
      _selected = null;
    });
    _reloadCalendar();
  }

  @override
  Widget build(BuildContext context) {
    final range = _visibleRange();
    final rangeLabel = _rangeCaption(_view, _anchor, range);

    return DecoratedBox(
      decoration: const BoxDecoration(color: _CalUi.bg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                                    dayColumnWidth: _view == _CalViewMode.day ? null : 148.0,
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

class _WeekTimeline extends StatefulWidget {
  const _WeekTimeline({
    required this.days,
    required this.itemsFuture,
    required this.filterFn,
    required this.selected,
    required this.onSelect,
    required this.startHour,
    required this.endHour,
    required this.pxPerMinute,
    /// Fixed width per day column (week view). When null and [days] has one entry, width fills viewport.
    this.dayColumnWidth,
  });

  final List<DateTime> days;
  final Future<List<RezervacijaCalendarItem>>? itemsFuture;
  final List<RezervacijaCalendarItem> Function(List<RezervacijaCalendarItem>) filterFn;
  final RezervacijaCalendarItem? selected;
  final ValueChanged<RezervacijaCalendarItem?> onSelect;
  final int startHour;
  final int endHour;
  final double pxPerMinute;
  final double? dayColumnWidth;

  @override
  State<_WeekTimeline> createState() => _WeekTimelineState();
}

class _WeekTimelineState extends State<_WeekTimeline> {
  final ScrollController _verticalCtrl = ScrollController();
  final ScrollController _horizontalCtrl = ScrollController();

  @override
  void dispose() {
    _verticalCtrl.dispose();
    _horizontalCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return FutureBuilder<List<RezervacijaCalendarItem>>(
      future: widget.itemsFuture,
      builder: (context, snap) {
        final raw = snap.data ?? const <RezervacijaCalendarItem>[];
        final items = widget.filterFn(raw);
        return LayoutBuilder(
          builder: (context, constraints) {
            const headerH = 40.0;
            final slotMinutes = (widget.endHour - widget.startHour) * 60.0;
            final effectivePx = widget.pxPerMinute;
            final totalH = slotMinutes * effectivePx;
            final contentH = headerH + totalH;
            const rulerW = 72.0;
            final n = widget.days.length;
            final minCol = widget.dayColumnWidth ?? 148.0;
            final viewportH = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : 480.0;
            final viewportW = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : (rulerW + n * minCol);

            final availDays = (viewportW - rulerW).clamp(0.0, double.infinity);
            final double colW;
            if (n == 1 && widget.dayColumnWidth == null) {
              colW = availDays < minCol ? minCol : availDays;
            } else {
              colW = minCol;
            }
            final contentW = rulerW + n * colW;

            return Listener(
              onPointerSignal: (signal) {
                if (signal is! PointerScrollEvent) return;
                if (!_horizontalCtrl.hasClients) return;
                final shift = HardwareKeyboard.instance.logicalKeysPressed
                    .contains(LogicalKeyboardKey.shiftLeft) ||
                    HardwareKeyboard.instance.logicalKeysPressed
                        .contains(LogicalKeyboardKey.shiftRight);
                if (!shift) return;
                final delta = signal.scrollDelta.dy;
                if (delta == 0) return;
                final p = _horizontalCtrl.position;
                final next = (p.pixels + delta)
                    .clamp(p.minScrollExtent, p.maxScrollExtent)
                    .toDouble();
                _horizontalCtrl.jumpTo(next);
              },
              child: SizedBox(
                height: viewportH,
                width: viewportW,
                child: Scrollbar(
                  controller: _horizontalCtrl,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _horizontalCtrl,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: contentW,
                      height: viewportH,
                      child: Scrollbar(
                        controller: _verticalCtrl,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _verticalCtrl,
                          scrollDirection: Axis.vertical,
                          child: SizedBox(
                            width: contentW,
                            height: contentH,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _TimeRuler(
                                  startHour: widget.startHour,
                                  endHour: widget.endHour,
                                  height: totalH,
                                  pxPerMinute: effectivePx,
                                ),
                                for (final day in widget.days)
                                  SizedBox(
                                    width: colW,
                                    child: _DayColumn(
                                      day: day,
                                      items: () {
                                        final d = items
                                            .where(
                                              (e) =>
                                                  _sameDay(e.datumRezervacije, day),
                                            )
                                            .toList();
                                        d.sort(
                                          (a, b) => a.datumRezervacije
                                              .compareTo(b.datumRezervacije),
                                        );
                                        return d;
                                      }(),
                                      height: totalH,
                                      startHour: widget.startHour,
                                      endHour: widget.endHour,
                                      pxPerMinute: effectivePx,
                                      now: now,
                                      selected: widget.selected,
                                      onSelect: widget.onSelect,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
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
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.52),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
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
                    left: 6,
                    right: 6,
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

enum _ApptCardVisualStatus { confirmed, pending, cancelled }

_ApptCardVisualStatus _apptCardVisualStatus(RezervacijaCalendarItem item) {
  if (item.isOtkazana) return _ApptCardVisualStatus.cancelled;
  if (!item.isPotvrdjena) return _ApptCardVisualStatus.pending;
  return _ApptCardVisualStatus.confirmed;
}

String _therapistFirstName(String? full) {
  final t = full?.trim();
  if (t == null || t.isEmpty) return 'Therapist';
  return t.split(RegExp(r'\s+')).first;
}

class _ApptCard extends StatefulWidget {
  const _ApptCard({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final RezervacijaCalendarItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_ApptCard> createState() => _ApptCardState();
}

class _ApptCardState extends State<_ApptCard> {
  bool _hover = false;

  static const double _radius = 15;

  TextStyle _txt(
    double size,
    FontWeight w,
    Color color, {
    double height = 1.2,
    double letterSpacing = 0,
  }) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: w,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  LinearGradient _statusGradient(_ApptCardVisualStatus s) {
    switch (s) {
      case _ApptCardVisualStatus.confirmed:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.fromRGBO(123, 77, 255, 0.28),
            Color.fromRGBO(91, 52, 186, 0.18),
          ],
        );
      case _ApptCardVisualStatus.pending:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.fromRGBO(245, 185, 66, 0.25),
            Color.fromRGBO(180, 120, 20, 0.18),
          ],
        );
      case _ApptCardVisualStatus.cancelled:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.fromRGBO(255, 94, 122, 0.25),
            Color.fromRGBO(180, 40, 60, 0.18),
          ],
        );
    }
  }

  Color _statusDotColor(_ApptCardVisualStatus s) {
    switch (s) {
      case _ApptCardVisualStatus.confirmed:
        return const Color(0xFFB388FF);
      case _ApptCardVisualStatus.pending:
        return const Color(0xFFF5B942);
      case _ApptCardVisualStatus.cancelled:
        return const Color(0xFFFF6B8A);
    }
  }

  List<BoxShadow> _outerShadows(_ApptCardVisualStatus status, bool vip) {
    final hover = _hover;
    final glow = switch (status) {
      _ApptCardVisualStatus.confirmed => const Color(0xFF7B4DFF),
      _ApptCardVisualStatus.pending => const Color(0xFFF5B942),
      _ApptCardVisualStatus.cancelled => const Color(0xFFFF5E7A),
    };

    final list = <BoxShadow>[
      if (vip)
        BoxShadow(
          color: const Color(0xFFD4AF7A).withValues(alpha: 0.35),
          blurRadius: 18,
          offset: Offset.zero,
        ),
      BoxShadow(
        color: glow.withValues(alpha: hover ? 0.28 : 0.18),
        offset: Offset(0, hover ? 12 : 8),
        blurRadius: hover ? 28 : 24,
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: hover ? 0.4 : 0.35),
        offset: Offset(0, hover ? 4 : 2),
        blurRadius: hover ? 12 : 6,
      ),
    ];
    return list;
  }

  List<BoxShadow> _innerGlow(_ApptCardVisualStatus status) {
    final c = switch (status) {
      _ApptCardVisualStatus.confirmed => const Color(0xFFB388FF),
      _ApptCardVisualStatus.pending => const Color(0xFFF5C96A),
      _ApptCardVisualStatus.cancelled => const Color(0xFFFF8A9B),
    };
    return [
      BoxShadow(
        color: c.withValues(alpha: 0.14),
        blurRadius: 20,
        spreadRadius: -10,
        offset: Offset.zero,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final status = _apptCardVisualStatus(item);
    final end = item.datumRezervacije.add(
      Duration(minutes: item.uslugaTrajanjeMinuta <= 0 ? 60 : item.uslugaTrajanjeMinuta),
    );
    final timeStr = '${_hm(item.datumRezervacije)} – ${_hm(end)}';
    final durationMin = item.uslugaTrajanjeMinuta <= 0 ? 60 : item.uslugaTrajanjeMinuta;
    final durationStr = '$durationMin min';
    final service = item.uslugaNaziv ?? 'Service';
    final client = item.korisnikIme ?? 'Guest';
    final therapist = _therapistFirstName(item.zaposlenikIme);
    final dotColor = _statusDotColor(status);

    final borderColor = widget.selected
        ? const Color(0xFFB388FF).withValues(alpha: 0.5)
        : const Color.fromRGBO(255, 255, 255, 0.06);
    final borderW = widget.selected ? 1.5 : 1.0;

    final dotShadow = status == _ApptCardVisualStatus.confirmed
        ? <BoxShadow>[
            BoxShadow(
              color: const Color(0xFFB388FF).withValues(alpha: 0.8),
              blurRadius: 8,
            ),
          ]
        : <BoxShadow>[
            BoxShadow(
              color: dotColor.withValues(alpha: 0.55),
              blurRadius: 6,
            ),
          ];

    Widget cardInterior(bool compact, double maxW, double maxH) {
      final topRow = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              timeStr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _txt(
                11,
                FontWeight.w500,
                Colors.white.withValues(alpha: 0.72),
                letterSpacing: 0.2,
              ),
            ),
          ),
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(left: 8, top: 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dotColor,
              boxShadow: dotShadow,
            ),
          ),
        ],
      );

      final serviceText = Text(
        service,
        maxLines: compact ? 1 : 2,
        overflow: TextOverflow.ellipsis,
        style: _txt(14, FontWeight.w600, const Color(0xFFF5F3FA), height: 1.2),
      );

      final clientText = Text(
        client,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _txt(12, FontWeight.w400, Colors.white.withValues(alpha: 0.75)),
      );

      final footer = Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              therapist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _txt(11, FontWeight.w500, const Color(0xFFC8B6E8)),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            durationStr,
            style: _txt(11, FontWeight.w500, Colors.white.withValues(alpha: 0.55)),
          ),
        ],
      );

      if (compact) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            topRow,
            const SizedBox(height: 4),
            serviceText,
            const SizedBox(height: 5),
            clientText,
            const SizedBox(height: 5),
            footer,
          ],
        );
      }

      return SizedBox(
        height: maxH,
        width: maxW,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            topRow,
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    serviceText,
                    const SizedBox(height: 5),
                    clientText,
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: footer,
            ),
          ],
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.ease,
          transform: Matrix4.translationValues(0, _hover ? -2.0 : 0.0, 0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.ease,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_radius),
              boxShadow: [
                ..._outerShadows(status, item.isVip),
                ..._innerGlow(status),
              ],
            ),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(_radius),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: _statusGradient(status),
                      borderRadius: BorderRadius.circular(_radius),
                      border: Border.all(color: borderColor, width: borderW),
                    ),
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final h = c.maxHeight;
                        final w = c.maxWidth;
                        final compact = h < 92;
                        if (compact) {
                          return Padding(
                            padding: const EdgeInsets.all(8),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.topLeft,
                              child: SizedBox(
                                width: w,
                                height: 84,
                                child: cardInterior(true, w, 84),
                              ),
                            ),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.all(12),
                          child: cardInterior(false, w, h - 24),
                        );
                      },
                    ),
                  ),
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
    required this.onViewFullSchedule,
    required this.onNew,
  });

  final RezervacijaCalendarItem? selected;
  final Future<List<RezervacijaCalendarItem>>? itemsFuture;
  final List<RezervacijaCalendarItem> Function(List<RezervacijaCalendarItem>) filterFn;
  final DateTime summaryDay;
  final VoidCallback onViewFullSchedule;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.only(right: 2, bottom: 24),
      children: [
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
