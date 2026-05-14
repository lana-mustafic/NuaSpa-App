import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/api/services/api_service.dart';
import '../../models/admin/admin_finance_dashboard.dart';
import '../../models/usluga.dart';
import '../../ui/theme/nua_luxury_tokens.dart';

String _formatKm(num v) {
  final s = v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2);
  final parts = s.split('.');
  final intPart = parts[0];
  final buf = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    final fromEnd = intPart.length - i;
    if (i > 0 && fromEnd % 3 == 0) buf.write(',');
    buf.write(intPart[i]);
  }
  if (parts.length > 1) buf.write('.${parts[1]}');
  return '${buf.toString()} KM';
}

String _formatGrowthLine(double? pct) {
  if (pct == null) return '— vs preth. period';
  final up = pct >= 0;
  final arrow = up ? '↑' : '↓';
  return '$arrow ${pct.abs().toStringAsFixed(0)}% vs preth. period';
}

/// Premium dark-mode Payments Overview (admin finance hub).
class AdminPaymentsOverviewScreen extends StatefulWidget {
  const AdminPaymentsOverviewScreen({super.key});

  static const Color textPrimary = Color(0xFFF5F3FA);
  static const Color secondaryPurple = Color(0xFF9D6BFF);
  static const Color successGreen = Color(0xFF4ADE80);
  static const Color errorRed = Color(0xFFFF5E7A);
  static const Color bgDeep = Color(0xFF090613);

  @override
  State<AdminPaymentsOverviewScreen> createState() =>
      _AdminPaymentsOverviewScreenState();
}

