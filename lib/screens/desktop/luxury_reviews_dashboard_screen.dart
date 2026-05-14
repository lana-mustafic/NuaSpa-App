import 'dart:ui';

import 'package:flutter/material.dart';

import '../../ui/theme/nua_luxury_tokens.dart';

/// Premium dark-mode Reviews & Feedback dashboard (desktop).
class LuxuryReviewsDashboardScreen extends StatefulWidget {
  const LuxuryReviewsDashboardScreen({super.key});

  static const Color secondaryPurple = Color(0xFF9D6BFF);
  static const Color successGreen = Color(0xFF4ADE80);
  static const Color textPrimary = Color(0xFFF5F3FA);

  @override
  State<LuxuryReviewsDashboardScreen> createState() =>
      _LuxuryReviewsDashboardScreenState();
}

class _LuxuryReviewsDashboardScreenState
    extends State<LuxuryReviewsDashboardScreen> {
  int _page = 1;
  final TextEditingController _tableSearch = TextEditingController();

  static const List<_ReviewRow> _rows = [
    _ReviewRow(
      guestName: 'Sarah Johnson',
      visits: 12,
      service: 'Swedish Massage',
      therapist: 'Amara Vuković',
      rating: 5.0,
      review:
          'Amazing experience! Amara was so professional and made me feel completely relaxed...',
      source: 'Google',
      dateLabel: 'May 14, 2026, 10:30 AM',
    ),
    _ReviewRow(
      guestName: 'Emma Wilson',
      visits: 8,
      service: 'Aromatherapy',
      therapist: 'Lana K.',
      rating: 4.5,
      review:
          'Very relaxing atmosphere and great service. Will definitely come back!',
      source: 'Facebook',
      dateLabel: 'May 13, 2026, 04:15 PM',
    ),
    _ReviewRow(
      guestName: 'Marko Petrović',
      visits: 5,
      service: 'Deep Tissue Massage',
      therapist: 'Mia H.',
      rating: 4.0,
      review:
          'Good massage, helped with my back pain. The room was a bit cold.',
      source: 'Google',
      dateLabel: 'May 13, 2026, 02:20 PM',
    ),
    _ReviewRow(
      guestName: 'Ana Kovač',
      visits: 15,
      service: 'Hot Stone Massage',
      therapist: 'Amara Vuković',
      rating: 5.0,
      review: 'Perfect! The hot stones were amazing and Amara has magic hands.',
      source: 'Instagram',
      dateLabel: 'May 12, 2026, 11:45 AM',
    ),
    _ReviewRow(
      guestName: 'Ivana Babić',
      visits: 3,
      service: 'Facial Treatment',
      therapist: 'Zara P.',
      rating: 4.5,
      review:
          'My skin feels fantastic! Very professional and clean environment.',
      source: 'Google',
      dateLabel: 'May 12, 2026, 09:10 AM',
    ),
  ];

  @override
  void dispose() {
    _tableSearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mq = MediaQuery.sizeOf(context);
    final showRight = mq.width >= 1300;
    final tightHeight = mq.height < 720;
    final pad = tightHeight ? 14.0 : 20.0;
    final gap = tightHeight ? 10.0 : 14.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        return ColoredBox(
          color: Colors.transparent,
          child: Padding(
            padding: EdgeInsets.fromLTRB(pad, tightHeight ? 8 : 12, pad, pad),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _HeaderGlassCard(theme: theme, compact: tightHeight),
                          SizedBox(height: gap),
                          _KpiRow(compact: tightHeight),
                          SizedBox(height: gap),
                          _FilterBar(
                            controller: _tableSearch,
                            compact: tightHeight,
                          ),
                          SizedBox(height: gap),
                          _ReviewsTable(rows: _rows, compact: tightHeight),
                          SizedBox(height: gap),
                          _PaginationBar(
                            page: _page,
                            totalPages: 13,
                            onPage: (p) => setState(() => _page = p),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (showRight) ...[
                  SizedBox(width: tightHeight ? 14 : 18),
                  SizedBox(
                    width: 300,
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: _RightInsightsColumn(compact: tightHeight),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReviewRow {
  const _ReviewRow({
    required this.guestName,
    required this.visits,
    required this.service,
    required this.therapist,
    required this.rating,
    required this.review,
    required this.source,
    required this.dateLabel,
  });

  final String guestName;
  final int visits;
  final String service;
  final String therapist;
  final double rating;
  final String review;
  final String source;
  final String dateLabel;
}

Widget _glassCard({
  required Widget child,
  double radius = 22,
  double borderOpacity = 0.08,
  List<BoxShadow>? extraShadow,
}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          color: Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: Colors.white.withValues(alpha: borderOpacity),
            width: 0.9,
          ),
          boxShadow: [
            ...?extraShadow,
            BoxShadow(
              color: NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.06),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: child,
      ),
    ),
  );
}

class _HeaderGlassCard extends StatelessWidget {
  const _HeaderGlassCard({required this.theme, required this.compact});

  final ThemeData theme;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return _glassCard(
      radius: 22,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 16 : 22,
          vertical: compact ? 14 : 18,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: compact ? 44 : 52,
              height: compact ? 44 : 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.95),
                    LuxuryReviewsDashboardScreen.secondaryPurple.withValues(
                      alpha: 0.75,
                    ),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: NuaLuxuryTokens.softPurpleGlow.withValues(
                      alpha: 0.35,
                    ),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                Icons.reviews_rounded,
                color: Colors.white.withValues(alpha: 0.95),
                size: compact ? 22 : 26,
              ),
            ),
            SizedBox(width: compact ? 14 : 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reviews & Feedback',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                      color: LuxuryReviewsDashboardScreen.textPrimary,
                      fontSize: compact ? 18 : 22,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Track reviews, guest sentiment and service reputation.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.65),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            if (!compact) ...[
              _MiniDropdown(
                label: 'May 8 – May 14, 2026',
                icon: Icons.date_range_outlined,
              ),
              const SizedBox(width: 12),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [
                      NuaLuxuryTokens.softPurpleGlow,
                      LuxuryReviewsDashboardScreen.secondaryPurple,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: NuaLuxuryTokens.softPurpleGlow.withValues(
                        alpha: 0.4,
                      ),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {},
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.download_rounded,
                            size: 18,
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Export Report',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ] else ...[
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: NuaLuxuryTokens.softPurpleGlow,
                ),
                onPressed: () {},
                icon: const Icon(Icons.download_rounded, size: 20),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniDropdown extends StatelessWidget {
  const _MiniDropdown({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {},
        child: _glassCard(
          radius: 14,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: LuxuryReviewsDashboardScreen.textPrimary,
                  ),
                ),
                Icon(
                  Icons.expand_more_rounded,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final gap = compact ? 10.0 : 12.0;
    return LayoutBuilder(
      builder: (context, c) {
        final oneRow = c.maxWidth >= 900;
        if (oneRow) {
          return Row(
            children: [
              Expanded(
                child: _KpiCard(
                  title: 'Average Rating',
                  value: '4.8',
                  suffix: ' / 5.0',
                  growth: '+0.3',
                  subtitle: 'vs previous 7 days',
                  compact: compact,
                  leading: Icon(
                    Icons.star_rounded,
                    color: NuaLuxuryTokens.champagneGold,
                    size: compact ? 22 : 26,
                  ),
                ),
              ),
              SizedBox(width: gap),
              Expanded(
                child: _KpiCard(
                  title: 'Total Reviews',
                  value: '128',
                  growth: '+18%',
                  subtitle: 'vs previous 7 days',
                  compact: compact,
                  progress: null,
                ),
              ),
              SizedBox(width: gap),
              Expanded(
                child: _KpiCard(
                  title: 'Positive Reviews',
                  value: '92%',
                  growth: '+6%',
                  subtitle: 'vs previous 7 days',
                  compact: compact,
                  progress: 0.92,
                ),
              ),
              SizedBox(width: gap),
              Expanded(
                child: _KpiCard(
                  title: 'Response Rate',
                  value: '96%',
                  growth: '+4%',
                  subtitle: 'vs previous 7 days',
                  compact: compact,
                  progress: 0.96,
                ),
              ),
            ],
          );
        }
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _KpiCard(
                    title: 'Average Rating',
                    value: '4.8',
                    suffix: ' / 5.0',
                    growth: '+0.3',
                    subtitle: 'vs previous 7 days',
                    compact: true,
                    leading: Icon(
                      Icons.star_rounded,
                      color: NuaLuxuryTokens.champagneGold,
                      size: 22,
                    ),
                  ),
                ),
                SizedBox(width: gap),
                Expanded(
                  child: _KpiCard(
                    title: 'Total Reviews',
                    value: '128',
                    growth: '+18%',
                    subtitle: 'vs previous 7 days',
                    compact: true,
                  ),
                ),
              ],
            ),
            SizedBox(height: gap),
            Row(
              children: [
                Expanded(
                  child: _KpiCard(
                    title: 'Positive Reviews',
                    value: '92%',
                    growth: '+6%',
                    subtitle: 'vs previous 7 days',
                    compact: true,
                    progress: 0.92,
                  ),
                ),
                SizedBox(width: gap),
                Expanded(
                  child: _KpiCard(
                    title: 'Response Rate',
                    value: '96%',
                    growth: '+4%',
                    subtitle: 'vs previous 7 days',
                    compact: true,
                    progress: 0.96,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.growth,
    required this.subtitle,
    required this.compact,
    this.suffix,
    this.leading,
    this.progress,
  });

  final String title;
  final String value;
  final String? suffix;
  final String growth;
  final String subtitle;
  final bool compact;
  final Widget? leading;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final growthColor = growth.startsWith('+')
        ? LuxuryReviewsDashboardScreen.successGreen
        : Colors.white70;

    return _glassCard(
      radius: 20,
      extraShadow: [
        BoxShadow(
          color: NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.08),
          blurRadius: 20,
        ),
      ],
      child: Padding(
        padding: EdgeInsets.all(compact ? 14 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 8)],
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: growthColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: growthColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    growth,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: growthColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 8 : 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                      color: LuxuryReviewsDashboardScreen.textPrimary,
                      fontSize: compact ? 26 : 30,
                    ),
                  ),
                ),
                if (suffix != null)
                  Text(
                    suffix!,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
              ],
            ),
            if (progress != null) ...[
              SizedBox(height: compact ? 8 : 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  color: NuaLuxuryTokens.softPurpleGlow,
                ),
              ),
            ],
            SizedBox(height: compact ? 6 : 8),
            Text(
              subtitle,
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.controller, required this.compact});

  final TextEditingController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth > 920;
        if (wide) {
          return Row(
            children: [
              Expanded(
                flex: 3,
                child: _FilterSearchField(controller: controller),
              ),
              SizedBox(width: compact ? 8 : 10),
              Expanded(child: _FilterDropdown(label: 'All ratings')),
              SizedBox(width: compact ? 8 : 10),
              Expanded(child: _FilterDropdown(label: 'All services')),
              SizedBox(width: compact ? 8 : 10),
              Expanded(child: _FilterDropdown(label: 'All therapists')),
              SizedBox(width: compact ? 8 : 10),
              Expanded(child: _FilterDropdown(label: 'All sources')),
              SizedBox(width: compact ? 8 : 10),
              _FiltersButton(),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FilterSearchField(controller: controller),
            SizedBox(height: compact ? 8 : 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FilterDropdown(label: 'All ratings'),
                _FilterDropdown(label: 'All services'),
                _FilterDropdown(label: 'All therapists'),
                _FilterDropdown(label: 'All sources'),
                _FiltersButton(),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _FilterSearchField extends StatelessWidget {
  const _FilterSearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _glassCard(
      radius: 14,
      child: TextField(
        controller: controller,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: LuxuryReviewsDashboardScreen.textPrimary,
        ),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search reviews…',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: Colors.white.withValues(alpha: 0.45),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 12,
          ),
        ),
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {},
        child: _glassCard(
          radius: 14,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.88),
                    ),
                  ),
                ),
                Icon(
                  Icons.expand_more_rounded,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FiltersButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {},
        child: _glassCard(
          radius: 14,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
                const SizedBox(width: 6),
                Text(
                  'Filters',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
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

class _ReviewsTable extends StatelessWidget {
  const _ReviewsTable({required this.rows, required this.compact});

  final List<_ReviewRow> rows;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _glassCard(
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 12 : 16,
              compact ? 10 : 14,
              compact ? 12 : 16,
              0,
            ),
            child: _TableHeaderRow(compact: compact, theme: theme),
          ),
          Divider(
            height: 1,
            thickness: 0.5,
            color: Colors.white.withValues(alpha: 0.08),
          ),
          for (var i = 0; i < rows.length; i++)
            _TableDataRow(row: rows[i], compact: compact, theme: theme),
        ],
      ),
    );
  }
}

class _TableHeaderRow extends StatelessWidget {
  const _TableHeaderRow({required this.compact, required this.theme});

  final bool compact;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(compact ? 16 : 20),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 8 : 10),
        child: Row(
          children: [
            _hCell('Guest', 2, theme),
            _hCell('Service', 2, theme),
            _hCell('Rating', 1, theme),
            _hCell('Review', 3, theme),
            _hCell('Source', 1, theme),
            _hCell('Date', 1, theme),
            _hCell('Actions', 1, theme),
          ],
        ),
      ),
    );
  }

  Widget _hCell(String t, int flex, ThemeData theme) {
    return Expanded(
      flex: flex,
      child: Text(
        t,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: Colors.white.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}

class _TableDataRow extends StatefulWidget {
  const _TableDataRow({
    required this.row,
    required this.compact,
    required this.theme,
  });

  final _ReviewRow row;
  final bool compact;
  final ThemeData theme;

  @override
  State<_TableDataRow> createState() => _TableDataRowState();
}

class _TableDataRowState extends State<_TableDataRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.row;
    final initials = r.guestName.isNotEmpty
        ? r.guestName[0].toUpperCase()
        : '?';

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: _hover
              ? NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.07)
              : Colors.transparent,
          border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
          ),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: widget.compact ? 12 : 16,
          vertical: widget.compact ? 10 : 12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: widget.compact ? 16 : 18,
                    backgroundColor: NuaLuxuryTokens.softPurpleGlow.withValues(
                      alpha: 0.35,
                    ),
                    child: Text(
                      initials,
                      style: widget.theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.guestName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: widget.theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: LuxuryReviewsDashboardScreen.textPrimary,
                          ),
                        ),
                        Text(
                          '${r.visits} visits',
                          style: widget.theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.service,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: widget.theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    r.therapist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: widget.theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: _StarRating(value: r.rating, theme: widget.theme),
            ),
            Expanded(
              flex: 3,
              child: Text(
                r.review,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: widget.theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.78),
                  height: 1.35,
                ),
              ),
            ),
            Expanded(flex: 1, child: _SourceBadge(label: r.source)),
            Expanded(
              flex: 1,
              child: Text(
                r.dateLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: widget.theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.6),
                  height: 1.3,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _iconAct(Icons.visibility_outlined),
                  const SizedBox(width: 4),
                  _iconAct(Icons.more_horiz_rounded),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconAct(IconData icon) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: () {},
      icon: Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.65)),
    );
  }
}

