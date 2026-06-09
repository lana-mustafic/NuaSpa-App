import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/api/services/api_service.dart';
import '../../models/rezervacija.dart';
import '../../models/rezervacija_povijest_item.dart';
import '../../providers/auth_provider.dart';
import '../../ui/navigation/desktop_nav.dart';
import 'therapist_schedule_timeline.dart';

abstract final class _SchedUi {
  static const bgTop = Color(0xFF07040F);
  static const bgBottom = Color(0xFF120A24);
  static const textPrimary = Color(0xFFF5F3FA);
  static const textSecondary = Color(0xA6FFFFFF);
  static const purple = Color(0xFF7B4DFF);
  static const lavender = Color(0xFF9D6BFF);
  static const green = Color(0xFF22C55E);
  static const blue = Color(0xFF60A5FA);
  static const gold = Color(0xFFF5B942);
  static const cardRadius = 24.0;
  static const heroRadius = 30.0;
  static const gap = 24.0;
  static const sidebarWidth = 340.0;
  static const contentPadding = 32.0;
}

const _statusPills = [
  'All',
  'Pending',
  'Confirmed',
  'Paid',
  'Unpaid',
  'Cancelled',
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

/// Therapist daily planner — luxury layout, existing API + timeline.
class TherapistScheduleScreen extends StatefulWidget {
  const TherapistScheduleScreen({super.key});

  @override
  State<TherapistScheduleScreen> createState() =>
      _TherapistScheduleScreenState();
}

class _TherapistScheduleScreenState extends State<TherapistScheduleScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late DateTime _day;
  Future<_DayData>? _dayFuture;
  bool _autoLoadScheduled = false;
  String? _loadError;
  bool? _filterPotvrdjena;
  bool? _filterPlacena;
  String _statusPill = 'All';

  final TextEditingController _searchCtrl = TextEditingController();
  Rezervacija? _detailBooking;
  final ScrollController _scrollController = ScrollController();
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;
  int _lastAvailabilityHint = -1;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _day = DateTime(n.year, n.month, n.day);
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final hint = context.read<DesktopNav>().scheduleAvailabilityHint;
    if (hint != _lastAvailabilityHint && hint > 0) {
      _lastAvailabilityHint = hint;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Availability is managed by your spa admin. '
              'Use this schedule to view bookings and open slots.',
            ),
            behavior: SnackBarBehavior.floating,
            width: 460,
          ),
        );
      });
    }
  }

  DateTime _onlyDate(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: _SchedUi.purple,
              surface: _SchedUi.bgBottom,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _day = _onlyDate(picked));
      await _reload();
    }
  }

  Future<void> _reload() async {
    final auth = context.read<AuthProvider>();
    final zid = auth.zaposlenikId;
    if (!auth.isZaposlenik || zid == null) return;

    final f = _loadDay(zid, _day);
    setState(() {
      _dayFuture = f;
      _loadError = null;
    });
  }

  void _shiftDay(int delta) {
    setState(() => _day = _day.add(Duration(days: delta)));
    _reload();
    _fadeCtrl.forward(from: 0);
  }

  void _selectStatusPill(String pill) {
    if (_statusPill == pill) return;
    setState(() {
      _statusPill = pill;
      switch (pill) {
        case 'Pending':
          _filterPotvrdjena = false;
          _filterPlacena = null;
        case 'Confirmed':
          _filterPotvrdjena = true;
          _filterPlacena = null;
        default:
          _filterPotvrdjena = null;
          _filterPlacena = null;
      }
    });
    _reload();
    _fadeCtrl.forward(from: 0);
  }

  List<Rezervacija> _filterBookings(List<Rezervacija> all) {
    final q = _searchCtrl.text.trim().toLowerCase();
    return all.where((r) {
      switch (_statusPill) {
        case 'Pending':
          if (r.isOtkazana || r.isPotvrdjena) return false;
        case 'Confirmed':
          if (r.isOtkazana || !r.isPotvrdjena) return false;
        case 'Paid':
          if (r.isOtkazana || !r.isPlacena) return false;
        case 'Unpaid':
          if (r.isOtkazana || r.isPlacena) return false;
        case 'Cancelled':
          if (!r.isOtkazana) return false;
        default:
          break;
      }
      if (_filterPlacena != null && r.isPlacena != _filterPlacena) {
        return false;
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
    }).toList();
  }

  _DayStats _dayStats(List<Rezervacija> dayAll) {
    final active = dayAll.where((r) => !r.isOtkazana).toList();
    final confirmed = active.where((r) => r.isPotvrdjena).length;
    final pending = active.where((r) => !r.isPotvrdjena).length;
    final revenue = active
        .where((r) => r.isPlacena)
        .fold<double>(0, (s, r) => s + r.uslugaCijena);
    final now = DateTime.now();
    final upcoming = active
        .where((r) => r.datumRezervacije.isAfter(now))
        .toList()
      ..sort((a, b) => a.datumRezervacije.compareTo(b.datumRezervacije));
    return _DayStats(
      total: active.length,
      confirmed: confirmed,
      pending: pending,
      revenue: revenue,
      upcoming: upcoming.take(6).toList(),
    );
  }

  void _openBookingDetail(Rezervacija r) {
    setState(() => _detailBooking = r);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scaffoldKey.currentState?.openEndDrawer();
    });
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
    final zid = auth.zaposlenikId;

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

    if (_dayFuture == null && !_autoLoadScheduled) {
      _autoLoadScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        _autoLoadScheduled = false;
        await _reload();
      });
    }

    final mq = MediaQuery.sizeOf(context);
    final drawerW = mq.width >= 600 ? 420.0 : mq.width * .92;
    final longDate = _formatLongDate(_day);

    return Theme(
      data: Theme.of(context).copyWith(
        drawerTheme: DrawerThemeData(
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          width: drawerW,
        ),
      ),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.transparent,
        onEndDrawerChanged: (opened) {
          if (!opened && mounted) setState(() => _detailBooking = null);
        },
        endDrawer: _detailBooking == null
            ? null
            : Drawer(
                backgroundColor: _SchedUi.bgBottom,
                child: _TherapistClientDrawerContent(
                  api: _api,
                  rezervacija: _detailBooking!,
                  onClose: () => Navigator.maybePop(context),
                  slotoviFuture: () async {
                    final data = await _dayFuture;
                    return data?.slotovi ?? [];
                  },
                  onPotvrdiToggled: _togglePotvrdaAndReload,
                ),
              ),
        body: _ScheduleShell(
          child: RefreshIndicator(
            color: _SchedUi.lavender,
            onRefresh: _reload,
            child: FutureBuilder<_DayData>(
              future: _dayFuture,
              builder: (context, snap) {
                if (_dayFuture == null ||
                    snap.connectionState == ConnectionState.waiting) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: 200),
                      Center(
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ],
                  );
                }

                if (snap.hasError) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(_SchedUi.contentPadding),
                    children: [
                      _SchedGlass(
                        child: Column(
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
                              _loadError ?? snap.error.toString(),
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
                    ],
                  );
                }

                final data =
                    snap.data ?? _DayData(rezervacije: [], slotovi: []);
                final filtered = _filterBookings(data.rezervacije);
                final stats = _dayStats(data.rezervacije);

                if (_detailBooking != null &&
                    !filtered.any((r) => r.id == _detailBooking!.id)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    setState(() => _detailBooking = null);
                    Navigator.maybePop(context);
                  });
                }

                return FadeTransition(
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
                          day: _day,
                          longDate: longDate,
                          statusPill: _statusPill,
                          searchCtrl: _searchCtrl,
                          filtered: filtered,
                          slotovi: data.slotovi,
                          selectedId: _detailBooking?.id,
                          onSearchChanged: () => setState(() {}),
                          onPill: _selectStatusPill,
                          onRefresh: _reload,
                          onPrevDay: () => _shiftDay(-1),
                          onNextDay: () => _shiftDay(1),
                          onPickDate: _pickDate,
                          onSelect: _openBookingDetail,
                          onBlockTime: () => _snack(
                            'Block time is managed by your spa admin. Contact them to update availability.',
                          ),
                          onViewCalendar: () => context
                              .read<DesktopNav>()
                              .goTo(DesktopRouteKey.therapistAppointments),
                          onWeekly: () => _snack(
                            'Weekly view opens from your schedule — use the date picker to browse other days.',
                          ),
                        );
                        final sidebar = _ScheduleSidebar(
                          stats: stats,
                          onBlockTime: () => _snack(
                            'Block time requests go through your spa administrator.',
                          ),
                          onOpenCalendar: () => context
                              .read<DesktopNav>()
                              .goTo(DesktopRouteKey.therapistAppointments),
                          onManageAvailability: () => _snack(
                            'Availability is updated by your spa admin.',
                          ),
                          onViewReviews: () => context
                              .read<DesktopNav>()
                              .goTo(DesktopRouteKey.therapistReviews),
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
                );
              },
            ),
          ),
        ),
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

  Future<_DayData> _loadDay(int zaposlenikId, DateTime day) async {
    try {
      final includeCancelled =
          _statusPill == 'Cancelled' || _statusPill == 'All';
      final results = await Future.wait([
        _api.getRezervacijeFiltered(
          datum: day,
          isPotvrdjena: _filterPotvrdjena,
          includeOtkazane: includeCancelled,
        ),
        _api.getDostupniTermini(zaposlenikId: zaposlenikId, datum: day),
      ]).timeout(const Duration(seconds: 12));

      final rez = results[0] as List<Rezervacija>;
      final slotovi = results[1] as List<DateTime>;
      return _DayData(rezervacije: rez, slotovi: slotovi);
    } catch (e) {
      if (mounted) setState(() => _loadError = e.toString());
      rethrow;
    }
  }
}