class _AdminPaymentsOverviewScreenState
    extends State<AdminPaymentsOverviewScreen> {
  final ApiService _api = ApiService();
  final ScrollController _scroll = ScrollController();

  late DateTimeRange _range;
  String _methodFilter = 'all';
  String _statusFilter = 'all';
  String _serviceFilter = 'all';
  final TextEditingController _tableSearch = TextEditingController();
  int _page = 1;
  int _pageSize = 10;

  AdminFinanceDashboard? _dash;
  List<Usluga> _usluge = [];
  bool _loading = true;
  String? _error;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    final end = DateTime.now();
    final start = end.subtract(const Duration(days: 30));
    _range = DateTimeRange(
      start: DateTime(start.year, start.month, start.day),
      end: DateTime(end.year, end.month, end.day),
    );
    _tableSearch.addListener(_onSearchChanged);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final usluge = await _api.getUsluge();
    if (!mounted) return;
    setState(() => _usluge = usluge);
    await _load();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      setState(() => _page = 1);
      _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final dash = await _api.getAdminFinanceDashboard(
      from: _range.start,
      toInclusive: _range.end,
      page: _page,
      pageSize: _pageSize,
      search: _tableSearch.text.trim().isEmpty ? null : _tableSearch.text.trim(),
      status: _statusFilter == 'all' ? null : _statusFilter,
      methodCategory: _methodFilter == 'all' ? null : _methodFilter,
      uslugaId: _serviceFilter == 'all' ? null : int.tryParse(_serviceFilter),
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (dash == null) {
        _error = 'Nije moguće učitati podatke o plaćanjima.';
        _dash = null;
      } else {
        _dash = dash;
        _page = dash.stranica;
        _pageSize = dash.velicinaStranice;
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tableSearch.removeListener(_onSearchChanged);
    _scroll.dispose();
    _tableSearch.dispose();
    super.dispose();
  }

  String _fmtRange() {
    String f(DateTime d) {
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }

    return '${f(_range.start)} – ${f(_range.end)}';
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _range,
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
        _range = DateTimeRange(
          start: DateTime(picked.start.year, picked.start.month, picked.start.day),
          end: DateTime(picked.end.year, picked.end.month, picked.end.day),
        );
        _page = 1;
      });
      await _load();
    }
  }

  Future<void> _exportReport() async {
    final ok = await _api.downloadAdminFinanceCsv(
      from: _range.start,
      toInclusive: _range.end,
      search: _tableSearch.text.trim().isEmpty ? null : _tableSearch.text.trim(),
      status: _statusFilter == 'all' ? null : _statusFilter,
      methodCategory: _methodFilter == 'all' ? null : _methodFilter,
      uslugaId: _serviceFilter == 'all' ? null : int.tryParse(_serviceFilter),
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mq = MediaQuery.sizeOf(context);
    final w = mq.width;
    final showRight = w >= 1300;
    final tight = mq.height < 760 || w < 1200;
    final gap = tight ? 10.0 : 14.0;
    final pad = tight ? 12.0 : 16.0;

    if (_error != null && _dash == null && !_loading) {
      return Material(
        color: Colors.transparent,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _pgGlass(
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
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AdminPaymentsOverviewScreen.bgDeep,
                    NuaLuxuryTokens.voidViolet,
                  ],
                ),
              ),
              child: Scrollbar(
                controller: _scroll,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _scroll,
                  primary: false,
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: ClampingScrollPhysics(),
                  ),
                  padding: EdgeInsets.fromLTRB(pad, 4, pad, pad + 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _PaymentsHeroCard(
                        theme: theme,
                        compact: tight,
                        rangeLabel: _fmtRange(),
                        onPickRange: _pickRange,
                        onExport: _exportReport,
                      ),
                      SizedBox(height: gap),
                      _KpiStrip(compact: tight, width: w, kpi: _dash?.kpi),
                      SizedBox(height: gap),
                      LayoutBuilder(
                        builder: (context, c) {
                          final innerW = c.maxWidth;
                          final showPanel = innerW >= 1300;
                          final rw = innerW >= 1500 ? 300.0 : 280.0;
                          if (!showPanel) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _FilterStrip(
                                  theme: theme,
                                  compact: tight,
                                  tableSearch: _tableSearch,
                                  usluge: _usluge,
                                  method: _methodFilter,
                                  status: _statusFilter,
                                  service: _serviceFilter,
                                  onMethod: (v) async {
                                    setState(() {
                                      _methodFilter = v;
                                      _page = 1;
                                    });
                                    await _load();
                                  },
                                  onStatus: (v) async {
                                    setState(() {
                                      _statusFilter = v;
                                      _page = 1;
                                    });
                                    await _load();
                                  },
                                  onService: (v) async {
                                    setState(() {
                                      _serviceFilter = v;
                                      _page = 1;
                                    });
                                    await _load();
                                  },
                                ),
                                SizedBox(height: gap),
                                _PaymentsTableBlock(
                                  theme: theme,
                                  compact: tight,
                                  rows: _dash?.redovi ?? const [],
                                  page: _page,
                                  pageSize: _pageSize,
                                  total: _dash?.ukupno ?? 0,
                                  onPage: (p) async {
                                    setState(() => _page = p);
                                    await _load();
                                  },
                                ),
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _FilterStrip(
                                      theme: theme,
                                      compact: tight,
                                      tableSearch: _tableSearch,
                                      usluge: _usluge,
                                      method: _methodFilter,
                                      status: _statusFilter,
                                      service: _serviceFilter,
                                      onMethod: (v) async {
                                        setState(() {
                                          _methodFilter = v;
                                          _page = 1;
                                        });
                                        await _load();
                                      },
                                      onStatus: (v) async {
                                        setState(() {
                                          _statusFilter = v;
                                          _page = 1;
                                        });
                                        await _load();
                                      },
                                      onService: (v) async {
                                        setState(() {
                                          _serviceFilter = v;
                                          _page = 1;
                                        });
                                        await _load();
                                      },
                                    ),
                                    SizedBox(height: gap),
                                    _PaymentsTableBlock(
                                      theme: theme,
                                      compact: tight,
                                      rows: _dash?.redovi ?? const [],
                                      page: _page,
                                      pageSize: _pageSize,
                                      total: _dash?.ukupno ?? 0,
                                      onPage: (p) async {
                                        setState(() => _page = p);
                                        await _load();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: tight ? 12 : 16),
                              SizedBox(
                                width: rw,
                                child: _RightAnalyticsStack(
                                  theme: theme,
                                  compact: tight,
                                  dash: _dash,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      if (!showRight) ...[
                        SizedBox(height: gap),
                        _RightAnalyticsStack(theme: theme, compact: tight, dash: _dash),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_loading && _dash == null)
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
      ),
    );
  }
}

// --- Glass shell -------------------------------------------------------------

Widget _pgGlass({
  required Widget child,
  double radius = 22,
  double borderOpacity = 0.08,
}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          color: Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: Colors.white.withValues(alpha: borderOpacity),
            width: 0.9,
          ),
          boxShadow: [
            BoxShadow(
              color: NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.07),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: child,
      ),
    ),
  );
}

// --- Hero -------------------------------------------------------------------

class _PaymentsHeroCard extends StatelessWidget {
  const _PaymentsHeroCard({
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
    return _pgGlass(
      radius: 24,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 16 : 22,
          vertical: compact ? 14 : 18,
        ),
        child: LayoutBuilder(
          builder: (context, c) {
            final narrow = c.maxWidth < 720;
            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Payments Overview',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.35,
                      color: AdminPaymentsOverviewScreen.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Financial overview and key metrics.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.62),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _rangePill(theme, rangeLabel, onPickRange),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: onExport,
                    icon: const Icon(Icons.ios_share_rounded, size: 18),
                    label: const Text('Export Report'),
                    style: FilledButton.styleFrom(
                      backgroundColor: NuaLuxuryTokens.softPurpleGlow,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payments Overview',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.45,
                          color: AdminPaymentsOverviewScreen.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Financial overview and key metrics.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.62),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                _rangePill(theme, rangeLabel, onPickRange),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: onExport,
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                  label: const Text('Export Report'),
                  style: FilledButton.styleFrom(
                    backgroundColor: NuaLuxuryTokens.softPurpleGlow,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _rangePill(ThemeData theme, String label, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: Colors.white.withValues(alpha: 0.06),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.date_range_rounded,
                size: 18,
                color: Colors.white.withValues(alpha: 0.65),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AdminPaymentsOverviewScreen.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.expand_more_rounded,
                size: 18,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- KPI --------------------------------------------------------------------

class _KpiStrip extends StatelessWidget {
  const _KpiStrip({
    required this.compact,
    required this.width,
    required this.kpi,
  });

  final bool compact;
  final double width;
  final AdminFinanceKpi? kpi;

  @override
  Widget build(BuildContext context) {
    final k = kpi;
    final cards = <Widget>[
      _KpiCard(
        label: 'Ukupni prihod',
        value: k == null ? '—' : _formatKm(k.ukupniPrihod),
        delta: _formatGrowthLine(k?.postotakPromjeneUkupniPrihod),
        deltaUp: (k?.postotakPromjeneUkupniPrihod ?? 0) >= 0,
        icon: Icons.account_balance_wallet_outlined,
        iconBg: NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.35),
      ),
      _KpiCard(
        label: 'Plaćene rezervacije',
        value: k == null ? '—' : '${k.placeneRezervacije}',
        delta: _formatGrowthLine(k?.postotakPromjenePlaceneRezervacije),
        deltaUp: (k?.postotakPromjenePlaceneRezervacije ?? 0) >= 0,
        icon: Icons.event_available_rounded,
        iconBg: AdminPaymentsOverviewScreen.successGreen.withValues(alpha: 0.25),
      ),
      _KpiCard(
        label: 'Prosječna vrijednost',
        value: k == null ? '—' : _formatKm(k.prosjecnaVrijednost),
        delta: _formatGrowthLine(k?.postotakPromjeneProsjecnaVrijednost),
        deltaUp: (k?.postotakPromjeneProsjecnaVrijednost ?? 0) >= 0,
        icon: Icons.stacked_line_chart_rounded,
        iconBg: AdminPaymentsOverviewScreen.secondaryPurple.withValues(alpha: 0.35),
      ),
      _KpiCard(
        label: 'Neplaćene rezervacije',
        value: k == null ? '—' : '${k.neplaceneRezervacije}',
        delta: _formatGrowthLine(k?.postotakPromjeneNeplaceneRezervacije),
        deltaUp: (k?.postotakPromjeneNeplaceneRezervacije ?? 0) < 0,
        icon: Icons.receipt_long_outlined,
        iconBg: AdminPaymentsOverviewScreen.errorRed.withValues(alpha: 0.22),
        accentRed: true,
      ),
      _KpiCard(
        label: 'Refunds',
        value: k == null ? '—' : _formatKm(k.iznosRefundacija),
        delta: _formatGrowthLine(k?.postotakPromjeneRefundacija),
        deltaUp: (k?.postotakPromjeneRefundacija ?? 0) < 0,
        icon: Icons.currency_exchange_rounded,
        iconBg: NuaLuxuryTokens.champagneGold.withValues(alpha: 0.28),
      ),
    ];

    if (width >= 1180) {
      return Row(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) SizedBox(width: compact ? 8 : 10),
            Expanded(child: cards[i]),
          ],
        ],
      );
    }

    return Wrap(
      spacing: compact ? 8 : 10,
      runSpacing: compact ? 8 : 10,
      children: [
        for (final c in cards)
          SizedBox(
            width: width >= 720
                ? (width - 10) / 2
                : width - 4,
            child: c,
          ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.delta,
    required this.deltaUp,
    required this.icon,
    required this.iconBg,
    this.accentRed = false,
  });

  final String label;
  final String value;
  final String delta;
  final bool deltaUp;
  final IconData icon;
  final Color iconBg;
  final bool accentRed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deltaColor = accentRed
        ? AdminPaymentsOverviewScreen.errorRed.withValues(alpha: 0.9)
        : (deltaUp
            ? AdminPaymentsOverviewScreen.successGreen
            : AdminPaymentsOverviewScreen.errorRed);

    return _pgGlass(
      radius: 18,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: Colors.white.withValues(alpha: 0.52),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AdminPaymentsOverviewScreen.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    delta,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: deltaColor.withValues(alpha: 0.92),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: iconBg,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Icon(icon, color: Colors.white.withValues(alpha: 0.9)),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Filters ----------------------------------------------------------------

class _FilterStrip extends StatelessWidget {
  const _FilterStrip({
    required this.theme,
    required this.compact,
    required this.tableSearch,
    required this.usluge,
    required this.method,
    required this.status,
    required this.service,
    required this.onMethod,
    required this.onStatus,
    required this.onService,
  });

  final ThemeData theme;
  final bool compact;
  final TextEditingController tableSearch;
  final List<Usluga> usluge;
  final String method;
  final String status;
  final String service;
  final Future<void> Function(String) onMethod;
  final Future<void> Function(String) onStatus;
  final Future<void> Function(String) onService;

  List<MapEntry<String, String>> _serviceItems() {
    final items = <MapEntry<String, String>>[
      const MapEntry('all', 'All services'),
    ];
    for (final u in usluge) {
      items.add(MapEntry('${u.id}', u.naziv));
    }
    return items;
  }

  InputDecoration _dec(String hint) {
    return InputDecoration(
      hintText: hint,
      isDense: true,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      hintStyle: TextStyle(
        color: Colors.white.withValues(alpha: 0.38),
        fontSize: 13,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: NuaLuxuryTokens.softPurpleGlow,
          width: 1.2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = compact ? 42.0 : 46.0;
    return LayoutBuilder(
      builder: (context, c) {
        final stack = c.maxWidth < 900;
        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: h,
                child: TextField(
                  controller: tableSearch,
                  style: const TextStyle(
                    color: AdminPaymentsOverviewScreen.textPrimary,
                    fontSize: 13,
                  ),
                  decoration: _dec('Search payments…'),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: (c.maxWidth - 8) / 2,
                    height: h,
                    child: _MiniDropdown(
                      value: method,
                      hint: 'All payment methods',
                      items: const [
                        MapEntry('all', 'All payment methods'),
                        MapEntry('card', 'Card'),
                        MapEntry('cash', 'Cash'),
                        MapEntry('digital', 'Digital wallets'),
                      ],
                      onChanged: onMethod,
                    ),
                  ),
                  SizedBox(
                    width: (c.maxWidth - 8) / 2,
                    height: h,
                    child: _MiniDropdown(
                      value: status,
                      hint: 'All status',
                      items: const [
                        MapEntry('all', 'All status'),
                        MapEntry('paid', 'Plaćeno'),
                        MapEntry('unpaid', 'Neplaćeno'),
                        MapEntry('refunded', 'Refundirano'),
                      ],
                      onChanged: onStatus,
                    ),
                  ),
                  SizedBox(
                    width: (c.maxWidth - 8) / 2,
                    height: h,
                    child: _MiniDropdown(
                      value: service,
                      hint: 'All services',
                      items: _serviceItems(),
                      onChanged: onService,
                    ),
                  ),
                  SizedBox(
                    height: h,
                    child: OutlinedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Napredni filteri uskoro.'),
                            behavior: SnackBarBehavior.floating,
                            width: 360,
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white.withValues(alpha: 0.88),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Filters'),
                    ),
                  ),
                ],
              ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 22,
              child: SizedBox(
                height: h,
                child: TextField(
                  controller: tableSearch,
                  style: const TextStyle(
                    color: AdminPaymentsOverviewScreen.textPrimary,
                    fontSize: 13,
                  ),
                  decoration: _dec('Search payments…'),
                ),
              ),
            ),
            SizedBox(width: compact ? 8 : 10),
            Expanded(
              flex: 18,
              child: SizedBox(
                height: h,
                child: _MiniDropdown(
                  value: method,
                  hint: 'All payment methods',
                  items: const [
                    MapEntry('all', 'All payment methods'),
                    MapEntry('card', 'Card'),
                    MapEntry('cash', 'Cash'),
                    MapEntry('digital', 'Digital wallets'),
                  ],
                  onChanged: onMethod,
                ),
              ),
            ),
            SizedBox(width: compact ? 8 : 10),
            Expanded(
              flex: 14,
              child: SizedBox(
                height: h,
                child: _MiniDropdown(
                  value: status,
                  hint: 'All status',
                  items: const [
                    MapEntry('all', 'All status'),
                    MapEntry('paid', 'Plaćeno'),
                    MapEntry('unpaid', 'Neplaćeno'),
                    MapEntry('refunded', 'Refundirano'),
                  ],
                  onChanged: onStatus,
                ),
              ),
            ),
            SizedBox(width: compact ? 8 : 10),
            Expanded(
              flex: 14,
              child: SizedBox(
                height: h,
                child: _MiniDropdown(
                  value: service,
                  hint: 'All services',
                  items: _serviceItems(),
                  onChanged: onService,
                ),
              ),
            ),
            SizedBox(width: compact ? 8 : 10),
            SizedBox(
              height: h,
              child: OutlinedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Napredni filteri uskoro.'),
                      behavior: SnackBarBehavior.floating,
                      width: 360,
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white.withValues(alpha: 0.88),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Text('Filters'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MiniDropdown extends StatelessWidget {
  const _MiniDropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  final String value;
  final String hint;
  final List<MapEntry<String, String>> items;
  final Future<void> Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      // ignore: deprecated_member_use — controlled selection
      value: value,
      isDense: true,
      isExpanded: true,
      dropdownColor: NuaLuxuryTokens.voidViolet,
      style: const TextStyle(
        color: AdminPaymentsOverviewScreen.textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: NuaLuxuryTokens.softPurpleGlow,
            width: 1.2,
          ),
        ),
      ),
      hint: Text(hint, style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
      items: items
          .map(
            (e) => DropdownMenuItem(
              value: e.key,
              child: Text(e.value, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) unawaited(onChanged(v));
      },
    );
  }
}

// --- Table ------------------------------------------------------------------

class _PaymentsTableBlock extends StatelessWidget {
  const _PaymentsTableBlock({
    required this.theme,
    required this.compact,
    required this.rows,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.onPage,
  });

  final ThemeData theme;
  final bool compact;
  final List<AdminFinanceTransactionRow> rows;
  final int page;
  final int pageSize;
  final int total;
  final Future<void> Function(int) onPage;

  String _fmtWhen(DateTime d) {
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final loc = d.toLocal();
    final h = loc.hour > 12 ? loc.hour - 12 : (loc.hour == 0 ? 12 : loc.hour);
    final am = loc.hour >= 12 ? 'PM' : 'AM';
    final mm = loc.minute.toString().padLeft(2, '0');
    return '${m[loc.month - 1]} ${loc.day}, ${loc.year} / $h:$mm $am';
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = total <= 0 ? 1 : ((total + pageSize - 1) / pageSize).ceil();
    final fromIdx = total == 0 ? 0 : (page - 1) * pageSize + 1;
    final toIdx = ((page - 1) * pageSize + pageSize).clamp(0, total);

    return _pgGlass(
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TableHeader(theme: theme, compact: compact),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'Nema transakcija za odabrane filtere i razdoblje.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ),
            )
          else
            for (final r in rows)
              _TableDataRow(theme: theme, compact: compact, row: r, fmt: _fmtWhen),
          Padding(
            padding: EdgeInsets.fromLTRB(compact ? 12 : 16, 12, compact ? 12 : 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _pageBtn(theme, Icons.chevron_left, page > 1, () {
                        unawaited(onPage(page - 1));
                      }),
                      for (final n in _pageNums(page, totalPages))
                        if (n == -1)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text('…', style: theme.textTheme.bodySmall),
                          )
                        else
                          _pageNum(theme, n, n == page, () {
                            unawaited(onPage(n));
                          }),
                      _pageBtn(
                        theme,
                        Icons.chevron_right,
                        page < totalPages,
                        () {
                          unawaited(onPage(page + 1));
                        },
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Prikaži $pageSize',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$fromIdx–$toIdx od $total transakcija',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<int> _pageNums(int page, int totalPages) {
    if (totalPages <= 7) {
      return List.generate(totalPages, (i) => i + 1);
    }
    if (page <= 3) return [1, 2, 3, 4, 5, -1, totalPages];
    if (page >= totalPages - 2) {
      return [1, -1, totalPages - 4, totalPages - 3, totalPages - 2, totalPages - 1, totalPages];
    }
    return [1, -1, page - 1, page, page + 1, -1, totalPages];
  }

  Widget _pageBtn(ThemeData theme, IconData icon, bool enabled, VoidCallback onTap) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? Colors.white70 : Colors.white24,
        ),
      ),
    );
  }

  Widget _pageNum(ThemeData theme, int n, bool active, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: active
            ? NuaLuxuryTokens.softPurpleGlow
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              '$n',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: active ? Colors.white : Colors.white70,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({required this.theme, required this.compact});

  final ThemeData theme;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16, vertical: compact ? 10 : 12),
      decoration: BoxDecoration(
        color: NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.12),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Row(
        children: [
          _h('Transaction ID', 10, theme, compact),
          _h('Client', 14, theme, compact),
          _h('Service / Package', 18, theme, compact),
          _h('Date & Time', 14, theme, compact),
          _h('Amount', 8, theme, compact),
          _h('Method', 11, theme, compact),
          _h('Status', 9, theme, compact),
          _h('Actions', 8, theme, compact),
        ],
      ),
    );
  }

  Widget _h(String t, int flex, ThemeData theme, bool compact) {
    return Expanded(
      flex: flex,
      child: Text(
        t,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: Colors.white.withValues(alpha: 0.55),
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _TableDataRow extends StatefulWidget {
  const _TableDataRow({
    required this.theme,
    required this.compact,
    required this.row,
    required this.fmt,
  });

  final ThemeData theme;
  final bool compact;
  final AdminFinanceTransactionRow row;
  final String Function(DateTime) fmt;

  @override
  State<_TableDataRow> createState() => _TableDataRowState();
}

class _TableDataRowState extends State<_TableDataRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.row;
    final initials = r.klijentPunoIme.trim().isNotEmpty
        ? r.klijentPunoIme.trim()[0].toUpperCase()
        : '?';

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        decoration: BoxDecoration(
          color: _hover
              ? const Color(0xFF7B4DFF).withValues(alpha: 0.08)
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
              flex: 10,
              child: Text(
                r.transakcijskiId,
                style: widget.theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.82),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 14,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: widget.compact ? 14 : 16,
                    backgroundColor: NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.35),
                    child: Text(
                      initials,
                      style: widget.theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      r.klijentPunoIme,
                      style: widget.theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AdminPaymentsOverviewScreen.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 18,
              child: Text(
                r.uslugaTekst,
                style: widget.theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.78),
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 14,
              child: Text(
                widget.fmt(r.datumVrijeme),
                style: widget.theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.58),
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 8,
              child: Text(
                _formatKm(r.iznos),
                style: widget.theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AdminPaymentsOverviewScreen.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 11,
              child: _MethodChip(method: r.metodaLabel, compact: widget.compact),
            ),
            Expanded(
              flex: 9,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _StatusPill(apiStatus: r.status),
              ),
            ),
            Expanded(
              flex: 8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Pregled',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () {},
                    icon: Icon(
                      Icons.visibility_outlined,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Više',
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.more_horiz_rounded,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                    color: NuaLuxuryTokens.voidViolet,
                    onSelected: (_) {},
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: '1', child: Text('Detalji transakcije')),
                      PopupMenuItem(value: '2', child: Text('Račun (PDF)')),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MethodChip extends StatelessWidget {
  const _MethodChip({required this.method, required this.compact});

  final String method;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isCard = method.contains('VISA') ||
        method.contains('Mastercard') ||
        method.contains('••');
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.white.withValues(alpha: 0.06),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isCard ? Icons.credit_card_rounded : Icons.payments_outlined,
              size: compact ? 13 : 14,
              color: NuaLuxuryTokens.champagneGold.withValues(alpha: 0.85),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                method,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.78),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.apiStatus});

  final String apiStatus;

  @override
  Widget build(BuildContext context) {
    late String label;
    late Color bg;
    late Color fg;
    switch (apiStatus) {
      case 'paid':
        label = 'Plaćeno';
        bg = AdminPaymentsOverviewScreen.successGreen.withValues(alpha: 0.22);
        fg = AdminPaymentsOverviewScreen.successGreen;
        break;
      case 'unpaid':
        label = 'Neplaćeno';
        bg = AdminPaymentsOverviewScreen.errorRed.withValues(alpha: 0.2);
        fg = AdminPaymentsOverviewScreen.errorRed;
        break;
      case 'refunded':
        label = 'Refundirano';
        bg = NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.28);
        fg = NuaLuxuryTokens.lavenderWhisper;
        break;
      default:
        label = apiStatus;
        bg = Colors.white.withValues(alpha: 0.1);
        fg = Colors.white70;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}

// --- Right panel ------------------------------------------------------------

class _RightAnalyticsStack extends StatelessWidget {
  const _RightAnalyticsStack({
    required this.theme,
    required this.compact,
    this.dash,
  });

  final ThemeData theme;
  final bool compact;
  final AdminFinanceDashboard? dash;

  @override
  Widget build(BuildContext context) {
    final gap = compact ? 10.0 : 12.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PaymentMethodsCard(
          theme: theme,
          compact: compact,
          shares: dash?.metodePostotak ?? const [],
          totalTransactions: dash?.ukupno ?? 0,
        ),
        SizedBox(height: gap),
        _RevenueTrendCard(
          theme: theme,
          compact: compact,
          points: dash?.prihodDnevno ?? const [],
        ),
        SizedBox(height: gap),
        _RecentActivityCard(
          theme: theme,
          compact: compact,
          items: dash?.nedavnaAktivnost ?? const [],
        ),
      ],
    );
  }
}

class _PaymentMethodsCard extends StatelessWidget {
  const _PaymentMethodsCard({
    required this.theme,
    required this.compact,
    required this.shares,
    required this.totalTransactions,
  });

  final ThemeData theme;
  final bool compact;
  final List<AdminFinanceMethodShare> shares;
  final int totalTransactions;

  Color _colorFor(String kljuc) {
    switch (kljuc) {
      case 'card':
        return NuaLuxuryTokens.softPurpleGlow;
      case 'cash':
        return NuaLuxuryTokens.champagneGold;
      case 'digital':
        return AdminPaymentsOverviewScreen.successGreen;
      default:
        return NuaLuxuryTokens.lavenderWhisper.withValues(alpha: 0.55);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vals = shares.map((s) => s.postotak <= 0 ? 0.01 : s.postotak).toList();
    final sections = <PieChartSectionData>[];
    for (var i = 0; i < shares.length; i++) {
      sections.add(
        PieChartSectionData(
          value: vals[i],
          color: _colorFor(shares[i].kljuc),
          radius: 22,
          showTitle: false,
        ),
      );
    }
    if (sections.isEmpty) {
      sections.add(
        PieChartSectionData(
          value: 1,
          color: Colors.white.withValues(alpha: 0.08),
          radius: 22,
          showTitle: false,
        ),
      );
    }

    return _pgGlass(
      radius: 20,
      child: Padding(
        padding: EdgeInsets.all(compact ? 14 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Methods',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: AdminPaymentsOverviewScreen.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: compact ? 160 : 180,
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 1.5,
                        centerSpaceRadius: 46,
                        sections: sections,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final s in shares)
                          _legend(s.label, '${s.postotak.toStringAsFixed(0)}%', _colorFor(s.kljuc)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Ukupno transakcija: $totalTransactions',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legend(String label, String pct, Color c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.65),
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            pct,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AdminPaymentsOverviewScreen.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _RevenueTrendCard extends StatefulWidget {
  const _RevenueTrendCard({
    required this.theme,
    required this.compact,
    required this.points,
  });

  final ThemeData theme;
  final bool compact;
  final List<AdminFinanceTrendPoint> points;

  @override
  State<_RevenueTrendCard> createState() => _RevenueTrendCardState();
}

class _RevenueTrendCardState extends State<_RevenueTrendCard> {
  String _granularity = 'Daily';

  @override
  Widget build(BuildContext context) {
    final pts = widget.points;
    final spots = <FlSpot>[];
    double minY = 0;
    double maxY = 1;
    if (pts.isNotEmpty) {
      minY = pts.map((e) => e.iznos).reduce((a, b) => a < b ? a : b);
      maxY = pts.map((e) => e.iznos).reduce((a, b) => a > b ? a : b);
      if (maxY <= minY) maxY = minY + 1;
      final pad = (maxY - minY) * 0.15;
      minY = (minY - pad).clamp(0, double.infinity);
      maxY = maxY + pad;
      for (var i = 0; i < pts.length; i++) {
        spots.add(FlSpot(i.toDouble(), pts[i].iznos));
      }
    } else {
      spots.add(const FlSpot(0, 0));
    }

    return _pgGlass(
      radius: 20,
      child: Padding(
        padding: EdgeInsets.all(widget.compact ? 14 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Revenue Trend',
                    style: widget.theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AdminPaymentsOverviewScreen.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _granularity,
                      isDense: true,
                      dropdownColor: NuaLuxuryTokens.voidViolet,
                      style: widget.theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Daily', child: Text('Daily')),
                        DropdownMenuItem(value: 'Weekly', child: Text('Weekly')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _granularity = v);
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Prihod (KM)',
              style: widget.theme.textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.45),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(
              height: widget.compact ? 150 : 170,
              child: LineChart(
                LineChartData(
                  minY: minY,
                  maxY: maxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: math.max(1, (maxY - minY) / 4),
                    getDrawingHorizontalLine: (v) => FlLine(
                      color: Colors.white.withValues(alpha: 0.06),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (v, m) => Text(
                          '${v.toInt()}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        getTitlesWidget: (v, m) {
                          final i = v.toInt();
                          if (i < 0 || i >= pts.length) {
                            return const SizedBox.shrink();
                          }
                          final d = pts[i].datum;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '${d.month}/${d.day}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.35),
                                fontSize: 10,
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
                      getTooltipItems: (touched) {
                        return touched.map((e) {
                          final idx = e.x.toInt();
                          final y = e.y;
                          final d = (idx >= 0 && idx < pts.length)
                              ? pts[idx].datum
                              : null;
                          final datePart = d != null ? '${d.day}/${d.month}' : '';
                          return LineTooltipItem(
                            '${y.toStringAsFixed(0)} KM${datePart.isEmpty ? '' : ' · $datePart'}',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      barWidth: 2.6,
                      color: NuaLuxuryTokens.softPurpleGlow,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.35),
                            Colors.transparent,
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

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({
    required this.theme,
    required this.compact,
    required this.items,
  });

  final ThemeData theme;
  final bool compact;
  final List<AdminFinanceActivity> items;

  static String _fmtClock(DateTime d) {
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return _pgGlass(
      radius: 20,
      child: Padding(
        padding: EdgeInsets.all(compact ? 14 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Activity',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: AdminPaymentsOverviewScreen.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              Text(
                'Nema nedavnih transakcija u odabranom periodu.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.45),
                  height: 1.35,
                ),
              )
            else
              for (final it in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: it.tip == 'refund'
                              ? NuaLuxuryTokens.champagneGold
                              : it.tip == 'pending'
                                  ? Colors.white.withValues(alpha: 0.35)
                                  : AdminPaymentsOverviewScreen.successGreen,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              it.opis.isNotEmpty ? it.opis : it.tip,
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Colors.white.withValues(alpha: 0.88),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${it.klijent} · ${_formatKm(it.iznos)} · ${_fmtClock(it.datumVrijeme)}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.5),
                                height: 1.25,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            if (items.length >= 12)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Prikazano zadnjih 12 plaćanja.',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.38),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
