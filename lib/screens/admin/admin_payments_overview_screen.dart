import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/services/api_service.dart';
import '../../models/admin/admin_finance_dashboard.dart';
import '../../models/usluga.dart';
import '../../ui/navigation/desktop_nav.dart';
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
  int _page = 1;
  int _pageSize = 10;

  AdminFinanceDashboard? _dash;
  List<Usluga> _usluge = [];
  bool _loading = true;
  bool _exporting = false;
  String? _error;
  Timer? _searchDebounce;
  DesktopNav? _nav;
  String _syncedPaymentQuery = '';
  DateTimeRange? _syncedHeaderRange;

  @override
  void initState() {
    super.initState();
    _range = DesktopNav.defaultHeaderDateRange();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _bootstrap();
    });
  }

  DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nav = context.read<DesktopNav>();
    if (_nav != nav) {
      _nav?.removeListener(_onNavChanged);
      _nav = nav;
      _nav!.addListener(_onNavChanged);
      _range = nav.headerDateRange;
      _syncedHeaderRange = _range;
      final pending = nav.takePendingPaymentSearch();
      if (pending != null && pending.isNotEmpty) {
        nav.setPaymentSearchQuery(pending);
        _syncedPaymentQuery = pending.trim();
      } else {
        _syncedPaymentQuery = nav.paymentSearchQuery;
      }
    }
    _nav!.setPaymentsCsvExport(_exportReport);
    _nav!.setPaymentsCsvExporting(_exporting);
  }

  void _onNavChanged() {
    if (!mounted || _nav == null) return;
    _handleHeaderRangeChange();
    _handleSearchChange();
  }

  void _handleHeaderRangeChange() {
    final headerRange = _nav!.headerDateRange;
    if (_syncedHeaderRange != null &&
        _sameDay(_syncedHeaderRange!.start, headerRange.start) &&
        _sameDay(_syncedHeaderRange!.end, headerRange.end)) {
      return;
    }
    _syncedHeaderRange = headerRange;
    setState(() {
      _range = DateTimeRange(
        start: _dayOnly(headerRange.start),
        end: _dayOnly(headerRange.end),
      );
      _page = 1;
    });
    unawaited(_load());
  }

  void _handleSearchChange() {
    final q = _nav!.paymentSearchQuery;
    if (q == _syncedPaymentQuery) return;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      _syncedPaymentQuery = q;
      setState(() => _page = 1);
      unawaited(_load());
    });
  }

  Future<void> _bootstrap() async {
    final usluge = await _api.getUslugeAll();
    if (!mounted) return;
    setState(() => _usluge = usluge);
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final search = _syncedPaymentQuery.trim();
    final dash = await _api.getAdminFinanceDashboard(
      from: _range.start,
      toInclusive: _range.end,
      page: _page,
      pageSize: _pageSize,
      search: search.isEmpty ? null : search,
      status: _statusFilter == 'all' ? null : _statusFilter,
      methodCategory: _methodFilter == 'all' ? null : _methodFilter,
      uslugaId: _serviceFilter == 'all' ? null : int.tryParse(_serviceFilter),
    );
    if (!mounted) return;
    final hadData = _dash != null;
    setState(() {
      _loading = false;
      if (dash == null) {
        _error = 'Could not load payment data.';
        if (!hadData) _dash = null;
      } else {
        _dash = dash;
        _error = null;
        _page = dash.stranica;
        _pageSize = dash.velicinaStranice;
      }
    });
    if (dash == null && hadData && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not refresh payments. Showing previous data.'),
          behavior: SnackBarBehavior.floating,
          width: 400,
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _nav?.removeListener(_onNavChanged);
    _nav?.setPaymentsCsvExport(null);
    _nav?.setPaymentsCsvExporting(false);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _clearFilters() async {
    setState(() {
      _methodFilter = 'all';
      _statusFilter = 'all';
      _serviceFilter = 'all';
      _page = 1;
    });
    _syncedPaymentQuery = '';
    _nav?.setPaymentSearchQuery('');
    await _load();
  }

  Future<void> _openTransactionDetail(AdminFinanceTransactionRow row) async {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    if (wide) {
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Close',
        barrierColor: Colors.black.withValues(alpha: 0.45),
        pageBuilder: (ctx, a1, a2) {
          return Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: math.min(440, MediaQuery.sizeOf(ctx).width * 0.38),
                height: MediaQuery.sizeOf(ctx).height,
                child: _TransactionDetailSheet(row: row, asSidePanel: true),
              ),
            ),
          );
        },
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TransactionDetailSheet(row: row),
    );
  }

  Future<void> _exportReport() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    _nav?.setPaymentsCsvExporting(true);
    final search = _syncedPaymentQuery.trim();
    final result = await _api.downloadAdminFinanceCsv(
      from: _range.start,
      toInclusive: _range.end,
      search: search.isEmpty ? null : search,
      status: _statusFilter == 'all' ? null : _statusFilter,
      methodCategory: _methodFilter == 'all' ? null : _methodFilter,
      uslugaId: _serviceFilter == 'all' ? null : int.tryParse(_serviceFilter),
    );
    if (!mounted) return;
    setState(() => _exporting = false);
    _nav?.setPaymentsCsvExporting(false);
    var msg = result.ok
        ? 'CSV report saved and opened.'
        : (result.errorMessage ?? 'CSV export failed.');
    if (result.ok && result.truncated) {
      msg =
          'CSV saved (${result.exportedRows} of ${result.totalRows} rows). Export was truncated — narrow your filters.';
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        width: 420,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mq = MediaQuery.sizeOf(context);
    final w = mq.width;
    final tight = mq.height < 760 || w < 1200;
    final gap = tight ? 10.0 : 12.0;

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
                  padding: LuxuryPageChrome.bodyPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_loading && _dash != null) ...[
                        const LinearProgressIndicator(
                          minHeight: 2,
                          color: NuaLuxuryTokens.softPurpleGlow,
                          backgroundColor: Colors.transparent,
                        ),
                        SizedBox(height: gap),
                      ],
                      _KpiStrip(compact: tight, width: w, kpi: _dash?.kpi),
                      SizedBox(height: gap),
                      _RevenueTrendCard(
                        theme: theme,
                        compact: tight,
                        points: _dash?.prihodDnevno ?? const [],
                      ),
                      if (_dash != null &&
                          (_dash!.metodePostotak.isNotEmpty ||
                              _dash!.nedavnaAktivnost.isNotEmpty)) ...[
                        SizedBox(height: gap),
                        _FinanceInsightsRow(
                          theme: theme,
                          compact: tight,
                          methods: _dash!.metodePostotak,
                          activity: _dash!.nedavnaAktivnost,
                        ),
                      ],
                      SizedBox(height: gap),
                      _PaymentsTableBlock(
                        theme: theme,
                        compact: tight,
                        rows: _dash?.redovi ?? const [],
                        page: _page,
                        pageSize: _pageSize,
                        total: _dash?.ukupno ?? 0,
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
                        onPage: (p) async {
                          setState(() => _page = p);
                          await _load();
                        },
                        onViewRow: _openTransactionDetail,
                        onClearFilters: _clearFilters,
                        onPageSize: (s) async {
                          setState(() {
                            _pageSize = s;
                            _page = 1;
                          });
                          await _load();
                        },
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
  double radius = 20,
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
            if (i > 0) SizedBox(width: compact ? 10 : 12),
            Expanded(child: cards[i]),
          ],
        ],
      );
    }

    return Wrap(
      spacing: compact ? 10 : 12,
      runSpacing: compact ? 10 : 12,
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
      child: SizedBox(
        height: 104,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: accent,
                  letterSpacing: -0.3,
                  height: 1.1,
                  fontSize: 22,
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
                  fontSize: 12,
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

// --- Table filters (in card header) -----------------------------------------

class _PaymentsTableFilters extends StatelessWidget {
  const _PaymentsTableFilters({
    required this.usluge,
    required this.method,
    required this.status,
    required this.service,
    required this.onMethod,
    required this.onStatus,
    required this.onService,
    required this.onClearFilters,
  });

  final List<Usluga> usluge;
  final String method;
  final String status;
  final String service;
  final Future<void> Function(String) onMethod;
  final Future<void> Function(String) onStatus;
  final Future<void> Function(String) onService;
  final Future<void> Function() onClearFilters;

  List<MapEntry<String, String>> _serviceItems() {
    final items = <MapEntry<String, String>>[
      const MapEntry('all', 'All services'),
    ];
    for (final u in usluge) {
      items.add(MapEntry('${u.id}', u.naziv));
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    const gap = 8.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 128,
          child: _MiniDropdown(
            value: method,
            hint: 'Method',
            compact: true,
            items: const [
              MapEntry('all', 'All methods'),
              MapEntry('card', 'Card'),
              MapEntry('cash', 'Cash'),
              MapEntry('digital', 'Digital'),
            ],
            onChanged: onMethod,
          ),
        ),
        const SizedBox(width: gap),
        SizedBox(
          width: 120,
          child: _MiniDropdown(
            value: status,
            hint: 'Status',
            compact: true,
            items: const [
              MapEntry('all', 'All status'),
              MapEntry('paid', 'Paid'),
              MapEntry('unpaid', 'Pending'),
              MapEntry('failed', 'Failed'),
              MapEntry('refunded', 'Refunded'),
            ],
            onChanged: onStatus,
          ),
        ),
        const SizedBox(width: gap),
        SizedBox(
          width: 128,
          child: _MiniDropdown(
            value: service,
            hint: 'Service',
            compact: true,
            items: _serviceItems(),
            onChanged: onService,
          ),
        ),
        const SizedBox(width: gap),
        PopupMenuButton<String>(
          tooltip: 'Filters',
          color: NuaLuxuryTokens.voidViolet,
          onSelected: (_) => unawaited(onClearFilters()),
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'clear',
              child: Text('Clear all filters'),
            ),
          ],
          child: const IgnorePointer(
            child: _ToolbarFilterButton(compact: true, onPressed: null),
          ),
        ),
      ],
    );
  }
}

