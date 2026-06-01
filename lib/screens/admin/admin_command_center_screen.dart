import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/services/api_service.dart';
import '../../models/admin/admin_client_stats.dart';
import '../../models/admin/admin_kpi.dart';
import '../../models/admin/admin_reviews_dashboard.dart';
import '../../models/admin/revenue_point.dart';
import '../../models/desktop_home_overview.dart';
import '../../models/rezervacija.dart';
import '../../ui/navigation/desktop_nav.dart';
import '../../ui/theme/nua_luxury_tokens.dart';
import '../../ui/widgets/luxury/luxury_mini_sparkline.dart';

/// NuaSpa admin operational dashboard — live backend data, luxury SaaS layout.
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
    required this.kpiYesterday,
    required this.revenue,
    required this.bookings,
    required this.yesterdayBookings,
    required this.homeOverview,
    required this.clientStats,
    required this.reviews,
    this.loadWarnings = const [],
  });

  final AdminKpi? kpi;
  final AdminKpi? kpiYesterday;
  final List<RevenuePoint> revenue;
  final List<Rezervacija> bookings;
  final List<Rezervacija> yesterdayBookings;
  final DesktopHomeOverview? homeOverview;
  final AdminClientStats? clientStats;
  final AdminReviewsDashboard? reviews;
  final List<String> loadWarnings;
}

abstract final class _DashUi {
  static const textPrimary = Color(0xFFF5F3FA);
  static const textSecondary = Color(0xA6FFFFFF);
  static const purple = Color(0xFF7B4DFF);
  static const lavender = Color(0xFF9D6BFF);
  static const green = Color(0xFF22C55E);
  static const orange = Color(0xFFF59E0B);
  static const pink = Color(0xFFEC4899);
  static const cardRadius = 24.0;
  static const kpiHeight = 180.0;
  static const sidebarWidth = 360.0;
  static const gap = 24.0;
}

String _pctTrendLabel(num current, num previous) {
  final c = current.toDouble();
  final p = previous.toDouble();
  if (p <= 0) {
    if (c <= 0) return 'Flat vs yesterday';
    return 'Up from zero yesterday';
  }
  final pct = ((c - p) / p) * 100;
  return '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(0)}% vs yesterday';
}

