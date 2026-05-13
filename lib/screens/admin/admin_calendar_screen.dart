import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/api/services/api_service.dart';
import '../../models/admin/rezervacija_calendar_item.dart';
import '../../models/usluga.dart';
import '../../models/zaposlenik.dart';
import '../../providers/auth_provider.dart';
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
  /// Display day through 16:xx; grid ends at 17:00 (exclusive end hour).
  static const int _endHour = 17;

  final ApiService _api = ApiService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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

  Future<void> _onVipToggle(bool value) async {
    final sel = _selected;
    if (sel == null || sel.isOtkazana) return;
    final ok = await _api.patchRezervacijaVip(sel.id, value);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('VIP status nije spremljen.')),
      );
      return;
    }
    setState(() {
      _selected = sel.copyWith(isVip: value);
    });
    _reloadCalendar();
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
    final mq = MediaQuery.sizeOf(context);
    final screenW = mq.width;
    final screenH = mq.height;
    final showRightPanel = screenW >= 1250;
    final rightPanelW = screenW < 1450 ? 260.0 : 280.0;

    Widget calendarBody({required bool inDrawer}) {
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
                          compactHeight: screenH < 850,
                        ),
                        SizedBox(height: screenH < 850 ? 6 : 8),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, gridCons) {
                              final headerH =
                                  screenH < 850 ? 28.0 : 32.0;
                              final slotMin =
                                  (_endHour - _startHour) * 60.0;
                              final px = math.max(
                                0.42,
                                math.min(
                                  1.22,
                                  (gridCons.maxHeight - headerH) / slotMin,
                                ),
                              );
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: _CalUi.surface,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: _CalUi.border
                                          .withValues(alpha: 0.85),
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
                                          onSelect: (e) =>
                                              setState(() => _selected = e),
                                          startHour: _startHour,
                                          endHour: _endHour,
                                          pxPerMinute: px,
                                          dayHeaderHeight: headerH,
                                          rulerWidth: screenW < 1450 ? 52.0 : 56.0,
                                        ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!inDrawer && showRightPanel) ...[
                    SizedBox(width: screenW < 1450 ? 10 : 12),
                    SizedBox(
                      width: rightPanelW,
                      child: _CalendarSidePanel(
                        anchor: _anchor,
                        onMonthDelta: (d) {
                          setState(() => _anchor = d);
                          _reloadCalendar();
                        },
                        onPickMiniDay: (d) {
                          setState(() {
                            _anchor = _dateOnly(d);
                            _view = _CalViewMode.week;
                          });
                          _reloadCalendar();
                        },
                        selected: _selected,
                        itemsFuture: _calendarFuture,
                        filterFn: _calendarPassThrough,
                        summaryDay: _summaryDay(),
                        onViewFullSchedule: _goToday,
                        showVipToggle:
                            context.watch<AuthProvider>().isAdmin,
                        onVipToggle: context.watch<AuthProvider>().isAdmin
                            ? _onVipToggle
                            : null,
                        onNew: () {
                          context.read<DesktopNav>().requestAppointmentCreate(
                                zaposlenikId: _filterZaposlenikId,
                              );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    final drawerChild = _CalendarSidePanel(
      anchor: _anchor,
      onMonthDelta: (d) {
        setState(() => _anchor = d);
        _reloadCalendar();
      },
      onPickMiniDay: (d) {
        setState(() {
          _anchor = _dateOnly(d);
          _view = _CalViewMode.week;
        });
        _reloadCalendar();
      },
      selected: _selected,
      itemsFuture: _calendarFuture,
      filterFn: _calendarPassThrough,
      summaryDay: _summaryDay(),
      onViewFullSchedule: _goToday,
      showVipToggle: context.watch<AuthProvider>().isAdmin,
      onVipToggle:
          context.watch<AuthProvider>().isAdmin ? _onVipToggle : null,
      onNew: () {
        context.read<DesktopNav>().requestAppointmentCreate(
              zaposlenikId: _filterZaposlenikId,
            );
      },
      inDrawer: true,
    );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _CalUi.bg,
      endDrawer: showRightPanel
          ? null
          : Drawer(
              width: math.min(320, screenW * 0.92),
              backgroundColor: _CalUi.surface,
              child: SafeArea(
                child: drawerChild,
              ),
            ),
      floatingActionButton: showRightPanel
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 8, right: 4),
              child: FloatingActionButton.small(
                heroTag: 'cal_details',
                tooltip: 'Details',
                backgroundColor: _CalUi.accent,
                onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                child: const Icon(Icons.view_sidebar_outlined, size: 18),
              ),
            ),
      body: calendarBody(inDrawer: false),
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
    required this.compactHeight,
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
  final bool compactHeight;

  InputDecoration _dropDecoration(String hint, {bool micro = false}) =>
      InputDecoration(
        isDense: true,
        labelText: hint,
        labelStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.55),
          fontSize: micro ? 11 : 12,
        ),
        filled: true,
        fillColor: _CalUi.surface,
        contentPadding: EdgeInsets.symmetric(
          horizontal: micro ? 8 : 10,
          vertical: micro ? 6 : 8,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _CalUi.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _CalUi.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _CalUi.accent, width: 1.1),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final h = compactHeight ? 42.0 : 46.0;
    return Container(
      height: h,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _CalUi.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _CalUi.border.withValues(alpha: 0.75)),
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: onToday,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Today',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Previous',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: onPrev,
            icon: Icon(
              Icons.chevron_left_rounded,
              size: compactHeight ? 22 : 24,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                rangeLabel,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Next',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: onNext,
            icon: Icon(
              Icons.chevron_right_rounded,
              size: compactHeight ? 22 : 24,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          SegmentedButton<_CalViewMode>(
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              ),
              minimumSize: WidgetStateProperty.all(Size.zero),
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
              ButtonSegment(value: _CalViewMode.day, label: Text('D')),
              ButtonSegment(value: _CalViewMode.week, label: Text('W')),
              ButtonSegment(value: _CalViewMode.month, label: Text('M')),
            ],
            selected: {view},
            onSelectionChanged: (s) => onView(s.first),
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            padding: EdgeInsets.zero,
            icon: Icon(
              Icons.more_horiz_rounded,
              color: Colors.white.withValues(alpha: 0.65),
              size: 22,
            ),
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
          const SizedBox(width: 4),
          Expanded(
            flex: 3,
            child: SizedBox(
              height: h - 6,
              child: DropdownButtonFormField<int?>(
                value: filterZaposlenikId,
                isExpanded: true,
                isDense: true,
                dropdownColor: _CalUi.surfaceCard,
                style: const TextStyle(color: Colors.white, fontSize: 11.5),
                decoration: _dropDecoration('Therapist', micro: true),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('All therapists', overflow: TextOverflow.ellipsis),
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
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 3,
            child: SizedBox(
              height: h - 6,
              child: DropdownButtonFormField<int?>(
                value: filterUslugaId,
                isExpanded: true,
                isDense: true,
                dropdownColor: _CalUi.surfaceCard,
                style: const TextStyle(color: Colors.white, fontSize: 11.5),
                decoration: _dropDecoration('Service', micro: true),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('All services', overflow: TextOverflow.ellipsis),
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
          ),
          const SizedBox(width: 6),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _CalUi.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: onAddAppointment,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(
              'Add',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
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
    required this.dayHeaderHeight,
    required this.rulerWidth,
  });

  final List<DateTime> days;
  final Future<List<RezervacijaCalendarItem>>? itemsFuture;
  final List<RezervacijaCalendarItem> Function(List<RezervacijaCalendarItem>) filterFn;
  final RezervacijaCalendarItem? selected;
  final ValueChanged<RezervacijaCalendarItem?> onSelect;
  final int startHour;
  final int endHour;
  final double pxPerMinute;
  final double dayHeaderHeight;
  final double rulerWidth;

  @override
  State<_WeekTimeline> createState() => _WeekTimelineState();
}

class _WeekTimelineState extends State<_WeekTimeline> {
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
            final headerH = widget.dayHeaderHeight;
            final slotMinutes = (widget.endHour - widget.startHour) * 60.0;
            final effectivePx = widget.pxPerMinute;
            final totalH = slotMinutes * effectivePx;
            final rulerW = widget.rulerWidth;
            final viewportH = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : 480.0;
            final viewportW = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : (rulerW + 7 * 100.0);

            return SizedBox(
              height: viewportH,
              width: viewportW,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TimeRuler(
                    startHour: widget.startHour,
                    endHour: widget.endHour,
                    height: totalH,
                    pxPerMinute: effectivePx,
                    headerHeight: headerH,
                    width: rulerW,
                  ),
                  for (final day in widget.days)
                    Expanded(
                      child: _DayColumn(
                        day: day,
                        items: () {
                          final d = items
                              .where(
                                (e) => _sameDay(e.datumRezervacije, day),
                              )
                              .toList();
                          d.sort(
                            (a, b) => a.datumRezervacije
                                .compareTo(b.datumRezervacije),
                          );
                          return d;
                        }(),
                        height: totalH,
                        headerHeight: headerH,
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
    required this.headerHeight,
    required this.width,
  });

  final int startHour;
  final int endHour;
  final double height;
  final double pxPerMinute;
  final double headerHeight;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      height: height + headerHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(height: headerHeight),
          SizedBox(
            height: height,
            child: Stack(
              children: [
                for (var h = startHour; h < endHour; h++)
                  Positioned(
                    top: (h - startHour) * 60 * pxPerMinute,
                    left: 0,
                    right: 4,
                    child: Text(
                      '${h.toString().padLeft(2, '0')}:00',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w700,
                        fontSize: 10.5,
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
    required this.headerHeight,
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
  final double headerHeight;
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
          height: headerHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
            ),
            color: isToday ? _CalUi.accent.withValues(alpha: 0.08) : null,
          ),
          child: isToday
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _CalUi.accent, width: 1.5),
                    color: _CalUi.accent.withValues(alpha: 0.15),
                  ),
                  child: Text(
                    '${_weekdayShort(day)} ${day.day}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      color: Colors.white,
                    ),
                  ),
                )
              : Text(
                  '${_weekdayShort(day)} ${day.day}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
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

enum _ApptCardVisualStatus { confirmed, pending, cancelled, vip }

_ApptCardVisualStatus _apptCardVisualStatus(RezervacijaCalendarItem item) {
  if (item.isOtkazana) return _ApptCardVisualStatus.cancelled;
  if (item.isVip) return _ApptCardVisualStatus.vip;
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

  static const double _radius = 13;

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
      case _ApptCardVisualStatus.vip:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.fromRGBO(74, 222, 128, 0.22),
            Color.fromRGBO(22, 101, 52, 0.2),
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
      case _ApptCardVisualStatus.vip:
        return const Color(0xFF4ADE80);
    }
  }

  List<BoxShadow> _outerShadows(_ApptCardVisualStatus status, bool vip) {
    final hover = _hover;
    final glow = switch (status) {
      _ApptCardVisualStatus.confirmed => const Color(0xFF7B4DFF),
      _ApptCardVisualStatus.pending => const Color(0xFFF5B942),
      _ApptCardVisualStatus.cancelled => const Color(0xFFFF5E7A),
      _ApptCardVisualStatus.vip => const Color(0xFF22C55E),
    };

    final list = <BoxShadow>[
      if (vip && status != _ApptCardVisualStatus.vip)
        BoxShadow(
          color: const Color(0xFF4ADE80).withValues(alpha: 0.2),
          blurRadius: 10,
          offset: Offset.zero,
        ),
      BoxShadow(
        color: glow.withValues(alpha: hover ? 0.22 : 0.15),
        offset: Offset(0, hover ? 8 : 5),
        blurRadius: hover ? 18 : 14,
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: hover ? 0.35 : 0.3),
        offset: Offset(0, hover ? 3 : 2),
        blurRadius: hover ? 8 : 5,
      ),
    ];
    return list;
  }

  List<BoxShadow> _innerGlow(_ApptCardVisualStatus status) {
    final c = switch (status) {
      _ApptCardVisualStatus.confirmed => const Color(0xFFB388FF),
      _ApptCardVisualStatus.pending => const Color(0xFFF5C96A),
      _ApptCardVisualStatus.cancelled => const Color(0xFFFF8A9B),
      _ApptCardVisualStatus.vip => const Color(0xFF86EFAC),
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

    late final List<BoxShadow> dotShadow;
    if (status == _ApptCardVisualStatus.confirmed) {
      dotShadow = [
        BoxShadow(
          color: const Color(0xFFB388FF).withValues(alpha: 0.8),
          blurRadius: 8,
        ),
      ];
    } else if (status == _ApptCardVisualStatus.vip) {
      dotShadow = [
        BoxShadow(
          color: const Color(0xFF4ADE80).withValues(alpha: 0.75),
          blurRadius: 8,
        ),
      ];
    } else {
      dotShadow = [
        BoxShadow(
          color: dotColor.withValues(alpha: 0.55),
          blurRadius: 6,
        ),
      ];
    }

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
                10.5,
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
        style: _txt(12.5, FontWeight.w700, const Color(0xFFF5F3FA), height: 1.2),
      );

      final clientText = Text(
        client,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _txt(10.5, FontWeight.w400, Colors.white.withValues(alpha: 0.75)),
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
              style: _txt(10.5, FontWeight.w500, const Color(0xFFC8B6E8)),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            durationStr,
            style: _txt(10, FontWeight.w500, Colors.white.withValues(alpha: 0.55)),
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
                          padding: const EdgeInsets.all(9),
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
          padding: const EdgeInsets.all(10),
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
                    childAspectRatio: 1.28,
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

class _CalendarSidePanel extends StatelessWidget {
  const _CalendarSidePanel({
    required this.anchor,
    required this.onMonthDelta,
    required this.onPickMiniDay,
    required this.selected,
    required this.itemsFuture,
    required this.filterFn,
    required this.summaryDay,
    required this.onViewFullSchedule,
    required this.showVipToggle,
    this.onVipToggle,
    required this.onNew,
    this.inDrawer = false,
  });

  final DateTime anchor;
  final ValueChanged<DateTime> onMonthDelta;
  final ValueChanged<DateTime> onPickMiniDay;
  final RezervacijaCalendarItem? selected;
  final Future<List<RezervacijaCalendarItem>>? itemsFuture;
  final List<RezervacijaCalendarItem> Function(List<RezervacijaCalendarItem>) filterFn;
  final DateTime summaryDay;
  final VoidCallback onViewFullSchedule;
  final bool showVipToggle;
  final Future<void> Function(bool value)? onVipToggle;
  final VoidCallback onNew;
  final bool inDrawer;

  void _maybeCloseDrawer(BuildContext context) {
    if (inDrawer && Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pad = inDrawer ? 12.0 : 2.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(pad, pad, pad, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MiniMonthCalendar(
            anchor: anchor,
            summaryDay: summaryDay,
            onPrevMonth: () {
              final d = DateTime(anchor.year, anchor.month - 1, 1);
              onMonthDelta(d);
            },
            onNextMonth: () {
              final d = DateTime(anchor.year, anchor.month + 1, 1);
              onMonthDelta(d);
            },
            onSelectDay: (d) {
              onPickMiniDay(d);
              _maybeCloseDrawer(context);
            },
            itemsFuture: itemsFuture,
            filterFn: filterFn,
          ),
          const SizedBox(height: 8),
          _TodaySummary(
            itemsFuture: itemsFuture,
            filterFn: filterFn,
          ),
          if (selected != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _CalUi.surfaceCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _CalUi.accent.withValues(alpha: 0.4),
                ),
              ),
              child: _DetailCard(
                item: selected!,
                showVipToggle: showVipToggle,
                onVipToggle: onVipToggle,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Upcoming',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: FutureBuilder<List<RezervacijaCalendarItem>>(
              future: itemsFuture,
              builder: (context, snap) {
                final list = filterFn(snap.data ?? const []);
                final dayItems = list
                    .where((e) => _sameDay(e.datumRezervacije, summaryDay))
                    .toList()
                  ..sort(
                    (a, b) => a.datumRezervacije.compareTo(b.datumRezervacije),
                  );
                if (dayItems.isEmpty) {
                  return Text(
                    'No appointments this day.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  );
                }
                final show = dayItems.take(8).toList();
                return ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: show.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (_, i) => _UpcomingRow(item: show[i]),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: _CalUi.border),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: onViewFullSchedule,
                  child: Text(
                    'Today',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _CalUi.accent,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: onNew,
                  child: Text(
                    'New',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniMonthCalendar extends StatelessWidget {
  const _MiniMonthCalendar({
    required this.anchor,
    required this.summaryDay,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onSelectDay,
    required this.itemsFuture,
    required this.filterFn,
  });

  final DateTime anchor;
  final DateTime summaryDay;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onSelectDay;
  final Future<List<RezervacijaCalendarItem>>? itemsFuture;
  final List<RezervacijaCalendarItem> Function(List<RezervacijaCalendarItem>) filterFn;

  static const _mons = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = DateTime(anchor.year, anchor.month);
    final daysInMonth = DateTime(anchor.year, anchor.month + 1, 0).day;
    final lead = first.weekday - 1;
    final cells = lead + daysInMonth;
    final rows = (cells / 7).ceil();

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      decoration: BoxDecoration(
        color: _CalUi.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _CalUi.border.withValues(alpha: 0.65)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: onPrevMonth,
                icon: Icon(
                  Icons.chevron_left_rounded,
                  color: Colors.white.withValues(alpha: 0.75),
                  size: 20,
                ),
              ),
              Expanded(
                child: Text(
                  '${_mons[anchor.month - 1]} ${anchor.year}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: onNextMonth,
                icon: Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.75),
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final w in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                Expanded(
                  child: Center(
                    child: Text(
                      w,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.38),
                        fontWeight: FontWeight.w800,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          FutureBuilder<List<RezervacijaCalendarItem>>(
            future: itemsFuture,
            builder: (context, snap) {
              final items = filterFn(snap.data ?? const []);
              final counts = <int, int>{};
              for (final e in items) {
                final loc = e.datumRezervacije.toLocal();
                if (loc.year == anchor.year && loc.month == anchor.month) {
                  counts[loc.day] = (counts[loc.day] ?? 0) + 1;
                }
              }
              final totalCells = rows * 7;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: totalCells,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 2,
                  childAspectRatio: 1.15,
                ),
                itemBuilder: (_, i) {
                  final dayNum = i - lead + 1;
                  if (i < lead || dayNum < 1 || dayNum > daysInMonth) {
                    return const SizedBox.shrink();
                  }
                  final day = DateTime(anchor.year, anchor.month, dayNum);
                  final isSel = _sameDay(day, summaryDay);
                  final c = counts[dayNum] ?? 0;
                  return InkWell(
                    onTap: () => onSelectDay(day),
                    borderRadius: BorderRadius.circular(6),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: isSel
                            ? _CalUi.accent.withValues(alpha: 0.35)
                            : Colors.white.withValues(alpha: c > 0 ? 0.06 : 0.02),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$dayNum',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                          if (c > 0)
                            Container(
                              width: 4,
                              height: 4,
                              margin: const EdgeInsets.only(top: 2),
                              decoration: const BoxDecoration(
                                color: _CalUi.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TodaySummary extends StatelessWidget {
  const _TodaySummary({
    required this.itemsFuture,
    required this.filterFn,
  });

  final Future<List<RezervacijaCalendarItem>>? itemsFuture;
  final List<RezervacijaCalendarItem> Function(List<RezervacijaCalendarItem>) filterFn;

  @override
  Widget build(BuildContext context) {
    final today = _dateOnly(DateTime.now());
    return FutureBuilder<List<RezervacijaCalendarItem>>(
      future: itemsFuture,
      builder: (context, snap) {
        final list = filterFn(snap.data ?? const []);
        final todays = list
            .where((e) => _sameDay(e.datumRezervacije, today) && !e.isOtkazana)
            .toList();
        final vip = todays.where((e) => e.isVip).length;
        final pending = todays.where((e) => !e.isPotvrdjena).length;
        final confirmed = todays.where((e) => e.isPotvrdjena).length;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: _CalUi.surfaceCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _CalUi.border.withValues(alpha: 0.65)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _SummaryCell(
                  label: 'Today',
                  value: '${todays.length}',
                  sub: 'appts',
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: Colors.white.withValues(alpha: 0.08),
              ),
              Expanded(
                child: _SummaryCell(
                  label: 'Confirmed',
                  value: '$confirmed',
                  sub: null,
                ),
              ),
              Expanded(
                child: _SummaryCell(
                  label: 'Pending',
                  value: '$pending',
                  sub: null,
                ),
              ),
              Expanded(
                child: _SummaryCell(
                  label: 'VIP',
                  value: '$vip',
                  sub: null,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SummaryCell extends StatelessWidget {
  const _SummaryCell({
    required this.label,
    required this.value,
    this.sub,
  });

  final String label;
  final String value;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.45),
            fontWeight: FontWeight.w700,
            fontSize: 9,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        if (sub != null)
          Text(
            sub!,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 8,
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
      padding: const EdgeInsets.only(bottom: 6),
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
  const _DetailCard({
    required this.item,
    required this.showVipToggle,
    this.onVipToggle,
  });
  final RezervacijaCalendarItem item;
  final bool showVipToggle;
  final Future<void> Function(bool value)? onVipToggle;

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
              radius: 20,
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
                    style: theme.textTheme.titleSmall?.copyWith(
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
            if (item.isVip) const _Tag(label: 'VIP', color: Color(0xFFE8C547)),
          ],
        ),
        if (showVipToggle && !item.isOtkazana && onVipToggle != null) ...[
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'VIP termin',
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            value: item.isVip,
            onChanged: (v) => onVipToggle!(v),
          ),
        ],
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
