import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/api/services/api_service.dart';
import '../../models/admin/admin_finance_dashboard.dart';
import '../../models/usluga.dart';
import '../../ui/theme/nua_luxury_tokens.dart';
import '../../ui/widgets/luxury/luxury_desktop_header.dart';

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
  if (pct == null) return '— vs previous period';
  final up = pct >= 0;
  final arrow = up ? '↑' : '↓';
  return '$arrow ${pct.abs().toStringAsFixed(0)}% vs previous period';
}

/// Premium dark-mode Payments Overview (admin finance hub).
class AdminPaymentsOverviewScreen extends StatefulWidget {
  const AdminPaymentsOverviewScreen({super.key});

  static const Color textPrimary = Color(0xFFF5F3FA);
  static const Color secondaryPurple = Color(0xFF9D6BFF);
  static const Color successGreen = Color(0xFF4ADE80);
  static const Color revenueTeal = Color(0xFF2DD4BF);
  static const Color unpaidAmber = Color(0xFFFBBF24);
  static const Color errorRed = Color(0xFFFF5E7A);
  static const Color refundMuted = Color(0xFFE879A8);
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
        _error = 'Could not load payment data.';
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

  Future<void> _clearFilters() async {
    setState(() {
      _methodFilter = 'all';
      _statusFilter = 'all';
      _serviceFilter = 'all';
      _page = 1;
    });
    _tableSearch.clear();
    await _load();
  }

  Future<void> _openTransactionDetail(AdminFinanceTransactionRow row) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TransactionDetailSheet(row: row),
    );
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
          ok ? 'CSV report saved and opened.' : 'CSV export failed.',
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
                      label: const Text('Try again'),
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
                  padding: LuxuryPageChrome.bodyPadding.copyWith(
                    left: pad,
                    right: pad,
                    bottom: pad + 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _PaymentsPageHeader(
                        theme: theme,
                        compact: tight,
                        rangeLabel: _fmtRange(),
                        onPickRange: _pickRange,
                        onExport: _exportReport,
                      ),
                      SizedBox(height: gap),
                      _KpiStrip(compact: tight, width: w, kpi: _dash?.kpi),
                      SizedBox(height: gap),
                      _RevenueTrendCard(
                        theme: theme,
                        compact: true,
                        points: _dash?.prihodDnevno ?? const [],
                      ),
                      SizedBox(height: gap),
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
                        onViewRow: _openTransactionDetail,
                        onClearFilters: _clearFilters,
                      ),
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

// --- Page header -------------------------------------------------------------