class _DayData {
  final List<Rezervacija> rezervacije;
  final List<DateTime> slotovi;

  _DayData({required this.rezervacije, required this.slotovi});
}

class _DayStats {
  const _DayStats({
    required this.total,
    required this.confirmed,
    required this.pending,
    required this.revenue,
    required this.upcoming,
  });

  final int total;
  final int confirmed;
  final int pending;
  final double revenue;
  final List<Rezervacija> upcoming;
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
    required this.day,
    required this.longDate,
    required this.statusPill,
    required this.searchCtrl,
    required this.filtered,
    required this.slotovi,
    required this.selectedId,
    required this.onSearchChanged,
    required this.onPill,
    required this.onRefresh,
    required this.onPrevDay,
    required this.onNextDay,
    required this.onPickDate,
    required this.onSelect,
    required this.onBlockTime,
    required this.onViewCalendar,
    required this.onWeekly,
  });

  final DateTime day;
  final String longDate;
  final String statusPill;
  final TextEditingController searchCtrl;
  final List<Rezervacija> filtered;
  final List<DateTime> slotovi;
  final int? selectedId;
  final VoidCallback onSearchChanged;
  final ValueChanged<String> onPill;
  final VoidCallback onRefresh;
  final VoidCallback onPrevDay;
  final VoidCallback onNextDay;
  final VoidCallback onPickDate;
  final ValueChanged<Rezervacija> onSelect;
  final VoidCallback onBlockTime;
  final VoidCallback onViewCalendar;
  final VoidCallback onWeekly;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ScheduleHeroCard(
          longDate: longDate,
          onPrevDay: onPrevDay,
          onNextDay: onNextDay,
          onPickDate: onPickDate,
        ),
        const SizedBox(height: _SchedUi.gap),
        _FilterActionBar(
          statusPill: statusPill,
          searchCtrl: searchCtrl,
          onSearchChanged: onSearchChanged,
          onPill: onPill,
          onRefresh: onRefresh,
          onBlockTime: onBlockTime,
          onViewCalendar: onViewCalendar,
        ),
        const SizedBox(height: 14),
        const _StatusLegendRow(),
        const SizedBox(height: _SchedUi.gap),
        _MainScheduleCard(
          longDate: longDate,
          filtered: filtered,
          slotovi: slotovi,
          selectedId: selectedId,
          onSelect: onSelect,
          onWeekly: onWeekly,
          onBlockTime: onBlockTime,
        ),
      ],
    );
  }
}

