import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/services/api_service.dart';
import '../../models/admin/rezervacija_calendar_item.dart';
import '../../models/desktop_home_overview.dart';
import '../../models/usluga.dart';
import '../../models/zaposlenik.dart';
import '../../ui/navigation/desktop_nav.dart';
import '../../ui/theme/nua_luxury_tokens.dart';
import '../../ui/widgets/luxury/luxury_glass_panel.dart';

enum _CalViewMode { day, week, month }

enum _CalColumnAxis { therapists, rooms }

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

Color _serviceAccent(RezervacijaCalendarItem e) {
  final key = e.uslugaId > 0 ? e.uslugaId : (e.uslugaNaziv ?? '').hashCode;
  const palette = <Color>[
    Color(0xFF7B4DFF),
    Color(0xFF22C55E),
    Color(0xFFF59E0B),
    Color(0xFFB45309),
    Color(0xFF38BDF8),
    Color(0xFFEC4899),
  ];
  return palette[key.abs() % palette.length];
}

/// Admin calendar — week timeline mockup + postojeći filteri (terapeuti/prostorije, otkazani, auto-refresh, pretraga).
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
  _CalColumnAxis _axis = _CalColumnAxis.therapists;

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
  Future<DesktopHomeOverview?>? _overviewFuture;

  RezervacijaCalendarItem? _selected;

  @override
  void initState() {
    super.initState();
    _bootstrapLists();
    _searchCtrl.addListener(_onSearchChanged);
    _reloadCalendar();
    _reloadOverview();
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

  void _reloadOverview() {
    setState(() {
      _overviewFuture = _api.getDesktopHomeOverview(day: _summaryDay());
    });
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
    _reloadOverview();
  }

  void _goToday() {
    setState(() {
      _anchor = _dateOnly(DateTime.now());
      _selected = null;
    });
    _reloadCalendar();
    _reloadOverview();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final range = _visibleRange();
    const months = <String>[
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
    final caption = switch (_view) {
      _CalViewMode.day =>
        '${months[_anchor.month - 1]} ${_anchor.day}, ${_anchor.year}',
      _CalViewMode.week =>
        '${months[range.from.month - 1]} ${range.from.year} · week ${_mondayOf(_anchor).day}–${_mondayOf(_anchor).add(const Duration(days: 6)).day}',
      _CalViewMode.month => '${months[_anchor.month - 1]} ${_anchor.year}',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Calendar',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                  color: const Color(0xFFF5F3FA),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Manage appointments, therapist schedules and availability.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: NuaLuxuryTokens.lavenderWhisper.withValues(alpha: 0.72),
                ),
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
                child: LayoutBuilder(
                  builder: (context, lc) {
                    const bottomBlock = 56.0 + 12.0 + 12.0;
                    final head =
                        (lc.maxHeight - bottomBlock).clamp(0.0, double.infinity);
                    final maxToolbar = head <= 0
                        ? 0.0
                        : (head * 0.42).clamp(48.0, 280.0).clamp(0.0, head);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: maxToolbar),
                          child: SingleChildScrollView(
                            child: _Toolbar(
                              caption: caption,
                              view: _view,
                              onView: (v) {
                                setState(() => _view = v);
                                _reloadCalendar();
                                _reloadOverview();
                              },
                              axis: _axis,
                              onAxis: (a) => setState(() => _axis = a),
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
                              searchCtrl: _searchCtrl,
                              onPrev: () => _shiftPeriod(-1),
                              onNext: () => _shiftPeriod(1),
                              onToday: _goToday,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.08),
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
                                        _reloadOverview();
                                      },
                                      filterFn: _calendarPassThrough,
                                    )
                                  : _WeekTimeline(
                                      days: _headerDays(),
                                      axis: _axis,
                                      itemsFuture: _calendarFuture,
                                      filterFn: _calendarPassThrough,
                                      selected: _selected,
                                      onSelect: (e) =>
                                          setState(() => _selected = e),
                                      startHour: _startHour,
                                      endHour: _endHour,
                                      pxPerMinute: _pxPerMinute,
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _BottomBar(
                          onNew: () {
                            context.read<DesktopNav>().requestAppointmentCreate(
                                  zaposlenikId: _filterZaposlenikId,
                                );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(width: 18),
              SizedBox(
                width: 360,
                child: _RightRail(
                  selected: _selected,
                  overviewFuture: _overviewFuture,
                  itemsFuture: _calendarFuture,
                  filterFn: _calendarPassThrough,
                  day: _summaryDay(),
                  therapists: _therapists,
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
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.caption,
    required this.view,
    required this.onView,
    required this.axis,
    required this.onAxis,
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
    required this.searchCtrl,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });

  final String caption;
  final _CalViewMode view;
  final ValueChanged<_CalViewMode> onView;
  final _CalColumnAxis axis;
  final ValueChanged<_CalColumnAxis> onAxis;
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
  final TextEditingController searchCtrl;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LuxuryGlassPanel(
      borderRadius: 20,
      blurSigma: 22,
      opacity: 0.28,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton(
                onPressed: onPrev,
                icon: const Icon(Icons.chevron_left_rounded),
                color: Colors.white.withValues(alpha: 0.85),
              ),
              Text(
                caption,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              IconButton(
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right_rounded),
                color: Colors.white.withValues(alpha: 0.85),
              ),
              TextButton(
                onPressed: onToday,
                child: const Text('Today'),
              ),
              const SizedBox(width: 8),
              SegmentedButton<_CalViewMode>(
                segments: const [
                  ButtonSegment(value: _CalViewMode.day, label: Text('Day')),
                  ButtonSegment(value: _CalViewMode.week, label: Text('Week')),
                  ButtonSegment(value: _CalViewMode.month, label: Text('Month')),
                ],
                selected: {view},
                onSelectionChanged: (s) => onView(s.first),
              ),
              const SizedBox(width: 8),
              SegmentedButton<_CalColumnAxis>(
                segments: const [
                  ButtonSegment(
                    value: _CalColumnAxis.therapists,
                    label: Text('Therapists'),
                    icon: Icon(Icons.groups_2_outlined, size: 18),
                  ),
                  ButtonSegment(
                    value: _CalColumnAxis.rooms,
                    label: Text('Rooms'),
                    icon: Icon(Icons.meeting_room_outlined, size: 18),
                  ),
                ],
                selected: {axis},
                onSelectionChanged: (s) => onAxis(s.first),
              ),
              FilterChip(
                label: const Text('Include cancelled'),
                selected: includeCancelled,
                onSelected: onToggleCancelled,
              ),
              FilterChip(
                label: const Text('Auto refresh (20s)'),
                selected: autoRefresh,
                onSelected: onToggleAuto,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 180, maxWidth: 240),
                child: DropdownButtonFormField<int?>(
                  value: filterZaposlenikId,
                  decoration: _dropDecoration('All therapists'),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('All therapists'),
                    ),
                    ...therapists.map(
                      (t) => DropdownMenuItem(
                        value: t.id,
                        child: Text('${t.ime} ${t.prezime}'.trim()),
                      ),
                    ),
                  ],
                  onChanged: onTherapist,
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 180, maxWidth: 260),
                child: DropdownButtonFormField<int?>(
                  value: filterUslugaId,
                  decoration: _dropDecoration('All services'),
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
              SizedBox(
                width: 260,
                child: TextField(
                  controller: searchCtrl,
                  style: theme.textTheme.bodyMedium,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search appointments…',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
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

  InputDecoration _dropDecoration(String hint) => InputDecoration(
        isDense: true,
        labelText: hint,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      );
}

class _WeekTimeline extends StatelessWidget {
  const _WeekTimeline({
    required this.days,
    required this.axis,
    required this.itemsFuture,
    required this.filterFn,
    required this.selected,
    required this.onSelect,
    required this.startHour,
    required this.endHour,
    required this.pxPerMinute,
  });

  final List<DateTime> days;
  final _CalColumnAxis axis;
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
            final bodyCap = maxBody.clamp(32.0, double.infinity);
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
                          axis: axis,
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
    required this.axis,
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
  final _CalColumnAxis axis;
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
            color: isToday
                ? NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.12)
                : null,
          ),
          child: Text(
            '${_weekdayShort(day)} ${day.day}',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: isToday
                  ? NuaLuxuryTokens.softPurpleGlow
                  : Colors.white.withValues(alpha: 0.88),
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
                      color: Colors.redAccent.withValues(alpha: 0.85),
                    ),
                  ),
                for (final e in items)
                  Positioned(
                    left: 4,
                    right: 4,
                    top: topFor(e).clamp(0, height - 24),
                    height: hFor(e).clamp(28, height),
                    child: _ApptCard(
                      axis: axis,
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
    required this.axis,
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _CalColumnAxis axis;
  final RezervacijaCalendarItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _serviceAccent(item);
    final end = item.datumRezervacije.add(
      Duration(minutes: item.uslugaTrajanjeMinuta <= 0 ? 60 : item.uslugaTrajanjeMinuta),
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: accent.withValues(alpha: item.isOtkazana ? 0.12 : 0.32),
            border: Border.all(
              color: selected
                  ? NuaLuxuryTokens.champagneGold.withValues(alpha: 0.95)
                  : Colors.white.withValues(alpha: 0.12),
              width: selected ? 2 : 1,
            ),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_hm(item.datumRezervacije)}–${_hm(end)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  Text(
                    item.uslugaNaziv ?? 'Service',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    item.korisnikIme ?? 'Client',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
                  Text(
                    () {
                      final a = axis == _CalColumnAxis.rooms
                          ? (item.prostorijaNaziv ?? 'Room TBD')
                          : (item.zaposlenikIme ?? 'Therapist');
                      final b = axis == _CalColumnAxis.rooms
                          ? (item.zaposlenikIme ?? '')
                          : (item.prostorijaNaziv ?? '');
                      final bb = b.trim();
                      return bb.isEmpty ? a : '$a · $b';
                    }(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.48),
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    '${item.uslugaTrajanjeMinuta <= 0 ? 60 : item.uslugaTrajanjeMinuta} min',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              if (item.isOtkazana)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Icon(
                    Icons.cancel_rounded,
                    size: 18,
                    color: Colors.redAccent.withValues(alpha: 0.9),
                  ),
                ),
            ],
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
    required this.overviewFuture,
    required this.itemsFuture,
    required this.filterFn,
    required this.day,
    required this.therapists,
    required this.onNew,
  });

  final RezervacijaCalendarItem? selected;
  final Future<DesktopHomeOverview?>? overviewFuture;
  final Future<List<RezervacijaCalendarItem>>? itemsFuture;
  final List<RezervacijaCalendarItem> Function(List<RezervacijaCalendarItem>) filterFn;
  final DateTime day;
  final List<Zaposlenik> therapists;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.only(right: 4, bottom: 28),
      children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: NuaLuxuryTokens.softPurpleGlow,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: onNew,
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'New Appointment',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(height: 16),
        if (selected != null) ...[
          LuxuryGlassPanel(
            borderRadius: 20,
            blurSigma: 22,
            opacity: 0.3,
            padding: const EdgeInsets.all(16),
            child: _DetailCard(item: selected!),
          ),
          const SizedBox(height: 14),
        ],
        LuxuryGlassPanel(
          borderRadius: 20,
          blurSigma: 22,
          opacity: 0.28,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _sameDay(day, DateTime.now()) ? 'Today summary' : 'Day summary',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (!_sameDay(day, DateTime.now()))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              FutureBuilder<List<RezervacijaCalendarItem>>(
                future: itemsFuture,
                builder: (context, snap) {
                  final list = filterFn(snap.data ?? const []);
                  final dayItems = list.where((e) => _sameDay(e.datumRezervacije, day)).toList();
                  final revenue = dayItems
                      .where((e) => e.isPlacena && !e.isOtkazana)
                      .fold<double>(0, (s, e) => s + e.uslugaCijena);
                  final therapistsBusy = dayItems.map((e) => e.zaposlenikId).toSet().length;
                  final total = dayItems.where((e) => !e.isOtkazana).length;
                  final minutes = dayItems
                      .where((e) => !e.isOtkazana)
                      .fold<int>(0, (s, e) => s + (e.uslugaTrajanjeMinuta <= 0 ? 60 : e.uslugaTrajanjeMinuta));
                  final cap = (therapists.isEmpty ? 1 : therapists.length) * 8 * 60;
                  final occ = cap <= 0 ? 0.0 : (minutes / cap * 100).clamp(0, 100);

                  return FutureBuilder<DesktopHomeOverview?>(
                    future: overviewFuture,
                    builder: (context, oSnap) {
                      final ov = oSnap.data;
                      return Column(
                        children: [
                          _StatRow('Total appointments', '$total'),
                          _StatRow('Therapists booked', '$therapistsBusy'),
                          _StatRow(
                            'Revenue (paid, est.)',
                            '${revenue.toStringAsFixed(0)} ${ov?.valuta ?? 'KM'}',
                          ),
                          _StatRow('Occupancy (heuristic)', '${occ.toStringAsFixed(0)}%'),
                          if (ov != null && ov.noviKlijentiZadnjih7Dana != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Portal: ${ov.noviKlijentiZadnjih7Dana} new clients (7d)',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.45),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        LuxuryGlassPanel(
          borderRadius: 20,
          blurSigma: 22,
          opacity: 0.28,
          padding: const EdgeInsets.all(16),
          child: _TherapistAvailability(
            therapists: therapists,
            itemsFuture: itemsFuture,
            filterFn: filterFn,
            day: day,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow(this.k, this.v);
  final String k;
  final String v;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              k,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ),
          Text(
            v,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w900,
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
        _DetailLine(Icons.meeting_room_outlined, 'Room', item.prostorijaNaziv ?? '—'),
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

class _TherapistAvailability extends StatelessWidget {
  const _TherapistAvailability({
    required this.therapists,
    required this.itemsFuture,
    required this.filterFn,
    required this.day,
  });

  final List<Zaposlenik> therapists;
  final Future<List<RezervacijaCalendarItem>>? itemsFuture;
  final List<RezervacijaCalendarItem> Function(List<RezervacijaCalendarItem>) filterFn;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Therapist availability',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<RezervacijaCalendarItem>>(
          future: itemsFuture,
          builder: (context, snap) {
            final list = filterFn(snap.data ?? const []);
            final today = _sameDay(day, now);
            return Column(
              children: [
                for (final t in therapists.take(12))
                  _TherapistRow(
                    name: '${t.ime} ${t.prezime}'.trim(),
                    status: _statusFor(t.id, list, now, today),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  String _statusFor(
    int tid,
    List<RezervacijaCalendarItem> list,
    DateTime now,
    bool today,
  ) {
    final dayList = list.where((e) => e.zaposlenikId == tid && _sameDay(e.datumRezervacije, day)).toList();
    if (dayList.isEmpty) return 'off';
    if (!today) return 'booked';
    final nm = now.hour * 60 + now.minute;
    for (final e in dayList.where((e) => !e.isOtkazana)) {
      final s = e.datumRezervacije.toLocal();
      final start = s.hour * 60 + s.minute;
      final dur = e.uslugaTrajanjeMinuta <= 0 ? 60 : e.uslugaTrajanjeMinuta;
      if (nm >= start && nm < start + dur) return 'busy';
    }
    return 'available';
  }
}

class _TherapistRow extends StatelessWidget {
  const _TherapistRow({required this.name, required this.status});
  final String name;
  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color dot;
    String label;
    switch (status) {
      case 'busy':
        dot = const Color(0xFFFBBF24);
        label = 'Busy';
      case 'booked':
        dot = NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.75);
        label = 'Scheduled';
      case 'available':
        dot = const Color(0xFF4ADE80);
        label = 'Available';
      default:
        dot = Colors.white.withValues(alpha: 0.25);
        label = 'Off / no bookings';
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.25),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.onNew});
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Center(
            child: FilledButton.tonalIcon(
              onPressed: onNew,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add appointment'),
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Export schedule — uskoro.')),
            );
          },
          icon: const Icon(Icons.ios_share_outlined, size: 18),
          label: const Text('Export'),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Print calendar — uskoro.')),
            );
          },
          icon: const Icon(Icons.print_outlined, size: 18),
          label: const Text('Print'),
        ),
      ],
    );
  }
}