String _formatDashboardDay(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

bool _isSameCalendarDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

bool? _pctTrendUp(num current, num previous) {
  final c = current.toDouble();
  final p = previous.toDouble();
  if (p <= 0 && c <= 0) return null;
  if (p <= 0) return true;
  return c >= p;
}

String _growthArrow(num current, num previous) {
  final up = _pctTrendUp(current, previous);
  final label = _pctTrendLabel(current, previous);
  if (up == true) return '↑ $label';
  if (up == false) return '↓ $label';
  return label;
}

List<double> _bookingCountSpark(List<RevenuePoint> rev) {
  if (rev.isEmpty) return const [0, 0, 1];
  final take = rev.length <= 14 ? rev : rev.sublist(rev.length - 14);
  return take.map((p) => p.brojRezervacija.toDouble()).toList();
}

List<double> _sparkRevenue(List<RevenuePoint> pts, double fallback) {
  if (pts.isEmpty) return [fallback, fallback * 1.05];
  final take = pts.length <= 14 ? pts : pts.sublist(pts.length - 14);
  final vals = take.map((p) => p.prihod).toList();
  if (vals.every((v) => v <= 0)) return [fallback, fallback * 1.08];
  return vals;
}

List<int> _hourlyBuckets(List<Rezervacija> bookings) {
  final buckets = List<int>.filled(7, 0);
  for (final r in bookings) {
    final h = r.datumRezervacije.toLocal().hour;
    final idx = h >= 20 ? 5 : (h ~/ 4).clamp(0, 5);
    buckets[idx]++;
  }
  return buckets;
}

String _formatTimeAmPm(DateTime d) {
  final loc = d.toLocal();
  final hour = loc.hour % 12 == 0 ? 12 : loc.hour % 12;
  final minute = loc.minute.toString().padLeft(2, '0');
  final suffix = loc.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}

class _AdminCommandCenterScreenState extends State<AdminCommandCenterScreen> {
  final ApiService _api = ApiService();
  Future<_CcData>? _future;

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
    final yesterday = day.subtract(const Duration(days: 1));
    final from30 = day.subtract(const Duration(days: 29));
    final reviewsFrom = day.subtract(const Duration(days: 29));
    setState(() {
      _future = _loadDashboard(
        day: day,
        yesterday: yesterday,
        from30: from30,
        reviewsFrom: reviewsFrom,
      );
    });
  }

  Future<_CcData> _loadDashboard({
    required DateTime day,
    required DateTime yesterday,
    required DateTime from30,
    required DateTime reviewsFrom,
  }) async {
    final warnings = <String>[];

    Future<T?> guard<T>(String label, Future<T?> Function() call) async {
      try {
        return await call();
      } catch (e) {
        warnings.add('$label failed to load.');
        debugPrint('Dashboard $label: $e');
        return null;
      }
    }

    final results = await Future.wait([
      guard('KPIs', () => _api.getAdminKpis(date: day)),
      guard('KPIs (yesterday)', () => _api.getAdminKpis(date: yesterday)),
      guard('Revenue trend', () async {
        final list = await _api.getRevenueSeries(from: from30, to: day);
        return list;
      }),
      guard('Today appointments', () async {
        final list = await _api.getRezervacijeFiltered(
          datum: day,
          includeOtkazane: true,
        );
        return list;
      }),
      guard('Yesterday appointments', () async {
        final list = await _api.getRezervacijeFiltered(
          datum: yesterday,
          includeOtkazane: true,
        );
        return list;
      }),
      guard('Overview', () => _api.getDesktopHomeOverview(day: day)),
      guard('Client stats', () => _api.getAdminClientStats()),
      guard('Reviews summary', () => _api.getAdminReviewsDashboard(
            from: reviewsFrom,
            toInclusive: day,
            pageSize: 1,
          )),
    ]);

    return _CcData(
      kpi: results[0] as AdminKpi?,
      kpiYesterday: results[1] as AdminKpi?,
      revenue: (results[2] as List<RevenuePoint>?) ?? const [],
      bookings: (results[3] as List<Rezervacija>?) ?? const [],
      yesterdayBookings: (results[4] as List<Rezervacija>?) ?? const [],
      homeOverview: results[5] as DesktopHomeOverview?,
      clientStats: results[6] as AdminClientStats?,
      reviews: results[7] as AdminReviewsDashboard?,
      loadWarnings: warnings,
    );
  }

  @override
  Widget build(BuildContext context) {
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

        if (snap.hasError) {
          return Center(
            child: _DashGlass(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Unable to load dashboard.',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _DashUi.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ),
          );
        }

        final d = snap.data;
        if (d == null) {
          return const Center(child: Text('No dashboard data.'));
        }

        return _DashboardLayout(
          data: d,
          filterDay: widget.filterDay,
        );
      },
    );
  }
}

class _DashboardLayout extends StatelessWidget {
  const _DashboardLayout({
    required this.data,
    required this.filterDay,
  });

  final _CcData data;
  final DateTime filterDay;

