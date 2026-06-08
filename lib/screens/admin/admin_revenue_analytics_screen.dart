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
      _nav = nav;
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

  Future<void> _pickRange() async {
    final initial = _activeFrom != null && _activeTo != null
        ? DateTimeRange(start: _activeFrom!, end: _activeTo!)
        : DateTimeRange(
            start: _rangeFor(_period).$1,
            end: _rangeFor(_period).$2,
          );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: NuaLuxuryTokens.softPurpleGlow,
              surface: NuaLuxuryTokens.voidViolet,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null || !mounted) return;
    final from = _dayOnly(picked.start);
    final to = _dayOnly(picked.end);
    final range = DateTimeRange(start: from, end: to);
    setState(() {
      _usingPeriodChips = false;
      _syncedHeaderRange = range;
    });
    _nav?.setHeaderDateRange(range);
    await _reload(from: from, to: to);
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
              'Tip: use 7 / 30 / 90 day period chips below, or change the header date range.',
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

    final chartValues = rev.map((p) => p.prihod).toList();
    final spark = chartValues.length <= 14
        ? chartValues
        : chartValues.sublist(chartValues.length - 14);

    RevenuePoint? bestDay;
    RevenuePoint? worstDay;
    for (final p in rev) {
      if (p.prihod <= 0) continue;
      if (bestDay == null || p.prihod > bestDay.prihod) bestDay = p;
      if (worstDay == null || p.prihod < worstDay.prihod) worstDay = p;
    }

    final mid = rev.length ~/ 2;
    final firstHalf = rev.take(mid).fold<double>(0, (s, p) => s + p.prihod);
    final secondHalf = rev.skip(mid).fold<double>(0, (s, p) => s + p.prihod);
    final changePct = firstHalf > 0
        ? ((secondHalf - firstHalf) / firstHalf * 100)
        : 0.0;

    final periodLabel = _usingPeriodChips
        ? switch (_period) {
            _ReportPeriod.days7 => '7 days',
            _ReportPeriod.days30 => '30 days',
            _ReportPeriod.days90 => '90 days',
          }
        : '${_fmtDate(data.from)} — ${_fmtDate(data.to)}';

    return Stack(
      children: [
        const Positioned(
          top: 18,
          right: 120,
          child: _AmbientGlow(size: 310, color: Color(0x267B4DFF)),
        ),
        const Positioned(
          left: 120,
          bottom: 30,
          child: _AmbientGlow(size: 260, color: Color(0x14D4AF7A)),
        ),
        Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: LuxuryPageChrome.bodyPadding.copyWith(
                      right: 22,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ReportsActionsBar(
                          rangeText:
                              '${_fmtDate(data.from)} — ${_fmtDate(data.to)}',
                          exporting: _exporting,
                          onPickRange: _pickRange,
                          onExport: _exportPdf,
                        ),
                        if (data.warnings.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _ReportsWarningBanner(messages: data.warnings),
                        ],
                        const SizedBox(height: 16),
                        _KpiGrid(
                          cards: [
                            _KpiSpec(
                              title: 'Total Revenue',
                              value: _fmtKm(totalRevenue),
                              subtitle: 'Period: $periodLabel',
                              icon: Icons.attach_money_rounded,
                              values: spark.isEmpty ? [totalRevenue] : spark,
                            ),
                            _KpiSpec(
                              title: 'Payments',
                              value: '$totalPayments',
                              subtitle: 'Completed payments in period',
                              icon: Icons.payments_outlined,
                              values: rev
                                  .map((p) => p.brojPlacanja.toDouble())
                                  .toList(),
                            ),
                            _KpiSpec(
                              title: 'Average Amount',
                              value: _fmtKm(avgTicket),
                              subtitle: 'Per completed payment',
                              icon: Icons.account_balance_wallet_outlined,
                              values: rev
                                  .map((p) => p.brojPlacanja > 0
                                      ? p.prihod / p.brojPlacanja
                                      : 0.0)
                                  .toList(),
                            ),
                            _KpiSpec(
                              title: 'Revenue Today',
                              value: _fmtKm(data.kpi?.prihodDanas ?? 0),
                              subtitle:
                                  '${data.kpi?.rezervacijeDanas ?? 0} bookings today',
                              icon: Icons.today_outlined,
                              values: rev.length >= 7
                                  ? rev
                                      .sublist(rev.length - 7)
                                      .map((p) => p.prihod)
                                      .toList()
                                  : spark,
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        _RevenueChartCard(
                          points: rev,
                          period: _period,
                          onPeriod: _setPeriod,
                          metrics: [
                            ('This period', _fmtKm(totalRevenue)),
                            (
                              'Trend (2nd half)',
                              '${changePct >= 0 ? '+' : ''}${changePct.toStringAsFixed(1)}%',
                            ),
                            (
                              'Best day',
                              bestDay == null
                                  ? '—'
                                  : '${_fmtDate(bestDay.datum)}\n${_fmtKm(bestDay.prihod)}',
                            ),
                            (
                              'Worst day',
                              worstDay == null
                                  ? '—'
                                  : '${_fmtDate(worstDay.datum)}\n${_fmtKm(worstDay.prihod)}',
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        _RevenueBreakdownTable(services: data.popularity),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: 356,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(0, 12, 28, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _RevenueByServiceCard(services: data.popularity),
                        const SizedBox(height: 18),
                        _TopSpendersCard(spenders: data.spenders),
                      ],
                    ),
                  ),
                ),
              ],
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

class _ReportsActionsBar extends StatelessWidget {
  const _ReportsActionsBar({
    required this.rangeText,
    required this.exporting,
    required this.onPickRange,
    required this.onExport,
  });

  final String rangeText;
  final bool exporting;
  final VoidCallback onPickRange;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPickRange,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.white.withValues(alpha: 0.04),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.date_range_rounded,
                    size: 17,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    rangeText,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.88),
                    ),
                  ),
                  Icon(
                    Icons.expand_more_rounded,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: exporting ? null : onExport,
          icon: exporting
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                )
              : Icon(
                  Icons.download_outlined,
                  size: 17,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
          label: Text(exporting ? 'Exporting...' : 'Export'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white.withValues(alpha: 0.88),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
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
        final width = (c.maxWidth - 18 * (cols - 1)) / cols;
        return Wrap(
          spacing: 18,
          runSpacing: 18,
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
    final spark = spec.values.isEmpty
        ? const [0.0, 0.0]
        : (spec.values.length <= 14
              ? spec.values
              : spec.values.sublist(spec.values.length - 14));

    return LuxuryGlassPanel(
      borderRadius: 24,
      blurSigma: 24,
      opacity: 0.38,
      borderOpacity: 0.12,
      padding: const EdgeInsets.fromLTRB(20, 18, 18, 16),
      child: SizedBox(
        height: 176,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: NuaLuxuryTokens.softPurpleGlow.withValues(
                      alpha: 0.14,
                    ),
                    border: Border.all(
                      color: NuaLuxuryTokens.softPurpleGlow.withValues(
                        alpha: 0.26,
                      ),
                    ),
                  ),
                  child: Icon(
                    spec.icon,
                    color: NuaLuxuryTokens.champagneGold,
                    size: 21,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 88,
                  height: 42,
                  child: _MiniLine(values: spark),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              spec.title,
              style: theme.textTheme.labelLarge?.copyWith(
                color: NuaLuxuryTokens.lavenderWhisper.withValues(alpha: 0.62),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              spec.value,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: const Color(0xFFF5F3FA),
                fontWeight: FontWeight.w900,
                letterSpacing: -0.55,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              spec.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: NuaLuxuryTokens.lavenderWhisper.withValues(alpha: 0.72),
                fontWeight: FontWeight.w700,
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
    required this.metrics,
  });

  final List<RevenuePoint> points;
  final _ReportPeriod period;
  final void Function(_ReportPeriod) onPeriod;
  final List<(String, String)> metrics;

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
      borderRadius: 24,
      blurSigma: 28,
      opacity: 0.38,
      borderOpacity: 0.12,
      padding: const EdgeInsets.all(22),
      child: SizedBox(
        height: 440,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Revenue Over Time',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
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
            const SizedBox(height: 18),
            Expanded(
              child: values.isEmpty
                  ? Center(
                      child: Text(
                        'No payments in the selected period.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
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
            const SizedBox(height: 18),
            _ChartMetrics(metrics: metrics),
          ],
        ),
      ),
    );
  }
}

class _ChartMetrics extends StatelessWidget {
  const _ChartMetrics({required this.metrics});

  final List<(String, String)> metrics;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < metrics.length; i++) ...[
          Expanded(
            child: _MetricText(
              label: metrics[i].$1,
              value: metrics[i].$2,
            ),
          ),
          if (i != metrics.length - 1)
            Container(
              width: 1,
              height: 36,
              color: Colors.white.withValues(alpha: 0.07),
            ),
        ],
      ],
    );
  }
}

class _MetricText extends StatelessWidget {
  const _MetricText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: NuaLuxuryTokens.lavenderWhisper.withValues(alpha: 0.52),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: const Color(0xFFF5F3FA),
              fontWeight: FontWeight.w900,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _RevenueByServiceCard extends StatelessWidget {
  const _RevenueByServiceCard({required this.services});

  static const _colors = [
    Color(0xFF7B4DFF),
    Color(0xFF9D6BFF),
    Color(0xFFC8B6E8),
    Color(0xFFD4AF7A),
    Color(0xFF4ADE80),
    Color(0xFF5EEAD4),
    Color(0xFFFF8A80),
    Color(0xFF60A5FA),
  ];

  final List<ServicePopularity> services;

  @override
  Widget build(BuildContext context) {
    final total = services.fold<double>(0, (s, x) => s + x.prihod);
    final items = [
      for (var i = 0; i < services.length; i++)
        _ServiceRevenue(
          services[i].naziv,
          total > 0
              ? '${(services[i].prihod / total * 100).round()}%'
              : '0%',
          _fmtKm(services[i].prihod),
          _colors[i % _colors.length],
          total > 0 ? services[i].prihod / total * 100 : 0,
        ),
    ];

    return LuxuryGlassPanel(
      borderRadius: 24,
      blurSigma: 26,
      opacity: 0.38,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Revenue by Service',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: const Color(0xFFF5F3FA),
            ),
          ),
          const SizedBox(height: 18),
          if (items.isEmpty)
            Text(
              'No data for the selected period.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.55),
              ),
            )
          else ...[
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  centerSpaceRadius: 58,
                  sectionsSpace: 3,
                  sections: [
                    for (final item in items)
                      PieChartSectionData(
                        value: item.chartValue,
                        color: item.color,
                        radius: 34,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            for (final item in items) _ServiceRevenueRow(item: item),
          ],
        ],
      ),
    );
  }
}

