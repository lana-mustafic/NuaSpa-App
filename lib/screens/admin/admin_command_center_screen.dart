import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/services/api_service.dart';
import '../../models/admin/admin_activity_feed_item.dart';
import '../../models/admin/admin_client_stats.dart';
import '../../models/admin/admin_finance_dashboard.dart';
import '../../models/admin/admin_kpi.dart';
import '../../models/admin/admin_reviews_dashboard.dart';
import '../../models/admin/revenue_point.dart';
import '../../models/admin/service_popularity.dart';
import '../../models/desktop_home_overview.dart';
import '../../models/rezervacija.dart';
import '../../models/zaposlenik.dart';
import '../../screens/admin/admin_suite_route.dart';
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
    required this.popularity,
    required this.bookings,
    required this.yesterdayBookings,
    required this.therapists,
    required this.activityFeed,
    required this.homeOverview,
    required this.clientStats,
    required this.financeToday,
    required this.reviews,
  });

  final AdminKpi? kpi;
  final AdminKpi? kpiYesterday;
  final List<RevenuePoint> revenue;
  final List<ServicePopularity> popularity;
  final List<Rezervacija> bookings;
  final List<Rezervacija> yesterdayBookings;
  final List<Zaposlenik> therapists;
  final List<AdminActivityFeedItem> activityFeed;
  final DesktopHomeOverview? homeOverview;
  final AdminClientStats? clientStats;
  final AdminFinanceDashboard? financeToday;
  final AdminReviewsDashboard? reviews;
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
    return '+100% vs yesterday';
  }
  final pct = ((c - p) / p) * 100;
  return '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(0)}% vs yesterday';
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
      _future = () async {
        final results = await Future.wait([
          _api.getAdminKpis(date: day),
          _api.getAdminKpis(date: yesterday),
          _api.getRevenueSeries(from: from30, to: day),
          _api.getServicePopularity(from: day, to: day, take: 8),
          _api.getRezervacijeFiltered(datum: day, includeOtkazane: true),
          _api.getRezervacijeFiltered(datum: yesterday, includeOtkazane: true),
          _api.getZaposlenici(),
          _api.getAdminActivityFeed(day: day, take: 16),
          _api.getDesktopHomeOverview(day: day),
          _api.getAdminClientStats(),
          _api.getAdminFinanceDashboard(
            from: day,
            toInclusive: day,
            pageSize: 1,
          ),
          _api.getAdminReviewsDashboard(
            from: reviewsFrom,
            toInclusive: day,
            pageSize: 1,
          ),
        ]);
        return _CcData(
          kpi: results[0] as AdminKpi?,
          kpiYesterday: results[1] as AdminKpi?,
          revenue: results[2] as List<RevenuePoint>,
          popularity: results[3] as List<ServicePopularity>,
          bookings: results[4] as List<Rezervacija>,
          yesterdayBookings: results[5] as List<Rezervacija>,
          therapists: results[6] as List<Zaposlenik>,
          activityFeed: results[7] as List<AdminActivityFeedItem>,
          homeOverview: results[8] as DesktopHomeOverview?,
          clientStats: results[9] as AdminClientStats?,
          financeToday: results[10] as AdminFinanceDashboard?,
          reviews: results[11] as AdminReviewsDashboard?,
        );
      }();
    });
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

        return _DashboardLayout(data: d);
      },
    );
  }
}

class _DashboardLayout extends StatelessWidget {
  const _DashboardLayout({required this.data});

  final _CcData data;

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