class _ScheduleHeroCard extends StatelessWidget {
  const _ScheduleHeroCard({
    required this.longDate,
    required this.onPrevDay,
    required this.onNextDay,
    required this.onPickDate,
  });

  final String longDate;
  final VoidCallback onPrevDay;
  final VoidCallback onNextDay;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    return _SchedGlass(
      radius: _SchedUi.heroRadius,
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 220),
        child: LayoutBuilder(
          builder: (context, c) {
            final stack = c.maxWidth < 720;
            final left = Row(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: LinearGradient(
                      colors: [
                        _SchedUi.purple.withValues(alpha: 0.4),
                        _SchedUi.lavender.withValues(alpha: 0.15),
                      ],
                    ),
                    border: Border.all(
                      color: _SchedUi.purple.withValues(alpha: 0.45),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _SchedUi.purple.withValues(alpha: 0.35),
                        blurRadius: 28,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    size: 44,
                    color: _SchedUi.lavender,
                  ),
                ),
                const SizedBox(width: 22),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Today's Schedule",
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: _SchedUi.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Track appointments, blocked time and therapist availability.',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          height: 1.45,
                          color: _SchedUi.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
            final nav = _DateNavRow(
              longDate: longDate,
              onPrev: onPrevDay,
              onNext: onNextDay,
              onPick: onPickDate,
            );
            if (stack) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [left, const SizedBox(height: 20), nav],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: left),
                const SizedBox(width: 20),
                nav,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DateNavRow extends StatelessWidget {
  const _DateNavRow({
    required this.longDate,
    required this.onPrev,
    required this.onNext,
    required this.onPick,
  });

  final String longDate;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _GlassIconButton(icon: Icons.chevron_left_rounded, onTap: onPrev),
        const SizedBox(width: 10),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPick,
            borderRadius: BorderRadius.circular(14),
            child: _SchedGlass(
              radius: 14,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Text(
                longDate,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: _SchedUi.textPrimary,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _GlassIconButton(icon: Icons.chevron_right_rounded, onTap: onNext),
      ],
    );
  }
}

class _FilterActionBar extends StatelessWidget {
  const _FilterActionBar({
    required this.statusPill,
    required this.searchCtrl,
    required this.onSearchChanged,
    required this.onPill,
    required this.onRefresh,
    required this.onBlockTime,
    required this.onViewCalendar,
  });

