import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/services/api_service.dart';
import '../../models/admin/admin_client_stats.dart';
import '../../models/admin/admin_kpi.dart';
import '../../models/admin/activity_feed_item.dart';
import '../../models/admin/admin_reviews_dashboard.dart';
import '../../models/admin/revenue_point.dart';
import '../../models/desktop_home_overview.dart';
import '../../models/rezervacija.dart';
import '../../ui/navigation/desktop_nav.dart';
import '../../ui/theme/nua_luxury_tokens.dart';
import '../../ui/widgets/luxury/luxury_desktop_header.dart';

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
    required this.activity,
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
  final List<_ActivityEvent> activity;
  final List<String> loadWarnings;
}

enum _ChartPeriod { day, week, month }

abstract final class _DashUi {
  static const textPrimary = Color(0xFFF5F3FA);
  static const textSecondary = Color(0xA6FFFFFF);
  static const purple = Color(0xFF7B4DFF);
  static const blue = Color(0xFF3B82F6);
  static const green = Color(0xFF22C55E);
  static const orange = Color(0xFFF59E0B);
  static const pink = Color(0xFFEC4899);
  static const cardRadius = 18.0;
  static const kpiHeight = 140.0;
  static const gap = 20.0;
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

List<int> _hourlyBuckets(
  List<Rezervacija> bookings, {
  required bool cancelled,
}) {
  final buckets = List<int>.filled(7, 0);
  for (final r in bookings) {
    if (r.isOtkazana != cancelled) continue;
    final h = r.datumRezervacije.toLocal().hour;
    final idx = h >= 20 ? 5 : (h ~/ 4).clamp(0, 5);
    buckets[idx]++;
  }
  return buckets;
}

class _ActivityEvent {
  const _ActivityEvent({
    required this.time,
    required this.text,
    required this.icon,
    required this.color,
    this.route,
  });