    final ratingGrowth = ratingPrev != null
        ? '↑ ${(rating - ratingPrev) >= 0 ? '+' : ''}${(rating - ratingPrev).toStringAsFixed(1)} vs last 7 days'
        : (reviews != null
            ? '${reviews.postotakPozitivnih.toStringAsFixed(0)}% positive (30d)'
            : 'All-time average');

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
              _KpiRow(
                cards: [
                  _DashboardKpiSpec(
                    label: "Today's Bookings",
                    value: '$bookingsToday',
                    growth: _growthArrow(bookingsToday, bookingsYesterday),
                    trendUp: _pctTrendUp(bookingsToday, bookingsYesterday),
                    icon: Icons.calendar_today_outlined,
                    accent: _DashUi.purple,
                    sparkline: _bookingCountSpark(rev),
                  ),
                  _DashboardKpiSpec(
                    label: 'Revenue Today',
                    value: '${revenueToday.toStringAsFixed(0)} KM',
                    growth: _growthArrow(revenueToday, revenueYesterday),
                    trendUp: _pctTrendUp(revenueToday, revenueYesterday),
                    icon: Icons.payments_outlined,
                    accent: _DashUi.green,
                    sparkline: _sparkRevenue(rev, revenueToday),
                  ),
                  _DashboardKpiSpec(
                    label: 'Active Clients',
                    value: '$activeClients',
                    growth: newClients7d > 0
                        ? '↑ $newClients7d new (7 days)'
                        : 'No new clients this week',
                    trendUp: newClients7d > 0 ? true : null,
                    icon: Icons.people_outline,
                    accent: _DashUi.orange,
                    sparkline: [
                      activeClients.toDouble(),
                      newClients7d.toDouble(),
                      (clientStats?.vipKlijenata ?? 0).toDouble(),
                    ],
                  ),
                  _DashboardKpiSpec(
                    label: 'Guest Rating',
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
                  final chart = _TodayOverviewCard(bookings: bookings);
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
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 3, child: chart),
                        const SizedBox(width: _DashUi.gap),
                        Expanded(flex: 2, child: actions),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: _DashUi.gap),
              _RecentAppointmentsCard(bookings: bookings),
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
        transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
        child: _DashGlass(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
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
                    child: Icon(s.icon, color: s.accent, size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                s.label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _DashUi.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                s.value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: _DashUi.textPrimary,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                s.growth,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: trendColor,
                ),
              ),
              const Spacer(),
              LuxuryMiniSparkline(
                values: s.sparkline,
                height: 40,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayOverviewCard extends StatelessWidget {
  const _TodayOverviewCard({required this.bookings});

  final List<Rezervacija> bookings;

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
                const Expanded(
                  child: Text(
                    "Today's Overview",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _DashUi.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Text(
                        'Today',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _DashUi.textPrimary,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.expand_more_rounded,
                        size: 18,
                        color: _DashUi.textSecondary,
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
        onTap: () => nav.goToAdminSuite(AdminSuiteRoute.clients),
      ),
      _QuickActionTile(
        icon: Icons.spa_outlined,
        label: 'Add Service',
        color: const Color(0xFF60A5FA),
        onTap: () => nav.goTo(DesktopRouteKey.catalog),
      ),
      _QuickActionTile(
        icon: Icons.calendar_month_outlined,
        label: 'Open Calendar',
        color: _DashUi.pink,
        onTap: () => nav.goTo(DesktopRouteKey.adminCalendar),
      ),
    ];

    return _DashGlass(
      child: SizedBox(
        height: 320,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _DashUi.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.15,
                physics: const NeverScrollableScrollPhysics(),
                children: items,
              ),
            ),
          ],
        ),
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
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: widget.color.withValues(alpha: _hover ? 0.2 : 0.1),
              border: Border.all(
                color: widget.color.withValues(alpha: _hover ? 0.5 : 0.28),
              ),
              boxShadow: _hover
                  ? [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.35),
                        blurRadius: 20,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, color: widget.color, size: 28),
                const SizedBox(height: 10),
                Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _DashUi.textPrimary,
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
  const _RecentAppointmentsCard({required this.bookings});

  final List<Rezervacija> bookings;

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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 960),
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
                                  onPressed: () => nav.goTo(
                                    DesktopRouteKey.reservations,
                                  ),
                                ),
                              ),
                            ],
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.rezervacija});

  final Rezervacija rezervacija;

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color color;
    if (rezervacija.isOtkazana) {
      label = 'Cancelled';
      color = _DashUi.pink;
    } else if (!rezervacija.isPotvrdjena) {
      label = 'Pending';
      color = _DashUi.orange;
    } else {
      label = 'Confirmed';
      color = _DashUi.green;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
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