  final String statusPill;
  final TextEditingController searchCtrl;
  final VoidCallback onSearchChanged;
  final ValueChanged<String> onPill;
  final VoidCallback onRefresh;
  final VoidCallback onBlockTime;
  final VoidCallback onViewCalendar;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SchedGlass(
              radius: 16,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: TextField(
                controller: searchCtrl,
                onChanged: (_) => onSearchChanged(),
                style: GoogleFonts.inter(color: _SchedUi.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search clients or services…',
                  hintStyle: GoogleFonts.inter(
                    color: _SchedUi.textSecondary,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  icon: Icon(
                    Icons.search_rounded,
                    color: _SchedUi.lavender.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, bc) {
                final actions = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _GlassIconButton(
                      icon: Icons.refresh_rounded,
                      onTap: onRefresh,
                      size: 52,
                    ),
                    const SizedBox(width: 8),
                    _GlassActionButton(
                      label: 'Block Time',
                      icon: Icons.block_rounded,
                      onTap: onBlockTime,
                    ),
                    const SizedBox(width: 8),
                    _PrimaryGradientButton(
                      label: 'View Calendar',
                      icon: Icons.calendar_month_outlined,
                      onTap: onViewCalendar,
                      compact: true,
                    ),
                  ],
                );
                if (bc.maxWidth < 800) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final p in _statusPills)
                            _StatusPillChip(
                              label: p,
                              selected: statusPill == p,
                              onTap: () => onPill(p),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      actions,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final p in _statusPills)
                            _StatusPillChip(
                              label: p,
                              selected: statusPill == p,
                              onTap: () => onPill(p),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    actions,
                  ],
                );
              },
            ),
          ],
        );
      },
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: widget.selected
                ? const LinearGradient(
                    colors: [_SchedUi.purple, _SchedUi.lavender],
                  )
                : null,
            color: widget.selected
                ? null
                : Colors.white.withValues(alpha: _hover ? 0.08 : 0.04),
            border: Border.all(
              color: widget.selected
                  ? _SchedUi.lavender.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: _hover ? 0.2 : 0.1),
            ),
            boxShadow: widget.selected || _hover
                ? [
                    BoxShadow(
                      color: _SchedUi.purple.withValues(
                        alpha: widget.selected ? 0.4 : 0.2,
                      ),
                      blurRadius: 14,
                    ),
                  ]
                : null,
          ),
          child: Text(
            widget.label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: widget.selected
                  ? Colors.white
                  : _SchedUi.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusLegendRow extends StatelessWidget {
  const _StatusLegendRow();

  @override
  Widget build(BuildContext context) {
    Widget dot(Color c, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: _SchedUi.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );

    return Wrap(
      spacing: 18,
      runSpacing: 8,
      children: [
        dot(_SchedUi.blue, 'Pending'),
        dot(_SchedUi.green, 'Confirmed'),
        dot(_SchedUi.gold, 'Premium / VIP'),
        dot(Colors.white.withValues(alpha: 0.45), 'Cancelled / Past'),
      ],
    );
  }
}

class _MainScheduleCard extends StatelessWidget {
  const _MainScheduleCard({
    required this.longDate,
    required this.filtered,
    required this.slotovi,
    required this.selectedId,
    required this.onSelect,
    required this.onWeekly,
    required this.onBlockTime,
  });

  final String longDate;
  final List<Rezervacija> filtered;
  final List<DateTime> slotovi;
  final int? selectedId;
  final ValueChanged<Rezervacija> onSelect;
  final VoidCallback onWeekly;
  final VoidCallback onBlockTime;

  @override
  Widget build(BuildContext context) {
    return _SchedGlass(
      radius: _SchedUi.heroRadius,
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 500),
        child: filtered.isEmpty
            ? _ScheduleEmptyState(longDate: longDate, onWeekly: onWeekly, onBlockTime: onBlockTime)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Appointments (${filtered.length})',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _SchedUi.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 520),
                      child: TherapistDayTimeline(
                        rezervacije: filtered,
                        selectedId: selectedId,
                        onSelect: onSelect,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _SlotsSection(slotovi: slotovi),
                ],
              ),
      ),
    );
  }
}

