import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/api/services/api_service.dart';
import '../../models/admin/admin_reviews_dashboard.dart';
import '../../models/usluga.dart';
import '../../models/zaposlenik.dart';
import '../../ui/theme/nua_luxury_tokens.dart';

/// Premium dark-mode Reviews & Feedback dashboard (desktop), backed by
/// `GET /api/Recenzija/admin-dashboard` and CSV export.
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
  final ApiService _api = ApiService();
  final TextEditingController _tableSearch = TextEditingController();

  AdminReviewsDashboard? _data;
  bool _loading = true;
  String? _error;

  late DateTime _rangeFrom;
  late DateTime _rangeTo;
  int _page = 1;
  int _pageSize = 10;

  int? _minOcjena;
  int? _maxOcjena;
  int? _filterUslugaId;
  int? _filterZaposlenikId;

  List<Usluga> _usluge = [];
  List<Zaposlenik> _zaposlenici = [];

  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _rangeTo = DateTime(n.year, n.month, n.day);
    _rangeFrom = _rangeTo.subtract(const Duration(days: 6));
    _tableSearch.addListener(_onSearchChanged);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final results = await Future.wait([
      _api.getUsluge(),
      _api.getZaposlenici(),
    ]);
    if (!mounted) return;
    setState(() {
      _usluge = results[0] as List<Usluga>;
      _zaposlenici = results[1] as List<Zaposlenik>;
    });
    await _load();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      _page = 1;
      _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final dash = await _api.getAdminReviewsDashboard(
      from: _rangeFrom,
      toInclusive: _rangeTo,
      page: _page,
      pageSize: _pageSize,
      search: _tableSearch.text.trim().isEmpty ? null : _tableSearch.text,
      minOcjena: _minOcjena,
      maxOcjena: _maxOcjena,
      uslugaId: _filterUslugaId,
      zaposlenikId: _filterZaposlenikId,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (dash == null) {
        _error = 'Nije moguće učitati recenzije. Provjerite vezu i admin ulogu.';
        _data = null;
      } else {
        _data = dash;
        _page = dash.stranica;
        _pageSize = dash.velicinaStranice;
      }
    });
  }

  Future<void> _pickRange() async {
    final initial = DateTimeRange(start: _rangeFrom, end: _rangeTo);
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
    if (picked != null && mounted) {
      setState(() {
        _rangeFrom = DateTime(
          picked.start.year,
          picked.start.month,
          picked.start.day,
        );
        _rangeTo = DateTime(
          picked.end.year,
          picked.end.month,
          picked.end.day,
        );
        _page = 1;
      });
      await _load();
    }
  }

  Future<void> _exportCsv() async {
    final ok = await _api.downloadAdminReviewsCsv(
      from: _rangeFrom,
      toInclusive: _rangeTo,
      search: _tableSearch.text.trim().isEmpty ? null : _tableSearch.text,
      minOcjena: _minOcjena,
      maxOcjena: _maxOcjena,
      uslugaId: _filterUslugaId,
      zaposlenikId: _filterZaposlenikId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'CSV izvještaj je spremljen i otvoren.' : 'Izvoz CSV nije uspio.',
        ),
        behavior: SnackBarBehavior.floating,
        width: 380,
      ),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tableSearch.removeListener(_onSearchChanged);
    _tableSearch.dispose();
    super.dispose();
  }

  String _rangeLabel() {
    String f(DateTime d) {
      const m = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${m[d.month - 1]} ${d.day}, ${d.year}';
    }

    return '${f(_rangeFrom)} – ${f(_rangeTo)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mq = MediaQuery.sizeOf(context);
    final showRight = mq.width >= 1300;
    final tightHeight = mq.height < 720;
    final pad = tightHeight ? 14.0 : 20.0;
    final gap = tightHeight ? 10.0 : 14.0;

    if (_error != null && _data == null && !_loading) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: _glassCard(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off_rounded,
                      size: 44, color: Colors.white.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Pokušaj ponovno'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final dash = _data;

    return Stack(
      children: [
        LayoutBuilder(
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
                              _HeaderGlassCard(
                                theme: theme,
                                compact: tightHeight,
                                rangeLabel: _rangeLabel(),
                                onPickRange: _pickRange,
                                onExport: _exportCsv,
                              ),
                              SizedBox(height: gap),
                              _KpiRow(
                                dash: dash,
                                compact: tightHeight,
                              ),
                              SizedBox(height: gap),
                              _FilterBar(
                                controller: _tableSearch,
                                compact: tightHeight,
                                usluge: _usluge,
                                zaposlenici: _zaposlenici,
                                filterUslugaId: _filterUslugaId,
                                filterZaposlenikId: _filterZaposlenikId,
                                minOcjena: _minOcjena,
                                maxOcjena: _maxOcjena,
                                onRatingChanged: (min, max) {
                                  setState(() {
                                    _minOcjena = min;
                                    _maxOcjena = max;
                                    _page = 1;
                                  });
                                  _load();
                                },
                                onServiceChanged: (id) {
                                  setState(() {
                                    _filterUslugaId = id;
                                    _page = 1;
                                  });
                                  _load();
                                },
                                onTherapistChanged: (id) {
                                  setState(() {
                                    _filterZaposlenikId = id;
                                    _page = 1;
                                  });
                                  _load();
                                },
                              ),
                              SizedBox(height: gap),
                              _ReviewsTable(
                                rows: dash?.redovi ?? const [],
                                compact: tightHeight,
                              ),
                              SizedBox(height: gap),
                              _PaginationBar(
                                page: _page,
                                pageSize: _pageSize,
                                total: dash?.ukupno ?? 0,
                                onPage: (p) {
                                  setState(() => _page = p);
                                  _load();
                                },
                                onPageSize: (s) {
                                  setState(() {
                                    _pageSize = s;
                                    _page = 1;
                                  });
                                  _load();
                                },
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
                            child: _RightInsightsColumn(
                              dash: dash,
                              compact: tightHeight,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
        if (_loading && _data == null)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.25),
              child: const Center(
                child: CircularProgressIndicator(
                  color: NuaLuxuryTokens.softPurpleGlow,
                ),
              ),
            ),
          ),
      ],
    );
  }
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
  const _HeaderGlassCard({
    required this.theme,
    required this.compact,
    required this.rangeLabel,
    required this.onPickRange,
    required this.onExport,
  });

  final ThemeData theme;
  final bool compact;
  final String rangeLabel;
  final VoidCallback onPickRange;
  final VoidCallback onExport;

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
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: onPickRange,
                  child: _glassCard(
                    radius: 14,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.date_range_outlined,
                            size: 18,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            rangeLabel,
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
                    onTap: onExport,
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
                onPressed: onExport,
                icon: const Icon(Icons.download_rounded, size: 20),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _fmtGrowthPercent(int current, int previous) {
  if (previous <= 0) {
    if (current > 0) return '+100%';
    return '0%';
  }
  final p = ((current - previous) / previous) * 100;
  final sign = p >= 0 ? '+' : '';
  return '$sign${p.round()}%';
}

String _fmtGrowthDouble(double current, double? previous) {
  if (previous == null) return '+0.0';
  final d = current - previous;
  final sign = d >= 0 ? '+' : '';
  return '$sign${d.toStringAsFixed(1)}';
}

String _fmtGrowthPercentD(double current, double? previous) {
  if (previous == null) return '+0%';
  final d = current - previous;
  final sign = d >= 0 ? '+' : '';
  return '$sign${d.round()}%';
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.dash, required this.compact});

  final AdminReviewsDashboard? dash;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final gap = compact ? 10.0 : 12.0;
    final d = dash;
    final avg = d?.prosjecnaOcjena ?? 0;
    final total = d?.ukupno ?? 0;
    final pos = d?.postotakPozitivnih ?? 0;
    final resp = d?.postotakOdgovora;

    return LayoutBuilder(
      builder: (context, c) {
        final oneRow = c.maxWidth >= 900;
        final children = <Widget>[
          Expanded(
            child: _KpiCard(
              title: 'Average Rating',
              value: avg.toStringAsFixed(1),
              suffix: ' / 5.0',
              growth: _fmtGrowthDouble(avg, d?.prosjecnaOcjenaPrethodno),
              subtitle: 'vs previous period',
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
              value: '$total',
              growth: _fmtGrowthPercent(total, d?.ukupnoPrethodno ?? 0),
              subtitle: 'vs previous period',
              compact: compact,
            ),
          ),
          SizedBox(width: gap),
          Expanded(
            child: _KpiCard(
              title: 'Positive Reviews',
              value: '${pos.toStringAsFixed(0)}%',
              growth: _fmtGrowthPercentD(
                pos,
                d?.postotakPozitivnihPrethodno,
              ),
              subtitle: 'vs previous period',
              compact: compact,
              progress: pos / 100,
            ),
          ),
          SizedBox(width: gap),
          Expanded(
            child: _KpiCard(
              title: 'Response Rate',
              value: resp == null ? '—' : '${resp.toStringAsFixed(0)}%',
              growth: resp == null ? '—' : '+0%',
              subtitle: 'vs previous period',
              compact: compact,
              progress: resp == null ? null : resp / 100,
            ),
          ),
        ];

        if (oneRow) {
          return Row(children: children);
        }
        return Column(
          children: [
            Row(
              children: [
                children[0],
                SizedBox(width: gap),
                children[2],
              ],
            ),
            SizedBox(height: gap),
            Row(
              children: [
                children[4],
                SizedBox(width: gap),
                children[6],
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
    final growthColor = growth == '—'
        ? Colors.white38
        : (growth.startsWith('+') || growth == '0%' || growth == '+0%')
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

String _lookupServiceName(List<Usluga> list, int id) {
  for (final u in list) {
    if (u.id == id) return u.naziv;
  }
  return 'Service';
}

String _lookupTherapistName(List<Zaposlenik> list, int id) {
  for (final z in list) {
    if (z.id == id) return '${z.ime} ${z.prezime}';
  }
  return 'Therapist';
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.controller,
    required this.compact,
    required this.usluge,
    required this.zaposlenici,
    required this.filterUslugaId,
    required this.filterZaposlenikId,
    required this.minOcjena,
    required this.maxOcjena,
    required this.onRatingChanged,
    required this.onServiceChanged,
    required this.onTherapistChanged,
  });

  final TextEditingController controller;
  final bool compact;
  final List<Usluga> usluge;
  final List<Zaposlenik> zaposlenici;
  final int? filterUslugaId;
  final int? filterZaposlenikId;
  final int? minOcjena;
  final int? maxOcjena;
  final void Function(int? min, int? max) onRatingChanged;
  final void Function(int?) onServiceChanged;
  final void Function(int?) onTherapistChanged;

  String _ratingLabel() {
    if (minOcjena == null && maxOcjena == null) return 'All ratings';
    if (minOcjena == 5 && maxOcjena == 5) return '5 stars';
    if (minOcjena == 4 && maxOcjena == null) return '4+ stars';
    if (minOcjena == 3 && maxOcjena == null) return '3+ stars';
    if (minOcjena == 1 && maxOcjena == 2) return '1–2 stars';
    return 'Filter';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth > 920;
        final ratingMenu = PopupMenuButton<String>(
          onSelected: (v) {
            switch (v) {
              case 'all':
                onRatingChanged(null, null);
                break;
              case '5':
                onRatingChanged(5, 5);
                break;
              case '4':
                onRatingChanged(4, null);
                break;
              case '3':
                onRatingChanged(3, null);
                break;
              case '12':
                onRatingChanged(1, 2);
                break;
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'all', child: Text('All ratings')),
            PopupMenuItem(value: '5', child: Text('5 stars')),
            PopupMenuItem(value: '4', child: Text('4+ stars')),
            PopupMenuItem(value: '3', child: Text('3+ stars')),
            PopupMenuItem(value: '12', child: Text('1–2 stars')),
          ],
          child: _FilterDropdownPill(label: _ratingLabel()),
        );

        final serviceMenu = PopupMenuButton<int?>(
          onSelected: onServiceChanged,
          itemBuilder: (context) => [
            const PopupMenuItem(value: null, child: Text('All services')),
            ...usluge.map(
              (u) => PopupMenuItem(value: u.id, child: Text(u.naziv)),
            ),
          ],
          child: _FilterDropdownPill(
            label: filterUslugaId == null
                ? 'All services'
                : _lookupServiceName(usluge, filterUslugaId!),
          ),
        );

        final therapistMenu = PopupMenuButton<int?>(
          onSelected: onTherapistChanged,
          itemBuilder: (context) => [
            const PopupMenuItem(value: null, child: Text('All therapists')),
            ...zaposlenici.map(
              (z) => PopupMenuItem(
                value: z.id,
                child: Text('${z.ime} ${z.prezime}'),
              ),
            ),
          ],
          child: _FilterDropdownPill(
            label: filterZaposlenikId == null
                ? 'All therapists'
                : _lookupTherapistName(zaposlenici, filterZaposlenikId!),
          ),
        );

        final sourceMenu = PopupMenuButton<String>(
          onSelected: (_) {},
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'all', child: Text('All sources')),
            PopupMenuItem(value: 'app', child: Text('NuaSpa')),
          ],
          child: const _FilterDropdownPill(label: 'All sources'),
        );

        if (wide) {
          return Row(
            children: [
              Expanded(
                flex: 3,
                child: _FilterSearchField(controller: controller),
              ),
              SizedBox(width: compact ? 8 : 10),
              Expanded(child: ratingMenu),
              SizedBox(width: compact ? 8 : 10),
              Expanded(child: serviceMenu),
              SizedBox(width: compact ? 8 : 10),
              Expanded(child: therapistMenu),
              SizedBox(width: compact ? 8 : 10),
              Expanded(child: sourceMenu),
              SizedBox(width: compact ? 8 : 10),
              const _FiltersButton(),
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
                ratingMenu,
                serviceMenu,
                therapistMenu,
                sourceMenu,
                const _FiltersButton(),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _FilterDropdownPill extends StatelessWidget {
  const _FilterDropdownPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _glassCard(
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
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
          ),
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

class _FiltersButton extends StatelessWidget {
  const _FiltersButton();

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

String _formatRowDate(DateTime utc) {
  final d = utc.toLocal();
  const m = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final h = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
  final am = d.hour >= 12 ? 'PM' : 'AM';
  final mm = d.minute.toString().padLeft(2, '0');
  return '${m[d.month - 1]} ${d.day}, ${d.year}, $h:$mm $am';
}

class _ReviewsTable extends StatelessWidget {
  const _ReviewsTable({required this.rows, required this.compact});

  final List<AdminReviewRow> rows;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (rows.isEmpty) {
      return _glassCard(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(
              'Nema recenzija za odabrane filtere i razdoblje.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
      );
    }
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
          for (final row in rows) _TableDataRow(row: row, compact: compact),
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
  const _TableDataRow({required this.row, required this.compact});

  final AdminReviewRow row;
  final bool compact;

  @override
  State<_TableDataRow> createState() => _TableDataRowState();
}

class _TableDataRowState extends State<_TableDataRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.row;
    final theme = Theme.of(context);
    final initials = r.korisnikPunoIme.trim().isNotEmpty
        ? r.korisnikPunoIme.trim()[0].toUpperCase()
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
            bottom: BorderSide(
              color: Colors.white.withValues(alpha: 0.06),
            ),
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
                      style: theme.textTheme.labelLarge?.copyWith(
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
                          r.korisnikPunoIme,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: LuxuryReviewsDashboardScreen.textPrimary,
                          ),
                        ),
                        Text(
                          '${r.brojPosjeta} visits',
                          style: theme.textTheme.labelSmall?.copyWith(
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
                    r.uslugaNaziv,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    (r.terapeutIme ?? '—').trim().isEmpty
                        ? '—'
                        : r.terapeutIme!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: _StarRatingInt(value: r.ocjena, theme: theme),
            ),
            Expanded(
              flex: 3,
              child: Text(
                r.komentar,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.78),
                  height: 1.35,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: _SourceBadge(label: r.izvor),
            ),
            Expanded(
              flex: 1,
              child: Text(
                _formatRowDate(r.createdAt),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
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
      icon: Icon(
        icon,
        size: 18,
        color: Colors.white.withValues(alpha: 0.65),
      ),
    );
  }
}

class _StarRatingInt extends StatelessWidget {
  const _StarRatingInt({required this.value, required this.theme});

  final int value;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0, 5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < 5; i++)
              Icon(
                i < v ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 16,
                color: NuaLuxuryTokens.champagneGold,
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '$v.0',
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
    required this.pageSize,
    required this.total,
    required this.onPage,
    required this.onPageSize,
  });

  final int page;
  final int pageSize;
  final int total;
  final ValueChanged<int> onPage;
  final ValueChanged<int> onPageSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalPages = total <= 0 ? 1 : ((total + pageSize - 1) / pageSize).ceil();
    final fromIdx = total == 0 ? 0 : (page - 1) * pageSize + 1;
    final toIdx = ((page - 1) * pageSize + pageSize).clamp(0, total);

    List<int> pageNums() {
      if (totalPages <= 7) {
        return List.generate(totalPages, (i) => i + 1);
      }
      if (page <= 3) return [1, 2, 3, 4, 5];
      if (page >= totalPages - 2) {
        return [
          totalPages - 4,
          totalPages - 3,
          totalPages - 2,
          totalPages - 1,
          totalPages,
        ];
      }
      return [page - 2, page - 1, page, page + 1, page + 2];
    }

    final nums = pageNums();

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
              for (final p in nums) _pageNum(p, theme, page, onPage),
              if (totalPages > 7 && nums.last < totalPages - 1)
                Text(
                  '...',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              if (totalPages > 7 && nums.last < totalPages)
                _pageNum(totalPages, theme, page, onPage),
              _pageArrow(Icons.chevron_right_rounded, () {
                if (page < totalPages) onPage(page + 1);
              }),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PopupMenuButton<int>(
              onSelected: onPageSize,
              itemBuilder: (context) => const [
                PopupMenuItem(value: 10, child: Text('Show 10')),
                PopupMenuItem(value: 25, child: Text('Show 25')),
                PopupMenuItem(value: 50, child: Text('Show 50')),
              ],
              child: _glassCard(
                radius: 12,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        'Show $pageSize',
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
            ),
            const SizedBox(width: 14),
            Text(
              total == 0
                  ? '0 reviews'
                  : '$fromIdx–$toIdx of $total reviews',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _pageNum(
    int p,
    ThemeData theme,
    int current,
    ValueChanged<int> onTap,
  ) {
    final active = p == current;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => onTap(p),
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
  const _RightInsightsColumn({required this.dash, required this.compact});

  final AdminReviewsDashboard? dash;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gap = compact ? 12.0 : 14.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RatingDistributionCard(dash: dash, theme: theme, compact: compact),
        SizedBox(height: gap),
        _TopServicesCard(dash: dash, theme: theme, compact: compact),
        SizedBox(height: gap),
        _RecentFeedbackCard(dash: dash, theme: theme, compact: compact),
        SizedBox(height: gap),
        _ManageReviewsCard(theme: theme, compact: compact),
      ],
    );
  }
}

class _RatingDistributionCard extends StatelessWidget {
  const _RatingDistributionCard({
    required this.dash,
    required this.theme,
    required this.compact,
  });

  final AdminReviewsDashboard? dash;
  final ThemeData theme;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final total = dash?.ukupno ?? 0;
    final dist = dash?.distribucijaOcjena ?? {for (var i = 1; i <= 5; i++) i: 0};

    double pct(int stars) {
      if (total <= 0) return 0;
      final c = dist[stars] ?? 0;
      return c / total;
    }

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
            for (var stars = 5; stars >= 1; stars--) ...[
              Row(
                children: [
                  SizedBox(
                    width: 56,
                    child: Text(
                      '$stars stars',
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
                        value: pct(stars) <= 0 ? 0.0 : pct(stars),
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
                      '${(pct(stars) * 100).round()}%',
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
              total == 0
                  ? 'No reviews in range'
                  : 'Based on $total reviews',
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
  const _TopServicesCard({
    required this.dash,
    required this.theme,
    required this.compact,
  });

  final AdminReviewsDashboard? dash;
  final ThemeData theme;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final items = dash?.topUsluge ?? [];
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
            if (items.isEmpty)
              Text(
                'Nema podataka.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              )
            else
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
                        items[i].naziv,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      items[i].prosjek.toStringAsFixed(1),
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
  const _RecentFeedbackCard({
    required this.dash,
    required this.theme,
    required this.compact,
  });

  final AdminReviewsDashboard? dash;
  final ThemeData theme;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final q = dash?.istaknutaRecenzija;
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
              q == null || q.tekst.trim().isEmpty
                  ? 'Još nema istaknutih recenzija s tekstom.'
                  : q.tekst,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.45,
                color: Colors.white.withValues(alpha: 0.88),
                fontStyle: FontStyle.italic,
              ),
            ),
            SizedBox(height: compact ? 12 : 14),
            Text(
              q?.autor ?? '—',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: List.generate(
                5,
                (i) => Icon(
                  i < (q?.ocjena ?? 0)
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
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
            _manageTile(theme, compact, Icons.settings_outlined, 'Review Settings'),
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
            _manageTile(
              theme,
              compact,
              Icons.auto_awesome_mosaic_outlined,
              'Auto-Response Templates',
            ),
          ],
        ),
      ),
    );
  }

  Widget _manageTile(
    ThemeData theme,
    bool compact,
    IconData icon,
    String label,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: compact ? 10 : 12),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: Colors.white.withValues(alpha: 0.55),
              ),
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
