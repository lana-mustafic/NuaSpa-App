import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../ui/theme/nua_luxury_tokens.dart';
import '../../ui/widgets/luxury/luxury_glass_panel.dart';

class AdminRevenueAnalyticsScreen extends StatelessWidget {
  const AdminRevenueAnalyticsScreen({super.key});

  static const _revenue = [
    2800.0,
    2150.0,
    3900.0,
    4300.0,
    5200.0,
    6100.0,
    7850.0,
    6900.0,
    8200.0,
    7450.0,
    9100.0,
    8750.0,
    9800.0,
    8650.0,
  ];

  @override
  Widget build(BuildContext context) {
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
                padding: const EdgeInsets.fromLTRB(28, 12, 22, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _KpiGrid(),
                    const SizedBox(height: 22),
                    _RevenueChartCard(values: _revenue),
                    const SizedBox(height: 22),
                    const _RevenueBreakdownTable(),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 356,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(0, 12, 28, 32),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _RevenueByServiceCard(),
                    SizedBox(height: 18),
                    _TopSpendersCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid();

  @override
  Widget build(BuildContext context) {
    final cards = const [
      _KpiSpec(
        title: 'Total Revenue',
        value: '12,450 KM',
        subtitle: '+18.5% vs Apr 12 — May 11, 2025',
        icon: Icons.attach_money_rounded,
        values: [3, 4.2, 4.0, 5.8, 6.4, 7.9, 8.8],
      ),
      _KpiSpec(
        title: 'Revenue from Services',
        value: '9,870 KM',
        subtitle: '+14.2% service revenue',
        icon: Icons.spa_outlined,
        values: [2.8, 3.5, 4.4, 4.2, 5.8, 6.7, 7.2],
      ),
      _KpiSpec(
        title: 'Revenue from Packages',
        value: '2,180 KM',
        subtitle: '+22.8% package sales',
        icon: Icons.card_giftcard_outlined,
        values: [1.2, 1.5, 1.4, 1.8, 2.0, 2.7, 3.0],
      ),
      _KpiSpec(
        title: 'Avg. Order Value',
        value: '145 KM',
        subtitle: '+6.1% average ticket',
        icon: Icons.account_balance_wallet_outlined,
        values: [1.8, 1.9, 2.2, 2.1, 2.35, 2.48, 2.56],
      ),
    ];

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
                    boxShadow: [
                      BoxShadow(
                        color: NuaLuxuryTokens.softPurpleGlow.withValues(
                          alpha: 0.18,
                        ),
                        blurRadius: 18,
                      ),
                    ],
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
                  child: _MiniLine(values: spec.values),
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
                color: const Color(0xFF4ADE80),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevenueChartCard extends StatelessWidget {
  const _RevenueChartCard({required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
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
                const _RangePill(label: 'Daily', active: true),
                const SizedBox(width: 8),
                const _RangePill(label: 'Weekly'),
                const SizedBox(width: 8),
                const _RangePill(label: 'Monthly'),
                const SizedBox(width: 8),
                const _IconGlassButton(icon: Icons.more_horiz_rounded),
              ],
            ),
            const SizedBox(height: 18),
            Expanded(
              child: LineChart(
                LineChartData(
                  minY: 2000,
                  maxY: 10000,
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: 2000,
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
                        reservedSize: 38,
                        interval: 2000,
                        getTitlesWidget: (v, _) => Text(
                          '${(v / 1000).round()}K',
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
                        showTitles: true,
                        reservedSize: 28,
                        interval: 4,
                        getTitlesWidget: (v, _) {
                          final labels = {
                            0: 'May 12',
                            4: 'May 20',
                            8: 'May 28',
                            12: 'Jun 9',
                          };
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              labels[v.round()] ?? '',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.42),
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
                      getTooltipItems: (items) => items
                          .map(
                            (item) => LineTooltipItem(
                              'May 27, 2025\n${item.y.toStringAsFixed(0)} KM',
                              const TextStyle(
                                color: Color(0xFFF5F3FA),
                                fontWeight: FontWeight.w800,
                                height: 1.45,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      barWidth: 3.2,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, bar, index) =>
                            FlDotCirclePainter(
                              radius: 3.2,
                              color: Colors.white.withValues(alpha: 0.86),
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
                      shadow: Shadow(
                        color: NuaLuxuryTokens.softPurpleGlow.withValues(
                          alpha: 0.55,
                        ),
                        blurRadius: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            const _ChartMetrics(),
          ],
        ),
      ),
    );
  }
}

class _ChartMetrics extends StatelessWidget {
  const _ChartMetrics();

  @override
  Widget build(BuildContext context) {
    final metrics = const [
      ('This Period', '12,450 KM'),
      ('Previous Period', '10,510 KM'),
      ('Change', '18.5% ↑'),
      ('Best Day', 'May 27, 2025\n7,850 KM'),
      ('Worst Day', 'May 15, 2025\n2,150 KM'),
    ];

    return Row(
      children: [
        for (var i = 0; i < metrics.length; i++) ...[
          Expanded(
            child: _MetricText(label: metrics[i].$1, value: metrics[i].$2),
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
  const _RevenueByServiceCard();

  @override
  Widget build(BuildContext context) {
    final items = const [
      _ServiceRevenue('Swedish Massage', '34%', '4,230 KM', Color(0xFF7B4DFF)),
      _ServiceRevenue(
        'Deep Tissue Massage',
        '24%',
        '2,980 KM',
        Color(0xFF9D6BFF),
      ),
      _ServiceRevenue('Facials', '18%', '2,240 KM', Color(0xFFC8B6E8)),
      _ServiceRevenue('Aromatherapy', '14%', '1,740 KM', Color(0xFFD4AF7A)),
      _ServiceRevenue('Other Services', '10%', '1,260 KM', Color(0xFF4ADE80)),
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
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                centerSpaceRadius: 58,
                sectionsSpace: 3,
                sections: [
                  for (final item in items)
                    PieChartSectionData(
                      value: double.parse(item.percent.replaceAll('%', '')),
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
      ),
    );
  }
}

class _TopSpendersCard extends StatelessWidget {
  const _TopSpendersCard();

  @override
  Widget build(BuildContext context) {
    final spenders = const [
      _Spender('Sarah Johnson', '12 appointments', '1,850 KM'),
      _Spender('Marko Petrović', '8 appointments', '1,420 KM'),
      _Spender('Emma Wilson', '10 appointments', '1,250 KM'),
      _Spender('Ana Kovač', '7 appointments', '980 KM'),
      _Spender('Ivana Babić', '6 appointments', '875 KM'),
    ];

    return LuxuryGlassPanel(
      borderRadius: 24,
      blurSigma: 26,
      opacity: 0.38,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Top Spenders',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFF5F3FA),
                  ),
                ),
              ),
              Text(
                'View All',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: NuaLuxuryTokens.champagneGold,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < spenders.length; i++)
            _SpenderRow(rank: i + 1, spender: spenders[i]),
        ],
      ),
    );
  }
}

class _RevenueBreakdownTable extends StatelessWidget {
  const _RevenueBreakdownTable();

  @override
  Widget build(BuildContext context) {
    final rows = const [
      _Breakdown('Services', '9,870', 0.79, '+14.2%', true),
      _Breakdown('Packages', '2,180', 0.18, '+22.8%', true),
      _Breakdown('Gift Cards', '280', 0.02, '-3.4%', false),
      _Breakdown('Other', '120', 0.01, '+1.8%', true),
    ];
    return LuxuryGlassPanel(
      borderRadius: 24,
      blurSigma: 24,
      opacity: 0.36,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Revenue Breakdown',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: const Color(0xFFF5F3FA),
            ),
          ),
          const SizedBox(height: 18),
          const _BreakdownHeader(),
          const SizedBox(height: 8),
          for (final row in rows) _BreakdownRow(row: row),
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
        Expanded(flex: 2, child: Text('CATEGORY', style: style)),
        Expanded(child: Text('REVENUE (KM)', style: style)),
        Expanded(flex: 2, child: Text('% OF TOTAL', style: style)),
        Expanded(
          child: Text('CHANGE', textAlign: TextAlign.right, style: style),
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
                      valueColor: AlwaysStoppedAnimation(
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
              row.change,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: row.positive
                    ? const Color(0xFF4ADE80)
                    : const Color(0xFFFF5E7A),
                fontWeight: FontWeight.w900,
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
    final minY = values.reduce(math.min);
    final maxY = values.reduce(math.max);
    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
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
            shadow: Shadow(
              color: NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.5),
              blurRadius: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _RangePill extends StatelessWidget {
  const _RangePill({required this.label, this.active = false});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

class _IconGlassButton extends StatelessWidget {
  const _IconGlassButton({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Icon(icon, size: 19),
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
              boxShadow: [
                BoxShadow(
                  color: item.color.withValues(alpha: 0.45),
                  blurRadius: 8,
                ),
              ],
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
            width: 70,
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
  const _ServiceRevenue(this.label, this.percent, this.revenue, this.color);

  final String label;
  final String percent;
  final String revenue;
  final Color color;
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
    this.change,
    this.positive,
  );

  final String category;
  final String revenue;
  final double percent;
  final String change;
  final bool positive;
}