class _ScheduleEmptyState extends StatelessWidget {
  const _ScheduleEmptyState({
    required this.longDate,
    required this.onWeekly,
    required this.onBlockTime,
  });

  final String longDate;
  final VoidCallback onWeekly;
  final VoidCallback onBlockTime;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ...List.generate(8, (i) {
          final angle = i * math.pi / 4;
          return Positioned(
            left: 100 + 120 * math.cos(angle),
            top: 60 + 80 * math.sin(angle),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _SchedUi.lavender.withValues(alpha: 0.4),
                boxShadow: [
                  BoxShadow(
                    color: _SchedUi.purple.withValues(alpha: 0.4),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          );
        }),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _SchedUi.purple.withValues(alpha: 0.35),
                      _SchedUi.lavender.withValues(alpha: 0.08),
                    ],
                  ),
                  border: Border.all(
                    color: _SchedUi.purple.withValues(alpha: 0.4),
                  ),
                ),
                child: const Icon(
                  Icons.self_improvement_rounded,
                  size: 72,
                  color: _SchedUi.lavender,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'You\'re all clear today!',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _SchedUi.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'No appointments scheduled for $longDate.',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: _SchedUi.textSecondary,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Try another date or adjust your filters.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: _SchedUi.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  _OutlinedGlowButton(
                    label: 'View Weekly Schedule',
                    icon: Icons.date_range_rounded,
                    onTap: onWeekly,
                  ),
                  _OutlinedGlowButton(
                    label: 'Add Block Time',
                    icon: Icons.block_rounded,
                    onTap: onBlockTime,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScheduleSidebar extends StatelessWidget {
  const _ScheduleSidebar({
    required this.stats,
    required this.onBlockTime,
    required this.onOpenCalendar,
    required this.onManageAvailability,
    required this.onViewReviews,
  });

  final _DayStats stats;
  final VoidCallback onBlockTime;
  final VoidCallback onOpenCalendar;
  final VoidCallback onManageAvailability;
  final VoidCallback onViewReviews;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TodayOverviewCard(stats: stats),
        const SizedBox(height: 18),
        _UpcomingTimelineCard(upcoming: stats.upcoming),
        const SizedBox(height: 18),
        _QuickActionsCard(
          onBlockTime: onBlockTime,
          onOpenCalendar: onOpenCalendar,
          onManageAvailability: onManageAvailability,
          onViewReviews: onViewReviews,
        ),
      ],
    );
  }
}

class _TodayOverviewCard extends StatelessWidget {
  const _TodayOverviewCard({required this.stats});

  final _DayStats stats;

  @override
  Widget build(BuildContext context) {
    return _SchedGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Today Overview',
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _SchedUi.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _MiniKpi(
            icon: Icons.event_rounded,
            label: 'Appointments Today',
            value: '${stats.total}',
            accent: _SchedUi.purple,
          ),
          const SizedBox(height: 10),
          _MiniKpi(
            icon: Icons.check_circle_rounded,
            label: 'Confirmed',
            value: '${stats.confirmed}',
            accent: _SchedUi.green,
          ),
          const SizedBox(height: 10),
          _MiniKpi(
            icon: Icons.schedule_rounded,
            label: 'Pending',
            value: '${stats.pending}',
            accent: _SchedUi.blue,
          ),
          const SizedBox(height: 10),
          _MiniKpi(
            icon: Icons.payments_rounded,
            label: 'Revenue',
            value: '€${stats.revenue.toStringAsFixed(0)}',
            accent: _SchedUi.gold,
          ),
        ],
      ),
    );
  }
}