  final DateTime time;
  final String text;
  final IconData icon;
  final Color color;
  final DesktopRouteKey? route;
}

List<_ActivityEvent> _activityFromApi(List<ActivityFeedItem> items) {
  return items.map((item) {
    late final IconData icon;
    late final Color color;
    DesktopRouteKey? route;
    switch (item.tip) {
      case 'payment':
        icon = Icons.payments_outlined;
        color = _DashUi.green;
        break;
      case 'review':
        icon = Icons.star_rounded;
        color = _DashUi.orange;
        route = DesktopRouteKey.reviews;
        break;
      case 'client':
        icon = Icons.person_add_alt_1_outlined;
        color = _DashUi.purple;
        break;
      default:
        icon = Icons.event_available_outlined;
        color = _DashUi.blue;
    }
    final subtitle = item.podnaslov?.trim();
    final text = subtitle != null && subtitle.isNotEmpty
        ? '${item.naslov} · $subtitle'
        : item.naslov;
    return _ActivityEvent(
      time: item.datumVrijeme,
      text: text,
      icon: icon,
      color: color,
      route: route,
    );
  }).toList();
}

List<_ActivityEvent> _buildActivityFeedFallback(
  List<Rezervacija> bookings,
  AdminReviewsDashboard? reviews,
) {
  final events = <_ActivityEvent>[];

  for (final r in bookings) {
    final client = r.korisnikIme?.trim();
    final name = (client != null && client.isNotEmpty) ? client : 'A client';
    final service = r.uslugaNaziv?.trim();
    final svc = (service != null && service.isNotEmpty) ? service : 'appointment';

    if (r.isOtkazana) {
      events.add(_ActivityEvent(
        time: r.otkazanaAt ?? r.datumRezervacije,
        icon: Icons.event_busy_outlined,
        color: _DashUi.pink,
        text: '$name cancelled $svc',
      ));
      continue;
    }

    events.add(_ActivityEvent(
      time: r.datumRezervacije,
      icon: Icons.event_available_outlined,
      color: _DashUi.blue,
      text: '$name booked $svc',
    ));

    if (r.isPlacena) {
      events.add(_ActivityEvent(
        time: r.datumRezervacije,
        icon: Icons.payments_outlined,
        color: _DashUi.green,
        text: 'Payment completed · $svc',
      ));
    }
  }

  for (final rv in reviews?.redovi ?? const <AdminReviewRow>[]) {
    events.add(_ActivityEvent(
      time: rv.createdAt,
      icon: Icons.star_rounded,
      color: _DashUi.orange,
      text: 'New review received (${rv.ocjena}★) · ${rv.korisnikPunoIme}',
      route: DesktopRouteKey.reviews,
    ));
  }

  events.sort((a, b) => b.time.compareTo(a.time));
  return events.take(8).toList();
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
      guard('Activity feed', () => _api.getAdminActivityFeed(day: day)),
    ]);

    final apiActivity = (results[8] as List<ActivityFeedItem>?) ?? const [];
    final activityEvents = apiActivity.isNotEmpty
        ? _activityFromApi(apiActivity)
        : _buildActivityFeedFallback(
            (results[3] as List<Rezervacija>?) ?? const [],
            results[7] as AdminReviewsDashboard?,
          );

    return _CcData(
      kpi: results[0] as AdminKpi?,
      kpiYesterday: results[1] as AdminKpi?,
      revenue: (results[2] as List<RevenuePoint>?) ?? const [],
      bookings: (results[3] as List<Rezervacija>?) ?? const [],
      yesterdayBookings: (results[4] as List<Rezervacija>?) ?? const [],
      homeOverview: results[5] as DesktopHomeOverview?,
      clientStats: results[6] as AdminClientStats?,
      reviews: results[7] as AdminReviewsDashboard?,
      activity: activityEvents,
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
    final cancelled = bookings.where((b) => b.isOtkazana).length;

    final isToday = _isSameCalendarDay(
      filterDay,
      DateTime.now(),
    );
    final bookingsLabel =
        isToday ? "Today's Bookings" : 'Bookings (${_formatDashboardDay(filterDay)})';
    final revenueLabel =
        isToday ? 'Revenue Today' : 'Revenue (${_formatDashboardDay(filterDay)})';

    final reviewCount = reviews?.ukupno ?? 0;
    final clientsGrowth = newClients7d > 0
        ? '+$newClients7d this week'
        : 'No new clients this week';
    final ratingGrowth = reviewCount > 0
        ? '$reviewCount reviews'
        : 'No reviews yet';

    final bookingsMayBeTruncated = bookings.length >= 500;
    final activity = data.activity;
    final therapistsWorking = kpi?.aktivniTerapeuti ?? 0;
    final pendingAppointments = bookings
        .where((b) => !b.isPotvrdjena && !b.isOtkazana)
        .length;
    final showInfoStrip = kpi != null;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF07040F), Color(0xFF0E0818)],
        ),
      ),
      child: SingleChildScrollView(
        padding: LuxuryPageChrome.bodyPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showInfoStrip) ...[
              _DashboardInfoStrip(
                appointments: bookingsToday,
                therapistsWorking: therapistsWorking,
                pendingAppointments: pendingAppointments,
              ),
              const SizedBox(height: 28),
            ],
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
                  accent: _DashUi.blue,
                ),
                _DashboardKpiSpec(
                  label: revenueLabel,
                  value: '${revenueToday.toStringAsFixed(0)} KM',
                  growth: _growthArrow(revenueToday, revenueYesterday),
                  trendUp: _pctTrendUp(revenueToday, revenueYesterday),
                  icon: Icons.payments_outlined,
                  accent: _DashUi.green,
                ),
                _DashboardKpiSpec(
                  label: 'Clients',
                  value: '$activeClients',
                  growth: clientsGrowth,
                  trendUp: newClients7d > 0 ? true : null,
                  icon: Icons.people_outline,
                  accent: _DashUi.purple,
                ),
                _DashboardKpiSpec(
                  label: 'Rating',
                  value: rating > 0 ? rating.toStringAsFixed(1) : '—',
                  growth: ratingGrowth,
                  trendUp: ratingPrev != null ? rating >= ratingPrev : null,
                  icon: Icons.star_rounded,
                  accent: _DashUi.orange,
                ),
              ],
            ),
            const SizedBox(height: _DashUi.gap),
            LayoutBuilder(
              builder: (context, mc) {
                final stack = mc.maxWidth < 1024;
                final chart = _AppointmentsChartCard(
                  bookings: bookings,
                  revenue: rev,
                  filterDay: filterDay,
                  confirmed: confirmed,
                  cancelled: cancelled,
                );
                final side = _DashboardSideColumn(
                  bookings: bookings,
                  activity: activity,
                );
                if (stack) {
                  return Column(
                    children: [
                      chart,
                      const SizedBox(height: _DashUi.gap),
                      side,
                    ],
                  );
                }
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 7, child: chart),
                      const SizedBox(width: _DashUi.gap),
                      Expanded(flex: 3, child: side),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: _DashUi.gap),
            _RecentAppointmentsCard(
              bookings: bookings,
              filterDay: filterDay,
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardInfoStrip extends StatelessWidget {
  const _DashboardInfoStrip({
    required this.appointments,
    required this.therapistsWorking,
    required this.pendingAppointments,
  });

  final int appointments;
  final int therapistsWorking;
  final int pendingAppointments;

  @override
  Widget build(BuildContext context) {
    final pendingLabel = pendingAppointments == 1
        ? '1 pending appointment'
        : '$pendingAppointments pending appointments';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        'Today: $appointments appointments scheduled'
        ' • $therapistsWorking therapists working'
        ' • $pendingLabel',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          height: 1.4,
          color: _DashUi.textSecondary,
        ),
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
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    const radius = _DashUi.cardRadius;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        padding: padding ?? const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 8),
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
    this.trendUp,
  });

  final String label;
  final String value;
  final String growth;
  final IconData icon;
  final Color accent;
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
  @override
  Widget build(BuildContext context) {
    final s = widget.spec;
    final trendColor = s.trendUp == null
        ? _DashUi.textSecondary
        : s.trendUp!
        ? _DashUi.green
        : _DashUi.pink;

    return _DashGlass(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 72,
            decoration: BoxDecoration(
              color: s.accent,
              borderRadius: BorderRadius.circular(2),
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
                        s.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _DashUi.textSecondary,
                        ),
                      ),
                    ),
                    Icon(s.icon, color: s.accent, size: 18),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  s.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: s.accent == _DashUi.green
                        ? _DashUi.green
                        : _DashUi.textPrimary,
                    letterSpacing: -0.6,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  s.growth,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: trendColor,
                    height: 1.25,
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

