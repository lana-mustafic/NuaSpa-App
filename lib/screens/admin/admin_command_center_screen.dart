import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/services/api_service.dart';
import '../../models/admin/admin_activity_feed_item.dart';
import '../../models/admin/admin_client_row.dart';
import '../../models/admin/admin_kpi.dart';
import '../../models/admin/revenue_point.dart';
import '../../models/admin/service_popularity.dart';
import '../../models/rezervacija.dart';
import '../../models/zaposlenik.dart';
import '../../ui/navigation/desktop_nav.dart';
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
    required this.bookings,
    required this.therapists,
    required this.activityFeed,
  });

  final AdminKpi? kpi;
  final List<RevenuePoint> revenue;
  final List<ServicePopularity> popularity;
  final List<Rezervacija> bookings;
  final List<Zaposlenik> therapists;
  final List<AdminActivityFeedItem> activityFeed;
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
    final from30 = day.subtract(const Duration(days: 29));
    setState(() {
      _future = () async {
        final results = await Future.wait([
          _api.getAdminKpis(date: day),
          _api.getRevenueSeries(from: from30, to: day),
          _api.getServicePopularity(from: day, to: day, take: 8),
          _api.getRezervacijeFiltered(datum: day, includeOtkazane: true),
          _api.getZaposlenici(),
          _api.getAdminActivityFeed(day: day, take: 16),
        ]);
        return _CcData(
          kpi: results[0] as AdminKpi?,
          revenue: results[1] as List<RevenuePoint>,
          popularity: results[2] as List<ServicePopularity>,
          bookings: results[3] as List<Rezervacija>,
          therapists: results[4] as List<Zaposlenik>,
          activityFeed: results[5] as List<AdminActivityFeedItem>,
        );
      }();
    });
  }

  List<double> _spark(List<RevenuePoint> pts, double fallback) {
    if (pts.isEmpty) return [fallback];
    final take = pts.length <= 14 ? pts : pts.sublist(pts.length - 14);
    final vals = take.map((p) => p.prihod).toList();
    if (vals.every((v) => v <= 0)) {
      return [fallback, fallback * 1.08, fallback * 0.96];
    }
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
        final bookings = d?.bookings ?? const <Rezervacija>[];
        final therapists = d?.therapists ?? const <Zaposlenik>[];
        final activityFeed =
            d?.activityFeed ?? const <AdminActivityFeedItem>[];

        return LayoutBuilder(
          builder: (context, c) {
            final sideW = c.maxWidth >= 1280 ? 344.0 : 306.0;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(
                      context,
                    ).copyWith(scrollbars: true),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(28, 10, 22, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Today at a Glance',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.55,
                              color: const Color(0xFFF5F3FA),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Cinematic operations cockpit for luxury bookings, revenue, therapists, and guest sentiment.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: NuaLuxuryTokens.lavenderWhisper.withValues(
                                alpha: 0.58,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          LayoutBuilder(
                            builder: (_, cc) {
                              final cols = cc.maxWidth >= 1060
                                  ? 4
                                  : (cc.maxWidth >= 720 ? 2 : 1);
                              final revenueToday = (kpi?.prihodDanas ?? 2450)
                                  .toDouble();
                              final therapistCount =
                                  kpi?.aktivniTerapeuti ?? therapists.length;
                              final kpis = [
                                LuxuryKpiCard(
                                  label: 'Total Bookings',
                                  value: '${kpi?.rezervacijeDanas ?? 28}',
                                  subtitle: 'Appointments scheduled today',
                                  trendLabel: '+12% vs yesterday',
                                  trendUp: true,
                                  icon: Icons.calendar_today_outlined,
                                  sparkline: _spark(rev, 28),
                                ),
                                LuxuryKpiCard(
                                  label: 'Revenue Today',
                                  value:
                                      '${revenueToday.toStringAsFixed(0)} KM',
                                  subtitle: 'Premium service revenue',
                                  trendLabel: '+8.4% collected',
                                  trendUp: true,
                                  icon: Icons.monetization_on_outlined,
                                  sparkline: _spark(rev, revenueToday),
                                ),
                                LuxuryKpiCard(
                                  label: 'Active Therapists',
                                  value: '$therapistCount',
                                  subtitle: 'Wellness experts online',
                                  trendLabel: 'Fully staffed',
                                  trendUp: null,
                                  icon: Icons.group_outlined,
                                  sparkline: [
                                    for (var i = 0; i < 9; i++)
                                      (therapistCount <= 0
                                              ? 12
                                              : therapistCount) +
                                          math.sin(i * 0.75) * 0.45,
                                  ],
                                ),
                                LuxuryKpiCard(
                                  label: 'Client Satisfaction Score',
                                  value:
                                      '${(kpi?.prosjecnaOcjena ?? 4.8).toStringAsFixed(1)} / 5',
                                  subtitle: 'Gold-star guest experience',
                                  trendLabel: '★★★★★',
                                  trendUp: true,
                                  icon: Icons.star_border_rounded,
                                  sparkline: const [
                                    4.6,
                                    4.7,
                                    4.74,
                                    4.72,
                                    4.8,
                                    4.78,
                                    4.85,
                                    4.8,
                                  ],
                                ),
                              ];
                              return Wrap(
                                spacing: 18,
                                runSpacing: 18,
                                children: kpis.map((card) {
                                  final w =
                                      (cc.maxWidth - 18 * (cols - 1)) / cols;
                                  return SizedBox(
                                    width: w.clamp(220, cc.maxWidth),
                                    child: card,
                                  );
                                }).toList(),
                              );
                            },
                          ),
                          const SizedBox(height: 30),
                          _AppointmentsHeader(
                            onOpenCalendar: () => context
                                .read<DesktopNav>()
                                .goTo(DesktopRouteKey.adminCalendar),
                            onOpenServicesCatalog: () => context
                                .read<DesktopNav>()
                                .goTo(DesktopRouteKey.catalog),
                          ),
                          const SizedBox(height: 14),
                          _BookingsTable(bookings: bookings),
                          const SizedBox(height: 120),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: sideW,
                  child: _RightDashboardSidebar(
                    bookings: bookings,
                    popularity: pop,
                    therapists: therapists,
                    therapistDirectoryCount: kpi?.aktivniTerapeuti,
                    activityFeed: activityFeed,
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

class _AppointmentsHeader extends StatelessWidget {
  const _AppointmentsHeader({
    required this.onOpenCalendar,
    required this.onOpenServicesCatalog,
  });

  final VoidCallback onOpenCalendar;
  final VoidCallback onOpenServicesCatalog;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            'Upcoming Appointments',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: const Color(0xFFF5F3FA),
              letterSpacing: -0.2,
            ),
          ),
        ),
        _ControlPill(
          icon: Icons.tune_rounded,
          label: 'All Services',
          trailing: Icons.keyboard_arrow_down_rounded,
          onTap: onOpenServicesCatalog,
        ),
        const SizedBox(width: 10),
        _ControlPill(
          icon: Icons.calendar_month_outlined,
          label: 'View Calendar',
          highlighted: true,
          onTap: onOpenCalendar,
        ),
      ],
    );
  }
}