class _ToolbarFilterButton extends StatelessWidget {
  const _ToolbarFilterButton({this.onPressed, this.compact = false});

  final VoidCallback? onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: compact ? 36 : 50,
          padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.tune_rounded,
                size: 16,
                color: Colors.white.withValues(alpha: 0.55),
              ),
              const SizedBox(width: 6),
              Text(
                'Filters',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AdminPaymentsOverviewScreen.textPrimary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniDropdown extends StatelessWidget {
  const _MiniDropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
    this.compact = false,
  });

  final String value;
  final String hint;
  final List<MapEntry<String, String>> items;
  final Future<void> Function(String) onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 36 : 50,
      child: DropdownButtonFormField<String>(
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
          contentPadding: EdgeInsets.symmetric(
            horizontal: 10,
            vertical: compact ? 6 : 8,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
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
      ),
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
    required this.usluge,
    required this.method,
    required this.status,
    required this.service,
    required this.onMethod,
    required this.onStatus,
    required this.onService,
    required this.onPage,
    required this.onViewRow,
    required this.onClearFilters,
    required this.onPageSize,
  });

  final ThemeData theme;
  final bool compact;
  final List<AdminFinanceTransactionRow> rows;
  final int page;
  final int pageSize;
  final int total;
  final List<Usluga> usluge;
  final String method;
  final String status;
  final String service;
  final Future<void> Function(String) onMethod;
  final Future<void> Function(String) onStatus;
  final Future<void> Function(String) onService;
  final Future<void> Function(int) onPage;
  final Future<void> Function(AdminFinanceTransactionRow) onViewRow;
  final Future<void> Function() onClearFilters;
  final Future<void> Function(int) onPageSize;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 16 : 20,
              compact ? 14 : 16,
              compact ? 16 : 20,
              compact ? 10 : 12,
            ),
            child: LayoutBuilder(
              builder: (context, c) {
                final stacked = c.maxWidth < 720;
                final filters = _PaymentsTableFilters(
                  usluge: usluge,
                  method: method,
                  status: status,
                  service: service,
                  onMethod: onMethod,
                  onStatus: onStatus,
                  onService: onService,
                  onClearFilters: onClearFilters,
                );

                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Transactions',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AdminPaymentsOverviewScreen.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: filters,
                        ),
                      ),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        'Transactions',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AdminPaymentsOverviewScreen.textPrimary,
                        ),
                      ),
                    ),
                    filters,
                  ],
                );
              },
            ),
          ),
          if (rows.isEmpty)
            SizedBox(
              height: compact ? 220 : 260,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
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
                          fontWeight: FontWeight.w700,
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
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, c) {
                final narrow = c.maxWidth < 980;
                if (narrow) {
                  return Column(
                    children: [
                      for (final r in rows)
                        _TransactionCard(
                          theme: theme,
                          row: r,
                          fmt: _fmtWhen,
                          onView: () => unawaited(onViewRow(r)),
                        ),
                    ],
                  );
                }
                return Column(
                  children: [
                    _TableHeader(theme: theme, compact: compact),
                    for (final r in rows)
                      _TableDataRow(
                        theme: theme,
                        compact: compact,
                        row: r,
                        fmt: _fmtWhen,
                        onView: () => unawaited(onViewRow(r)),
                      ),
                  ],
                );
              },
            ),
          if (total > 0)
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
                      DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: pageSize,
                          isDense: true,
                          dropdownColor: NuaLuxuryTokens.voidViolet,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w700,
                          ),
                          items: const [
                            DropdownMenuItem(value: 10, child: Text('Show 10')),
                            DropdownMenuItem(value: 25, child: Text('Show 25')),
                            DropdownMenuItem(value: 50, child: Text('Show 50')),
                          ],
                          onChanged: (v) {
                            if (v != null) unawaited(onPageSize(v));
                          },
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
    final lower = method.toLowerCase();
    final isCard = lower.contains('card') ||
        lower.contains('stripe') ||
        lower.contains('visa') ||
        lower.contains('master') ||
        method.contains('••');
    final isCash = lower.contains('cash') || lower.contains('gotovin') || lower.contains('spa');
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
              isCard
                  ? Icons.credit_card_rounded
                  : isCash
                      ? Icons.payments_outlined
                      : Icons.account_balance_wallet_outlined,
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
  bool _hasRevenueData(List<AdminFinanceTrendPoint> pts) {
    return pts.isNotEmpty && pts.any((p) => p.iznos > 0);
  }

  @override
  Widget build(BuildContext context) {
    final pts = widget.points;
    if (!_hasRevenueData(pts)) {
      return _pgGlass(
        child: SizedBox(
          height: widget.compact ? 220 : 260,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              widget.compact ? 16 : 20,
              widget.compact ? 14 : 16,
              widget.compact ? 16 : 20,
              widget.compact ? 16 : 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Revenue Trend',
                  style: widget.theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AdminPaymentsOverviewScreen.textPrimary,
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.show_chart_rounded,
                          size: 32,
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No revenue data available',
                          style: widget.theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.72),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Revenue trends will appear once payments are recorded.',
                          textAlign: TextAlign.center,
                          style: widget.theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.42),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
      child: Padding(
        padding: EdgeInsets.all(widget.compact ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Revenue Trend',
              style: widget.theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
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

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({
    required this.theme,
    required this.row,
    required this.fmt,
    required this.onView,
  });

  final ThemeData theme;
  final AdminFinanceTransactionRow row;
  final String Function(DateTime) fmt;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onView,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.klijentPunoIme,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AdminPaymentsOverviewScreen.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      _formatKm(row.iznos),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  row.uslugaTekst,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _StatusPill(apiStatus: row.status),
                    Text(
                      row.metodaLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    Text(
                      fmt(row.datumVrijeme),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.42),
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
}

class _FinanceInsightsRow extends StatelessWidget {
  const _FinanceInsightsRow({
    required this.theme,
    required this.compact,
    required this.methods,
    required this.activity,
  });

  final ThemeData theme;
  final bool compact;
  final List<AdminFinanceMethodShare> methods;
  final List<AdminFinanceActivity> activity;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final stacked = c.maxWidth < 900;
        Widget methodCard({required bool stretch}) {
          return _pgGlass(
            child: Padding(
              padding: EdgeInsets.all(compact ? 16 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: stretch ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  Text(
                    'Payment methods',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AdminPaymentsOverviewScreen.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (methods.isEmpty)
                    stretch
                        ? Expanded(
                            child: Center(
                              child: Text(
                                'No method data for this period.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.45),
                                ),
                              ),
                            ),
                          )
                        : Text(
                            'No method data for this period.',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.45),
                            ),
                          )
                  else ...[
                    for (final m in methods)
                      if (m.postotak > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  m.label,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.62),
                                  ),
                                ),
                              ),
                              Text(
                                '${m.postotak.toStringAsFixed(0)}%',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AdminPaymentsOverviewScreen.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                    if (stretch) const Spacer(),
                  ],
                ],
              ),
            ),
          );
        }

        Widget activityCard({required bool stretch}) {
          return _pgGlass(
            child: Padding(
              padding: EdgeInsets.all(compact ? 16 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: stretch ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  Text(
                    'Recent activity',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AdminPaymentsOverviewScreen.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (activity.isEmpty)
                    stretch
                        ? Expanded(
                            child: Center(
                              child: Text(
                                'No recent transactions in the selected period.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.45),
                                ),
                              ),
                            ),
                          )
                        : Text(
                            'No recent transactions in the selected period.',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.45),
                            ),
                          )
                  else ...[
                    for (final a in activity.take(6))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${a.opis} · ${a.klijent}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.72),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              _formatKm(a.iznos),
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (stretch) const Spacer(),
                  ],
                ],
              ),
            ),
          );
        }

        if (stacked) {
          return Column(
            children: [
              methodCard(stretch: false),
              const SizedBox(height: 12),
              activityCard(stretch: false),
            ],
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: methodCard(stretch: true)),
              const SizedBox(width: 12),
              Expanded(child: activityCard(stretch: true)),
            ],
          ),
        );
      },
    );
  }
}

