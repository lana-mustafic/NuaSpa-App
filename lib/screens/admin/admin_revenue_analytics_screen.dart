import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/services/api_service.dart';
import '../../ui/navigation/desktop_nav.dart';
import '../../models/admin/admin_kpi.dart';
import '../../models/admin/revenue_point.dart';
import '../../models/admin/service_popularity.dart';
import '../../models/admin/top_spender.dart';
import '../../ui/theme/nua_luxury_tokens.dart';
import '../../ui/widgets/luxury/luxury_desktop_header.dart';
import '../../ui/widgets/luxury/luxury_glass_panel.dart';

enum _ReportPeriod { days7, days30, days90 }

String _fmtKm(num v) {
  final d = v.toDouble();
  if (d == d.roundToDouble()) return '${d.round()} KM';
  return '${d.toStringAsFixed(2)} KM';
}

String _fmtDate(DateTime d) => '${d.day}.${d.month}.${d.year}';

String _fmtShort(DateTime d) => '${d.day}.${d.month}.';

class _ReportsData {
  const _ReportsData({
    required this.kpi,
    required this.revenue,
    required this.popularity,
    required this.spenders,
    required this.from,
    required this.to,
    this.warnings = const [],
  });

  final AdminKpi? kpi;
  final List<RevenuePoint> revenue;
  final List<ServicePopularity> popularity;
  final List<TopSpender> spenders;
  final DateTime from;
  final DateTime to;
  final List<String> warnings;
}

/// Admin Reports hub — live data from `api/Izvjestaj/*`.
class AdminRevenueAnalyticsScreen extends StatefulWidget {
  const AdminRevenueAnalyticsScreen({super.key});

  @override
  State<AdminRevenueAnalyticsScreen> createState() =>
      _AdminRevenueAnalyticsScreenState();
}