class _MiniKpi extends StatelessWidget {
  const _MiniKpi({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: accent.withValues(alpha: 0.08),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: accent.withValues(alpha: 0.15),
              boxShadow: [
                BoxShadow(color: accent.withValues(alpha: 0.3), blurRadius: 10),
              ],
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: _SchedUi.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _SchedUi.textPrimary,
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

class _UpcomingTimelineCard extends StatelessWidget {
  const _UpcomingTimelineCard({required this.upcoming});

  final List<Rezervacija> upcoming;

  Color _dotColor(Rezervacija r) {
    if (r.isOtkazana) return Colors.white54;
    if (!r.isPotvrdjena) return _SchedUi.blue;
    if (r.premiumKlijent || (r.isPotvrdjena && r.isPlacena)) {
      return _SchedUi.gold;
    }
    return _SchedUi.green;
  }

  @override
  Widget build(BuildContext context) {
    return _SchedGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Upcoming Timeline',
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _SchedUi.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          if (upcoming.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Icon(
                    Icons.event_busy_outlined,
                    size: 40,
                    color: _SchedUi.lavender.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No upcoming appointments',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      color: _SchedUi.textPrimary,
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                for (var i = 0; i < upcoming.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _TimelineRow(r: upcoming[i], dotColor: _dotColor(upcoming[i])),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.r, required this.dotColor});

  final Rezervacija r;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    final l = r.datumRezervacije.toLocal();
    final time =
        '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
    final initials = (r.korisnikIme?.trim().isNotEmpty ?? false)
        ? r.korisnikIme!.trim()[0].toUpperCase()
        : '?';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Text(
              time,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _SchedUi.lavender,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: dotColor.withValues(alpha: 0.6), blurRadius: 8),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        CircleAvatar(
          radius: 18,
          backgroundColor: _SchedUi.purple.withValues(alpha: 0.25),
          child: Text(
            initials,
            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.korisnikIme ?? 'Client',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: _SchedUi.textPrimary,
                ),
              ),
              Text(
                r.uslugaNaziv ?? 'Service',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: _SchedUi.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard({
    required this.onBlockTime,
    required this.onOpenCalendar,
    required this.onManageAvailability,
    required this.onViewReviews,
  });

  final VoidCallback onBlockTime;
  final VoidCallback onOpenCalendar;
  final VoidCallback onManageAvailability;
  final VoidCallback onViewReviews;

  @override
  Widget build(BuildContext context) {
    return _SchedGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Quick Actions',
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _SchedUi.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          _QuickActionRow(
            icon: Icons.block_rounded,
            label: 'Block Time',
            onTap: onBlockTime,
          ),
          const SizedBox(height: 10),
          _QuickActionRow(
            icon: Icons.calendar_month_outlined,
            label: 'Open Calendar',
            onTap: onOpenCalendar,
          ),
          const SizedBox(height: 10),
          _QuickActionRow(
            icon: Icons.event_available_rounded,
            label: 'Manage Availability',
            onTap: onManageAvailability,
          ),
          const SizedBox(height: 10),
          _QuickActionRow(
            icon: Icons.reviews_outlined,
            label: 'View Reviews',
            onTap: onViewReviews,
          ),
        ],
      ),
    );
  }
}

class _QuickActionRow extends StatefulWidget {
  const _QuickActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_QuickActionRow> createState() => _QuickActionRowState();
}

class _QuickActionRowState extends State<_QuickActionRow> {
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
                color: _SchedUi.purple.withValues(alpha: _hover ? 0.4 : 0.18),
              ),
              boxShadow: _hover
                  ? [
                      BoxShadow(
                        color: _SchedUi.purple.withValues(alpha: 0.22),
                        blurRadius: 14,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Icon(widget.icon, color: _SchedUi.lavender, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.label,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: _SchedUi.textPrimary,
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
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _SchedUi.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        if (slotovi.isEmpty)
          Text(
            'No open slots for this day.',
            style: GoogleFonts.inter(color: _SchedUi.textSecondary),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: slotovi
                .map(
                  (t) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
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
                        fontSize: 12,
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
                                      color: TherapistSchedulePalette
                                          .premiumStroke,
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
