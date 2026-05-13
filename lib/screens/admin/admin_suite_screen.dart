import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api/services/api_service.dart';
import '../../models/admin/admin_kpi.dart';
import '../../models/admin/revenue_point.dart';
import '../../models/admin/service_popularity.dart';
import '../../models/admin/top_spender.dart';
import '../../models/admin/rezervacija_calendar_item.dart';
import '../../models/zaposlenik.dart';
import '../../ui/widgets/page_header.dart';
import 'admin_clients_desktop_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_resources_screen.dart';
import 'admin_therapist_profile_screen.dart';
import 'admin_suite_route.dart';

class AdminSuiteScreen extends StatefulWidget {
  const AdminSuiteScreen({super.key, required this.initialRoute});

  /// Shell-controlled deep link (fresh state per sidebar jump).
  final AdminSuiteRoute initialRoute;

  @override
  State<AdminSuiteScreen> createState() => _AdminSuiteScreenState();
}

enum _TherapistsView { availability, calendar }

String _calendarDialogDayCaption(DateTime day) {
  const names = ['Pon', 'Uto', 'Sri', 'Čet', 'Pet', 'Sub', 'Ned'];
  final loc = day.toLocal();
  final w = names[(loc.weekday - 1).clamp(0, 6)];
  final dd = loc.day.toString().padLeft(2, '0');
  final mm = loc.month.toString().padLeft(2, '0');
  return '$w · $dd.$mm.${loc.year}';
}

bool _rezCalMatchesSearch(RezervacijaCalendarItem e, String q) {
  if (q.isEmpty) return true;
  bool hay(String? s) => s?.toLowerCase().contains(q) ?? false;
  return hay(e.korisnikIme) ||
      hay(e.korisnikTelefon) ||
      hay(e.korisnikEmail) ||
      hay(e.zaposlenikIme) ||
      hay(e.uslugaNaziv) ||
      hay(e.razlogOtkaza) ||
      e.id.toString().contains(q) ||
      e.korisnikId.toString().contains(q);
}

String _formatTimeHm(DateTime d) {
  final loc = d.toLocal();
  return '${loc.hour.toString().padLeft(2, '0')}:${loc.minute.toString().padLeft(2, '0')}';
}

String _rezCalBookingStatsLine(List<RezervacijaCalendarItem> xs) {
  if (xs.isEmpty) return '';
  final otk = xs.where((x) => x.isOtkazana).length;
  final pot = xs.where((x) => !x.isOtkazana && x.isPotvrdjena).length;
  final cek = xs.where((x) => !x.isOtkazana && !x.isPotvrdjena).length;
  final plac = xs.where((x) => x.isPlacena && !x.isOtkazana).length;
  final tot = xs.length;
  final parts = <String>[
    'Ukupno $tot',
    'Potvrđene $pot',
    if (cek > 0) 'Čekanje $cek',
    'Plaćene $plac',
    if (otk > 0) 'Otkazane $otk',
  ];
  return parts.join(' · ');
}

class _CalendarDayBookingDialog extends StatefulWidget {
  const _CalendarDayBookingDialog({
    required this.day,
    required this.rowLabel,
    required this.items,
    required this.dismissContext,
  });

  final DateTime day;
  final String rowLabel;

  /// Bookings already filtered and sorted for this calendar cell/day.
  final List<RezervacijaCalendarItem> items;

  /// `Navigator`/`Theme` ancestor from opener (not the overlay).
  final BuildContext dismissContext;

  @override
  State<_CalendarDayBookingDialog> createState() =>
      _CalendarDayBookingDialogState();
}

class _CalendarDayBookingDialogState extends State<_CalendarDayBookingDialog> {
  late TextEditingController _query;