class _AdminRevenueAnalyticsScreenState
    extends State<AdminRevenueAnalyticsScreen> {
  final ApiService _api = ApiService();
  _ReportPeriod _period = _ReportPeriod.days30;
  _ReportsData? _data;
  bool _loading = true;
  String? _error;
  bool _exporting = false;
  DateTime? _activeFrom;
  DateTime? _activeTo;
  bool _usingPeriodChips = true;
  DateTimeRange? _syncedHeaderRange;
  int _lastFiltersPulse = 0;
  DesktopNav? _nav;

  @override
  void initState() {
    super.initState();
    final (from, to) = _rangeFor(_period);
    _syncedHeaderRange = DateTimeRange(start: from, end: to);
    _reload(from: from, to: to);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nav = context.read<DesktopNav>();
    if (_nav != nav) {
      _nav?.removeListener(_onHeaderRangeChanged);
      _nav?.setReportsPdfExport(null);
      _nav = nav;
      _nav!.setReportsPdfExport(_exportPdf);
      _nav!.setReportsPdfExporting(_exporting);
      _nav!.addListener(_onHeaderRangeChanged);
      _onHeaderRangeChanged();
    }
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _matchesPeriodRange(DateTimeRange range, _ReportPeriod period) {
    final (from, to) = _rangeFor(period);
    return _sameDay(range.start, from) && _sameDay(range.end, to);
  }

  void _onHeaderRangeChanged() {
    if (!mounted || _nav == null) return;
    final headerRange = _nav!.headerDateRange;
    if (_syncedHeaderRange != null &&
        _sameDay(_syncedHeaderRange!.start, headerRange.start) &&
        _sameDay(_syncedHeaderRange!.end, headerRange.end)) {
      return;
    }

    if (_usingPeriodChips && _matchesPeriodRange(headerRange, _period)) {
      _syncedHeaderRange = headerRange;
      return;
    }

    setState(() => _usingPeriodChips = false);
    _syncedHeaderRange = headerRange;
    _reload(
      from: _dayOnly(headerRange.start),
      to: _dayOnly(headerRange.end),
    );
  }

  @override
  void dispose() {
    _nav?.removeListener(_onHeaderRangeChanged);
    _nav?.setReportsPdfExport(null);
    _nav?.setReportsPdfExporting(false);
    super.dispose();
  }

  DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  (DateTime from, DateTime to) _rangeFor(_ReportPeriod p) {
    final to = _dayOnly(DateTime.now());
    final days = switch (p) {
      _ReportPeriod.days7 => 6,
      _ReportPeriod.days30 => 29,
      _ReportPeriod.days90 => 89,
    };
    return (to.subtract(Duration(days: days)), to);
  }

  Future<void> _reload({DateTime? from, DateTime? to}) async {
    final (rangeFrom, rangeTo) = from != null && to != null
        ? (from, to)
        : _rangeFor(_period);
    setState(() {
      _loading = true;
      _error = null;
      _activeFrom = rangeFrom;
      _activeTo = rangeTo;
    });

    final result = await _api.getAdminReportsDataResult(
      from: rangeFrom,
      to: rangeTo,
    );
    if (!mounted) return;

    setState(() {
      _loading = false;
      if (result.error != null) {
        _error = result.error;
        return;
      }
      _error = null;
      _data = _ReportsData(
        kpi: result.kpi,
        revenue: result.revenue,
        popularity: result.popularity,
        spenders: result.spenders,
        from: rangeFrom,
        to: rangeTo,
        warnings: result.warnings,
      );
    });
  }

  void _setPeriod(_ReportPeriod p) {
    if (_period == p) return;
    final (from, to) = _rangeFor(p);
    final range = DateTimeRange(start: from, end: to);
    setState(() {
      _period = p;
      _usingPeriodChips = true;
      _syncedHeaderRange = range;
    });
    _nav?.setHeaderDateRange(range);
    _reload(from: from, to: to);
  }

  Future<void> _exportPdf() async {
    if (_exporting) return;
    final from = _activeFrom;
    final to = _activeTo;
    if (from == null || to == null) return;
    setState(() => _exporting = true);
    final ok = await _api.downloadReport(from: from, to: to);
    if (!mounted) return;
    setState(() => _exporting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'PDF report (Top 5 services) downloaded and opened.'
              : 'PDF export failed. Check backend connection and sign-in.',
        ),
        behavior: SnackBarBehavior.floating,
        width: 420,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<DesktopNav>();
    if (nav.headerFiltersPulse != _lastFiltersPulse) {
      _lastFiltersPulse = nav.headerFiltersPulse;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Use the header date range and period toggles below the chart to refine analytics.',
            ),
            behavior: SnackBarBehavior.floating,
            width: 420,
          ),
        );
      });
    }

    if (_error != null && _data == null && !_loading) {
      return _ReportsError(message: _error!, onRetry: () => _reload());
    }

    if (_data == null && _loading) {
      return const Center(
        child: SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final data = _data;
    if (data == null) {
      return _ReportsError(message: 'No data available.', onRetry: () => _reload());
    }

    final rev = data.revenue;
    final totalRevenue = rev.fold<double>(0, (s, p) => s + p.prihod);
    final totalPayments = rev.fold<int>(0, (s, p) => s + p.brojPlacanja);
    final avgTicket =
        totalPayments > 0 ? totalRevenue / totalPayments : 0.0;

    final periodLabel = _usingPeriodChips
        ? switch (_period) {
            _ReportPeriod.days7 => 'Last 7 days',
            _ReportPeriod.days30 => 'Last 30 days',
            _ReportPeriod.days90 => 'Last 90 days',
          }
        : 'Selected period';
    final hasRevenueData = rev.any((p) => p.prihod > 0);

    return Stack(
      children: [
        SingleChildScrollView(
          padding: LuxuryPageChrome.bodyPadding.copyWith(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (data.warnings.isNotEmpty) ...[
                _ReportsWarningBanner(messages: data.warnings),
                const SizedBox(height: 12),
              ],
              _KpiGrid(
                cards: [
                  _KpiSpec(
                    title: 'Total Revenue',
                    value: _fmtKm(totalRevenue),
                    subtitle: periodLabel,
                  ),
                  _KpiSpec(
                    title: 'Completed Payments',
                    value: '$totalPayments',
                    subtitle: 'In selected period',
                  ),
                  _KpiSpec(
                    title: 'Average Transaction Value',
                    value: _fmtKm(avgTicket),
                    subtitle: 'Per completed payment',
                  ),
                  _KpiSpec(
                    title: 'Revenue Today',
                    value: _fmtKm(data.kpi?.prihodDanas ?? 0),
                    subtitle:
                        '${data.kpi?.rezervacijeDanas ?? 0} bookings today',
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _RevenueChartCard(
                points: rev,
                period: _period,
                onPeriod: _setPeriod,
                hasData: hasRevenueData,
              ),
              const SizedBox(height: 28),
              _RevenueByServiceSection(services: data.popularity),
              const SizedBox(height: 28),
              _TopClientsSection(spenders: data.spenders),
              const SizedBox(height: 32),
            ],
          ),
        ),
        if (_loading)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              minHeight: 2,
              color: NuaLuxuryTokens.softPurpleGlow,
              backgroundColor: Colors.transparent,
            ),
          ),
      ],
    );
  }
}

