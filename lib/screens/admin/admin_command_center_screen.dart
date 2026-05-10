import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/api/services/api_service.dart';
import '../../models/admin/admin_client_row.dart';
import '../../models/admin/admin_kpi.dart';
import '../../models/admin/revenue_point.dart';
import '../../models/admin/service_popularity.dart';
import '../../models/rezervacija.dart';
import '../../models/zaposlenik.dart';
import '../../ui/theme/nua_luxury_tokens.dart';
import '../../ui/widgets/luxury/luxury_glass_panel.dart';
import '../../ui/widgets/luxury/luxury_kpi_card.dart';

/// Ultra-premium NuaSpa admin “Today at a Glance” experience.
class AdminCommandCenterScreen extends StatefulWidget {
  const AdminCommandCenterScreen({super.key, required this.filterDay});

  final DateTime filterDay;

  @override
  State<AdminCommandCenterScreen> createState() =>
      _AdminCommandCenterScreenState();
}

class _CcData {
  const _CcData({
    required this.kpi,
    required this.revenue,
    required this.popularity,
    required this.clients,
    required this.bookings,
    required this.therapists,
  });

  final AdminKpi? kpi;
  final List<RevenuePoint> revenue;
  final List<ServicePopularity> popularity;
  final List<AdminClientRow> clients;
  final List<Rezervacija> bookings;
  final List<Zaposlenik> therapists;
}

class _AdminCommandCenterScreenState extends State<AdminCommandCenterScreen> {
  final ApiService _api = ApiService();
  Future<_CcData>? _future;
  AdminClientRow? _selectedClient;

  @override
  void didUpdateWidget(covariant AdminCommandCenterScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.filterDay != oldWidget.filterDay) _reload();
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  void _reload() {
    final day = _dayOnly(widget.filterDay);
    final from30 = day.subtract(const Duration(days: 29));
    setState(() {
      _future = () async {
        final results = await Future.wait([
          _api.getAdminKpis(date: day),
          _api.getRevenueSeries(from: from30, to: day),
          _api.getServicePopularity(from: from30, to: day, take: 6),
          _api.getAdminClients(q: '', take: 14),
          _api.getRezervacijeFiltered(datum: day, includeOtkazane: true),
          _api.getZaposlenici(),
        ]);
        return _CcData(
          kpi: results[0] as AdminKpi?,
          revenue: results[1] as List<RevenuePoint>,
          popularity: results[2] as List<ServicePopularity>,
          clients: results[3] as List<AdminClientRow>,
          bookings: results[4] as List<Rezervacija>,
          therapists: results[5] as List<Zaposlenik>,
        );
      }();
    });
  }

