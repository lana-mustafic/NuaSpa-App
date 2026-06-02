import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/api/services/api_service.dart';
import '../../models/admin/radno_vrijeme.dart';
import '../../models/admin/rezervacija_calendar_item.dart';
import '../../models/usluga.dart';
import '../../models/zaposlenik.dart';
import '../../providers/auth_provider.dart';
import '../../ui/navigation/desktop_nav.dart';
import '../../ui/theme/nua_luxury_tokens.dart';
import '../../ui/widgets/luxury/luxury_desktop_header.dart';

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

String _hm(DateTime d) {
  final l = d.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

String _weekdayShort(DateTime d) {
  const n = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return n[(d.weekday - 1).clamp(0, 6)];
}

/// Admin calendar — NuaSpa dark luxury palette.
abstract final class _CalUi {
  static const Color accent = Color(0xFF7B4DFF);
  static const Color accent2 = Color(0xFF9B7BFF);
  static const Color lavender = Color(0xFFC8B6E8);
  static const Color textPrimary = Color(0xFFF5F3FA);

  static Color get border => Colors.white.withValues(alpha: 0.08);
  static Color get glassFill => Colors.white.withValues(alpha: 0.04);
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

int _durationMinutes(RezervacijaCalendarItem e) =>
    e.uslugaTrajanjeMinuta <= 0 ? 60 : e.uslugaTrajanjeMinuta;

double _minutesOfDay(DateTime d) {
  final l = d.toLocal();
  return l.hour * 60.0 + l.minute + l.second / 60.0;
}

({int startHour, int endHour}) _resolveGridHours(
  List<DateTime> days,
  List<RadnoVrijeme> hours,
) {
  const fallbackStart = 8;
  const fallbackEnd = 17;
  if (hours.isEmpty) {
    return (startHour: fallbackStart, endHour: fallbackEnd);
  }
  var minOpen = 24 * 60;
  var maxClose = 0;
  var anyOpen = false;
  for (final day in days) {
    RadnoVrijeme? rv;
    for (final h in hours) {
      if (h.danUSedmici == day.weekday) {
        rv = h;
        break;
      }
    }
    if (rv == null || rv.isClosed) continue;
    anyOpen = true;
    final open = rv.otvaraMin ?? fallbackStart * 60;
    final close = rv.zatvaraMin ?? fallbackEnd * 60;
    if (open < minOpen) minOpen = open;
    if (close > maxClose) maxClose = close;
  }
  if (!anyOpen || minOpen >= maxClose) {
    return (startHour: fallbackStart, endHour: fallbackEnd);
  }
  return (startHour: minOpen ~/ 60, endHour: (maxClose + 59) ~/ 60);
}

class _LanePlacement {
  const _LanePlacement({
    required this.item,
    required this.lane,
    required this.laneCount,
  });

  final RezervacijaCalendarItem item;
  final int lane;
  final int laneCount;
}

List<_LanePlacement> _assignDayLanes(List<RezervacijaCalendarItem> items) {
  if (items.isEmpty) return const [];
  final sorted = [...items]
    ..sort((a, b) => a.datumRezervacije.compareTo(b.datumRezervacije));
  final lanes = <List<RezervacijaCalendarItem>>[];

  bool overlaps(RezervacijaCalendarItem a, RezervacijaCalendarItem b) {
    final aStart = _minutesOfDay(a.datumRezervacije);
    final aEnd = aStart + _durationMinutes(a);
    final bStart = _minutesOfDay(b.datumRezervacije);
    final bEnd = bStart + _durationMinutes(b);
    return aStart < bEnd && bStart < aEnd;
  }

  final laneOf = <int, int>{};
  for (final e in sorted) {
    var laneIndex = 0;
    while (true) {
      if (laneIndex >= lanes.length) {
        lanes.add([e]);
        laneOf[e.id] = laneIndex;
        break;
      }
      final conflict = lanes[laneIndex].any((o) => overlaps(o, e));
      if (!conflict) {
        lanes[laneIndex].add(e);
        laneOf[e.id] = laneIndex;
        break;
      }
      laneIndex++;
    }
  }

  final laneCount = lanes.length;
  return [
    for (final e in sorted)
      _LanePlacement(
        item: e,
        lane: laneOf[e.id] ?? 0,
        laneCount: laneCount,
      ),
  ];
}

String _calendarStatusLabel(RezervacijaCalendarItem item) {
  if (item.isOtkazana || item.status == 'Cancelled') return 'Cancelled';
  if (item.isCompleted || item.status == 'Completed') return 'Completed';
  if (item.isPotvrdjena || item.status == 'Confirmed') return 'Confirmed';
  return 'Pending';
}

String _calendarNotesText(RezervacijaCalendarItem item) {
  final note = item.napomenaZaTerapeuta?.trim();
  if (note != null && note.isNotEmpty) return note;
  if (item.isOtkazana) {
    final reason = item.razlogOtkaza?.trim();
    if (reason != null && reason.isNotEmpty) {
      return 'Cancellation reason: $reason';
    }
  }
  return 'No notes on file.';
}

Color _statusTagColor(RezervacijaCalendarItem item) {
  switch (_calendarStatusLabel(item)) {
    case 'Completed':
      return const Color(0xFF60A5FA);
    case 'Cancelled':
      return Colors.redAccent;
    case 'Pending':
      return const Color(0xFFF5B942);
    default:
      return NuaLuxuryTokens.softPurpleGlow;
  }
}

/// Admin calendar — week timeline, filters, search, auto-refresh.
class AdminCalendarScreen extends StatefulWidget {
  const AdminCalendarScreen({super.key});

  @override
  State<AdminCalendarScreen> createState() => _AdminCalendarScreenState();
}

class _AdminCalendarScreenState extends State<AdminCalendarScreen> {
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
  List<RadnoVrijeme> _radnoVrijeme = [];

  List<RezervacijaCalendarItem> _items = const [];
  bool _loading = true;
  String? _loadError;
  int _loadSeq = 0;

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
    final results = await Future.wait([
      _api.getZaposlenici(),
      _api.getUsluge(),
      _api.getRadnoVrijeme(),
    ]);
    if (!mounted) return;
    setState(() {
      _therapists = results[0] as List<Zaposlenik>;
      _usluge = results[1] as List<Usluga>;
      _radnoVrijeme = results[2] as List<RadnoVrijeme>;
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
        return (from: d, to: d);
      case _CalViewMode.week:
        final m = _mondayOf(_anchor);
        return (from: m, to: m.add(const Duration(days: 6)));
      case _CalViewMode.month:
        final first = DateTime(_anchor.year, _anchor.month, 1);
        final last = DateTime(_anchor.year, _anchor.month + 1, 0);
        return (from: first, to: last);
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
        return const [];
    }
  }

  Future<void> _reloadCalendar() async {
    final seq = ++_loadSeq;
    final r = _visibleRange();
    final qq = _nav.calendarSearchController.text.trim();
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    final result = await _api.getRezervacijeCalendar(
      from: r.from,
      to: r.to,
      zaposlenikId: _filterZaposlenikId,
      uslugaId: _filterUslugaId,
      q: qq.isEmpty ? null : qq,
      includeOtkazane: _includeCancelled,
    );
    if (!mounted || seq != _loadSeq) return;
    setState(() {
      _loading = false;
      _items = result.items;
      _loadError = result.error;
    });
  }

  Future<void> _onVipToggle(bool value) async {
    final sel = _selected;
    if (sel == null || sel.isOtkazana || sel.isCompleted) return;
    final ok = await _api.patchRezervacijaVip(sel.id, value);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save VIP status.')),
      );
      return;
    }
    final updated = sel.copyWith(isVip: value);
    setState(() {
      _selected = updated;
      _items = [
        for (final e in _items)
          if (e.id == updated.id) updated else e,
      ];
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
  }

  void _goToday() {
    setState(() {
      _anchor = _dateOnly(DateTime.now());
      _selected = null;
    });
    _reloadCalendar();
  }

  void _openAppointmentDetails(RezervacijaCalendarItem item) {
    setState(() => _selected = item);
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (dialogContext) => _CalendarAppointmentDetailsModal(
        initialItem: item,
        showVipToggle: context.read<AuthProvider>().isAdmin,
        onVipToggle: context.read<AuthProvider>().isAdmin
            ? (value) async {
                await _onVipToggle(value);
                return _selected ?? item;
              }
            : null,
        onEdit: () {
          Navigator.pop(dialogContext);
          _nav.requestAppointmentEdit(item.id);
        },
      ),
    ).then((_) {
      if (mounted) setState(() => _selected = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final range = _visibleRange();
    final rangeLabel = _rangeCaption(_view, _anchor, range);
    final mq = MediaQuery.sizeOf(context);
    final screenW = mq.width;
    final screenH = mq.height;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF07040F), Color(0xFF120A24)],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          LuxuryPageChrome.bodyPadding.left,
          LuxuryPageChrome.bodyPadding.top,
          LuxuryPageChrome.bodyPadding.right,
          LuxuryPageChrome.bodyPadding.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CalendarToolbar(
              rangeLabel: rangeLabel,
              view: _view,
              onView: (v) {
                setState(() => _view = v);
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
            _TodayScheduleStrip(items: _items),
            const SizedBox(height: 14),
            Expanded(
              child: LayoutBuilder(
                builder: (context, gridCons) {
                  if (_loading && _items.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  }
                  if (_loadError != null && _items.isEmpty) {
                    return _CalendarErrorState(
                      message: _loadError!,
                      onRetry: _reloadCalendar,
                    );
                  }
                  final days = _headerDays();
                  final gridHours = _view == _CalViewMode.month
                      ? (startHour: 8, endHour: 17)
                      : _resolveGridHours(days, _radnoVrijeme);
                  final headerH = screenH < 850 ? 36.0 : 40.0;
                  final slotMin =
                      (gridHours.endHour - gridHours.startHour) * 60.0;
                  final px = math.max(
                    0.55,
                    math.min(
                      1.35,
                      (gridCons.maxHeight - headerH) / slotMin,
                    ),
                  );
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: _CalUi.glassFill,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _CalUi.border),
                      ),
                      child: _view == _CalViewMode.month
                          ? _MonthOverview(
                              anchor: _anchor,
                              items: _items,
                              loading: _loading,
                              onPickDay: (d) {
                                setState(() {
                                  _anchor = d;
                                  _view = _CalViewMode.week;
                                });
                                _reloadCalendar();
                              },
                            )
                          : _WeekTimeline(
                              days: days,
                              items: _items,
                              loading: _loading,
                              loadError: _loadError,
                              selected: _selected,
                              onSelect: (e) {
                                if (e != null) _openAppointmentDetails(e);
                              },
                              startHour: gridHours.startHour,
                              endHour: gridHours.endHour,
                              pxPerMinute: px,
                              dayHeaderHeight: headerH,
                              rulerWidth: screenW < 1200 ? 56.0 : 60.0,
                              viewMode: _view,
                            ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarToolbar extends StatelessWidget {
  const _CalendarToolbar({
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

  static const _gap = 14.0;

  InputDecoration _dropDecoration(String hint) => InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.45),
          fontSize: 13,
        ),
        filled: true,
        fillColor: _CalUi.glassFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _CalUi.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _CalUi.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _CalUi.accent.withValues(alpha: 0.75)),
        ),
      );

  Widget _navIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return _CalGlassIconButton(
      tooltip: tooltip,
      icon: icon,
      onPressed: onPressed,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _CalUi.glassFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _CalUi.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
        children: [
          _navIconButton(
            icon: Icons.chevron_left_rounded,
            tooltip: 'Previous',
            onPressed: onPrev,
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onToday,
            style: TextButton.styleFrom(
              foregroundColor: _CalUi.textPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: _CalUi.border),
              ),
            ),
            child: const Text(
              'Today',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          _navIconButton(
            icon: Icons.chevron_right_rounded,
            tooltip: 'Next',
            onPressed: onNext,
          ),
          const SizedBox(width: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 160, maxWidth: 280),
            child: Text(
              rangeLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _CalUi.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: _gap),
          SegmentedButton<_CalViewMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: _CalViewMode.day, label: Text('Day')),
              ButtonSegment(value: _CalViewMode.week, label: Text('Week')),
              ButtonSegment(value: _CalViewMode.month, label: Text('Month')),
            ],
            selected: {view},
            onSelectionChanged: (s) => onView(s.first),
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              foregroundColor: WidgetStateProperty.resolveWith((s) {
                return s.contains(WidgetState.selected)
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.65);
              }),
              backgroundColor: WidgetStateProperty.resolveWith((s) {
                return s.contains(WidgetState.selected)
                    ? _CalUi.accent
                    : Colors.white.withValues(alpha: 0.04);
              }),
              side: WidgetStateProperty.all(BorderSide(color: _CalUi.border)),
            ),
          ),
          const SizedBox(width: _gap),
          SizedBox(
            width: 168,
            child: DropdownButtonFormField<int?>(
              value: filterZaposlenikId,
              isExpanded: true,
              dropdownColor: const Color(0xFF1A1228),
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
                    child: Text('${t.ime} ${t.prezime}'.trim()),
                  ),
                ),
              ],
              onChanged: onTherapist,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 168,
            child: DropdownButtonFormField<int?>(
              value: filterUslugaId,
              isExpanded: true,
              dropdownColor: const Color(0xFF1A1228),
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
          const SizedBox(width: 10),
          FilterChip(
            label: Text(
              includeCancelled ? 'Cancelled on' : 'Cancelled',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            selected: includeCancelled,
            onSelected: onToggleCancelled,
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
            selectedColor: _CalUi.accent.withValues(alpha: 0.28),
            backgroundColor: Colors.white.withValues(alpha: 0.04),
            side: BorderSide(color: _CalUi.border),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: onAddAppointment,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Appointment'),
            style: FilledButton.styleFrom(
              backgroundColor: _CalUi.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            tooltip: 'More options',
            color: const Color(0xFF1A1228),
            icon: Icon(
              Icons.more_horiz_rounded,
              color: Colors.white.withValues(alpha: 0.72),
            ),
            onSelected: (id) {
              if (id == 'a') onToggleAuto(!autoRefresh);
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'a',
                child: Text(
                  autoRefresh
                      ? 'Auto refresh (on)'
                      : 'Auto refresh (20s)',
                ),
              ),
            ],
          ),
        ],
        ),
      ),
    );
  }
}