class _TopSpendersCard extends StatelessWidget {
  const _TopSpendersCard({required this.spenders});

  final List<TopSpender> spenders;

  @override
  Widget build(BuildContext context) {
    return LuxuryGlassPanel(
      borderRadius: 24,
      blurSigma: 26,
      opacity: 0.38,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Clients',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: const Color(0xFFF5F3FA),
            ),
          ),
          const SizedBox(height: 16),
          if (spenders.isEmpty)
            Text(
              'No client payments in the selected period.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.55),
              ),
            )
          else
            for (var i = 0; i < spenders.length; i++)
              _SpenderRow(
                rank: i + 1,
                spender: _Spender(
                  spenders[i].imePrezime,
                  '${spenders[i].brojPosjeta} visits',
                  _fmtKm(spenders[i].ukupnoPotroseno),
                ),
              ),
        ],
      ),
    );
  }
}

class _RevenueBreakdownTable extends StatelessWidget {
  const _RevenueBreakdownTable({required this.services});

  final List<ServicePopularity> services;

  @override
  Widget build(BuildContext context) {
    final total = services.fold<double>(0, (s, x) => s + x.prihod);

    return LuxuryGlassPanel(
      borderRadius: 24,
      blurSigma: 24,
      opacity: 0.36,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Revenue Breakdown by Service',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: const Color(0xFFF5F3FA),
            ),
          ),
          const SizedBox(height: 18),
          const _BreakdownHeader(),
          const SizedBox(height: 8),
          if (services.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No data for the table.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
            )
          else
            for (final s in services)
              _BreakdownRow(
                row: _Breakdown(
                  s.naziv,
                  s.prihod.toStringAsFixed(0),
                  total > 0 ? s.prihod / total : 0,
                  '${s.brojRezervacija} payments',
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
        Expanded(child: Text('REVENUE (KM)', style: style)),
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

class _MiniLine extends StatelessWidget {
  const _MiniLine({required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    final minY = values.reduce(math.min);
    final maxY = values.reduce(math.max);
    final pad = maxY == minY ? 1.0 : 0.0;
    return LineChart(
      LineChartData(
        minY: minY - pad,
        maxY: maxY + pad,
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < values.length; i++)
                FlSpot(i.toDouble(), values[i]),
            ],
            isCurved: true,
            barWidth: 2.4,
            dotData: const FlDotData(show: false),
            color: NuaLuxuryTokens.softPurpleGlow,
            belowBarData: BarAreaData(
              show: true,
              color: NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.12),
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

class _ServiceRevenueRow extends StatelessWidget {
  const _ServiceRevenueRow({required this.item});

  final _ServiceRevenue item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: item.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            item.percent,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: NuaLuxuryTokens.lavenderWhisper.withValues(alpha: 0.64),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 80,
            child: Text(
              item.revenue,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: const Color(0xFFF5F3FA),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpenderRow extends StatelessWidget {
  const _SpenderRow({required this.rank, required this.spender});

  final int rank;
  final _Spender spender;

  @override
  Widget build(BuildContext context) {
    final initials = spender.name
        .split(' ')
        .where((p) => p.isNotEmpty)
        .map((p) => p[0])
        .take(2)
        .join()
        .toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.055)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: rank <= 3
                  ? NuaLuxuryTokens.champagneGold.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.05),
            ),
            child: Text(
              '$rank',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: rank <= 3
                    ? NuaLuxuryTokens.champagneGold
                    : Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            radius: 17,
            backgroundColor: NuaLuxuryTokens.softPurpleGlow.withValues(
              alpha: 0.34,
            ),
            child: Text(
              initials,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  spender.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                Text(
                  spender.appointments,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: NuaLuxuryTokens.lavenderWhisper.withValues(
                      alpha: 0.52,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (rank <= 3)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(
                Icons.workspace_premium_rounded,
                size: 16,
                color: NuaLuxuryTokens.champagneGold,
              ),
            ),
          Text(
            spender.revenue,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: const Color(0xFFF5F3FA),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [BoxShadow(color: color, blurRadius: size * 0.45)],
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
    required this.icon,
    required this.values,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final List<double> values;
}

class _ServiceRevenue {
  const _ServiceRevenue(
    this.label,
    this.percent,
    this.revenue,
    this.color,
    this.chartValue,
  );

  final String label;
  final String percent;
  final String revenue;
  final Color color;
  final double chartValue;
}

class _Spender {
  const _Spender(this.name, this.appointments, this.revenue);

  final String name;
  final String appointments;
  final String revenue;
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