class _ControlPill extends StatefulWidget {
  const _ControlPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final IconData? trailing;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  State<_ControlPill> createState() => _ControlPillState();
}

class _ControlPillState extends State<_ControlPill> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.highlighted
        ? NuaLuxuryTokens.softPurpleGlow
        : NuaLuxuryTokens.lavenderWhisper;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: color.withValues(alpha: _hover ? 0.16 : 0.09),
            border: Border.all(color: color.withValues(alpha: 0.28)),
            boxShadow: widget.highlighted
                ? [
                    BoxShadow(
                      color: NuaLuxuryTokens.softPurpleGlow.withValues(
                        alpha: 0.18,
                      ),
                      blurRadius: 18,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFF5F3FA),
                ),
              ),
              if (widget.trailing != null) ...[
                const SizedBox(width: 4),
                Icon(widget.trailing, size: 18, color: color),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RightDashboardSidebar extends StatelessWidget {
  const _RightDashboardSidebar({
    required this.bookings,
    required this.popularity,
    required this.therapists,
    required this.activityFeed,
    this.therapistDirectoryCount,
  });

  final List<Rezervacija> bookings;
  final List<ServicePopularity> popularity;
  final List<Zaposlenik> therapists;
  final List<AdminActivityFeedItem> activityFeed;
  /// From admin KPI (directory size); falls back to [therapists.length].
  final int? therapistDirectoryCount;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, 10, 28, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _UpcomingTodayCard(bookings: bookings),
          const SizedBox(height: 16),
          _RecentActivityCard(activityFeed: activityFeed),
          const SizedBox(height: 16),
          _TopServicesTodayCard(popularity: popularity),
          const SizedBox(height: 16),
          _TherapistPresenceCard(
            therapists: therapists,
            directoryCount: therapistDirectoryCount,
          ),
        ],
      ),
    );
  }
}