class _CalGlassIconButton extends StatelessWidget {
  const _CalGlassIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _CalUi.border),
            ),
            child: Icon(icon, color: Colors.white.withValues(alpha: 0.88), size: 22),
          ),
        ),
      ),
    );
  }
}

class _TodayScheduleStrip extends StatelessWidget {
  const _TodayScheduleStrip({required this.items});

  final List<RezervacijaCalendarItem> items;

  @override
  Widget build(BuildContext context) {
    final today = _dateOnly(DateTime.now());
    final todays = items
        .where((e) => _sameDay(e.datumRezervacije, today) && !e.isOtkazana)
        .toList()
      ..sort((a, b) => a.datumRezervacije.compareTo(b.datumRezervacije));

    final now = DateTime.now();
    final upcoming =
        todays.where((e) => !e.datumRezervacije.isBefore(now)).toList();
    final next = upcoming.isNotEmpty ? upcoming.first : null;

    String detail;
    if (todays.isEmpty) {
      detail = 'No appointments scheduled for today.';
    } else if (next != null) {
      final service = next.uslugaNaziv ?? 'Appointment';
      final client = next.korisnikIme?.trim();
      final clientPart =
          client != null && client.isNotEmpty ? ' · $client' : '';
      detail =
          "${todays.length} appointment${todays.length == 1 ? '' : 's'} • Next: ${_hm(next.datumRezervacije)} $service$clientPart";
    } else {
      detail =
          "${todays.length} appointment${todays.length == 1 ? '' : 's'} today (all completed)";
    }

    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: _CalUi.glassFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _CalUi.border),
      ),
      child: Row(
        children: [
          Icon(
            Icons.today_rounded,
            size: 20,
            color: _CalUi.accent2.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 12),
          Text(
            "Today's Schedule:",
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _CalUi.lavender.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _CalUi.textPrimary.withValues(alpha: 0.88),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarErrorState extends StatelessWidget {
  const _CalendarErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
        decoration: BoxDecoration(
          color: _CalUi.glassFill,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _CalUi.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 36,
              color: Colors.redAccent.withValues(alpha: 0.85),
            ),
            const SizedBox(height: 12),
            Text(
              'Could not load calendar',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _CalUi.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: _CalUi.accent,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarEmptyState extends StatelessWidget {
  const _CalendarEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
        decoration: BoxDecoration(
          color: _CalUi.glassFill,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _CalUi.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_available_outlined,
              size: 36,
              color: _CalUi.accent2.withValues(alpha: 0.75),
            ),
            const SizedBox(height: 12),
            Text(
              'No appointments scheduled.',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _CalUi.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try another date or add a new appointment.',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekTimeline extends StatelessWidget {
  const _WeekTimeline({
    required this.days,
    required this.items,
    required this.loading,
    required this.loadError,
    required this.selected,
    required this.onSelect,
    required this.startHour,
    required this.endHour,
    required this.pxPerMinute,
    required this.dayHeaderHeight,
    required this.rulerWidth,
    required this.viewMode,
  });

  final List<DateTime> days;
  final List<RezervacijaCalendarItem> items;
  final bool loading;
  final String? loadError;
  final RezervacijaCalendarItem? selected;
  final ValueChanged<RezervacijaCalendarItem?> onSelect;
  final int startHour;
  final int endHour;
  final double pxPerMinute;
  final double dayHeaderHeight;
  final double rulerWidth;
  final _CalViewMode viewMode;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isDay = viewMode == _CalViewMode.day;
    final visibleAppts = items
        .where((e) => days.any((d) => _sameDay(e.datumRezervacije, d)))
        .toList();
    final showEmpty =
        !loading && loadError == null && visibleAppts.isEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final headerH = dayHeaderHeight;
        final slotMinutes = (endHour - startHour) * 60.0;
        final rulerW = rulerWidth;
        final viewportH = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 480.0;
        final viewportW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : (rulerW + days.length * 100.0);

        final maxPx = math.max(0.45, (viewportH - headerH) / slotMinutes);
        final effectivePx = isDay
            ? math.min(math.max(pxPerMinute, 1.05), maxPx)
            : math.min(pxPerMinute, maxPx);
        final totalH = slotMinutes * effectivePx;
        final contentH = headerH + totalH;

        final grid = SizedBox(
          width: viewportW,
          height: contentH,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TimeRuler(
                startHour: startHour,
                endHour: endHour,
                height: totalH,
                pxPerMinute: effectivePx,
                headerHeight: headerH,
                width: rulerW,
              ),
              for (final day in days)
                Expanded(
                  child: _DayColumn(
                    day: day,
                    placements: () {
                      final d = items
                          .where((e) => _sameDay(e.datumRezervacije, day))
                          .toList();
                      return _assignDayLanes(d);
                    }(),
                    height: totalH,
                    headerHeight: headerH,
                    startHour: startHour,
                    endHour: endHour,
                    pxPerMinute: effectivePx,
                    now: now,
                    selected: selected,
                    onSelect: onSelect,
                    isDayView: isDay,
                    showColumnEmpty: isDay,
                  ),
                ),
            ],
          ),
        );

        final needsScroll = contentH > viewportH + 1;
        final timeline = needsScroll
            ? Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  primary: false,
                  physics: const ClampingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  child: grid,
                ),
              )
            : SizedBox(
                height: viewportH,
                width: viewportW,
                child: grid,
              );

        return Stack(
          fit: StackFit.expand,
          children: [
            timeline,
            if (showEmpty) const _CalendarEmptyState(),
          ],
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
    required this.placements,
    required this.height,
    required this.headerHeight,
    required this.startHour,
    required this.endHour,
    required this.pxPerMinute,
    required this.now,
    required this.selected,
    required this.onSelect,
    required this.isDayView,
    required this.showColumnEmpty,
  });

  final DateTime day;
  final List<_LanePlacement> placements;
  final double height;
  final double headerHeight;
  final int startHour;
  final int endHour;
  final double pxPerMinute;
  final DateTime now;
  final RezervacijaCalendarItem? selected;
  final ValueChanged<RezervacijaCalendarItem?> onSelect;
  final bool isDayView;
  final bool showColumnEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isToday = _sameDay(day, now);
    final startM = startHour * 60.0;
    final endM = endHour * 60.0;

    double topFor(RezervacijaCalendarItem e) {
      final m = _minutesOfDay(e.datumRezervacije);
      return (m - startM) * pxPerMinute;
    }

    double hFor(RezervacijaCalendarItem e) {
      return _durationMinutes(e) * pxPerMinute;
    }

    double? nowTop;
    if (isToday) {
      final nm = _minutesOfDay(now);
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
            child: LayoutBuilder(
              builder: (context, col) {
                final laneCount = placements.fold<int>(
                  1,
                  (max, p) => math.max(max, p.laneCount),
                );
                final innerW = col.maxWidth - 8;
                final laneW = innerW / laneCount;
                return Stack(
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
                    if (showColumnEmpty && placements.isEmpty)
                      Positioned.fill(
                        child: Center(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'No appointments scheduled.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.42),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    for (final p in placements)
                      Positioned(
                        left: 4 + p.lane * laneW + 1,
                        width: laneW - 2,
                        top: topFor(p.item).clamp(0, height - 40),
                        height: hFor(p.item).clamp(
                          isDayView ? 56.0 : 52.0,
                          height,
                        ),
                        child: _ApptCard(
                          item: p.item,
                          selected: selected?.id == p.item.id,
                          spacious: isDayView,
                          onTap: () => onSelect(p.item),
                        ),
                      ),
                  ],
                );
              },
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

enum _ApptCardVisualStatus { confirmed, pending, cancelled, completed, vip }

_ApptCardVisualStatus _apptCardVisualStatus(RezervacijaCalendarItem item) {
  if (item.isOtkazana || item.status == 'Cancelled') {
    return _ApptCardVisualStatus.cancelled;
  }
  if (item.isCompleted || item.status == 'Completed') {
    return _ApptCardVisualStatus.completed;
  }
  if (item.isVip) return _ApptCardVisualStatus.vip;
  if (!item.isPotvrdjena && item.status == 'Pending') {
    return _ApptCardVisualStatus.pending;
  }
  return _ApptCardVisualStatus.confirmed;
}

String _appointmentDateTimeLabel(DateTime d) {
  final l = d.toLocal();
  return '${_monthLong(l.month)} ${l.day}, ${l.year} · ${_hm(l)}';
}

class _ApptCard extends StatefulWidget {
  const _ApptCard({
    required this.item,
    required this.selected,
    required this.onTap,
    this.spacious = false,
  });

  final RezervacijaCalendarItem item;
  final bool selected;
  final VoidCallback onTap;
  final bool spacious;

  @override
  State<_ApptCard> createState() => _ApptCardState();
}

class _ApptCardState extends State<_ApptCard> {
  bool _hover = false;

  static const double _radius = 11;

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
      case _ApptCardVisualStatus.completed:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.fromRGBO(96, 165, 250, 0.22),
            Color.fromRGBO(30, 64, 120, 0.18),
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
      case _ApptCardVisualStatus.completed:
        return const Color(0xFF60A5FA);
      case _ApptCardVisualStatus.vip:
        return const Color(0xFF4ADE80);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final status = _apptCardVisualStatus(item);
    final end = item.datumRezervacije.add(
      Duration(minutes: item.uslugaTrajanjeMinuta <= 0 ? 60 : item.uslugaTrajanjeMinuta),
    );
    final timeStr = '${_hm(item.datumRezervacije)}–${_hm(end)}';
    final service = item.uslugaNaziv ?? 'Service';
    final client = item.korisnikIme ?? 'Guest';
    final therapist = item.zaposlenikIme?.trim();
    final accent = _statusDotColor(status);
    final spacious = widget.spacious;
    final timeSize = spacious ? 12.0 : 11.0;
    final serviceSize = spacious ? 13.5 : 12.5;
    final lineSize = spacious ? 12.0 : 11.0;

    final borderColor = widget.selected
        ? _CalUi.accent2.withValues(alpha: 0.65)
        : Colors.white.withValues(alpha: 0.08);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          transform: Matrix4.translationValues(0, _hover ? -1.0 : 0.0, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(
              color: borderColor,
              width: widget.selected ? 1.5 : 1,
            ),
            boxShadow: _hover
                ? [
                    BoxShadow(
                      color: _CalUi.accent.withValues(alpha: 0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_radius),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: accent),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(gradient: _statusGradient(status)),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final maxH = constraints.maxHeight;
                        final maxW = constraints.maxWidth;
                        final compact = maxH < 52;
                        final showClient =
                            !compact && maxH >= 50 && client.isNotEmpty;
                        final showTherapist = showClient &&
                            therapist != null &&
                            therapist.isNotEmpty &&
                            maxH >= 64;
                        final tSize = compact ? 10.0 : timeSize;
                        final sSize = compact ? 11.0 : serviceSize;
                        final lSize = compact ? 10.0 : lineSize;

                        final column = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              timeStr,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _txt(
                                tSize,
                                FontWeight.w600,
                                Colors.white.withValues(alpha: 0.78),
                              ),
                            ),
                            SizedBox(height: compact ? 2 : (spacious ? 4 : 3)),
                            Text(
                              service,
                              maxLines: compact ? 1 : (spacious ? 2 : 1),
                              overflow: TextOverflow.ellipsis,
                              style: _txt(
                                sSize,
                                FontWeight.w700,
                                _CalUi.textPrimary,
                                height: 1.12,
                              ),
                            ),
                            if (showClient) ...[
                              SizedBox(height: compact ? 2 : 3),
                              Text(
                                client,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _txt(
                                  lSize,
                                  FontWeight.w500,
                                  Colors.white.withValues(alpha: 0.82),
                                ),
                              ),
                            ],
                            if (showTherapist) ...[
                              SizedBox(height: compact ? 2 : 3),
                              Text(
                                therapist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _txt(
                                  lSize,
                                  FontWeight.w500,
                                  _CalUi.lavender.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ],
                        );

                        return Padding(
                          padding: EdgeInsets.fromLTRB(
                            spacious ? 10 : 8,
                            spacious ? 8 : 6,
                            spacious ? 10 : 8,
                            spacious ? 8 : 6,
                          ),
                          child: ClipRect(
                            child: compact
                                ? FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.topLeft,
                                    child: SizedBox(
                                      width: maxW,
                                      height: 46,
                                      child: column,
                                    ),
                                  )
                                : Align(
                                    alignment: Alignment.topLeft,
                                    child: column,
                                  ),
                          ),
                        );
                      },
                    ),
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

class _MonthOverview extends StatelessWidget {
  const _MonthOverview({
    required this.anchor,
    required this.items,
    required this.loading,
    required this.onPickDay,
  });

  final DateTime anchor;
  final List<RezervacijaCalendarItem> items;
  final bool loading;
  final void Function(DateTime day) onPickDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = _dateOnly(DateTime.now());
    final first = DateTime(anchor.year, anchor.month);
    final daysInMonth = DateTime(anchor.year, anchor.month + 1, 0).day;
    final lead = first.weekday - 1;

    final counts = <int, int>{};
    for (final e in items) {
      final loc = e.datumRezervacije.toLocal();
      if (loc.year == anchor.year && loc.month == anchor.month) {
        counts[loc.day] = (counts[loc.day] ?? 0) + 1;
      }
    }
    final cells = lead + daysInMonth;
    final rows = (cells / 7).ceil();
    final totalCells = rows * 7;
    final monthEmpty = !loading && items.isEmpty;

    const weekdayHeaderH = 28.0;
    const gridSpacing = 6.0;

    return Padding(
      padding: const EdgeInsets.all(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: weekdayHeaderH,
                child: Row(
                  children: [
                    for (final w in [
                      'Mon',
                      'Tue',
                      'Wed',
                      'Thu',
                      'Fri',
                      'Sat',
                      'Sun',
                    ])
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
              ),
              const SizedBox(height: 8),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, gridBox) {
                    final gridW = gridBox.maxWidth;
                    final gridH = gridBox.maxHeight;
                    final rowCount = rows.toDouble();
                    final cellW = (gridW - gridSpacing * 6) / 7;
                    final fitCellH =
                        (gridH - gridSpacing * (rowCount - 1)) / rowCount;
                    const minCellH = 44.0;
                    final cellH = math.max(minCellH, fitCellH);
                    final aspectRatio = cellW / cellH;
                    final totalGridH =
                        rowCount * cellH + gridSpacing * (rowCount - 1);
                    final needsScroll = totalGridH > gridH + 0.5;

                    final grid = GridView.builder(
                      padding: EdgeInsets.zero,
                      physics: needsScroll
                          ? const ClampingScrollPhysics()
                          : const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        childAspectRatio: aspectRatio.clamp(0.72, 1.35),
                        mainAxisSpacing: gridSpacing,
                        crossAxisSpacing: gridSpacing,
                      ),
                      itemCount: totalCells,
                      itemBuilder: (_, i) {
                          final dayNum = i - lead + 1;
                          if (i < lead ||
                              dayNum < 1 ||
                              dayNum > daysInMonth) {
                            return const SizedBox.shrink();
                          }
                          final c = counts[dayNum] ?? 0;
                          final day =
                              DateTime(anchor.year, anchor.month, dayNum);
                          final isToday = _sameDay(day, today);
                          return InkWell(
                            onTap: () => onPickDay(day),
                            borderRadius: BorderRadius.circular(12),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.white.withValues(
                                  alpha: isToday
                                      ? 0.1
                                      : c == 0
                                          ? 0.03
                                          : 0.07,
                                ),
                                border: Border.all(
                                  color: isToday
                                      ? _CalUi.accent.withValues(alpha: 0.65)
                                      : Colors.white.withValues(alpha: 0.08),
                                  width: isToday ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '$dayNum',
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                      color: isToday ? _CalUi.accent2 : null,
                                    ),
                                  ),
                                  if (c > 0)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        '$c appts',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style:
                                            theme.textTheme.labelSmall?.copyWith(
                                          fontSize: 10,
                                          color: NuaLuxuryTokens
                                              .lavenderWhisper
                                              .withValues(alpha: 0.75),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                    );

                    if (needsScroll) {
                      return Scrollbar(
                        thumbVisibility: true,
                        child: grid,
                      );
                    }
                    return grid;
                  },
                ),
              ),
            ],
          ),
          if (monthEmpty) const _CalendarEmptyState(),
        ],
      ),
    );
  }
}