class _TransactionDetailSheet extends StatelessWidget {
  const _TransactionDetailSheet({
    required this.row,
    this.asSidePanel = false,
  });

  final AdminFinanceTransactionRow row;
  final bool asSidePanel;

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

    final content = ListView(
      padding: EdgeInsets.fromLTRB(22, asSidePanel ? 22 : 12, 22, 28),
      children: [
        if (!asSidePanel)
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
        if (!asSidePanel) const SizedBox(height: 18),
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
        if (row.stripePaymentIntentId != null &&
            row.stripePaymentIntentId!.isNotEmpty)
          _detailRow(theme, 'Stripe payment', row.stripePaymentIntentId!),
        _detailRow(theme, 'Client', row.klijentPunoIme),
        _detailRow(theme, 'Service', row.uslugaTekst),
        _detailRow(theme, 'Amount', _formatKm(row.iznos)),
        if (row.naplaceniIznos != null)
          _detailRow(theme, 'Charged amount', _formatKm(row.naplaceniIznos!)),
        _detailRow(
          theme,
          'Status',
          null,
          trailing: _StatusPill(apiStatus: row.status),
        ),
        _detailRow(theme, 'Payment method', row.metodaLabel),
        _detailRow(theme, 'Date & time', _fmtDetailDate(row.datumVrijeme)),
        if (row.datumZavrsetka != null)
          _detailRow(
            theme,
            'Completed at',
            _fmtDetailDate(row.datumZavrsetka!),
          ),
        if (row.rezervacijaId != null && row.rezervacijaId! > 0)
          _detailRow(
            theme,
            'Booking reference',
            '#${row.rezervacijaId}',
          ),
        if (row.stripeRefundId != null && row.stripeRefundId!.isNotEmpty)
          _detailRow(theme, 'Refund reference', row.stripeRefundId!),
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
    );

    if (asSidePanel) {
      return ClipRRect(
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(22)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF120A22).withValues(alpha: 0.98),
              border: Border(
                left: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
            child: content,
          ),
        ),
      );
    }

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
                child: content,
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