class _PaymentsPageHeader extends StatelessWidget {
  const _PaymentsPageHeader({
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
    return LayoutBuilder(
      builder: (context, c) {
        final narrow = c.maxWidth < 720;
        final actions = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _rangePill(theme, rangeLabel, onPickRange),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: onExport,
              icon: Icon(
                Icons.ios_share_rounded,
                size: 17,
                color: Colors.white.withValues(alpha: 0.75),
              ),
              label: const Text('Export'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white.withValues(alpha: 0.88),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 14 : 16,
                  vertical: compact ? 10 : 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        );

        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _titleBlock(theme, compact),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.end,
                children: [actions],
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _titleBlock(theme, compact)),
            actions,
          ],
        );
      },
    );
  }

  Widget _titleBlock(ThemeData theme, bool compact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payments',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.45,
            color: AdminPaymentsOverviewScreen.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Track revenue, refunds and transactions.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.58),
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _rangePill(ThemeData theme, String label, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
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
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AdminPaymentsOverviewScreen.textPrimary,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.expand_more_rounded,
                size: 18,
                color: Colors.white.withValues(alpha: 0.4),
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
        label: 'Revenue',
        value: k == null ? '—' : _formatKm(k.ukupniPrihod),
        delta: _formatGrowthLine(k?.postotakPromjeneUkupniPrihod),
        deltaUp: (k?.postotakPromjeneUkupniPrihod ?? 0) >= 0,
        accent: AdminPaymentsOverviewScreen.revenueTeal,
      ),
      _KpiCard(
        label: 'Paid Reservations',
        value: k == null ? '—' : '${k.placeneRezervacije}',
        delta: _formatGrowthLine(k?.postotakPromjenePlaceneRezervacije),
        deltaUp: (k?.postotakPromjenePlaceneRezervacije ?? 0) >= 0,
        accent: AdminPaymentsOverviewScreen.successGreen,
      ),
      _KpiCard(
        label: 'Average Value',
        value: k == null ? '—' : _formatKm(k.prosjecnaVrijednost),
        delta: _formatGrowthLine(k?.postotakPromjeneProsjecnaVrijednost),
        deltaUp: (k?.postotakPromjeneProsjecnaVrijednost ?? 0) >= 0,
        accent: AdminPaymentsOverviewScreen.secondaryPurple,
      ),
      _KpiCard(
        label: 'Unpaid Reservations',
        value: k == null ? '—' : '${k.neplaceneRezervacije}',
        delta: _formatGrowthLine(k?.postotakPromjeneNeplaceneRezervacije),
        deltaUp: (k?.postotakPromjeneNeplaceneRezervacije ?? 0) < 0,
        accent: AdminPaymentsOverviewScreen.unpaidAmber,
        invertDeltaColor: true,
      ),
      _KpiCard(
        label: 'Refunds',
        value: k == null ? '—' : _formatKm(k.iznosRefundacija),
        delta: _formatGrowthLine(k?.postotakPromjeneRefundacija),
        deltaUp: (k?.postotakPromjeneRefundacija ?? 0) < 0,
        accent: AdminPaymentsOverviewScreen.refundMuted,
        invertDeltaColor: true,
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
    required this.accent,
    this.invertDeltaColor = false,
  });

  final String label;
  final String value;
  final String delta;
  final bool deltaUp;
  final Color accent;
  final bool invertDeltaColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final positive = invertDeltaColor ? !deltaUp : deltaUp;
    final deltaColor = positive
        ? AdminPaymentsOverviewScreen.successGreen
        : Colors.white.withValues(alpha: 0.45);

    return _pgGlass(
      radius: 18,
      child: SizedBox(
        height: 104,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: accent,
                  letterSpacing: -0.3,
                  height: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.48),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Text(
                delta,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: deltaColor,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
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
    const h = 50.0;
    const gap = 12.0;

    Widget toolbarRow({required bool scrollable, required double maxW}) {
      final children = <Widget>[
        SizedBox(
          width: scrollable ? math.max(220, maxW * 0.34) : null,
          child: SizedBox(
            height: h,
            child: TextField(
              controller: tableSearch,
              style: const TextStyle(
                color: AdminPaymentsOverviewScreen.textPrimary,
                fontSize: 13,
              ),
              decoration: _dec('Search transactions...').copyWith(
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.38),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 40),
              ),
            ),
          ),
        ),
        SizedBox(
          width: scrollable ? 148 : null,
          child: SizedBox(
            height: h,
            child: _MiniDropdown(
              value: method,
              hint: 'Method',
              items: const [
                MapEntry('all', 'All methods'),
                MapEntry('card', 'Card'),
                MapEntry('cash', 'Cash'),
                MapEntry('digital', 'Digital'),
              ],
              onChanged: onMethod,
            ),
          ),
        ),
        SizedBox(
          width: scrollable ? 132 : null,
          child: SizedBox(
            height: h,
            child: _MiniDropdown(
              value: status,
              hint: 'Status',
              items: const [
                MapEntry('all', 'All status'),
                MapEntry('paid', 'Paid'),
                MapEntry('unpaid', 'Unpaid'),
                MapEntry('refunded', 'Refunded'),
              ],
              onChanged: onStatus,
            ),
          ),
        ),
        SizedBox(
          width: scrollable ? 148 : null,
          child: SizedBox(
            height: h,
            child: _MiniDropdown(
              value: service,
              hint: 'Service',
              items: _serviceItems(),
              onChanged: onService,
            ),
          ),
        ),
        SizedBox(
          height: h,
          child: OutlinedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('More filters coming soon.'),
                  behavior: SnackBarBehavior.floating,
                  width: 360,
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white.withValues(alpha: 0.72),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            child: const Text('More Filters'),
          ),
        ),
      ];

      if (scrollable) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: gap),
                children[i],
              ],
            ],
          ),
        );
      }

      return Row(
        children: [
          Expanded(flex: 34, child: children[0]),
          const SizedBox(width: gap),
          Expanded(flex: 14, child: children[1]),
          const SizedBox(width: gap),
          Expanded(flex: 12, child: children[2]),
          const SizedBox(width: gap),
          Expanded(flex: 14, child: children[3]),
          const SizedBox(width: gap),
          children[4],
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        final scrollable = c.maxWidth < 980;
        return toolbarRow(scrollable: scrollable, maxW: c.maxWidth);
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
    required this.onViewRow,
    required this.onClearFilters,
  });

  final ThemeData theme;
  final bool compact;
  final List<AdminFinanceTransactionRow> rows;
  final int page;
  final int pageSize;
  final int total;
  final Future<void> Function(int) onPage;
  final Future<void> Function(AdminFinanceTransactionRow) onViewRow;
  final Future<void> Function() onClearFilters;

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
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(compact ? 14 : 18, 14, compact ? 14 : 18, 0),
            child: Text(
              'Transactions',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: AdminPaymentsOverviewScreen.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _TableHeader(theme: theme, compact: compact),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 36,
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'No payments found',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No transactions match the selected filters or date range.\n'
                    'Try changing filters or selecting a different period.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.48),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton(
                    onPressed: () => unawaited(onClearFilters()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white.withValues(alpha: 0.82),
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Clear filters'),
                  ),
                ],
              ),
            )
          else
            for (final r in rows)
              _TableDataRow(
                theme: theme,
                compact: compact,
                row: r,
                fmt: _fmtWhen,
                onView: () => unawaited(onViewRow(r)),
              ),
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
                      'Show $pageSize',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$fromIdx–$toIdx of $total transactions',
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
          _h('Client', 16, theme, compact),
          _h('Service', 18, theme, compact),
          _h('Amount', 10, theme, compact),
          _h('Status', 10, theme, compact),
          _h('Method', 12, theme, compact),
          _h('Date', 12, theme, compact),
          _h('Actions', 6, theme, compact),
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
    required this.onView,
  });

  final ThemeData theme;
  final bool compact;
  final AdminFinanceTransactionRow row;
  final String Function(DateTime) fmt;
  final VoidCallback onView;

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
        child: InkWell(
          onTap: widget.onView,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 16,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: widget.compact ? 13 : 15,
                      backgroundColor:
                          NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.3),
                      child: Text(
                        initials,
                        style: widget.theme.textTheme.labelMedium?.copyWith(
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
                flex: 10,
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
                flex: 10,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _StatusPill(apiStatus: r.status),
                ),
              ),
              Expanded(
                flex: 12,
                child: _MethodChip(method: r.metodaLabel, compact: widget.compact),
              ),
              Expanded(
                flex: 12,
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
                flex: 6,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: 'View details',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: widget.onView,
                    icon: Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
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
        label = 'Paid';
        bg = AdminPaymentsOverviewScreen.revenueTeal.withValues(alpha: 0.18);
        fg = AdminPaymentsOverviewScreen.revenueTeal;
        break;
      case 'unpaid':
        label = 'Pending';
        bg = AdminPaymentsOverviewScreen.unpaidAmber.withValues(alpha: 0.18);
        fg = AdminPaymentsOverviewScreen.unpaidAmber;
        break;
      case 'failed':
        label = 'Failed';
        bg = AdminPaymentsOverviewScreen.errorRed.withValues(alpha: 0.16);
        fg = AdminPaymentsOverviewScreen.errorRed.withValues(alpha: 0.85);
        break;
      case 'refunded':
        label = 'Refunded';
        bg = NuaLuxuryTokens.lavenderWhisper.withValues(alpha: 0.14);
        fg = NuaLuxuryTokens.lavenderWhisper;
        break;
      default:
        label = apiStatus.isEmpty ? 'Unknown' : apiStatus;
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

// --- Revenue trend -----------------------------------------------------------

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
  @override
  Widget build(BuildContext context) {
    final pts = widget.points;
    if (pts.isEmpty) {
      return _pgGlass(
        radius: 18,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 14 : 16,
            vertical: widget.compact ? 14 : 16,
          ),
          child: Row(
            children: [
              Text(
                'Revenue Trend',
                style: widget.theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AdminPaymentsOverviewScreen.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No revenue data for this period.',
                  style: widget.theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.42),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final spots = <FlSpot>[];
    var minY = pts.map((e) => e.iznos).reduce((a, b) => a < b ? a : b);
    var maxY = pts.map((e) => e.iznos).reduce((a, b) => a > b ? a : b);
    if (maxY <= minY) maxY = minY + 1;
    final pad = (maxY - minY) * 0.15;
    minY = (minY - pad).clamp(0, double.infinity);
    maxY = maxY + pad;
    for (var i = 0; i < pts.length; i++) {
      spots.add(FlSpot(i.toDouble(), pts[i].iznos));
    }

    return _pgGlass(
      radius: 18,
      child: Padding(
        padding: EdgeInsets.all(widget.compact ? 14 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Revenue Trend',
              style: widget.theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: AdminPaymentsOverviewScreen.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Revenue (KM)',
              style: widget.theme.textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.42),
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(
              height: widget.compact ? 120 : 140,
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

// --- Transaction detail ------------------------------------------------------

class _TransactionDetailSheet extends StatelessWidget {
  const _TransactionDetailSheet({required this.row});

  final AdminFinanceTransactionRow row;

  String _fmtDetailDate(DateTime d) {
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final loc = d.toLocal();
    final h = loc.hour > 12 ? loc.hour - 12 : (loc.hour == 0 ? 12 : loc.hour);
    final am = loc.hour >= 12 ? 'PM' : 'AM';
    final mm = loc.minute.toString().padLeft(2, '0');
    return '${m[loc.month - 1]} ${loc.day}, ${loc.year} at $h:$mm $am';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.62,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF120A22).withValues(alpha: 0.96),
                  border: Border(
                    top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Transaction details',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: AdminPaymentsOverviewScreen.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(
                            Icons.close_rounded,
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _detailRow(theme, 'Transaction ID', row.transakcijskiId),
                    _detailRow(theme, 'Client', row.klijentPunoIme),
                    _detailRow(theme, 'Service', row.uslugaTekst),
                    _detailRow(theme, 'Amount', _formatKm(row.iznos)),
                    _detailRow(
                      theme,
                      'Status',
                      null,
                      trailing: _StatusPill(apiStatus: row.status),
                    ),
                    _detailRow(theme, 'Payment method', row.metodaLabel),
                    _detailRow(theme, 'Date & time', _fmtDetailDate(row.datumVrijeme)),
                    if (row.placanjeId > 0)
                      _detailRow(
                        theme,
                        'Booking reference',
                        '#${row.placanjeId}',
                      ),
                    if (row.status == 'refunded') ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: NuaLuxuryTokens.lavenderWhisper.withValues(alpha: 0.08),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Text(
                          'This transaction has been refunded. The amount was returned to the client.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.62),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _detailRow(
    ThemeData theme,
    String label,
    String? value, {
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.45),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: trailing ??
                Text(
                  value ?? '—',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AdminPaymentsOverviewScreen.textPrimary,
                    height: 1.35,
                  ),
                ),
          ),
        ],
      ),
    );
  }
}