  @override
  void initState() {
    super.initState();
    _query = TextEditingController();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.maybeOf(widget.dismissContext)?.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        width: 360,
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mq = MediaQuery.sizeOf(context);
    final paneH = (mq.height * 0.55).clamp(280.0, 480.0);
    final paneW = (mq.width - 96).clamp(300.0, 720.0);
    final cap = _calendarDialogDayCaption(widget.day);
    final baseCount = widget.items.length;

    final qq = _query.text.trim().toLowerCase();
    final visible = qq.isEmpty
        ? widget.items
        : widget.items.where((e) => _rezCalMatchesSearch(e, qq)).toList();

    final statsLine = _rezCalBookingStatsLine(visible);
    final titleExtra = [
      if (qq.isNotEmpty && visible.length != widget.items.length)
        'pretraga: ${visible.length}/${widget.items.length}',
    ].join(', ');

    return AlertDialog(
      icon: Icon(
        Icons.event_available_outlined,
        color: theme.colorScheme.primary,
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            cap,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.person_outline,
                size: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.rowLabel,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$baseCount termina za odabrani dan'
            '${titleExtra.isEmpty ? '' : ' · $titleExtra'}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: paneW,
        height: paneH,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _query,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText:
                    'Pretraži: klijent, telefon, email, usluga, terapeut, ID…',
                prefixIcon: const Icon(Icons.search, size: 22),
                isDense: true,
                filled: true,
                suffixIcon: qq.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Očisti pretragu',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _query.clear();
                          setState(() {});
                        },
                      ),
              ),
            ),
            if (statsLine.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                statsLine,
                style: theme.textTheme.labelMedium?.copyWith(
                  height: 1.35,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const Divider(height: 22),
            Expanded(
              child: visible.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.event_busy_rounded,
                            size: 40,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.35,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            () {
                              if (qq.isNotEmpty) {
                                return 'Nema pogodaka za ovaj upit pretrage.';
                              }
                              return 'Nema rezervacija za ovaj prikaz.';
                            }(),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.64,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Scrollbar(
                      thumbVisibility: true,
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: visible.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final r = visible[i];
                          final startLoc = r.datumRezervacije.toLocal();
                          final timeHm = _formatTimeHm(startLoc);
                          final dur = r.uslugaTrajanjeMinuta;
                          final endLoc = dur > 0
                              ? startLoc.add(Duration(minutes: dur))
                              : null;
                          final cijenaStr = r.uslugaCijena > 0
                              ? '${r.uslugaCijena.toStringAsFixed(2)} KM'
                              : '—';
                          final spanLine = (dur > 0 && endLoc != null)
                              ? '$timeHm–${_formatTimeHm(endLoc)} · $dur min · $cijenaStr'
                              : '$timeHm · $cijenaStr';
                          final subMuted = theme.textTheme.bodySmall?.copyWith(
                            height: 1.35,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.74,
                            ),
                          );
                          final klijent = r.korisnikIme?.trim();
                          final klijentLabel =
                              (klijent == null || klijent.isEmpty)
                                  ? '—'
                                  : klijent;
                          final ter = r.zaposlenikIme?.trim();
                          final terLabel =
                              (ter == null || ter.isEmpty) ? '—' : ter;
                          final tel = r.korisnikTelefon?.trim();
                          final telLabel =
                              (tel == null || tel.isEmpty) ? '—' : tel;
                          final mail = r.korisnikEmail?.trim();
                          final mailLabel =
                              (mail == null || mail.isEmpty) ? '—' : mail;

                          final chips = Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (r.isPlacena)
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  label: const Text('Plaćeno'),
                                  backgroundColor: Colors.green.withValues(
                                    alpha: 0.22,
                                  ),
                                ),
                              if (r.isOtkazana)
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  label: const Text('Otkazana'),
                                  backgroundColor: Colors.redAccent.withValues(
                                    alpha: 0.22,
                                  ),
                                )
                              else if (r.isPotvrdjena)
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  label: const Text('Potvrđena'),
                                  backgroundColor: Colors.green.withValues(
                                    alpha: 0.14,
                                  ),
                                )
                              else
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  label: const Text('Čekanje'),
                                  backgroundColor: Colors.orange.withValues(
                                    alpha: 0.18,
                                  ),
                                ),
                              IconButton(
                                tooltip:
                                    'Kopiraj ID rezervacije u međuspremnik',
                                icon: const Icon(Icons.copy_outlined, size: 18),
                                visualDensity: VisualDensity.compact,
                                onPressed: () async {
                                  await Clipboard.setData(
                                    ClipboardData(text: '${r.id}'),
                                  );
                                  _toast('Kopiran ID rezervacije ${r.id}');
                                },
                              ),
                            ],
                          );

                          final titleStyle = theme.textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                height: 1.25,
                              );

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Tooltip(
                                  message:
                                      dur > 0
                                          ? 'Početak $timeHm (trajanje $dur min)'
                                          : 'Početak termina $timeHm',
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: CircleAvatar(
                                      radius: 18,
                                      backgroundColor: theme
                                          .colorScheme
                                          .surfaceContainerHighest
                                          .withValues(alpha: 0.92),
                                      child: Text(
                                        timeHm,
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              fontFeatures: const [
                                                FontFeature.tabularFigures(),
                                              ],
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        r.uslugaNaziv ?? 'Usluga',
                                        style: titleStyle,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        spanLine,
                                        style:
                                            theme.textTheme.labelMedium
                                                ?.copyWith(
                                              color:
                                                  theme
                                                      .colorScheme
                                                      .onSurface
                                                      .withValues(
                                                        alpha: 0.72,
                                                      ),
                                              fontFeatures: const [
                                                FontFeature.tabularFigures(),
                                              ],
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const SizedBox(height: 8),
                                      chips,
                                      const SizedBox(height: 6),
                                      Text(
                                        'Klijent: $klijentLabel\n'
                                        'Tel: $telLabel · Mail: $mailLabel\n'
                                        'Terapeut: $terLabel\n'
                                        'Korisnik #${r.korisnikId} · Rezerv. #${r.id}',
                                        style: subMuted,
                                      ),
                                      if (r.isOtkazana &&
                                          (r.razlogOtkaza
                                                  ?.trim()
                                                  .isNotEmpty ??
                                              false))
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 6),
                                          child: Text(
                                            'Razlog otkaza: ${r.razlogOtkaza}',
                                            style: subMuted?.copyWith(
                                              color: theme.colorScheme.error
                                                  .withValues(alpha: 0.92),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      actionsAlignment: MainAxisAlignment.end,
      actions: [
        FilledButton.tonalIcon(
          onPressed: visible.isEmpty
              ? null
              : () async {
                  final lines = visible
                      .map((r) {
                        final s = r.datumRezervacije.toLocal();
                        final tl = _formatTimeHm(s);
                        final st = r.isOtkazana
                            ? 'otk'
                            : (r.isPotvrdjena ? 'potvrd' : 'ček');
                        final plac = r.isPlacena ? ' plaćeno' : '';
                        final tel = r.korisnikTelefon ?? '—';
                        final em = r.korisnikEmail ?? '—';
                        final rz = r.isOtkazana
                            ? (r.razlogOtkaza ?? '—')
                            : '';
                        final end = r.uslugaTrajanjeMinuta > 0
                            ? _formatTimeHm(
                              s.add(
                                Duration(minutes: r.uslugaTrajanjeMinuta),
                              ),
                            )
                            : '—';
                        return '$tl–$end | ${r.uslugaTrajanjeMinuta} min | '
                            '${r.uslugaCijena.toStringAsFixed(2)} KM | '
                            'ID ${r.id} | kor ${r.korisnikId} | '
                            '${r.uslugaNaziv ?? "usluga"} | '
                            '${r.korisnikIme ?? "—"} | tel $tel | mail $em | '
                            '${r.zaposlenikIme ?? "—"} | '
                            '$st$plac'
                            '${rz.isEmpty ? "" : " | razlog: $rz"}';
                      })
                      .join('\n');
                  final header =
                      '${_calendarDialogDayCaption(widget.day)}\n'
                      '${widget.rowLabel}\n'
                      '---\n';
                  await Clipboard.setData(ClipboardData(text: '$header$lines'));
                  _toast(
                    'U međuspremnik je kopirano ${visible.length} '
                    'stavki (tekstualna lista).',
                  );
                },
          icon: const Icon(Icons.content_copy_outlined, size: 18),
          label: Text('Kopiraj listu (${visible.length})'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Zatvori'),
        ),
      ],
    );
  }
}

class _AdminSuiteState {
  const _AdminSuiteState({
    required this.kpi,
    required this.revenue,
    required this.popularity,
    required this.topSpenders,
  });

  final AdminKpi? kpi;
  final List<RevenuePoint> revenue;
  final List<ServicePopularity> popularity;
  final List<TopSpender> topSpenders;
}

class _AdminSuiteScreenState extends State<AdminSuiteScreen> {
  final ApiService _api = ApiService();
  DateTimeRange _range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );

  Future<_AdminSuiteState>? _overviewFuture;

  // Therapists module
  _TherapistsView _therapistsView = _TherapistsView.availability;
  Future<List<Zaposlenik>>? _therapistsFuture;
  DateTime _weekStart = _startOfWeek(DateTime.now());
  final Map<String, Future<int>> _freeCountCache = {};

  // Calendar (admin)
  Future<List<RezervacijaCalendarItem>>? _calendarFuture;
  bool _includeCancelledInCalendar = false;
  bool _autoRefreshCalendar = true;
  Timer? _calendarTimer;

  void _syncTherapistsViewFromRoute() {
    switch (widget.initialRoute) {
      case AdminSuiteRoute.therapists:
        _therapistsView = _TherapistsView.availability;
        break;
      case AdminSuiteRoute.therapistsCalendar:
        _therapistsView = _TherapistsView.calendar;
        break;
      default:
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    _syncTherapistsViewFromRoute();
    _reloadOverview();
    _reloadTherapists();
    _reloadCalendar();
    _startCalendarTimerIfNeeded();
  }

  @override
  void didUpdateWidget(covariant AdminSuiteScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialRoute != widget.initialRoute) {
      _syncTherapistsViewFromRoute();
      if (widget.initialRoute == AdminSuiteRoute.therapists ||
          widget.initialRoute == AdminSuiteRoute.therapistsCalendar) {
        _reloadCalendar();
      }
      _startCalendarTimerIfNeeded();
    }
  }

  @override
  void dispose() {
    _calendarTimer?.cancel();
    super.dispose();
  }

  void _reloadOverview() {
    final from = DateTime(
      _range.start.year,
      _range.start.month,
      _range.start.day,
    );
    final to = DateTime(_range.end.year, _range.end.month, _range.end.day);
    setState(() {
      _overviewFuture = () async {
        final kpi = await _api.getAdminKpis(date: DateTime.now());
        final revenue = await _api.getRevenueSeries(from: from, to: to);
        final popularity = await _api.getServicePopularity(
          from: from,
          to: to,
          take: 8,
        );
        final top = await _api.getTopSpenders(from: from, to: to, take: 10);
        return _AdminSuiteState(
          kpi: kpi,
          revenue: revenue,
          popularity: popularity,
          topSpenders: top,
        );
      }();
    });
  }

  void _reloadTherapists() {
    setState(() {
      _therapistsFuture = _api.getZaposlenici();
    });
  }

  void _reloadCalendar() {
    final from = _weekStart;
    final to = _weekStart.add(const Duration(days: 6));
    setState(() {
      _calendarFuture = _api.getRezervacijeCalendar(
        from: from,
        to: to,
        includeOtkazane: _includeCancelledInCalendar,
      );
    });
  }

  void _startCalendarTimerIfNeeded() {
    _calendarTimer?.cancel();
    if (!_autoRefreshCalendar) return;
    // “Real-time” MVP: refresh every 20 seconds while screen is open.
    _calendarTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      final inTherapists = widget.initialRoute == AdminSuiteRoute.therapists ||
          widget.initialRoute == AdminSuiteRoute.therapistsCalendar;
      if (!inTherapists) return;
      final calendarMode =
          widget.initialRoute == AdminSuiteRoute.therapistsCalendar ||
              (widget.initialRoute == AdminSuiteRoute.therapists &&
                  _therapistsView == _TherapistsView.calendar);
      if (!calendarMode) return;
      _reloadCalendar();
    });
  }

  static DateTime _startOfWeek(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    // Monday-based week
    final delta = (day.weekday - DateTime.monday) % 7;
    return day.subtract(Duration(days: delta));
  }

  List<DateTime> _weekDays() =>
      List.generate(7, (i) => _weekStart.add(Duration(days: i)));

  String _freeKey(int therapistId, DateTime day) =>
      '$therapistId-${day.year}-${day.month}-${day.day}';

  Future<int> _getFreeSlotsCount(int therapistId, DateTime day) {
    final key = _freeKey(therapistId, day);
    final cached = _freeCountCache[key];
    if (cached != null) return cached;
    final fut = () async {
      final slots = await _api.getDostupniTermini(
        zaposlenikId: therapistId,
        datum: day,
      );
      return slots.length;
    }();
    _freeCountCache[key] = fut;
    return fut;
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      initialDateRange: _range,
    );
    if (picked == null || !mounted) return;
    setState(() => _range = picked);
    _reloadOverview();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
        child: _buildRouteBody(context),
      ),
    );
  }

  Widget _buildRouteBody(BuildContext context) {
    switch (widget.initialRoute) {
      case AdminSuiteRoute.overview:
      case AdminSuiteRoute.finance:
        return _buildOverview(context);
      case AdminSuiteRoute.therapists:
      case AdminSuiteRoute.therapistsCalendar:
        return _buildTherapists(context);
      case AdminSuiteRoute.clients:
        return AdminClientsDesktopScreen(api: _api);
      case AdminSuiteRoute.resources:
        return const AdminResourcesScreen();
      case AdminSuiteRoute.manage:
        return const AdminDashboardScreen();
    }
  }

  Widget _buildOverview(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: 'Dashboard',
          subtitle: 'KPIs, promet i aktivnost (plaćene rezervacije).',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: _pickRange,
                icon: const Icon(Icons.date_range_outlined),
                label: Text(
                  '${_range.start.toLocal().toString().split(' ').first} – '
                  '${_range.end.toLocal().toString().split(' ').first}',
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _reloadOverview,
                icon: const Icon(Icons.refresh),
                label: const Text('Osvježi'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: FutureBuilder<_AdminSuiteState>(
            future: _overviewFuture,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = snap.data;
              if (data == null) {
                return const Center(child: Text('Nema podataka.'));
              }

              return LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth >= 1100;
                  return SingleChildScrollView(
                    primary: false,
                    child: Column(
                      children: [
                        _KpiRow(kpi: data.kpi),
                        const SizedBox(height: 14),
                        wide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 7,
                                    child: _RevenueCard(points: data.revenue),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    flex: 5,
                                    child: _PopularityCard(
                                      items: data.popularity,
                                      topSpenders: data.topSpenders,
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  _RevenueCard(points: data.revenue),
                                  const SizedBox(height: 14),
                                  _PopularityCard(
                                    items: data.popularity,
                                    topSpenders: data.topSpenders,
                                  ),
                                ],
                              ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTherapists(BuildContext context) {
    final days = _weekDays();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: 'Terapeuti i raspored',
          subtitle: _therapistsView == _TherapistsView.availability
              ? 'Kartice terapeuta + sedmična dostupnost (slobodni slotovi).'
              : 'Kalendar zauzetosti (rezervisani termini) u realnom vremenu.',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<_TherapistsView>(
                segments: const [
                  ButtonSegment(
                    value: _TherapistsView.availability,
                    label: Text('Dostupnost'),
                    icon: Icon(Icons.grid_view_rounded),
                  ),
                  ButtonSegment(
                    value: _TherapistsView.calendar,
                    label: Text('Kalendar'),
                    icon: Icon(Icons.calendar_month_outlined),
                  ),
                ],
                selected: {_therapistsView},
                onSelectionChanged: (s) {
                  setState(() => _therapistsView = s.first);
                  if (_therapistsView == _TherapistsView.calendar) {
                    _reloadCalendar();
                  }
                  _startCalendarTimerIfNeeded();
                },
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () => setState(() {
                  _weekStart = _weekStart.subtract(const Duration(days: 7));
                  _reloadCalendar();
                }),
                icon: const Icon(Icons.chevron_left_rounded),
                label: const Text('Prethodna'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () => setState(() {
                  _weekStart = _weekStart.add(const Duration(days: 7));
                  _reloadCalendar();
                }),
                icon: const Icon(Icons.chevron_right_rounded),
                label: const Text('Sljedeća'),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: () {
                  _freeCountCache.clear();
                  _reloadTherapists();
                  _reloadCalendar();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Osvježi'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: FutureBuilder<List<Zaposlenik>>(
            future: _therapistsFuture,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final list = snap.data ?? [];
              if (list.isEmpty) {
                return const Center(child: Text('Nema terapeuta.'));
              }

              if (_therapistsView == _TherapistsView.calendar) {
                return _AdminCalendarView(
                  therapists: list,
                  days: days,
                  calendarFuture: _calendarFuture,
                  includeCancelled: _includeCancelledInCalendar,
                  autoRefresh: _autoRefreshCalendar,
                  onToggleCancelled: (v) {
                    setState(() => _includeCancelledInCalendar = v);
                    _reloadCalendar();
                  },
                  onToggleAutoRefresh: (v) {
                    setState(() => _autoRefreshCalendar = v);
                    _startCalendarTimerIfNeeded();
                  },
                );
              }

              return LayoutBuilder(
                builder: (context, c) {
                  final w = c.maxWidth;
                  final crossAxisCount = w >= 1400 ? 3 : (w >= 980 ? 2 : 1);
                  return GridView.builder(
                    primary: false,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.9,
                    ),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      return _TherapistCard(
                        therapist: list[i],
                        days: days,
                        getFreeSlotsCount: _getFreeSlotsCount,
                        onOpenDay: (t, d) async {
                          final slots = await _api.getDostupniTermini(
                            zaposlenikId: t.id,
                            datum: d,
                          );
                          if (!context.mounted) return;
                          showDialog<void>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(
                                '${t.ime} ${t.prezime} · '
                                '${d.toLocal().toString().split(' ').first}',
                              ),
                              content: SizedBox(
                                width: 520,
                                child: slots.isEmpty
                                    ? const Text('Nema slobodnih termina.')
                                    : Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: slots
                                            .map(
                                              (s) => Chip(
                                                label: Text(
                                                  s
                                                      .toLocal()
                                                      .toString()
                                                      .split(' ')
                                                      .last
                                                      .substring(0, 5),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                      ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Zatvori'),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TherapistCard extends StatelessWidget {
  const _TherapistCard({
    required this.therapist,
    required this.days,
    required this.getFreeSlotsCount,
    required this.onOpenDay,
  });

  final Zaposlenik therapist;
  final List<DateTime> days;
  final Future<int> Function(int therapistId, DateTime day) getFreeSlotsCount;
  final Future<void> Function(Zaposlenik therapist, DateTime day) onOpenDay;

  List<String> _tags(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return const [];
    return t
        .split(RegExp(r'[,;/]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(4)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final name = '${therapist.ime} ${therapist.prezime}'.trim();
    final tags = _tags(therapist.specijalizacija);
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: scheme.primary.withValues(alpha: 0.12),
              child: Icon(
                Icons.person_outline_rounded,
                color: scheme.primary.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: Theme.of(context).textTheme.titleLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Tooltip(
                        message: 'Otvori profil terapeuta',
                        child: IconButton(
                          onPressed: () {
                            Navigator.push<void>(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => AdminTherapistProfileScreen(
                                  therapist: therapist,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.open_in_new_rounded),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.10),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_border_rounded, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              '—',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final t in tags)
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.secondary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: scheme.secondary.withValues(alpha: 0.22),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: Text(
                              t,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                          ),
                        ),
                      if (tags.isEmpty)
                        Text(
                          'Specijalizacija nije postavljena.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.calendar_month_outlined, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Dostupnost (sedmica)',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _MiniWeekGrid(
                    therapistId: therapist.id,
                    days: days,
                    getFreeSlotsCount: getFreeSlotsCount,
                    onOpenDay: (d) => onOpenDay(therapist, d),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniWeekGrid extends StatelessWidget {
  const _MiniWeekGrid({
    required this.therapistId,
    required this.days,
    required this.getFreeSlotsCount,
    required this.onOpenDay,
  });

  final int therapistId;
  final List<DateTime> days;
  final Future<int> Function(int therapistId, DateTime day) getFreeSlotsCount;
  final Future<void> Function(DateTime day) onOpenDay;

  String _dayLabel(DateTime d) {
    const names = ['Pon', 'Uto', 'Sri', 'Čet', 'Pet', 'Sub', 'Ned'];
    return names[(d.weekday - 1).clamp(0, 6)];
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final d in days)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InkWell(
                onTap: () => onOpenDay(d),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _dayLabel(d),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.70),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FutureBuilder<int>(
                        future: getFreeSlotsCount(therapistId, d),
                        builder: (context, snap) {
                          final v = snap.data;
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            );
                          }
                          return Text(
                            v == null ? '—' : '$v',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'slots',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AdminCalendarView extends StatelessWidget {
  const _AdminCalendarView({
    required this.therapists,
    required this.days,
    required this.calendarFuture,
    required this.includeCancelled,
    required this.autoRefresh,
    required this.onToggleCancelled,
    required this.onToggleAutoRefresh,
  });

  final List<Zaposlenik> therapists;
  final List<DateTime> days;
  final Future<List<RezervacijaCalendarItem>>? calendarFuture;
  final bool includeCancelled;
  final bool autoRefresh;
  final ValueChanged<bool> onToggleCancelled;
  final ValueChanged<bool> onToggleAutoRefresh;

  String _dayHeader(DateTime d) {
    const names = ['Pon', 'Uto', 'Sri', 'Čet', 'Pet', 'Sub', 'Ned'];
    return '${names[(d.weekday - 1).clamp(0, 6)]}\n${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            FilterChip(
              label: const Text('Uključi otkazane'),
              selected: includeCancelled,
              onSelected: onToggleCancelled,
            ),
            const SizedBox(width: 10),
            FilterChip(
              label: const Text('Auto refresh (20s)'),
              selected: autoRefresh,
              onSelected: onToggleAutoRefresh,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: FutureBuilder<List<RezervacijaCalendarItem>>(
            future: calendarFuture,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cloud_off_rounded,
                          size: 48,
                          color: Theme.of(
                            context,
                          ).colorScheme.error.withValues(alpha: 0.85),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Ne možemo učitati kalendar',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          '${snap.error}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.75),
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }
              final items = snap.data ?? const <RezervacijaCalendarItem>[];
              final byTherapist = <int, List<RezervacijaCalendarItem>>{};
              for (final it in items) {
                byTherapist.putIfAbsent(it.zaposlenikId, () => []).add(it);
              }

              return Card(
                child: SingleChildScrollView(
                  primary: false,
                  child: DataTable(
                    columnSpacing: 18,
                    columns: [
                      const DataColumn(label: Text('Terapeut')),
                      for (final d in days)
                        DataColumn(
                          label: Text(
                            _dayHeader(d),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                    rows: [
                      for (final t in therapists)
                        DataRow(
                          cells: [
                            DataCell(Text('${t.ime} ${t.prezime}')),
                            for (final d in days)
                              _buildCalendarCell(
                                context,
                                rowLabel: '${t.ime} ${t.prezime}'.trim(),
                                day: d,
                                items: byTherapist[t.id] ?? const [],
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  DataCell _buildCalendarCell(
    BuildContext context, {
    required String rowLabel,
    required DateTime day,
    required List<RezervacijaCalendarItem> items,
  }) {
    final list =
        items
            .where(
              (e) =>
                  e.datumRezervacije.year == day.year &&
                  e.datumRezervacije.month == day.month &&
                  e.datumRezervacije.day == day.day,
            )
            .toList()
          ..sort((a, b) => a.datumRezervacije.compareTo(b.datumRezervacije));

    final count = list.length;

    Color color;
    if (count == 0) {
      color = Colors.white.withValues(alpha: 0.04);
    } else if (count <= 2) {
      color = Colors.green.withValues(alpha: 0.12);
    } else if (count <= 4) {
      color = Colors.orange.withValues(alpha: 0.14);
    } else {
      color = Colors.redAccent.withValues(alpha: 0.14);
    }

    final dayCap = _calendarDialogDayCaption(day);

    return DataCell(
      Tooltip(
        message: count == 0
            ? 'Nema termina za $dayCap'
            : '$count termina za $dayCap — klik za detalje, pretragu i izvoz',
        waitDuration: const Duration(milliseconds: 400),
        child: Semantics(
          button: true,
          enabled: count > 0,
          label: count == 0
              ? 'Ćelija kalendara, nema termina'
              : '$count termina, $rowLabel, $dayCap',
          child: InkWell(
            onTap: count == 0
                ? null
                : () {
                    showDialog<void>(
                      context: context,
                      builder: (_) => _CalendarDayBookingDialog(
                        day: day,
                        rowLabel: rowLabel,
                        items: list,
                        dismissContext: context,
                      ),
                    );
                  },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Text(
                count == 0 ? '—' : '$count',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.kpi});

  final AdminKpi? kpi;

  @override
  Widget build(BuildContext context) {
    final items = [
      _KpiTile(
        label: 'Rezervacije (ukupno)',
        value: '${kpi?.ukupnoRezervacija ?? '—'}',
        icon: Icons.event_note_outlined,
      ),
      _KpiTile(
        label: 'Rezervacije (danas)',
        value: '${kpi?.rezervacijeDanas ?? '—'}',
        icon: Icons.today_outlined,
      ),
      _KpiTile(
        label: 'Prihod (danas)',
        value: kpi == null ? '—' : '${kpi!.prihodDanas.toStringAsFixed(0)} KM',
        icon: Icons.payments_outlined,
      ),
      _KpiTile(
        label: 'Aktivni terapeuti',
        value: '${kpi?.aktivniTerapeuti ?? '—'}',
        icon: Icons.groups_2_outlined,
      ),
      _KpiTile(
        label: 'Ocjena zadovoljstva',
        value: kpi == null ? '—' : kpi!.prosjecnaOcjena.toStringAsFixed(2),
        icon: Icons.star_border_rounded,
      ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final cols = w >= 1200 ? 5 : (w >= 950 ? 3 : 2);
        const gap = 12.0;
        final tileW = (w - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: items
              .map((it) => SizedBox(width: tileW, child: it))
              .toList(),
        );
      },
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.70),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevenueCard extends StatelessWidget {
  const _RevenueCard({required this.points});

  final List<RevenuePoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final data = points;

    final spots = <FlSpot>[];
    for (var i = 0; i < data.length; i++) {
      spots.add(FlSpot(i.toDouble(), data[i].prihod));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Prihod kroz vrijeme', style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Plaćene rezervacije (KM)',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.70)),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 260,
              child: data.isEmpty
                  ? const Center(child: Text('Nema podataka za period.'))
                  : LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: true),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            color: primary,
                            barWidth: 2,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: primary.withValues(alpha: 0.15),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PopularityCard extends StatelessWidget {
  const _PopularityCard({required this.items, required this.topSpenders});

  final List<ServicePopularity> items;
  final List<TopSpender> topSpenders;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = [
      theme.colorScheme.primary,
      theme.colorScheme.secondary,
      theme.colorScheme.tertiary,
      Colors.purpleAccent,
      Colors.deepPurpleAccent,
      Colors.tealAccent,
    ];

    final total = items.fold<int>(0, (sum, e) => sum + e.brojRezervacija);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Popularnost usluga', style: theme.textTheme.titleLarge),
            const SizedBox(height: 14),
            SizedBox(
              height: 180,
              child: items.isEmpty
                  ? const Center(child: Text('Nema podataka.'))
                  : PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 44,
                        sections: [
                          for (var i = 0; i < items.length; i++)
                            PieChartSectionData(
                              value: items[i].brojRezervacija.toDouble(),
                              color: colors[i % colors.length],
                              title: '',
                              radius: 52,
                            ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 10),
            ...items.take(6).map((e) {
              final pct = total == 0 ? 0 : (e.brojRezervacija / total * 100);
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        e.naziv,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text('${pct.toStringAsFixed(0)}%'),
                  ],
                ),
              );
            }),
            const Divider(height: 22),
            Text('Top Spenders', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (topSpenders.isEmpty)
              const Text('Nema podataka.')
            else
              ...topSpenders
                  .take(6)
                  .map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              t.imePrezime,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text('${t.ukupnoPotroseno.toStringAsFixed(0)} KM'),
                        ],
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