class _StarRating extends StatelessWidget {
  const _StarRating({required this.value, required this.theme});

  final double value;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final full = value.floor();
    final half = value - full >= 0.25 && value - full < 0.99;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < 5; i++)
              Icon(
                i < full
                    ? Icons.star_rounded
                    : (half && i == full
                          ? Icons.star_half_rounded
                          : Icons.star_outline_rounded),
                size: 16,
                color: NuaLuxuryTokens.champagneGold,
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value.toStringAsFixed(1),
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: Colors.white.withValues(alpha: 0.75),
          ),
        ),
      ),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.page,
    required this.totalPages,
    required this.onPage,
  });

  final int page;
  final int totalPages;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 6,
            children: [
              _pageArrow(Icons.chevron_left_rounded, () {
                if (page > 1) onPage(page - 1);
              }),
              for (final p in [1, 2, 3, 4, 5]) _pageNum(p, theme),
              Text(
                '...',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
              _pageNum(13, theme),
              _pageArrow(Icons.chevron_right_rounded, () {
                if (page < totalPages) onPage(page + 1);
              }),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _glassCard(
              radius: 12,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Text(
                      'Show 10',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Icon(
                      Icons.expand_more_rounded,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            Text(
              '1–10 of 128 reviews',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _pageNum(int p, ThemeData theme) {
    final active = p == page;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => onPage(p),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: active
                ? const LinearGradient(
                    colors: [
                      NuaLuxuryTokens.softPurpleGlow,
                      LuxuryReviewsDashboardScreen.secondaryPurple,
                    ],
                  )
                : null,
            color: active ? null : Colors.white.withValues(alpha: 0.04),
            border: Border.all(
              color: active
                  ? Colors.transparent
                  : Colors.white.withValues(alpha: 0.08),
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: NuaLuxuryTokens.softPurpleGlow.withValues(
                        alpha: 0.35,
                      ),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: Text(
            '$p',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: active
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.65),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pageArrow(IconData icon, VoidCallback onTap) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white.withValues(alpha: 0.65)),
    );
  }
}

class _RightInsightsColumn extends StatelessWidget {
  const _RightInsightsColumn({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gap = compact ? 12.0 : 14.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RatingDistributionCard(theme: theme, compact: compact),
        SizedBox(height: gap),
        _TopServicesCard(theme: theme, compact: compact),
        SizedBox(height: gap),
        _RecentFeedbackCard(theme: theme, compact: compact),
        SizedBox(height: gap),
        _ManageReviewsCard(theme: theme, compact: compact),
      ],
    );
  }
}

class _RatingDistributionCard extends StatelessWidget {
  const _RatingDistributionCard({required this.theme, required this.compact});

  final ThemeData theme;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final data = <(String, double)>[
      ('5 stars', 0.72),
      ('4 stars', 0.20),
      ('3 stars', 0.06),
      ('2 stars', 0.02),
      ('1 star', 0.0),
    ];
    return _glassCard(
      radius: 20,
      child: Padding(
        padding: EdgeInsets.all(compact ? 14 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rating Distribution',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: LuxuryReviewsDashboardScreen.textPrimary,
              ),
            ),
            SizedBox(height: compact ? 12 : 14),
            for (final e in data) ...[
              Row(
                children: [
                  SizedBox(
                    width: 56,
                    child: Text(
                      e.$1,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: e.$2,
                        minHeight: 6,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        color: NuaLuxuryTokens.softPurpleGlow,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 36,
                    child: Text(
                      '${(e.$2 * 100).round()}%',
                      textAlign: TextAlign.end,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: compact ? 8 : 10),
            ],
            Text(
              'Based on 128 reviews',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopServicesCard extends StatelessWidget {
  const _TopServicesCard({required this.theme, required this.compact});

  final ThemeData theme;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    const items = <(String, String)>[
      ('Swedish Massage', '4.9'),
      ('Hot Stone Massage', '4.8'),
      ('Aromatherapy', '4.7'),
      ('Deep Tissue Massage', '4.6'),
      ('Facial Treatment', '4.6'),
    ];
    return _glassCard(
      radius: 20,
      child: Padding(
        padding: EdgeInsets.all(compact ? 14 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top Services by Rating',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: compact ? 10 : 12),
            for (var i = 0; i < items.length; i++) ...[
              Row(
                children: [
                  Text(
                    '${i + 1}.',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: NuaLuxuryTokens.softPurpleGlow,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      items[i].$1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    items[i].$2,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.star_rounded,
                    size: 16,
                    color: NuaLuxuryTokens.champagneGold,
                  ),
                ],
              ),
              if (i < items.length - 1)
                Divider(
                  height: compact ? 14 : 16,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
            ],
            SizedBox(height: compact ? 12 : 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: LuxuryReviewsDashboardScreen.textPrimary,
                  side: BorderSide(
                    color: NuaLuxuryTokens.softPurpleGlow.withValues(
                      alpha: 0.55,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'View all services',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentFeedbackCard extends StatelessWidget {
  const _RecentFeedbackCard({required this.theme, required this.compact});

  final ThemeData theme;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return _glassCard(
      radius: 20,
      child: Padding(
        padding: EdgeInsets.all(compact ? 14 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Feedback',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: compact ? 12 : 14),
            Icon(
              Icons.format_quote_rounded,
              size: 28,
              color: NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.75),
            ),
            const SizedBox(height: 6),
            Text(
              'NuaSpa is my go-to place for relaxation and self care.',
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.45,
                color: Colors.white.withValues(alpha: 0.88),
                fontStyle: FontStyle.italic,
              ),
            ),
            SizedBox(height: compact ? 12 : 14),
            Text(
              'Sarah Johnson',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: List.generate(
                5,
                (_) => Icon(
                  Icons.star_rounded,
                  size: 18,
                  color: NuaLuxuryTokens.champagneGold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManageReviewsCard extends StatelessWidget {
  const _ManageReviewsCard({required this.theme, required this.compact});

  final ThemeData theme;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return _glassCard(
      radius: 20,
      child: Padding(
        padding: EdgeInsets.all(compact ? 14 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manage Reviews',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: compact ? 10 : 12),
            _manageTile(theme, Icons.settings_outlined, 'Review Settings'),
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
            _manageTile(
              theme,
              Icons.auto_awesome_mosaic_outlined,
              'Auto-Response Templates',
            ),
          ],
        ),
      ),
    );
  }

  Widget _manageTile(ThemeData theme, IconData icon, String label) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: compact ? 10 : 12),
          child: Row(
            children: [
              Icon(icon, size: 20, color: Colors.white.withValues(alpha: 0.55)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.88),
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