class _ReportsWarningBanner extends StatelessWidget {
  const _ReportsWarningBanner({required this.messages});

  final List<String> messages;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LuxuryGlassPanel(
      borderRadius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: Colors.white.withValues(alpha: 0.65),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              messages.join(' '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.72),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportsError extends StatelessWidget {
  const _ReportsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LuxuryGlassPanel(
        borderRadius: 24,
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsEmptyState extends StatelessWidget {
  const _AnalyticsEmptyState({
    required this.title,
    required this.subtitle,
    this.height = 160,
  });

  final String title;
  final String subtitle;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: height,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFF5F3FA),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.5),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.cards});

  final List<_KpiSpec> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 1040
            ? 4
            : c.maxWidth >= 700
            ? 2
            : 1;
        final width = (c.maxWidth - 12 * (cols - 1)) / cols;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final card in cards)
              SizedBox(
                width: width,
                child: _RevenueKpiCard(spec: card),
              ),
          ],
        );
      },
    );
  }
}

class _RevenueKpiCard extends StatelessWidget {
  const _RevenueKpiCard({required this.spec});

  final _KpiSpec spec;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LuxuryGlassPanel(
      borderRadius: 18,
      blurSigma: 22,
      opacity: 0.34,
      borderOpacity: 0.08,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: SizedBox(
        height: 108,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              spec.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.55),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
            const Spacer(),
            Text(
              spec.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: const Color(0xFFF5F3FA),
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              spec.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.38),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevenueChartCard extends StatelessWidget {
  const _RevenueChartCard({
    required this.points,
    required this.period,
    required this.onPeriod,
    required this.hasData,
  });

  final List<RevenuePoint> points;
  final _ReportPeriod period;
  final void Function(_ReportPeriod) onPeriod;
  final bool hasData;

  @override
  Widget build(BuildContext context) {
    final values = points.map((p) => p.prihod).toList();
    final maxVal = values.isEmpty ? 1.0 : values.reduce(math.max);
    final minVal = 0.0;
    final maxY = maxVal <= 0 ? 100.0 : maxVal * 1.15;
    final interval = maxY <= 500 ? 100.0 : (maxY / 5).ceilToDouble();

    final spots = [
      for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
    ];

    return LuxuryGlassPanel(
      borderRadius: 18,
      blurSigma: 24,
      opacity: 0.34,
      borderOpacity: 0.08,
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        height: hasData ? 380 : 300,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Revenue Over Time',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFF5F3FA),
                    ),
                  ),
                ),
                _RangePill(
                  label: '7d',
                  active: period == _ReportPeriod.days7,
                  onTap: () => onPeriod(_ReportPeriod.days7),
                ),
                const SizedBox(width: 8),
                _RangePill(
                  label: '30d',
                  active: period == _ReportPeriod.days30,
                  onTap: () => onPeriod(_ReportPeriod.days30),
                ),
                const SizedBox(width: 8),
                _RangePill(
                  label: '90d',
                  active: period == _ReportPeriod.days90,
                  onTap: () => onPeriod(_ReportPeriod.days90),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: !hasData
                  ? const _AnalyticsEmptyState(
                      title: 'No revenue data available',
                      subtitle:
                          'Revenue analytics will appear once payments are recorded.',
                      height: 220,
                    )
                  : LineChart(
                      LineChartData(
                        minY: minVal,
                        maxY: maxY,
                        gridData: FlGridData(
                          drawVerticalLine: false,
                          horizontalInterval: interval,
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: Colors.white.withValues(alpha: 0.055),
                            strokeWidth: 0.8,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(),
                          rightTitles: const AxisTitles(),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 42,
                              interval: interval,
                              getTitlesWidget: (v, _) => Text(
                                v >= 1000
                                    ? '${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1)}k'
                                    : v.toStringAsFixed(0),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.42),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: points.length >= 2,
                              reservedSize: 28,
                              interval: math.max(1, (points.length / 4).floor())
                                  .toDouble(),
                              getTitlesWidget: (v, _) {
                                final i = v.round();
                                if (i < 0 || i >= points.length) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    _fmtShort(points[i].datum),
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.42,
                                      ),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        lineTouchData: LineTouchData(
                          enabled: true,
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipItems: (items) => items.map((item) {
                              final idx = item.spotIndex;
                              final date = idx >= 0 && idx < points.length
                                  ? _fmtDate(points[idx].datum)
                                  : '';
                              return LineTooltipItem(
                                '$date\n${item.y.toStringAsFixed(0)} KM',
                                const TextStyle(
                                  color: Color(0xFFF5F3FA),
                                  fontWeight: FontWeight.w800,
                                  height: 1.45,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            barWidth: 3.2,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: points.length <= 31,
                              getDotPainter: (_, __, ___, ____) =>
                                  FlDotCirclePainter(
                                    radius: 3.2,
                                    color: Colors.white.withValues(
                                      alpha: 0.86,
                                    ),
                                    strokeWidth: 4,
                                    strokeColor: NuaLuxuryTokens.softPurpleGlow
                                        .withValues(alpha: 0.36),
                                  ),
                            ),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF7B4DFF), Color(0xFF9D6BFF)],
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  NuaLuxuryTokens.softPurpleGlow.withValues(
                                    alpha: 0.22,
                                  ),
                                  NuaLuxuryTokens.softPurpleGlow.withValues(
                                    alpha: 0.015,
                                  ),
                                ],
                              ),
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

class _RevenueByServiceSection extends StatelessWidget {
  const _RevenueByServiceSection({required this.services});

  final List<ServicePopularity> services;

  @override
  Widget build(BuildContext context) {
    final total = services.fold<double>(0, (s, x) => s + x.prihod);
    final hasData = services.isNotEmpty && total > 0;

    return LuxuryGlassPanel(
      borderRadius: 18,
      blurSigma: 22,
      opacity: 0.34,
      borderOpacity: 0.08,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Revenue by Service',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFFF5F3FA),
            ),
          ),
          const SizedBox(height: 16),
          if (!hasData)
            const _AnalyticsEmptyState(
              title: 'No service revenue yet',
              subtitle:
                  'Revenue by service will appear once paid bookings exist.',
              height: 140,
            )
          else ...[
            const _BreakdownHeader(),
            const SizedBox(height: 8),
            for (final s in services)
              _BreakdownRow(
                row: _Breakdown(
                  s.naziv,
                  _fmtKm(s.prihod),
                  total > 0 ? s.prihod / total : 0,
                  '${s.brojRezervacija} payments',
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _TopClientsSection extends StatelessWidget {
  const _TopClientsSection({required this.spenders});

  final List<TopSpender> spenders;

  @override
  Widget build(BuildContext context) {
    return LuxuryGlassPanel(
      borderRadius: 18,
      blurSigma: 22,
      opacity: 0.34,
      borderOpacity: 0.08,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Top Clients',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFFF5F3FA),
            ),
          ),
          const SizedBox(height: 16),
          if (spenders.isEmpty)
            const _AnalyticsEmptyState(
              title: 'No client payments yet',
              subtitle:
                  'Top clients will appear once payments are recorded.',
              height: 140,
            )
          else ...[
            const _TopClientsHeader(),
            const SizedBox(height: 8),
            for (final s in spenders) _TopClientRow(spender: s),
          ],
        ],
      ),
    );
  }
}

class _TopClientsHeader extends StatelessWidget {
  const _TopClientsHeader();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Colors.white.withValues(alpha: 0.45),
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
    );
    return Row(
      children: [
        Expanded(flex: 3, child: Text('CLIENT', style: style)),
        Expanded(flex: 2, child: Text('TOTAL SPENT', style: style)),
        Expanded(child: Text('APPOINTMENTS', style: style)),
        Expanded(flex: 2, child: Text('LAST VISIT', textAlign: TextAlign.right, style: style)),
      ],
    );
  }
}

class _TopClientRow extends StatelessWidget {
  const _TopClientRow({required this.spender});

  final TopSpender spender;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lastVisit = spender.zadnjaPosjeta == null
        ? '—'
        : _fmtDate(spender.zadnjaPosjeta!.toLocal());

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              spender.imePrezime,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: const Color(0xFFF5F3FA),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _fmtKm(spender.ukupnoPotroseno),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '${spender.brojPosjeta}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.65),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              lastVisit,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownHeader extends StatelessWidget {
  const _BreakdownHeader();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: NuaLuxuryTokens.lavenderWhisper.withValues(alpha: 0.54),
      fontWeight: FontWeight.w900,
      letterSpacing: 0.6,
    );
    return Row(
      children: [
        Expanded(flex: 2, child: Text('SERVICE', style: style)),
        Expanded(child: Text('REVENUE', style: style)),
        Expanded(flex: 2, child: Text('% OF TOTAL', style: style)),
        Expanded(
          child: Text('PAYMENTS', textAlign: TextAlign.right, style: style),
        ),
      ],
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({required this.row});

  final _Breakdown row;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.055)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              row.category,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
          Expanded(
            child: Text(
              row.revenue,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: const Color(0xFFF5F3FA),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: row.percent,
                      minHeight: 8,
                      backgroundColor: Colors.white.withValues(alpha: 0.07),
                      valueColor: const AlwaysStoppedAnimation(
                        NuaLuxuryTokens.softPurpleGlow,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 42,
                  child: Text(
                    '${(row.percent * 100).round()}%',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.58),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              row.visits,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: NuaLuxuryTokens.lavenderWhisper.withValues(alpha: 0.72),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RangePill extends StatelessWidget {
  const _RangePill({
    required this.label,
    this.active = false,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? NuaLuxuryTokens.softPurpleGlow
                : Colors.white.withValues(alpha: 0.045),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active
                  ? NuaLuxuryTokens.softPurpleGlow
                  : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: const Color(0xFFF5F3FA),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _KpiSpec {
  const _KpiSpec({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final String title;
  final String value;
  final String subtitle;
}

class _Breakdown {
  const _Breakdown(
    this.category,
    this.revenue,
    this.percent,
    this.visits,
  );

  final String category;
  final String revenue;
  final double percent;
  final String visits;
}
