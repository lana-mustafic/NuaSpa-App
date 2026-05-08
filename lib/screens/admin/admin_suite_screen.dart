import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/api/services/api_service.dart';
import '../../models/admin/admin_client_row.dart';
import '../../models/admin/admin_kpi.dart';
import '../../models/admin/revenue_point.dart';
import '../../models/admin/service_popularity.dart';
import '../../models/admin/top_spender.dart';
import '../../models/admin/rezervacija_calendar_item.dart';
import '../../models/zaposlenik.dart';
import '../../ui/widgets/page_header.dart';
import 'admin_dashboard_screen.dart';
import 'admin_therapist_profile_screen.dart';

class AdminSuiteScreen extends StatefulWidget {
  const AdminSuiteScreen({super.key});

  @override
  State<AdminSuiteScreen> createState() => _AdminSuiteScreenState();
}

enum _AdminSuiteTab { overview, therapists, finance, clients, manage }
enum _TherapistsView { availability, calendar }

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
  _AdminSuiteTab _tab = _AdminSuiteTab.overview;
  DateTimeRange _range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );

  Future<_AdminSuiteState>? _overviewFuture;

  final TextEditingController _clientSearch = TextEditingController();
  Future<List<AdminClientRow>>? _clientsFuture;
  AdminClientRow? _selectedClient;

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

  @override
  void initState() {
    super.initState();
    _reloadOverview();
    _reloadClients();
    _reloadTherapists();
    _reloadCalendar();
    _startCalendarTimerIfNeeded();
  }

  @override
  void dispose() {
    _calendarTimer?.cancel();
    _clientSearch.dispose();
    super.dispose();
  }

  void _reloadOverview() {
    final from = DateTime(_range.start.year, _range.start.month, _range.start.day);
    final to = DateTime(_range.end.year, _range.end.month, _range.end.day);
    setState(() {
      _overviewFuture = () async {
        final kpi = await _api.getAdminKpis(date: DateTime.now());
        final revenue = await _api.getRevenueSeries(from: from, to: to);
        final popularity = await _api.getServicePopularity(from: from, to: to, take: 8);
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

  void _reloadClients() {
    setState(() {
      _clientsFuture = _api.getAdminClients(q: _clientSearch.text, take: 400);
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
      if (_tab != _AdminSuiteTab.therapists) return;
      if (_therapistsView != _TherapistsView.calendar) return;
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
        padding: const EdgeInsets.fromLTRB(26, 22, 26, 26),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NavigationRail(
              selectedIndex: _tab.index,
              onDestinationSelected: (i) =>
                  setState(() => _tab = _AdminSuiteTab.values[i]),
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.space_dashboard_outlined),
                  label: Text('Dashboard'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.groups_2_outlined),
                  label: Text('Terapeuti'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.show_chart_rounded),
                  label: Text('Finansije'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.people_outline),
                  label: Text('Klijenti'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.admin_panel_settings_outlined),
                  label: Text('Upravljanje'),
                ),
              ],
            ),
            const SizedBox(width: 18),
            Expanded(
              child: IndexedStack(
                index: _tab.index,
                children: [
                  _buildOverview(context),
                  _buildTherapists(context),
                  _buildFinance(context),
                  _buildClients(context),
                  const AdminDashboardScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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

  Widget _buildFinance(BuildContext context) {
    return _buildOverview(context);
  }

  Widget _buildClients(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: 'Klijenti',
          subtitle: 'Pretraga, posjete i VIP status.',
          trailing: SizedBox(
            width: 380,
            child: TextField(
              controller: _clientSearch,
              onChanged: (_) => _reloadClients(),
              decoration: const InputDecoration(
                hintText: 'Pretraži klijente (ime, email, username)…',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 7,
                child: FutureBuilder<List<AdminClientRow>>(
                  future: _clientsFuture,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final list = snap.data ?? [];
                    if (list.isEmpty) {
                      return const Center(child: Text('Nema rezultata.'));
                    }
                    _selectedClient ??= list.first;

                    return Card(
                      child: SingleChildScrollView(
                        primary: false,
                        child: DataTable(
                          showCheckboxColumn: false,
                          columns: const [
                            DataColumn(label: Text('Klijent')),
                            DataColumn(label: Text('VIP')),
                            DataColumn(label: Text('Posjete')),
                            DataColumn(label: Text('Potrošnja')),
                            DataColumn(label: Text('Zadnja posjeta')),
                          ],
                          rows: list.map((c) {
                            final selected = _selectedClient?.id == c.id;
                            return DataRow(
                              selected: selected,
                              onSelectChanged: (_) =>
                                  setState(() => _selectedClient = c),
                              cells: [
                                DataCell(Text(c.punoIme)),
                                DataCell(
                                  c.isVip
                                      ? const Icon(Icons.workspace_premium_outlined)
                                      : const SizedBox.shrink(),
                                ),
                                DataCell(Text('${c.ukupnoPosjeta}')),
                                DataCell(Text('${c.ukupnoPotroseno.toStringAsFixed(0)} KM')),
                                DataCell(Text(
                                  c.zadnjaPosjeta == null
                                      ? '—'
                                      : c.zadnjaPosjeta!
                                          .toLocal()
                                          .toString()
                                          .split('.')
                                          .first,
                                )),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 4,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _selectedClient == null
                        ? const Center(child: Text('Odaberi klijenta.'))
                        : _ClientDetails(client: _selectedClient!),
                  ),
                ),
              ),
            ],
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
                  final crossAxisCount = w >= 1400
                      ? 3
                      : (w >= 980 ? 2 : 1);
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
                                            .map((s) => Chip(
                                                  label: Text(
                                                    s.toLocal()
                                                        .toString()
                                                        .split(' ')
                                                        .last
                                                        .substring(0, 5),
                                                  ),
                                                ))
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
                    border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
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
                        DataColumn(label: Text(_dayHeader(d), textAlign: TextAlign.center)),
                    ],
                    rows: [
                      for (final t in therapists)
                        DataRow(
                          cells: [
                            DataCell(
                              Text('${t.ime} ${t.prezime}'),
                            ),
                            for (final d in days)
                              _buildCalendarCell(
                                context,
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
    required DateTime day,
    required List<RezervacijaCalendarItem> items,
  }) {
    final list = items
        .where((e) =>
            e.datumRezervacije.year == day.year &&
            e.datumRezervacije.month == day.month &&
            e.datumRezervacije.day == day.day)
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

    return DataCell(
      InkWell(
        onTap: count == 0
            ? null
            : () {
                showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(
                      '${day.toLocal().toString().split(' ').first} · $count termina',
                    ),
                    content: SizedBox(
                      width: 680,
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final r = list[i];
                          final time = r.datumRezervacije
                              .toLocal()
                              .toString()
                              .split(' ')
                              .last
                              .substring(0, 5);
                          final status = r.isOtkazana
                              ? 'Otkazana'
                              : (r.isPotvrdjena ? 'Potvrđena' : 'Na čekanju');
                          return ListTile(
                            dense: true,
                            title: Text('$time · ${r.uslugaNaziv ?? 'Usluga'}'),
                            subtitle: Text(r.korisnikIme ?? ''),
                            trailing: Chip(label: Text(status)),
                          );
                        },
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
          children: items.map((it) => SizedBox(width: tileW, child: it)).toList(),
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
  const _PopularityCard({
    required this.items,
    required this.topSpenders,
  });

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
              ...topSpenders.take(6).map((t) => Padding(
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
                  )),
          ],
        ),
      ),
    );
  }
}

class _ClientDetails extends StatelessWidget {
  const _ClientDetails({required this.client});

  final AdminClientRow client;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(client.punoIme, style: tt.titleLarge),
        const SizedBox(height: 8),
        Text(client.email, style: TextStyle(color: Colors.white.withValues(alpha: 0.75))),
        const SizedBox(height: 4),
        Text(client.telefon.isEmpty ? '—' : client.telefon,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.75))),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _InfoChip(label: 'VIP', value: client.isVip ? 'Da' : 'Ne'),
            _InfoChip(label: 'Posjete', value: '${client.ukupnoPosjeta}'),
            _InfoChip(
              label: 'Potrošnja',
              value: '${client.ukupnoPotroseno.toStringAsFixed(0)} KM',
            ),
            _InfoChip(
              label: 'Zadnja posjeta',
              value: client.zadnjaPosjeta == null
                  ? '—'
                  : client.zadnjaPosjeta!.toLocal().toString().split('.').first,
            ),
          ],
        ),
        const Spacer(),
        FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.notes_outlined),
          label: const Text('Preference (uskoro)'),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.70)),
            ),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