  @override
  Widget build(BuildContext context) {
    final kpi = data.kpi;
    final kpiYesterday = data.kpiYesterday;
    final rev = data.revenue;
    final bookings = data.bookings;
    final yesterdayBookings = data.yesterdayBookings;
    final clientStats = data.clientStats;
    final reviews = data.reviews;
    final homeOverview = data.homeOverview;

    final bookingsToday = kpi?.rezervacijeDanas ?? bookings.length;
    final bookingsYesterday =
        kpiYesterday?.rezervacijeDanas ?? yesterdayBookings.length;
    final revenueToday = (kpi?.prihodDanas ?? 0).toDouble();
    final revenueYesterday = (kpiYesterday?.prihodDanas ?? 0).toDouble();
    final activeClients = clientStats?.ukupnoKlijenata ?? 0;
    final newClients7d = homeOverview?.noviKlijentiZadnjih7Dana ?? 0;
    final rating = kpi?.prosjecnaOcjena ?? reviews?.prosjecnaOcjena ?? 0;
    final ratingPrev = reviews?.prosjecnaOcjenaPrethodno;

    final confirmed =
        bookings.where((b) => b.isPotvrdjena && !b.isOtkazana).length;
    final pending =
        bookings.where((b) => !b.isPotvrdjena && !b.isOtkazana).length;
    final cancelled = bookings.where((b) => b.isOtkazana).length;

    final isToday = _isSameCalendarDay(
      filterDay,
      DateTime.now(),
    );
    final bookingsLabel =
        isToday ? "Today's Bookings" : 'Bookings (${_formatDashboardDay(filterDay)})';
    final revenueLabel =
        isToday ? 'Revenue Today' : 'Revenue (${_formatDashboardDay(filterDay)})';

    final ratingGrowth = ratingPrev != null
        ? '${(rating - ratingPrev) >= 0 ? '+' : ''}${(rating - ratingPrev).toStringAsFixed(1)} vs prior 30d avg'
        : 'All-time average';

    final bookingsMayBeTruncated = bookings.length >= 500;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF07040F), Color(0xFF120A24)],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 1300;
          final main = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (data.loadWarnings.isNotEmpty || bookingsMayBeTruncated)
                Padding(
                  padding: const EdgeInsets.only(bottom: _DashUi.gap),
                  child: _DashLoadWarningsBanner(
                    messages: [
                      ...data.loadWarnings,
                      if (bookingsMayBeTruncated)
                        'Showing first 500 appointments for this day. Open Appointments for the full list.',
                    ],
                  ),
                ),
              _KpiRow(
                cards: [
                  _DashboardKpiSpec(
                    label: bookingsLabel,
                    value: '$bookingsToday',
                    growth: _growthArrow(bookingsToday, bookingsYesterday),
                    trendUp: _pctTrendUp(bookingsToday, bookingsYesterday),
                    icon: Icons.calendar_today_outlined,
                    accent: _DashUi.purple,
                    sparkline: _bookingCountSpark(rev),
                  ),
                  _DashboardKpiSpec(
                    label: revenueLabel,
                    value: '${revenueToday.toStringAsFixed(0)} KM',
                    growth:
                        '${_growthArrow(revenueToday, revenueYesterday)} · payments',
                    trendUp: _pctTrendUp(revenueToday, revenueYesterday),
                    icon: Icons.payments_outlined,
                    accent: _DashUi.green,
                    sparkline: _sparkRevenue(rev, revenueToday),
                  ),
                  _DashboardKpiSpec(
                    label: 'Total Clients',
                    value: '$activeClients',
                    growth: newClients7d > 0
                        ? '$newClients7d new (7 days before ${_formatDashboardDay(filterDay)})'
                        : 'No new registrations in last 7 days',
                    trendUp: newClients7d > 0 ? true : null,
                    icon: Icons.people_outline,
                    accent: _DashUi.orange,
                    sparkline: [
                      math.max(0, activeClients - newClients7d).toDouble(),
                      activeClients.toDouble(),
                    ],
                  ),
                  _DashboardKpiSpec(
                    label: 'Average Rating',
                    value: rating > 0
                        ? '${rating.toStringAsFixed(1)} / 5'
                        : '—',
                    growth: ratingGrowth,
                    trendUp: ratingPrev != null
                        ? rating >= ratingPrev
                        : null,
                    icon: Icons.star_rounded,
                    accent: _DashUi.pink,
                    sparkline: [
                      if (ratingPrev != null) ratingPrev,
                      rating,
                      rating,
                    ],
                  ),
                ],
              ),
              const SizedBox(height: _DashUi.gap),
              LayoutBuilder(
                builder: (context, mc) {
                  final stack = mc.maxWidth < 900;
                  final chart = _TodayOverviewCard(
                    bookings: bookings,
                    filterDay: filterDay,
                  );
                  final actions = _QuickActionsCard();
                  if (stack) {
                    return Column(
                      children: [
                        chart,
                        const SizedBox(height: _DashUi.gap),
                        actions,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: chart),
                      const SizedBox(width: _DashUi.gap),
                      Expanded(flex: 2, child: actions),
                    ],
                  );
                },
              ),
              const SizedBox(height: _DashUi.gap),
              _RecentAppointmentsCard(
                bookings: bookings,
                filterDay: filterDay,
              ),
            ],
          );

          final sidebar = _DashboardSidebar(
            bookings: bookings,
            confirmed: confirmed,
            pending: pending,
            cancelled: cancelled,
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 8, 28, 40),
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: main),
                      const SizedBox(width: _DashUi.gap),
                      SizedBox(width: _DashUi.sidebarWidth, child: sidebar),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      main,
                      const SizedBox(height: _DashUi.gap),
                      sidebar,
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _DashLoadWarningsBanner extends StatelessWidget {
  const _DashLoadWarningsBanner({required this.messages});

  final List<String> messages;

  @override
  Widget build(BuildContext context) {
    return _DashGlass(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: _DashUi.orange.withValues(alpha: 0.95),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              messages.join(' '),
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: _DashUi.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashGlass extends StatelessWidget {
  const _DashGlass({
    required this.child,
    this.padding,
    this.radius = _DashUi.cardRadius,
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
              color: _DashUi.purple.withValues(alpha: 0.12),
              blurRadius: 60,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class _DashboardKpiSpec {
  const _DashboardKpiSpec({
    required this.label,
    required this.value,
    required this.growth,
    required this.icon,
    required this.accent,
    required this.sparkline,
    this.trendUp,
  });

  final String label;
  final String value;
  final String growth;
  final IconData icon;
  final Color accent;
  final List<double> sparkline;
  final bool? trendUp;
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.cards});

  final List<_DashboardKpiSpec> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 1300
            ? 4
            : c.maxWidth >= 720
            ? 2
            : 1;
        final w = (c.maxWidth - 18 * (cols - 1)) / cols;
        return Wrap(
          spacing: 18,
          runSpacing: 18,
          children: [
            for (final card in cards)
              SizedBox(
                width: w.clamp(220, c.maxWidth),
                height: _DashUi.kpiHeight,
                child: _DashboardKpiCard(spec: card),
              ),
          ],
        );
      },
    );
  }
}

class _DashboardKpiCard extends StatefulWidget {
  const _DashboardKpiCard({required this.spec});

  final _DashboardKpiSpec spec;

  @override
  State<_DashboardKpiCard> createState() => _DashboardKpiCardState();
}

class _DashboardKpiCardState extends State<_DashboardKpiCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.spec;
    final trendColor = s.trendUp == null
        ? _DashUi.textSecondary
        : s.trendUp!
        ? _DashUi.green
        : _DashUi.pink;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: double.infinity,
        transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
        child: _DashGlass(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: s.accent.withValues(alpha: 0.18),
                  border: Border.all(
                    color: s.accent.withValues(alpha: 0.35),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: s.accent.withValues(
                        alpha: _hover ? 0.45 : 0.25,
                      ),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: Icon(s.icon, color: s.accent, size: 20),
              ),
              const SizedBox(height: 12),
              Text(
                s.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _DashUi.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                s.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _DashUi.textPrimary,
                  letterSpacing: -0.5,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                s.growth,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: trendColor,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: LuxuryMiniSparkline(
                    values: s.sparkline,
                    height: 32,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayOverviewCard extends StatelessWidget {
  const _TodayOverviewCard({
    required this.bookings,
    required this.filterDay,
  });

  final List<Rezervacija> bookings;
  final DateTime filterDay;

  static const _labels = ['00:00', '04:00', '08:00', '12:00', '16:00', '20:00', '24:00'];

  @override
  Widget build(BuildContext context) {
    final buckets = _hourlyBuckets(bookings);
    final peak = buckets.isEmpty ? 0 : buckets.reduce(math.max);
    final maxY = math.max(20.0, peak.toDouble());
    final spots = [
      for (var i = 0; i < buckets.length; i++)
        FlSpot(i.toDouble(), buckets[i].toDouble()),
    ];

    return _DashGlass(
      child: SizedBox(
        height: 320,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Appointments overview',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _DashUi.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDashboardDay(filterDay),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _DashUi.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY,
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 4,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: Colors.white.withValues(alpha: 0.06),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: maxY / 4,
                        getTitlesWidget: (v, _) => Text(
                          v.toInt().toString(),
                          style: const TextStyle(
                            fontSize: 11,
                            color: _DashUi.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: 1,
                        getTitlesWidget: (v, _) {
                          final i = v.round();
                          if (i < 0 || i >= _labels.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _labels[i],
                              style: const TextStyle(
                                fontSize: 11,
                                color: _DashUi.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                  ),
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touched) => touched.map((t) {
                        final i = t.spotIndex;
                        final label = i >= 0 && i < _labels.length
                            ? _labels[i]
                            : '';
                        return LineTooltipItem(
                          '$label — ${t.y.toInt()} bookings',
                          const TextStyle(
                            color: _DashUi.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      barWidth: 3,
                      color: _DashUi.purple,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            _DashUi.purple.withValues(alpha: 0.35),
                            _DashUi.purple.withValues(alpha: 0.02),
                          ],
                        ),
                      ),
                      shadow: Shadow(
                        color: _DashUi.purple.withValues(alpha: 0.5),
                        blurRadius: 16,
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

class _QuickActionsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final nav = context.read<DesktopNav>();
    final items = [
      _QuickActionTile(
        icon: Icons.add_circle_outline,
        label: 'New Appointment',
        color: _DashUi.purple,
        onTap: () => nav.requestAppointmentCreate(),
      ),
      _QuickActionTile(
        icon: Icons.person_add_alt_1_outlined,
        label: 'Add Client',
        color: _DashUi.lavender,
        onTap: () => nav.requestClientAdd(),
      ),
      _QuickActionTile(
        icon: Icons.spa_outlined,
        label: 'Add Service',
        color: const Color(0xFF60A5FA),
        onTap: () => nav.requestServiceAdd(),
      ),
      _QuickActionTile(
        icon: Icons.calendar_month_outlined,
        label: 'Open Calendar',
        color: _DashUi.pink,
        onTap: () => nav.goTo(DesktopRouteKey.adminCalendar),
      ),
    ];

    Widget rowPair(_QuickActionTile a, _QuickActionTile b) {
      return Row(
        children: [
          Expanded(child: a),
          const SizedBox(width: 8),
          Expanded(child: b),
        ],
      );
    }

    return _DashGlass(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _DashUi.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          rowPair(items[0], items[1]),
          const SizedBox(height: 8),
          rowPair(items[2], items[3]),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatefulWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<_QuickActionTile> {
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
            duration: const Duration(milliseconds: 180),
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: widget.color.withValues(alpha: _hover ? 0.2 : 0.1),
              border: Border.all(
                color: widget.color.withValues(alpha: _hover ? 0.5 : 0.28),
              ),
              boxShadow: _hover
                  ? [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.35),
                        blurRadius: 14,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, color: widget.color, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: _DashUi.textPrimary,
                      height: 1.2,
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

class _RecentAppointmentsCard extends StatelessWidget {
  const _RecentAppointmentsCard({
    required this.bookings,
    required this.filterDay,
  });

  final List<Rezervacija> bookings;
  final DateTime filterDay;

  @override
  Widget build(BuildContext context) {
    final nav = context.read<DesktopNav>();
    final sorted = [...bookings]
      ..sort((a, b) => a.datumRezervacije.compareTo(b.datumRezervacije));

    return _DashGlass(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Recent Appointments',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _DashUi.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => nav.goTo(DesktopRouteKey.reservations),
                child: const Text(
                  'View all',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: NuaLuxuryTokens.champagneGold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, c) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: c.maxWidth),
                  child: DataTable(
                headingTextStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: _DashUi.textSecondary,
                ),
                dataTextStyle: const TextStyle(
                  fontSize: 13,
                  color: _DashUi.textPrimary,
                ),
                columnSpacing: 28,
                horizontalMargin: 12,
                columns: const [
                  DataColumn(label: Text('TIME')),
                  DataColumn(label: Text('CLIENT')),
                  DataColumn(label: Text('SERVICE')),
                  DataColumn(label: Text('THERAPIST')),
                  DataColumn(label: Text('STATUS')),
                  DataColumn(label: Text('ACTIONS')),
                ],
                rows: sorted.isEmpty
                    ? [
                        DataRow(
                          cells: List.generate(
                            6,
                            (_) => const DataCell(Text('—')),
                          ),
                        ),
                      ]
                    : [
                        for (final r in sorted.take(12))
                          DataRow(
                            cells: [
                              DataCell(Text(_formatTimeAmPm(r.datumRezervacije))),
                              DataCell(Text(r.korisnikIme ?? 'Guest')),
                              DataCell(Text(r.uslugaNaziv ?? '—')),
                              DataCell(Text(r.zaposlenikIme ?? '—')),
                              DataCell(_StatusBadge(rezervacija: r)),
                              DataCell(
                                IconButton(
                                  icon: const Icon(
                                    Icons.open_in_new_rounded,
                                    size: 18,
                                  ),
                                  tooltip: 'Open in appointments',
                                  onPressed: () {
                                    final name = r.korisnikIme?.trim();
                                    if (name != null && name.isNotEmpty) {
                                      nav.setAppointmentSearchQuery(name);
                                    }
                                    nav.goTo(DesktopRouteKey.reservations);
                                  },
                                ),
                              ),
                            ],
                          ),
                      ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.rezervacija});

  final Rezervacija rezervacija;

  @override
  Widget build(BuildContext context) {
    final statusNorm = rezervacija.status.trim().toLowerCase();
    final isCompleted = statusNorm == 'completed' || statusNorm == 'zavrsena';

    late final String primary;
    late final Color color;
    if (rezervacija.isOtkazana) {
      primary = 'Cancelled';
      color = _DashUi.pink;
    } else if (isCompleted) {
      primary = 'Completed';
      color = const Color(0xFF94A3B8);
    } else if (!rezervacija.isPotvrdjena) {
      primary = 'Pending';
      color = _DashUi.orange;
    } else {
      primary = 'Confirmed';
      color = _DashUi.green;
    }

    final chips = <Widget>[
      _statusChip(primary, color),
      if (rezervacija.isVip) _statusChip('VIP', const Color(0xFFE8C547)),
      if (rezervacija.isPlacena) _statusChip('Paid', const Color(0xFF2DD4BF)),
      if (!rezervacija.isPlacena &&
          !rezervacija.isOtkazana &&
          rezervacija.isPotvrdjena)
        _statusChip('Unpaid', _DashUi.orange),
    ];

    return Wrap(spacing: 6, runSpacing: 4, children: chips);
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _DashboardSidebar extends StatelessWidget {
  const _DashboardSidebar({
    required this.bookings,
    required this.confirmed,
    required this.pending,
    required this.cancelled,
  });

  final List<Rezervacija> bookings;
  final int confirmed;
  final int pending;
  final int cancelled;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _UpcomingTimelineCard(bookings: bookings),
        const SizedBox(height: 18),
        _TodaySummaryCard(
          confirmed: confirmed,
          pending: pending,
          cancelled: cancelled,
        ),
      ],
    );
  }
}

class _UpcomingTimelineCard extends StatelessWidget {
  const _UpcomingTimelineCard({required this.bookings});

  final List<Rezervacija> bookings;

  @override
  Widget build(BuildContext context) {
    final nav = context.read<DesktopNav>();
    final active = bookings.where((b) => !b.isOtkazana).toList()
      ..sort((a, b) => a.datumRezervacije.compareTo(b.datumRezervacije));

    return _DashGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Upcoming Today',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _DashUi.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          if (active.isEmpty)
            const Text(
              'No upcoming appointments.',
              style: TextStyle(color: _DashUi.textSecondary),
            )
          else
            ...active.take(6).map((r) => _TimelineRow(rezervacija: r)),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => nav.goTo(DesktopRouteKey.adminCalendar),
            child: const Text('View full schedule'),
          ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.rezervacija});

  final Rezervacija rezervacija;

  Color get _dotColor {
    if (rezervacija.isOtkazana) return _DashUi.pink;
    if (!rezervacija.isPotvrdjena) return _DashUi.orange;
    return _DashUi.green;
  }

  String _initials(String? name) {
    final parts = (name ?? 'G')
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'G';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _dotColor,
                  boxShadow: [
                    BoxShadow(
                      color: _dotColor.withValues(alpha: 0.6),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              Container(
                width: 2,
                height: 36,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Text(
            _formatTimeAmPm(rezervacija.datumRezervacije),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: NuaLuxuryTokens.champagneGold,
            ),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            radius: 16,
            backgroundColor: _DashUi.purple.withValues(alpha: 0.35),
            child: Text(
              _initials(rezervacija.korisnikIme),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rezervacija.korisnikIme ?? 'Guest',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _DashUi.textPrimary,
                  ),
                ),
                Text(
                  rezervacija.uslugaNaziv ?? '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _DashUi.textSecondary,
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

class _TodaySummaryCard extends StatelessWidget {
  const _TodaySummaryCard({
    required this.confirmed,
    required this.pending,
    required this.cancelled,
  });

  final int confirmed;
  final int pending;
  final int cancelled;

  @override
  Widget build(BuildContext context) {
    return _DashGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Today's Summary",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _DashUi.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              _SummaryMini(
                label: 'Confirmed',
                value: '$confirmed',
                color: _DashUi.green,
              ),
              _SummaryMini(
                label: 'Pending',
                value: '$pending',
                color: _DashUi.orange,
              ),
              _SummaryMini(
                label: 'Cancelled',
                value: '$cancelled',
                color: _DashUi.pink,
              ),
              const _SummaryMini(
                label: 'No Shows',
                value: '0',
                color: _DashUi.textSecondary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryMini extends StatelessWidget {
  const _SummaryMini({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: _DashUi.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