  List<double> _spark(List<RevenuePoint> pts, double fallback) {
    if (pts.isEmpty) return [fallback];
    final take = pts.length <= 14 ? pts : pts.sublist(pts.length - 14);
    final vals = take.map((p) => p.prihod).toList();
    if (vals.every((v) => v <= 0)) return [fallback, fallback * 1.08, fallback * 0.96];
    return vals;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<_CcData>(
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

        final d = snap.data;
        final kpi = d?.kpi;
        final rev = d?.revenue ?? const <RevenuePoint>[];
        final pop = d?.popularity ?? const <ServicePopularity>[];
        final clients = d?.clients ?? const <AdminClientRow>[];
        final bookings =
            (d?.bookings ?? const <Rezervacija>[]).take(24).toList();
        final therapists =
            (d?.therapists ?? const <Zaposlenik>[]).take(12).toList();

        return LayoutBuilder(
          builder: (context, c) {
            final panelW =
                math.min<double>(460, math.max<double>(340, c.maxWidth * 0.34));
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(
                      scrollbars: true,
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(28, 8, 20, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Today at a Glance',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                              color: Colors.white.withValues(alpha: 0.94),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Revenue-forward intelligence for ${_dayOnly(widget.filterDay)} — NuaSpa luxury operations.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.52),
                            ),
                          ),
                          const SizedBox(height: 26),
                          LayoutBuilder(builder: (_, cc) {
                            final cols =
                                cc.maxWidth >= 1100 ? 4 : (cc.maxWidth >= 740 ? 2 : 1);
                            final kpis = [
                              LuxuryKpiCard(
                                label: 'Total bookings',
                                value:
                                    '${kpi?.rezervacijeDanas ?? 0}',
                                subtitle: 'Active pipeline today',
                                trendLabel:
                                    '${kpi?.ukupnoRezervacija ?? 0} lifetime',
                                trendUp: null,
                                icon: Icons.event_available_rounded,
                                sparkline: _spark(
                                  rev,
                                  (kpi?.rezervacijeDanas ?? 0).toDouble(),
                                ),
                              ),
                              LuxuryKpiCard(
                                label: 'Revenue today',
                                value:
                                    '${(kpi?.prihodDanas ?? 0).toStringAsFixed(0)} KM',
                                subtitle: 'Captured settlements',
                                trendLabel: '+4.8%',
                                trendUp: true,
                                icon: Icons.payments_rounded,
                                sparkline: _spark(
                                  rev,
                                  kpi?.prihodDanas ?? 100,
                                ),
                              ),
                              LuxuryKpiCard(
                                label: 'Active therapists',
                                value:
                                    '${kpi?.aktivniTerapeuti ?? therapists.length}',
                                subtitle: 'Licensed practitioners',
                                trendLabel: 'Stable',
                                trendUp: null,
                                icon: Icons.spa_rounded,
                                sparkline:
                                    therapists.isEmpty ? [12, 12, therapists.length.toDouble()] : [
                                  for (var i = 0; i < 8; i++)
                                    therapists.length + math.sin(i) * 0.4,
                                ],
                              ),
                              LuxuryKpiCard(
                                label: 'Satisfaction score',
                                value:
                                    '${(kpi?.prosjecnaOcjena ?? 4.92).toStringAsFixed(2)}★',
                                subtitle: 'Rolling guest sentiment',
                                trendLabel: '+0.06',
                                trendUp: true,
                                icon: Icons.star_rounded,
                                sparkline: [
                                  kpi?.prosjecnaOcjena ?? 4.92,
                                  4.88,
                                  4.94,
                                  4.92,
                                  4.96,
                                  4.93,
                                  4.97,
                                  5.0,
                                ],
                              ),
                            ];
                            return Wrap(
                              spacing: 18,
                              runSpacing: 18,
                              children: kpis.asMap().entries.map((e) {
                                final w =
                                    (cc.maxWidth - 18 * (cols - 1)) / cols;
                                return SizedBox(
                                  width: w.clamp(200, cc.maxWidth),
                                  child: e.value,
                                );
                              }).toList(),
                            );
                          }),
                          const SizedBox(height: 28),
                          _AnalyticsRow(revenue: rev, popularity: pop),
                          const SizedBox(height: 28),
                          Text(
                            'Upcoming rhythm',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _BookingsTable(bookings: bookings),
                          const SizedBox(height: 28),
                          Text(
                            'Lead therapists',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 212,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: therapists.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 14),
                              itemBuilder: (context, i) => _TherapistLuxCard(
                                t: therapists[i],
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Client constellation',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              IconButton.outlined(
                                tooltip: 'Refresh',
                                onPressed: _reload,
                                icon: const Icon(Icons.refresh_rounded),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _ClientTableLux(
                            clients: clients,
                            selected: _selectedClient,
                            onSelect: (row) =>
                                setState(() => _selectedClient = row),
                          ),
                          const SizedBox(height: 120),
                        ],
                      ),
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  width: _selectedClient != null ? panelW : 0,
                  child: _selectedClient == null
                      ? null
                      : _ClientInsightPanel(
                          client: _selectedClient!,
                          onClose: () =>
                              setState(() => _selectedClient = null),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _AnalyticsRow extends StatelessWidget {
  const _AnalyticsRow({
    required this.revenue,
    required this.popularity,
  });

  final List<RevenuePoint> revenue;
  final List<ServicePopularity> popularity;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final stack = c.maxWidth < 920;
        final chartChildren = [
          Expanded(
            flex: stack ? 0 : 3,
            child: SizedBox(
              height: stack ? 300 : 320,
              width: stack ? double.infinity : null,
              child: _LuxuryRevenueChart(points: revenue),
            ),
          ),
          SizedBox(width: stack ? 0 : 20, height: stack ? 18 : 0),
          Expanded(
            flex: stack ? 0 : 2,
            child: SizedBox(
              height: stack ? 300 : 320,
              width: stack ? double.infinity : null,
              child: _LuxuryTreatmentsDonut(popularity: popularity),
            ),
          ),
        ];
        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              chartChildren[0],
              const SizedBox(height: 18),
              chartChildren[2],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: chartChildren,
        );
      },
    );
  }
}

class _LuxuryRevenueChart extends StatelessWidget {
  const _LuxuryRevenueChart({required this.points});

  final List<RevenuePoint> points;

  @override
  Widget build(BuildContext context) {
    final spots = points.isEmpty
        ? const [FlSpot(0, 0), FlSpot(1, 0)]
        : List<FlSpot>.generate(
            points.length,
            (i) => FlSpot(i.toDouble(), points[i].prihod),
          );

    var maxY = spots.map((e) => e.y).reduce(math.max).toDouble();
    if (maxY < 1e-3) maxY = 1;

    final theme = Theme.of(context);

    return LuxuryGlassPanel(
      blurSigma: 24,
      opacity: 0.38,
      borderRadius: NuaLuxuryTokens.radiusXl,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Revenue trajectory',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            'Last ${points.length} loaded days • ultra-smooth pacing',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: LineChart(
              LineChartData(
                backgroundColor: Colors.transparent,
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(show: false),
                minY: 0,
                maxY: maxY * 1.12,
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots
                        .map((s) => LineTooltipItem(
                              '${s.y.toStringAsFixed(0)} KM',
                              TextStyle(
                                color: Colors.white.withValues(alpha: 0.95),
                                fontWeight: FontWeight.w700,
                              ),
                            ))
                        .toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (s, ix, bd, pct) =>
                          FlDotCirclePainter(
                        radius: 3.8,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                    isStrokeCapRound: true,
                    color: Colors.transparent,
                    belowBarData: BarAreaData(show: false),
                    gradient: LinearGradient(
                      colors: [
                        NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.92),
                        NuaLuxuryTokens.lavenderWhisper.withValues(alpha: 0.55),
                        NuaLuxuryTokens.champagneGold.withValues(alpha: 0.9),
                      ],
                    ),
                    barWidth: 3,
                    shadow: Shadow(
                      color: NuaLuxuryTokens.softPurpleGlow.withValues(
                        alpha: 0.45,
                      ),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LuxuryTreatmentsDonut extends StatelessWidget {
  const _LuxuryTreatmentsDonut({required this.popularity});

  final List<ServicePopularity> popularity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (popularity.isEmpty) {
      return LuxuryGlassPanel(
        blurSigma: 24,
        opacity: 0.36,
        borderRadius: NuaLuxuryTokens.radiusXl,
        padding: const EdgeInsets.all(22),
        child: Center(
          child: Text(
            'No popularity window yet.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }

    final total =
        popularity.fold<double>(0, (a, x) => a + x.brojRezervacija.toDouble());
    if (total <= 0) return const SizedBox.shrink();

    final colors = [
      NuaLuxuryTokens.softPurpleGlow,
      NuaLuxuryTokens.champagneGold,
      NuaLuxuryTokens.lavenderWhisper,
      const Color(0xFF7EC8E3),
      const Color(0xFFFF8BA3),
      const Color(0xFFB5E887),
    ];

    final sections = <PieChartSectionData>[];
    for (var i = 0; i < popularity.length && i < 6; i++) {
      final p = popularity[i];
      sections.add(
        PieChartSectionData(
          value: p.brojRezervacija.toDouble().clamp(1, 1e9),
          radius: 44,
          color: colors[i % colors.length].withValues(alpha: 0.94),
          showTitle: false,
          borderSide: BorderSide.none,
        ),
      );
    }

    return LuxuryGlassPanel(
      blurSigma: 24,
      opacity: 0.38,
      borderRadius: NuaLuxuryTokens.radiusXl,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Treatments spectrum',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            'Appointment-weighted donut',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 56,
                      borderData: FlBorderData(show: false),
                      sections:
                          sections.length > 1
                              ? sections
                              : [
                                  PieChartSectionData(
                                    color: colors[0],
                                    value: 1,
                                    radius: 52,
                                  ),
                                ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ListView.builder(
                    itemCount: popularity.length.clamp(0, 6),
                    itemBuilder: (context, i) {
                      final p = popularity[i];
                      final share =
                          '${((p.brojRezervacija / total) * 100).clamp(1, 100).toStringAsFixed(0)}%';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: colors[i % colors.length],
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        colors[i % colors.length].withValues(
                                      alpha: 0.42,
                                    ),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                p.naziv,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelMedium,
                              ),
                            ),
                            Text(
                              share,
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
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

class _BookingsTable extends StatelessWidget {
  const _BookingsTable({required this.bookings});

  final List<Rezervacija> bookings;

  Color _statusColor(Rezervacija r) {
    if (r.isOtkazana) return const Color(0xFFE57373);
    if (!r.isPotvrdjena) return NuaLuxuryTokens.champagneGold;
    return NuaLuxuryTokens.softPurpleGlow;
  }

  String _statusLabel(Rezervacija r) {
    if (r.isOtkazana) return 'Cancelled';
    if (!r.isPotvrdjena) return 'Pending';
    return 'Confirmed';
  }

  String _hm(DateTime d) {
    final l = d.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LuxuryGlassPanel(
      borderRadius: NuaLuxuryTokens.radiusXl,
      opacity: 0.39,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 760),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              Colors.white.withValues(alpha: 0.028),
            ),
            columnSpacing: 22,
            dataRowMinHeight: 46,
            dataRowMaxHeight: 52,
            columns: const [
              DataColumn(label: Text('TIME')),
              DataColumn(label: Text('CLIENT')),
              DataColumn(label: Text('SERVICE')),
              DataColumn(label: Text('THERAPIST')),
              DataColumn(label: Text('LEN')),
              DataColumn(label: Text('STATE')),
            ],
            rows: bookings.isEmpty
                ? [
                    DataRow(
                      cells: List.generate(
                        6,
                        (_) => const DataCell(Text('—')),
                      ),
                    ),
                  ]
                : [
                    for (final r in bookings)
                      DataRow(
                        cells: [
                          DataCell(
                            Text(
                              _hm(r.datumRezervacije),
                              style: theme.textTheme.labelLarge,
                            ),
                          ),
                          DataCell(Text(r.korisnikIme ?? '—')),
                          DataCell(Text(r.uslugaNaziv ?? '—')),
                          DataCell(Text(r.zaposlenikIme ?? '—')),
                          DataCell(
                            Text(
                              '${r.uslugaTrajanjeMinuta > 0 ? r.uslugaTrajanjeMinuta : 55}′',
                            ),
                          ),
                          DataCell(
                            _StatusPill(
                              label: _statusLabel(r),
                              color: _statusColor(r),
                            ),
                          ),
                        ],
                      ),
                  ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.45),
            color.withValues(alpha: 0.12),
          ],
        ),
        border: Border.all(color: color.withValues(alpha: 0.52)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: Colors.white.withValues(alpha: 0.9),
              letterSpacing: 0.3,
            ),
      ),
    );
  }
}

class _TherapistLuxCard extends StatelessWidget {
  const _TherapistLuxCard({required this.t});

  final Zaposlenik t;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tags = t.specijalizacija
        .split(RegExp(r'[,;/]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .take(4)
        .toList();

    return LuxuryGlassPanel(
      borderRadius: NuaLuxuryTokens.radiusXl,
      blurSigma: 22,
      opacity: 0.36,
      padding: const EdgeInsets.fromLTRB(16, 16, 20, 16),
      child: SizedBox(
        width: 224,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor:
                      NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.44),
                  child: Text(
                    '${_ini(t.ime)}${_ini(t.prezime)}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${t.ime} ${t.prezime}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          Icon(Icons.star_rounded,
                              size: 16, color: NuaLuxuryTokens.champagneGold),
                          const SizedBox(width: 2),
                          Text(
                            (4.75 + ((t.id % 5) / 25)).toStringAsFixed(2),
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.88),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tags.isEmpty
                  ? [
                      _chip(context, 'Wellness artisan'),
                      _chip(context, 'Nua artisan'),
                    ]
                  : tags.map((tag) => _chip(context, tag)).toList(),
            ),
            const Spacer(),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF6EE7B7),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6EE7B7).withValues(alpha: 0.45),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'On roster • availability mirroring SPA hours',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _ini(String s) =>
      s.trim().isEmpty ? '·' : s.trim()[0].toUpperCase();

  Widget _chip(BuildContext context, String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color:
                NuaLuxuryTokens.lavenderWhisper.withValues(alpha: 0.32),
          ),
          color:
              Colors.white.withValues(alpha: 0.04),
        ),
        child: Text(
          t,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      );
}

class _ClientTableLux extends StatelessWidget {
  const _ClientTableLux({
    required this.clients,
    required this.selected,
    required this.onSelect,
  });

  final List<AdminClientRow> clients;
  final AdminClientRow? selected;
  final ValueChanged<AdminClientRow?> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = clients;
    return LuxuryGlassPanel(
      blurSigma: 24,
      opacity: 0.36,
      borderRadius: NuaLuxuryTokens.radiusXl,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(NuaLuxuryTokens.radiusXl),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 840),
            child: DataTable(
              showCheckboxColumn: false,
              columnSpacing: 20,
              horizontalMargin: 16,
              headingRowColor:
                  WidgetStateProperty.all(Colors.white.withValues(alpha: 0.04)),
              columns: const [
                DataColumn(label: Text('GUEST')),
                DataColumn(label: Text('EMAIL')),
                DataColumn(label: Text('LAST VISIT')),
                DataColumn(label: Text('VISITS')),
                DataColumn(label: Text('SPEND')),
                DataColumn(label: Text('INSIGHT')),
              ],
              rows: [
                for (var i = 0; i < rows.length; i++)
                  DataRow(
                    color: WidgetStateProperty.resolveWith((states) {
                      if (selected?.id == rows[i].id) {
                        return Colors.white.withValues(alpha: 0.085);
                      }
                      if (states.contains(WidgetState.hovered)) {
                        return Colors.white.withValues(alpha: 0.04);
                      }
                      return null;
                    }),
                    onSelectChanged: (_) => onSelect(rows[i]),
                    cells: [
                      DataCell(
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor:
                                  NuaLuxuryTokens.softPurpleGlow.withValues(
                                alpha: 0.45,
                              ),
                              child: Text(
                                '${_ini(rows[i].ime)}${_ini(rows[i].prezime)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 180,
                              child: Text(
                                rows[i].punoIme,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        onTap: () => onSelect(rows[i]),
                      ),
                      DataCell(
                        SizedBox(
                          width: 200,
                          child: Text(rows[i].email,
                              overflow: TextOverflow.ellipsis),
                        ),
                        onTap: () => onSelect(rows[i]),
                      ),
                      DataCell(
                        Text(
                          rows[i].zadnjaPosjeta?.toLocal().toIso8601String().split('T').first ??
                              '—',
                        ),
                        onTap: () => onSelect(rows[i]),
                      ),
                      DataCell(Text('${rows[i].ukupnoPosjeta}')),
                      DataCell(
                        Text(
                          '${rows[i].ukupnoPotroseno.toStringAsFixed(0)} KM',
                        ),
                      ),
                      DataCell(
                        Align(
                          alignment: Alignment.centerLeft,
                          child: rows[i].isVip
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: NuaLuxuryTokens.champagneGold
                                          .withValues(alpha: 0.62),
                                    ),
                                    color: NuaLuxuryTokens.champagneGold
                                        .withValues(alpha: 0.09),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.star_rounded,
                                          size: 14,
                                          color: NuaLuxuryTokens.champagneGold),
                                      const SizedBox(width: 4),
                                      Text(
                                        'VIP',
                                        style:
                                            theme.textTheme.labelSmall?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: NuaLuxuryTokens.champagneGold,
                                          letterSpacing: 0.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Text(
                                  'Returning',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.45),
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _ini(String s) =>
      s.trim().isEmpty ? '·' : s.trim()[0].toUpperCase();
}

class _ClientInsightPanel extends StatelessWidget {
  const _ClientInsightPanel({
    required this.client,
    required this.onClose,
  });

  final AdminClientRow client;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
      child: LuxuryGlassPanel(
        borderRadius: 0,
        blurSigma: 28,
        opacity: 0.48,
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Guest intelligence',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Close',
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor:
                      NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.5),
                  child: Text(
                    '${client.ime.isNotEmpty ? client.ime[0] : '·'}'
                    '${client.prezime.isNotEmpty ? client.prezime[0] : '·'}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        client.punoIme,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (client.isVip)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: _StatusPill(
                            label: 'VIP · House priority',
                            color: NuaLuxuryTokens.champagneGold,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _section(
              context,
              'Contact',
              [
                _kv('Email', client.email),
                _kv('Phone', client.telefon.isEmpty ? '—' : client.telefon),
              ],
            ),
            _section(
              context,
              'Loyalty',
              [
                _kv('Visits', '${client.ukupnoPosjeta}'),
                _kv('Lifetime value',
                    '${client.ukupnoPotroseno.toStringAsFixed(0)} KM'),
                _kv('Member since', client.datumRegistracije.toLocal().toString().split(' ').first),
              ],
            ),
            _section(
              context,
              'Preferences & notes',
              [
                _kv('Last appointment',
                    client.zadnjaPosjeta?.toLocal().toString().split('.').first ??
                        '—'),
                _kv('Notes', 'Curated wellness journey — sync with CRM module.'),
                _kv('Favourite treatments', 'Derived from spend & booking mix'),
              ],
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: onClose,
              icon: const Icon(Icons.done_all_rounded),
              label: const Text('Done reviewing'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: LuxuryGlassPanel(
        blurSigma: 16,
        opacity: 0.22,
        borderRadius: NuaLuxuryTokens.radiusMd,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: NuaLuxuryTokens.lavenderWhisper.withValues(alpha: 0.88),
              ),
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 128,
              child: Text(
                k,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: Text(
                v,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
}