class _AppointmentsChartCard extends StatefulWidget {
  const _AppointmentsChartCard({
    required this.bookings,
    required this.revenue,
    required this.filterDay,
    required this.confirmed,
    required this.cancelled,
  });

  final List<Rezervacija> bookings;
  final List<RevenuePoint> revenue;
  final DateTime filterDay;
  final int confirmed;
  final int cancelled;

  @override
  State<_AppointmentsChartCard> createState() => _AppointmentsChartCardState();
}

class _AppointmentsChartCardState extends State<_AppointmentsChartCard> {
  _ChartPeriod _period = _ChartPeriod.day;

  static const _dayLabels = [
    '00:00',
    '04:00',
    '08:00',
    '12:00',
    '16:00',
    '20:00',
    '24:00',
  ];

  List<RevenuePoint> get _seriesPoints {
    final sorted = [...widget.revenue]
      ..sort((a, b) => a.datum.compareTo(b.datum));
    if (_period == _ChartPeriod.week) {
      return sorted.length <= 7
          ? sorted
          : sorted.sublist(sorted.length - 7);
    }
    if (_period == _ChartPeriod.month) {
      return sorted.length <= 30
          ? sorted
          : sorted.sublist(sorted.length - 30);
    }
    return sorted;
  }

  String _xLabel(int index, int count) {
    if (_period == _ChartPeriod.day) {
      return index >= 0 && index < _dayLabels.length ? _dayLabels[index] : '';
    }
    if (index < 0 || index >= count) return '';
    final pts = _seriesPoints;
    if (index >= pts.length) return '';
    final d = pts[index].datum;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final confirmedBuckets = _hourlyBuckets(
      widget.bookings,
      cancelled: false,
    );
    final cancelledBuckets = _hourlyBuckets(
      widget.bookings,
      cancelled: true,
    );

    final int pointCount;
    final List<FlSpot> confirmedSpots;
    final List<FlSpot> cancelledSpots;
    final List<FlSpot> revenueSpots;

    if (_period == _ChartPeriod.day) {
      pointCount = confirmedBuckets.length;
      confirmedSpots = [
        for (var i = 0; i < pointCount; i++)
          FlSpot(i.toDouble(), confirmedBuckets[i].toDouble()),
      ];
      cancelledSpots = [
        for (var i = 0; i < pointCount; i++)
          FlSpot(i.toDouble(), cancelledBuckets[i].toDouble()),
      ];
      final revToday = widget.revenue
          .where((p) => _isSameCalendarDay(p.datum, widget.filterDay))
          .fold<double>(0, (a, p) => a + p.prihod);
      revenueSpots = [
        for (var i = 0; i < pointCount; i++)
          FlSpot(i.toDouble(), revToday / math.max(pointCount, 1)),
      ];
    } else {
      final pts = _seriesPoints;
      pointCount = pts.length;
      confirmedSpots = [
        for (var i = 0; i < pts.length; i++)
          FlSpot(i.toDouble(), pts[i].brojPotvrdjenih.toDouble()),
      ];
      cancelledSpots = [
        for (var i = 0; i < pts.length; i++)
          FlSpot(i.toDouble(), pts[i].brojOtkazanih.toDouble()),
      ];
      revenueSpots = [
        for (var i = 0; i < pts.length; i++)
          FlSpot(i.toDouble(), pts[i].prihod),
      ];
    }

    final allY = [
      ...confirmedSpots.map((s) => s.y),
      ...cancelledSpots.map((s) => s.y),
    ];
    final maxBookings = allY.isEmpty ? 4.0 : allY.reduce(math.max);
    final maxY = math.max(4.0, maxBookings * 1.2);

    final maxRevenue = revenueSpots.isEmpty
        ? 1.0
        : revenueSpots.map((s) => s.y).reduce(math.max);
    final revenueScale = maxRevenue <= 0 ? 1.0 : maxY / maxRevenue;
    final scaledRevenue = [
      for (final s in revenueSpots)
        FlSpot(s.x, s.y * revenueScale),
    ];

    return _DashGlass(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: SizedBox(
        height: 340,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Appointments Overview',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: _DashUi.textPrimary,
                    ),
                  ),
                ),
                _ChartTab(
                  label: 'Day',
                  selected: _period == _ChartPeriod.day,
                  onTap: () => setState(() => _period = _ChartPeriod.day),
                ),
                const SizedBox(width: 6),
                _ChartTab(
                  label: 'Week',
                  selected: _period == _ChartPeriod.week,
                  onTap: () => setState(() => _period = _ChartPeriod.week),
                ),
                const SizedBox(width: 6),
                _ChartTab(
                  label: 'Month',
                  selected: _period == _ChartPeriod.month,
                  onTap: () => setState(() => _period = _ChartPeriod.month),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _ChartLegendDot(
                  color: _DashUi.blue,
                  label: _period == _ChartPeriod.day
                      ? 'Confirmed (${widget.confirmed})'
                      : 'Confirmed',
                ),
                _ChartLegendDot(
                  color: _DashUi.pink,
                  label: _period == _ChartPeriod.day
                      ? 'Cancelled (${widget.cancelled})'
                      : 'Cancelled',
                ),
                const _ChartLegendDot(
                  color: _DashUi.green,
                  label: 'Revenue trend',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY,
                  minX: 0,
                  maxX: math.max(0, pointCount - 1).toDouble(),
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
                        reservedSize: 30,
                        interval: maxY / 4,
                        getTitlesWidget: (v, _) => Text(
                          v.toInt().toString(),
                          style: const TextStyle(
                            fontSize: 10,
                            color: _DashUi.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 26,
                        interval: _period == _ChartPeriod.month ? 5 : 1,
                        getTitlesWidget: (v, _) {
                          final label = _xLabel(v.round(), pointCount);
                          if (label.isEmpty) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              label,
                              style: const TextStyle(
                                fontSize: 10,
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
                  lineBarsData: [
                    LineChartBarData(
                      spots: confirmedSpots,
                      isCurved: true,
                      barWidth: 2.5,
                      color: _DashUi.blue,
                      dotData: FlDotData(
                        show: _period == _ChartPeriod.day,
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: _DashUi.blue.withValues(alpha: 0.08),
                      ),
                    ),
                    LineChartBarData(
                      spots: cancelledSpots,
                      isCurved: true,
                      barWidth: 2,
                      color: _DashUi.pink,
                      dotData: const FlDotData(show: false),
                    ),
                    LineChartBarData(
                      spots: scaledRevenue,
                      isCurved: true,
                      barWidth: 2,
                      color: _DashUi.green,
                      dotData: const FlDotData(show: false),
                      dashArray: [6, 4],
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

class _ChartTab extends StatelessWidget {
  const _ChartTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? _DashUi.purple.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? _DashUi.purple.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? _DashUi.textPrimary : _DashUi.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChartLegendDot extends StatelessWidget {
  const _ChartLegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _DashUi.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _DashboardSideColumn extends StatelessWidget {
  const _DashboardSideColumn({
    required this.bookings,
    required this.activity,
  });

  final List<Rezervacija> bookings;
  final List<_ActivityEvent> activity;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _QuickActionsCard(),
        const SizedBox(height: _DashUi.gap),
        _UpcomingTodayCard(bookings: bookings),
        const SizedBox(height: _DashUi.gap),
        _RecentActivityCard(events: activity),
      ],
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard();

  @override
  Widget build(BuildContext context) {
    final nav = context.read<DesktopNav>();

    return _DashGlass(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _DashUi.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          _PrimaryActionButton(
            icon: Icons.add_circle_outline,
            label: 'New Appointment',
            color: _DashUi.purple,
            onTap: () => nav.requestAppointmentCreate(),
          ),
          const SizedBox(height: 8),
          _PrimaryActionButton(
            icon: Icons.person_add_alt_1_outlined,
            label: 'Add Client',
            color: _DashUi.purple,
            onTap: () => nav.requestClientAdd(),
          ),
        ],
      ),
    );
  }
}

class _PrimaryActionButton extends StatefulWidget {
  const _PrimaryActionButton({
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
  State<_PrimaryActionButton> createState() => _PrimaryActionButtonState();
}

class _PrimaryActionButtonState extends State<_PrimaryActionButton> {
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
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: widget.color.withValues(alpha: _hover ? 0.28 : 0.18),
              border: Border.all(
                color: widget.color.withValues(alpha: _hover ? 0.65 : 0.45),
              ),
            ),
            child: Row(
              children: [
                Icon(widget.icon, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 13,
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

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.event});

  final _ActivityEvent event;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(event.icon, size: 16, color: event.color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            event.text,
            style: const TextStyle(
              fontSize: 12,
              height: 1.35,
              color: _DashUi.textPrimary,
            ),
          ),
        ),
        if (event.route != null)
          Icon(
            Icons.chevron_right_rounded,
            size: 16,
            color: Colors.white.withValues(alpha: 0.35),
          ),
      ],
    );

    if (event.route == null) return row;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.read<DesktopNav>().goTo(event.route!),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: row,
        ),
      ),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({required this.events});

  final List<_ActivityEvent> events;

  @override
  Widget build(BuildContext context) {
    return _DashGlass(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _DashUi.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (events.isEmpty)
            const Text(
              'No recent activity for this day.',
              style: TextStyle(
                fontSize: 12,
                color: _DashUi.textSecondary,
              ),
            )
          else
            ...events.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ActivityRow(event: e),
              ),
            ),
        ],
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

class _UpcomingTodayCard extends StatelessWidget {
  const _UpcomingTodayCard({required this.bookings});

  final List<Rezervacija> bookings;

  @override
  Widget build(BuildContext context) {
    final nav = context.read<DesktopNav>();
    final now = DateTime.now();
    final upcoming = bookings
        .where((b) => !b.isOtkazana && !b.datumRezervacije.isBefore(now))
        .toList()
      ..sort((a, b) => a.datumRezervacije.compareTo(b.datumRezervacije));

    return _DashGlass(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Upcoming Today',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _DashUi.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => nav.goTo(DesktopRouteKey.adminCalendar),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Calendar',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: NuaLuxuryTokens.champagneGold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (upcoming.isEmpty)
            const Text(
              'No more appointments scheduled.',
              style: TextStyle(fontSize: 12, color: _DashUi.textSecondary),
            )
          else
            ...upcoming.take(5).map((r) => _UpcomingRow(rezervacija: r)),
        ],
      ),
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({required this.rezervacija});

  final Rezervacija rezervacija;

  @override
  Widget build(BuildContext context) {
    final time = _formatTimeAmPm(rezervacija.datumRezervacije);
    final service = rezervacija.uslugaNaziv ?? 'Appointment';
    final client = rezervacija.korisnikIme ?? 'Guest';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Text(
              time,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: _DashUi.blue,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _DashUi.textPrimary,
                  ),
                ),
                Text(
                  client,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
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