class _CalendarAppointmentDetailsModal extends StatefulWidget {
  const _CalendarAppointmentDetailsModal({
    required this.initialItem,
    required this.showVipToggle,
    required this.onEdit,
    this.onVipToggle,
  });

  final RezervacijaCalendarItem initialItem;
  final bool showVipToggle;
  final VoidCallback onEdit;
  final Future<RezervacijaCalendarItem?> Function(bool value)? onVipToggle;

  @override
  State<_CalendarAppointmentDetailsModal> createState() =>
      _CalendarAppointmentDetailsModalState();
}

class _CalendarAppointmentDetailsModalState
    extends State<_CalendarAppointmentDetailsModal> {
  late RezervacijaCalendarItem _item;

  @override
  void initState() {
    super.initState();
    _item = widget.initialItem;
  }

  Future<void> _handleVipToggle(bool value) async {
    final handler = widget.onVipToggle;
    if (handler == null) return;
    final updated = await handler(value);
    if (!mounted || updated == null) return;
    setState(() => _item = updated);
  }

  @override
  Widget build(BuildContext context) {
    final duration =
        _item.uslugaTrajanjeMinuta <= 0 ? 60 : _item.uslugaTrajanjeMinuta;
    final notes = _calendarNotesText(_item);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFA120A24),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _CalUi.border),
            boxShadow: [
              BoxShadow(
                color: _CalUi.accent.withValues(alpha: 0.2),
                blurRadius: 40,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Appointment Details',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _CalUi.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
                child: _DetailCard(
                  item: _item,
                  showVipToggle: widget.showVipToggle,
                  onVipToggle: widget.onVipToggle == null
                      ? null
                      : _handleVipToggle,
                  dateTimeLabel:
                      _appointmentDateTimeLabel(_item.datumRezervacije),
                  durationMinutes: duration,
                  notes: notes,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: widget.onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit Appointment'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _CalUi.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.item,
    required this.showVipToggle,
    this.onVipToggle,
    this.dateTimeLabel,
    this.durationMinutes,
    this.notes,
  });
  final RezervacijaCalendarItem item;
  final bool showVipToggle;
  final Future<void> Function(bool value)? onVipToggle;
  final String? dateTimeLabel;
  final int? durationMinutes;
  final String? notes;

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
        _DetailLine(
          Icons.event_rounded,
          'Date & time',
          dateTimeLabel ?? _appointmentDateTimeLabel(item.datumRezervacije),
        ),
        _DetailLine(Icons.spa_rounded, 'Service', item.uslugaNaziv ?? '—'),
        _DetailLine(
          Icons.timer_outlined,
          'Duration',
          '${durationMinutes ?? (item.uslugaTrajanjeMinuta <= 0 ? 60 : item.uslugaTrajanjeMinuta)} min',
        ),
        if (item.zaposlenikIme?.trim().isNotEmpty == true)
          _DetailLine(Icons.person_outline, 'Therapist', item.zaposlenikIme!.trim()),
        if (item.prostorijaNaziv?.trim().isNotEmpty == true)
          _DetailLine(Icons.meeting_room_outlined, 'Room', item.prostorijaNaziv!.trim()),
        if (notes != null)
          _DetailLine(Icons.notes_outlined, 'Notes', notes!),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Tag(
              label: _calendarStatusLabel(item),
              color: _statusTagColor(item),
            ),
            _Tag(
              label: item.isPlacena ? 'Paid' : 'Unpaid',
              color: item.isPlacena ? const Color(0xFF4ADE80) : Colors.white54,
            ),
            if (item.isVip) const _Tag(label: 'VIP', color: Color(0xFFE8C547)),
          ],
        ),
        if (showVipToggle && !item.isOtkazana && !item.isCompleted && onVipToggle != null) ...[
          const SizedBox(height: 8),
            SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'VIP appointment',
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