class _UpcomingTodayCard extends StatelessWidget {
  const _UpcomingTodayCard({required this.bookings});

  final List<Rezervacija> bookings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = bookings.where((b) => !b.isOtkazana).toList();
    active.sort((a, b) => a.datumRezervacije.compareTo(b.datumRezervacije));
    final next = active.isEmpty ? null : active.first;
    final count = active.length;
    return LuxuryGlassPanel(
      borderRadius: NuaLuxuryTokens.radiusXl,
      opacity: 0.42,
      blurSigma: 28,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Upcoming Today',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Icon(
                Icons.auto_awesome_rounded,
                color: NuaLuxuryTokens.champagneGold,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            count == 1 ? '1 appointment' : '$count appointments',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: const Color(0xFFF5F3FA),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            next == null
                ? 'No upcoming slots today'
                : 'Next: ${_formatTimeAmPm(next.datumRezervacije)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: NuaLuxuryTokens.lavenderWhisper.withValues(alpha: 0.62),
            ),
          ),
          const SizedBox(height: 18),
          const _UpcomingAmbientPanel(),
        ],
      ),
    );
  }
}

class _UpcomingAmbientPanel extends StatelessWidget {
  const _UpcomingAmbientPanel();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 112,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.20),
              NuaLuxuryTokens.champagneGold.withValues(alpha: 0.10),
              Colors.white.withValues(alpha: 0.035),
            ],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.16),
              blurRadius: 26,
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -18,
              top: -30,
              child: Container(
                width: 116,
                height: 116,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.16),
                ),
              ),
            ),
            Positioned(
              left: 18,
              top: 20,
              child: Text(
                'Luxury flow',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFF5F3FA),
                ),
              ),
            ),
            Positioned(
              left: 18,
              top: 46,
              right: 88,
              child: Text(
                'Soft capacity pacing for therapists, rooms, and guest arrivals.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: NuaLuxuryTokens.lavenderWhisper.withValues(
                    alpha: 0.58,
                  ),
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({required this.activityFeed});

  final List<AdminActivityFeedItem> activityFeed;

  @override
  Widget build(BuildContext context) {
    final items = activityFeed.map((row) {
      final vis = _activityFeedVisual(row.tip, row.naslov);
      final sub = row.podnaslov;
      final timeBits = <String>[
        if (sub != null && sub.isNotEmpty) sub,
        _relativeTimeLabel(row.datumVrijeme),
      ];
      return _ActivityItem(
        icon: vis.$1,
        color: vis.$2,
        text: row.naslov,
        time: timeBits.join(' · '),
      );
    }).toList();

    return LuxuryGlassPanel(
      borderRadius: NuaLuxuryTokens.radiusXl,
      opacity: 0.38,
      blurSigma: 24,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Activity',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            Text(
              'No activity for this day yet.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: NuaLuxuryTokens.lavenderWhisper.withValues(
                      alpha: 0.55,
                    ),
                  ),
            )
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 13),
                child: item,
              ),
            ),
        ],
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  const _ActivityItem({
    required this.icon,
    required this.color,
    required this.text,
    required this.time,
  });

  final IconData icon;
  final Color color;
  final String text;
  final String time;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.13),
            border: Border.all(color: color.withValues(alpha: 0.32)),
          ),
          child: Icon(icon, size: 17, color: color),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                time,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: NuaLuxuryTokens.lavenderWhisper.withValues(
                    alpha: 0.48,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TopServicesTodayCard extends StatelessWidget {
  const _TopServicesTodayCard({required this.popularity});

  final List<ServicePopularity> popularity;

  @override
  Widget build(BuildContext context) {
    final items = popularity.take(4).toList();
    final theme = Theme.of(context);

    if (items.isEmpty) {
      return LuxuryGlassPanel(
        borderRadius: NuaLuxuryTokens.radiusXl,
        opacity: 0.38,
        blurSigma: 24,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top Services Today',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No paid service volume for this day yet.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: NuaLuxuryTokens.lavenderWhisper.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      );
    }

    final total = items.fold<double>(
      0,
      (sum, item) => sum + item.brojRezervacija,
    );
    final colors = [
      NuaLuxuryTokens.softPurpleGlow,
      NuaLuxuryTokens.champagneGold,
      NuaLuxuryTokens.lavenderWhisper,
      const Color(0xFF6EE7B7),
    ];

    return LuxuryGlassPanel(
      borderRadius: NuaLuxuryTokens.radiusXl,
      opacity: 0.38,
      blurSigma: 24,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Services Today',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 154,
            child: Row(
              children: [
                SizedBox(
                  width: 116,
                  child: ClipRect(
                    child: Center(
                      child: SizedBox.square(
                        dimension: 106,
                        child: PieChart(
                          PieChartData(
                            centerSpaceRadius: 32,
                            sectionsSpace: 2.5,
                            sections: [
                              for (var i = 0; i < items.length; i++)
                                PieChartSectionData(
                                  value: items[i].brojRezervacija
                                      .toDouble()
                                      .clamp(1, 1e9),
                                  color: colors[i % colors.length],
                                  radius: 24,
                                  showTitle: false,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < items.length; i++)
                        _ServiceLegendRow(
                          label: items[i].naziv,
                          share: total <= 0
                              ? '0%'
                              : '${((items[i].brojRezervacija / total) * 100).round()}%',
                          color: colors[i % colors.length],
                        ),
                    ],
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

class _ServiceLegendRow extends StatelessWidget {
  const _ServiceLegendRow({
    required this.label,
    required this.share,
    required this.color,
  });

  final String label;
  final String share;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.42), blurRadius: 8),
              ],
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          Text(
            share,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _TherapistPresenceCard extends StatelessWidget {
  const _TherapistPresenceCard({
    required this.therapists,
    this.directoryCount,
  });

  final List<Zaposlenik> therapists;
  final int? directoryCount;

  @override
  Widget build(BuildContext context) {
    final visible = therapists.take(5).toList();
    final n = directoryCount ?? therapists.length;
    return LuxuryGlassPanel(
      borderRadius: NuaLuxuryTokens.radiusXl,
      opacity: 0.34,
      blurSigma: 22,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          for (final t in visible)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: CircleAvatar(
                radius: 17,
                backgroundColor: NuaLuxuryTokens.softPurpleGlow.withValues(
                  alpha: 0.42,
                ),
                child: Text(
                  '${_initial(t.ime)}${_initial(t.prezime)}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          Expanded(
            child: Text(
              n <= 0
                  ? 'No therapists in directory'
                  : n == 1
                      ? '1 therapist active'
                      : '$n therapists active',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: NuaLuxuryTokens.lavenderWhisper.withValues(alpha: 0.66),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _initial(String value) =>
      value.trim().isEmpty ? 'N' : value.trim()[0].toUpperCase();
}

(IconData, Color) _activityFeedVisual(String tip, String naslov) {
  final t = tip.toLowerCase();
  switch (t) {
    case 'payment':
      return (Icons.payments_outlined, NuaLuxuryTokens.champagneGold);
    case 'review':
      return (Icons.star_rate_rounded, const Color(0xFFE8C07D));
    case 'client':
      return (Icons.person_add_alt_outlined, const Color(0xFF6EE7B7));
    case 'booking':
      if (naslov.toLowerCase().contains('cancel')) {
        return (Icons.event_busy_outlined, const Color(0xFFE57373));
      }
      return (Icons.event_available_outlined, NuaLuxuryTokens.softPurpleGlow);
    default:
      if (naslov.toLowerCase().contains('cancel')) {
        return (Icons.event_busy_outlined, const Color(0xFFE57373));
      }
      return (Icons.notifications_none_outlined, NuaLuxuryTokens.lavenderWhisper);
  }
}

String _relativeTimeLabel(DateTime t) {
  final now = DateTime.now();
  final d = t.toLocal();
  final n = now.toLocal();
  final diff = n.difference(d);
  if (diff.isNegative) {
    final ahead = d.difference(n);
    if (ahead.inMinutes < 1) return 'Soon';
    if (ahead.inMinutes < 60) return 'In ${ahead.inMinutes} min';
    if (ahead.inHours < 24) return 'In ${ahead.inHours} h';
    return _formatTimeAmPm(d);
  }
  if (diff.inSeconds < 45) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays < 7) return '${diff.inDays} d ago';
  return '${d.month}/${d.day}/${d.year}';
}

String _formatTimeAmPm(DateTime d) {
  final loc = d.toLocal();
  final hour = loc.hour % 12 == 0 ? 12 : loc.hour % 12;
  final minute = loc.minute.toString().padLeft(2, '0');
  final suffix = loc.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}

// Kept as a ready-to-restore deep analytics section for later admin iterations.
// ignore: unused_element
class _AnalyticsRow extends StatelessWidget {
  const _AnalyticsRow({required this.revenue, required this.popularity});

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
                        .map(
                          (s) => LineTooltipItem(
                            '${s.y.toStringAsFixed(0)} KM',
                            TextStyle(
                              color: Colors.white.withValues(alpha: 0.95),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (s, ix, bd, pct) => FlDotCirclePainter(
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

    final total = popularity.fold<double>(
      0,
      (a, x) => a + x.brojRezervacija.toDouble(),
    );
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
                      sections: sections.length > 1
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
                                    color: colors[i % colors.length].withValues(
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

  String _initials(String? name) {
    final parts = (name ?? 'Nua Guest')
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'NG';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String _serviceCategory(String? service) {
    final s = (service ?? '').toLowerCase();
    if (s.contains('massage') || s.contains('masa')) return 'Massage therapy';
    if (s.contains('facial') || s.contains('face')) return 'Skin ritual';
    if (s.contains('sauna') || s.contains('hammam')) return 'Thermal wellness';
    return 'Luxury wellness';
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
          constraints: const BoxConstraints(minWidth: 900),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              Colors.white.withValues(alpha: 0.028),
            ),
            dividerThickness: 0.35,
            columnSpacing: 24,
            dataRowMinHeight: 62,
            dataRowMaxHeight: 70,
            columns: const [
              DataColumn(label: Text('TIME')),
              DataColumn(label: Text('CLIENT')),
              DataColumn(label: Text('SERVICE')),
              DataColumn(label: Text('THERAPIST')),
              DataColumn(label: Text('DURATION')),
              DataColumn(label: Text('STATUS')),
            ],
            rows: bookings.isEmpty
                ? [
                    DataRow(
                      cells: List.generate(6, (_) => const DataCell(Text('—'))),
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
                          DataCell(
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: NuaLuxuryTokens
                                      .softPurpleGlow
                                      .withValues(alpha: 0.36),
                                  child: Text(
                                    _initials(r.korisnikIme),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 11),
                                SizedBox(
                                  width: 170,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        r.korisnikIme ?? 'Nua Guest',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      Text(
                                        r.korisnikTelefon ?? '+387 61 000 000',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color: NuaLuxuryTokens
                                                  .lavenderWhisper
                                                  .withValues(alpha: 0.48),
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 180,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.uslugaNaziv ?? 'Signature Ritual',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    _serviceCategory(r.uslugaNaziv),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: NuaLuxuryTokens.champagneGold
                                          .withValues(alpha: 0.72),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          DataCell(
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: NuaLuxuryTokens.champagneGold
                                      .withValues(alpha: 0.2),
                                  child: Text(
                                    _initials(r.zaposlenikIme),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                SizedBox(
                                  width: 150,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        r.zaposlenikIme ?? 'Nua Therapist',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        'Senior therapist',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color: NuaLuxuryTokens
                                                  .lavenderWhisper
                                                  .withValues(alpha: 0.48),
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DataCell(
                            Text(
                              '${r.uslugaTrajanjeMinuta > 0 ? r.uslugaTrajanjeMinuta : 60} min',
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

// ignore: unused_element
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
                  backgroundColor: NuaLuxuryTokens.softPurpleGlow.withValues(
                    alpha: 0.44,
                  ),
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
                          Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: NuaLuxuryTokens.champagneGold,
                          ),
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

  String _ini(String s) => s.trim().isEmpty ? '·' : s.trim()[0].toUpperCase();

  Widget _chip(BuildContext context, String t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(999),
      border: Border.all(
        color: NuaLuxuryTokens.lavenderWhisper.withValues(alpha: 0.32),
      ),
      color: Colors.white.withValues(alpha: 0.04),
    ),
    child: Text(
      t,
      style: Theme.of(
        context,
      ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
    ),
  );
}

// ignore: unused_element
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
              headingRowColor: WidgetStateProperty.all(
                Colors.white.withValues(alpha: 0.04),
              ),
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
                              backgroundColor: NuaLuxuryTokens.softPurpleGlow
                                  .withValues(alpha: 0.45),
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
                          child: Text(
                            rows[i].email,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        onTap: () => onSelect(rows[i]),
                      ),
                      DataCell(
                        Text(
                          rows[i].zadnjaPosjeta
                                  ?.toLocal()
                                  .toIso8601String()
                                  .split('T')
                                  .first ??
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
                                      Icon(
                                        Icons.star_rounded,
                                        size: 14,
                                        color: NuaLuxuryTokens.champagneGold,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'VIP',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color:
                                                  NuaLuxuryTokens.champagneGold,
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

  String _ini(String s) => s.trim().isEmpty ? '·' : s.trim()[0].toUpperCase();
}

// ignore: unused_element
class _ClientInsightPanel extends StatelessWidget {
  const _ClientInsightPanel({required this.client, required this.onClose});

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
                  backgroundColor: NuaLuxuryTokens.softPurpleGlow.withValues(
                    alpha: 0.5,
                  ),
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
            _section(context, 'Contact', [
              _kv('Email', client.email),
              _kv('Phone', client.telefon.isEmpty ? '—' : client.telefon),
            ]),
            _section(context, 'Loyalty', [
              _kv('Visits', '${client.ukupnoPosjeta}'),
              _kv(
                'Lifetime value',
                '${client.ukupnoPotroseno.toStringAsFixed(0)} KM',
              ),
              _kv(
                'Member since',
                client.datumRegistracije.toLocal().toString().split(' ').first,
              ),
            ]),
            _section(context, 'Preferences & notes', [
              _kv(
                'Last appointment',
                client.zadnjaPosjeta?.toLocal().toString().split('.').first ??
                    '—',
              ),
              _kv('Notes', 'Curated wellness journey — sync with CRM module.'),
              _kv('Favourite treatments', 'Derived from spend & booking mix'),
            ]),
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

  Widget _section(BuildContext context, String title, List<Widget> children) {
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
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ],
    ),
  );
}
