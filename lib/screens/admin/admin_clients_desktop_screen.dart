import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/services/api_service.dart';
import '../../models/admin/admin_client_row.dart';
import '../../models/zaposlenik.dart';
import '../../ui/theme/nua_luxury_tokens.dart';

/// Premium dark admin dashboard for Clients (desktop shell provides global header + rail).
class AdminClientsDesktopScreen extends StatefulWidget {
  const AdminClientsDesktopScreen({super.key, required this.api});

  final ApiService api;

  @override
  State<AdminClientsDesktopScreen> createState() =>
      _AdminClientsDesktopScreenState();
}

class _AdminClientsDesktopScreenState extends State<AdminClientsDesktopScreen> {
  static const Color _textPrimary = Color(0xFFF5F3FA);
  static const Color _purple = Color(0xFF7B4DFF);
  static const Color _purple2 = Color(0xFF9D6BFF);
  static const Color _gold = Color(0xFFD4AF7A);
  static const Color _success = Color(0xFF4ADE80);

  final TextEditingController _apiSearch = TextEditingController();
  final TextEditingController _quickSearch = TextEditingController();
  Timer? _searchDebounce;

  Future<List<AdminClientRow>>? _loadFuture;
  Future<List<Zaposlenik>>? _therapistsFuture;

  String _vipFilter = 'all'; // all | vip | none
  int? _therapistFilterIndex; // null = all; else index into therapists
  String _sortKey = 'new'; // new | old | visit | name
  int _page = 0;
  int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _therapistsFuture = widget.api.getZaposlenici();
    _scheduleReload(immediate: true);
    _apiSearch.addListener(_onApiSearchChanged);
    _quickSearch.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _apiSearch.removeListener(_onApiSearchChanged);
    _apiSearch.dispose();
    _quickSearch.dispose();
    super.dispose();
  }

  void _onApiSearchChanged() {
    _scheduleReload();
  }

  void _scheduleReload({bool immediate = false}) {
    _searchDebounce?.cancel();
    if (immediate) {
      _reloadFromApi();
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 320), _reloadFromApi);
  }

  void _reloadFromApi() {
    setState(() {
      _loadFuture = widget.api.getAdminClients(
        q: _apiSearch.text.trim(),
        take: 500,
      );
      _page = 0;
    });
  }

  Zaposlenik? _therapistFor(AdminClientRow c, List<Zaposlenik> th) {
    if (th.isEmpty) return null;
    return th[c.id.abs() % th.length];
  }

  String _therapistName(Zaposlenik z) => '${z.ime} ${z.prezime}'.trim();

  String _fmtVisit(DateTime? d) {
    if (d == null) return '—';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final loc = d.toLocal();
    return '${months[loc.month - 1]} ${loc.day}, ${loc.year}';
  }

  String _fmtInt(int n) {
    final s = n.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return n < 0 ? '-$buf' : buf.toString();
  }

  List<AdminClientRow> _applyLocalFilters(
    List<AdminClientRow> raw,
    List<Zaposlenik> therapists,
  ) {
    var xs = List<AdminClientRow>.from(raw);

    final qQuick = _quickSearch.text.trim().toLowerCase();
    if (qQuick.isNotEmpty) {
      xs = xs.where((c) {
        final blob =
            '${c.punoIme} ${c.email} ${c.telefon}'.toLowerCase();
        return blob.contains(qQuick);
      }).toList();
    }

    if (_vipFilter == 'vip') {
      xs = xs.where((c) => c.isVip).toList();
    } else if (_vipFilter == 'none') {
      xs = xs.where((c) => !c.isVip).toList();
    }

    if (_therapistFilterIndex != null &&
        therapists.isNotEmpty &&
        _therapistFilterIndex! < therapists.length) {
      final z = therapists[_therapistFilterIndex!];
      xs = xs.where((c) => _therapistFor(c, therapists)?.id == z.id).toList();
    }

    int cmp(AdminClientRow a, AdminClientRow b) {
      switch (_sortKey) {
        case 'old':
          return a.datumRegistracije.compareTo(b.datumRegistracije);
        case 'visit':
          final ad = a.zadnjaPosjeta;
          final bd = b.zadnjaPosjeta;
          if (ad == null && bd == null) return 0;
          if (ad == null) return 1;
          if (bd == null) return -1;
          return bd.compareTo(ad);
        case 'name':
          return a.punoIme.toLowerCase().compareTo(b.punoIme.toLowerCase());
        case 'new':
        default:
          return b.datumRegistracije.compareTo(a.datumRegistracije);
      }
    }

    xs.sort(cmp);
    return xs;
  }

  void _openClientSheet(AdminClientRow c, List<Zaposlenik> th) {
    final tName = _therapistFor(c, th) != null
        ? _therapistName(_therapistFor(c, th)!)
        : '—';
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NuaLuxuryTokens.voidViolet,
        title: Text(c.punoIme),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(c.email, style: TextStyle(color: Colors.white.withValues(alpha: 0.75))),
              const SizedBox(height: 6),
              Text(
                c.telefon.isEmpty ? '—' : c.telefon,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
              ),
              const SizedBox(height: 14),
              Text('VIP: ${c.isVip ? "Da" : "Ne"}'),
              Text('Terapeut: $tName'),
              Text('Posjete: ${c.ukupnoPosjeta}'),
              Text('Potrošnja: ${c.ukupnoPotroseno.toStringAsFixed(0)} KM'),
              Text('Zadnja posjeta: ${_fmtVisit(c.zadnjaPosjeta)}'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Zatvori')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseText = Theme.of(context).textTheme;

    return FutureBuilder<List<Zaposlenik>>(
      future: _therapistsFuture,
      builder: (context, thSnap) {
        final therapists = thSnap.data ?? const <Zaposlenik>[];

        return FutureBuilder<List<AdminClientRow>>(
          future: _loadFuture,
          builder: (context, snap) {
            final loading = snap.connectionState == ConnectionState.waiting;
            final raw = snap.data ?? const <AdminClientRow>[];
            final filtered = _applyLocalFilters(raw, therapists);
            final totalFiltered = filtered.length;
            final pageCount = totalFiltered == 0
                ? 1
                : ((totalFiltered - 1) ~/ _pageSize) + 1;
            final maxPage = pageCount - 1;
            final safePage = _page > maxPage ? maxPage : _page;
            if (safePage != _page) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _page = safePage);
              });
            }
            final start = safePage * _pageSize;
            final pageSlice = filtered.skip(start).take(_pageSize).toList();

            final vipN = filtered.where((e) => e.isVip).length;
            final visitsSum = filtered.fold<int>(0, (a, b) => a + b.ukupnoPosjeta);
            final spendSum =
                filtered.fold<double>(0, (a, b) => a + b.ukupnoPotroseno);

            return LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;
                final showRight = w >= 1300;
                final rightW = w >= 1550 ? 310.0 : 285.0;

                final content = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TitleKpiRow(
                      textTheme: baseText,
                      totalClients: totalFiltered,
                      vipCount: vipN,
                      visitsSum: visitsSum,
                      spendSum: spendSum,
                      loading: loading,
                      fmtInt: _fmtInt,
                    ),
                    const SizedBox(height: 20),
                    _FilterBar(
                      apiSearch: _apiSearch,
                      vipFilter: _vipFilter,
                      onVip: (v) => setState(() {
                        _vipFilter = v;
                        _page = 0;
                      }),
                      therapists: therapists,
                      therapistFilterIndex:
                          (_therapistFilterIndex != null &&
                                  therapists.isNotEmpty &&
                                  _therapistFilterIndex! < therapists.length)
                              ? _therapistFilterIndex
                              : null,
                      onTherapist: (i) => setState(() {
                        _therapistFilterIndex = i;
                        _page = 0;
                      }),
                      sortKey: _sortKey,
                      onSort: (s) => setState(() {
                        _sortKey = s;
                        _page = 0;
                      }),
                      onAdd: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Dodavanje klijenta — uskoro.'),
                            behavior: SnackBarBehavior.floating,
                            width: 380,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: _ClientsTableCard(
                        loading: loading,
                        rows: pageSlice,
                        therapists: therapists,
                        therapistFor: _therapistFor,
                        therapistName: _therapistName,
                        fmtVisit: _fmtVisit,
                        onView: (row) => _openClientSheet(row, therapists),
                        onMore: (_) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Više akcija — uskoro.'),
                              behavior: SnackBarBehavior.floating,
                              width: 360,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    _PaginationBar(
                      page: safePage,
                      pageCount: pageCount,
                      pageSize: _pageSize,
                      total: totalFiltered,
                      start: totalFiltered == 0 ? 0 : start + 1,
                      end: (start + pageSlice.length).clamp(0, totalFiltered),
                      fmtInt: _fmtInt,
                      onPage: (p) => setState(() => _page = p),
                      onPageSize: (s) => setState(() {
                        _pageSize = s;
                        _page = 0;
                      }),
                    ),
                  ],
                );

                if (!showRight) {
                  return content;
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: content),
                    SizedBox(width: rightW, child: _RightPanel(
                      quickSearch: _quickSearch,
                      recent: _recentClients(filtered),
                      therapists: therapists,
                      countsForTherapist: (z) => filtered
                          .where((c) => _therapistFor(c, therapists)?.id == z.id)
                          .length,
                      therapistName: _therapistName,
                    )),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  List<AdminClientRow> _recentClients(List<AdminClientRow> filtered) {
    final xs = List<AdminClientRow>.from(filtered);
    int visitRank(AdminClientRow c) {
      final d = c.zadnjaPosjeta;
      if (d == null) return 0;
      return d.millisecondsSinceEpoch;
    }

    xs.sort((a, b) => visitRank(b).compareTo(visitRank(a)));
    return xs.take(5).toList();
  }
}

// ——— UI blocks ———

class _Glass extends StatelessWidget {
  const _Glass({
    required this.child,
    this.radius = 20,
    this.padding,
    this.borderAlpha = 0.06,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final double borderAlpha;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: borderAlpha)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7B4DFF).withValues(alpha: 0.10),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: padding ?? EdgeInsets.zero,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _TitleKpiRow extends StatelessWidget {
  const _TitleKpiRow({
    required this.textTheme,
    required this.totalClients,
    required this.vipCount,
    required this.visitsSum,
    required this.spendSum,
    required this.loading,
    required this.fmtInt,
  });

  final TextTheme textTheme;
  final int totalClients;
  final int vipCount;
  final int visitsSum;
  final double spendSum;
  final bool loading;
  final String Function(int) fmtInt;

  @override
  Widget build(BuildContext context) {
    final titleStyle = GoogleFonts.inter(
      textStyle: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        color: _AdminClientsDesktopScreenState._textPrimary,
        letterSpacing: -0.3,
      ),
    );
    final subStyle = GoogleFonts.inter(
      fontSize: 13.5,
      color: Colors.white.withValues(alpha: 0.62),
      height: 1.35,
    );

    return LayoutBuilder(
      builder: (context, c) {
        final stackKpi = c.maxWidth < 1100;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Glass(
                  radius: 18,
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.people_alt_outlined,
                    color: NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.95),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Klijenti', style: titleStyle),
                      const SizedBox(height: 4),
                      Text('Pretraga, posjete i VIP status.', style: subStyle),
                    ],
                  ),
                ),
                if (!stackKpi) ...[
                  const SizedBox(width: 12),
                  _KpiMini(
                    label: 'Ukupno klijenata',
                    value: loading ? '…' : fmtInt(totalClients),
                    icon: Icons.groups_2_outlined,
                  ),
                  const SizedBox(width: 12),
                  _KpiMini(
                    label: 'VIP klijenti',
                    value: loading ? '…' : fmtInt(vipCount),
                    icon: Icons.workspace_premium_outlined,
                  ),
                  const SizedBox(width: 12),
                  _KpiMini(
                    label: 'Ukupno posjeta',
                    value: loading ? '…' : fmtInt(visitsSum),
                    icon: Icons.bar_chart_rounded,
                  ),
                  const SizedBox(width: 12),
                  _KpiMini(
                    label: 'Potrošnja',
                    value: loading ? '…' : '${fmtInt(spendSum.round())} KM',
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                ],
              ],
            ),
            if (stackKpi) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _KpiMini(
                    label: 'Ukupno klijenata',
                    value: loading ? '…' : fmtInt(totalClients),
                    icon: Icons.groups_2_outlined,
                  ),
                  _KpiMini(
                    label: 'VIP klijenti',
                    value: loading ? '…' : fmtInt(vipCount),
                    icon: Icons.workspace_premium_outlined,
                  ),
                  _KpiMini(
                    label: 'Ukupno posjeta',
                    value: loading ? '…' : fmtInt(visitsSum),
                    icon: Icons.bar_chart_rounded,
                  ),
                  _KpiMini(
                    label: 'Potrošnja',
                    value: loading ? '…' : '${fmtInt(spendSum.round())} KM',
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

class _KpiMini extends StatelessWidget {
  const _KpiMini({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 148,
      child: _Glass(
        radius: 18,
        borderAlpha: 0.065,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.55)),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _AdminClientsDesktopScreenState._textPrimary,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.apiSearch,
    required this.vipFilter,
    required this.onVip,
    required this.therapists,
    required this.therapistFilterIndex,
    required this.onTherapist,
    required this.sortKey,
    required this.onSort,
    required this.onAdd,
  });

  final TextEditingController apiSearch;
  final String vipFilter;
  final ValueChanged<String> onVip;
  final List<Zaposlenik> therapists;
  final int? therapistFilterIndex;
  final ValueChanged<int?> onTherapist;
  final String sortKey;
  final ValueChanged<String> onSort;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final fieldStyle = GoogleFonts.inter(fontSize: 14);

    InputDecoration deco(String hint) => InputDecoration(
          isDense: true,
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.38)),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.045),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.55)),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        );

    Widget dropdown<T>({
      required T value,
      required List<DropdownMenuItem<T>> items,
      required ValueChanged<T?> onChanged,
    }) {
      return Theme(
        data: Theme.of(context).copyWith(canvasColor: NuaLuxuryTokens.voidViolet),
        child: InputDecorator(
          decoration: deco(''),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              isExpanded: true,
              value: value,
              items: items,
              onChanged: onChanged,
              style: fieldStyle.copyWith(color: _AdminClientsDesktopScreenState._textPrimary),
              icon: Icon(Icons.expand_more_rounded, color: Colors.white.withValues(alpha: 0.55)),
              dropdownColor: NuaLuxuryTokens.voidViolet,
            ),
          ),
        ),
      );
    }

    return _Glass(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: LayoutBuilder(
        builder: (context, c) {
          final narrow = c.maxWidth < 980;
          final children = <Widget>[
            Expanded(
              flex: narrow ? 2 : 3,
              child: TextField(
                controller: apiSearch,
                style: fieldStyle.copyWith(color: _AdminClientsDesktopScreenState._textPrimary),
                decoration: deco('Pretraži klijente...').copyWith(
                  prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.45)),
                ),
              ),
            ),
            SizedBox(
              width: narrow ? double.infinity : 168,
              child: dropdown<String>(
                value: vipFilter,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Svi VIP statusi')),
                  DropdownMenuItem(value: 'vip', child: Text('Samo VIP')),
                  DropdownMenuItem(value: 'none', child: Text('Bez VIP')),
                ],
                onChanged: (v) {
                  if (v != null) onVip(v);
                },
              ),
            ),
            SizedBox(
              width: narrow ? double.infinity : 168,
              child: dropdown<int?>(
                value: therapistFilterIndex,
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Svi terapeuti')),
                  for (var i = 0; i < therapists.length; i++)
                    DropdownMenuItem<int?>(
                      value: i,
                      child: Text(
                        _tn(therapists[i]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: onTherapist,
              ),
            ),
            SizedBox(
              width: narrow ? double.infinity : 200,
              child: dropdown<String>(
                value: sortKey,
                items: const [
                  DropdownMenuItem(value: 'new', child: Text('Sortiraj: Novi prvo')),
                  DropdownMenuItem(value: 'old', child: Text('Sortiraj: Stariji prvo')),
                  DropdownMenuItem(value: 'visit', child: Text('Sortiraj: Zadnja posjeta')),
                  DropdownMenuItem(value: 'name', child: Text('Sortiraj: Ime A–Ž')),
                ],
                onChanged: (v) {
                  if (v != null) onSort(v);
                },
              ),
            ),
            SizedBox(
              width: narrow ? double.infinity : 168,
              height: 46,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_AdminClientsDesktopScreenState._purple, _AdminClientsDesktopScreenState._purple2],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: _AdminClientsDesktopScreenState._purple.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: onAdd,
                    child: Center(
                      child: Text(
                        '+ Dodaj klijenta',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ];

          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  children[i],
                ],
              ],
            );
          }

          return Row(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: 14),
                children[i],
              ],
            ],
          );
        },
      ),
    );
  }

  static String _tn(Zaposlenik z) => '${z.ime} ${z.prezime}'.trim();
}

class _ClientsTableCard extends StatelessWidget {
  const _ClientsTableCard({
    required this.loading,
    required this.rows,
    required this.therapists,
    required this.therapistFor,
    required this.therapistName,
    required this.fmtVisit,
    required this.onView,
    required this.onMore,
  });

  final bool loading;
  final List<AdminClientRow> rows;
  final List<Zaposlenik> therapists;
  final Zaposlenik? Function(AdminClientRow c, List<Zaposlenik> th) therapistFor;
  final String Function(Zaposlenik z) therapistName;
  final String Function(DateTime? d) fmtVisit;
  final void Function(AdminClientRow) onView;
  final void Function(AdminClientRow) onMore;

  @override
  Widget build(BuildContext context) {
    if (loading && rows.isEmpty) {
      return const _Glass(
        radius: 22,
        child: Center(child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(strokeWidth: 2),
        )),
      );
    }

    if (!loading && rows.isEmpty) {
      return _Glass(
        radius: 22,
        padding: const EdgeInsets.all(48),
        child: Center(
          child: Text(
            'Nema klijenata za prikaz.',
            style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.6)),
          ),
        ),
      );
    }

    return _Glass(
      radius: 22,
      borderAlpha: 0.08,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TableHeaderRow(),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: rows.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                thickness: 1,
                color: Colors.white.withValues(alpha: 0.06),
              ),
              itemBuilder: (context, i) {
                final c = rows[i];
                final z = therapistFor(c, therapists);
                final tLabel = z == null ? '—' : therapistName(z);
                return _TableDataRow(
                  client: c,
                  therapistLabel: tLabel,
                  fmtVisit: fmtVisit,
                  onView: () => onView(c),
                  onMore: () => onMore(c),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TableHeaderRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: Colors.white.withValues(alpha: 0.72),
      letterSpacing: 0.2,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
        ),
      ),
      child: Row(
        children: [
          Expanded(flex: 22, child: Text('Klijent', style: s)),
          Expanded(flex: 22, child: Text('Kontakt', style: s)),
          Expanded(flex: 8, child: Text('VIP', style: s)),
          Expanded(flex: 14, child: Text('Terapeut', style: s)),
          Expanded(flex: 9, child: Text('Ukupno posjeta', style: s)),
          Expanded(flex: 10, child: Text('Potrošnja', style: s)),
          Expanded(flex: 12, child: Text('Zadnja posjeta', style: s)),
          SizedBox(
            width: 88,
            child: Align(alignment: Alignment.centerRight, child: Text('Akcije', style: s)),
          ),
        ],
      ),
    );
  }
}

class _TableDataRow extends StatefulWidget {
  const _TableDataRow({
    required this.client,
    required this.therapistLabel,
    required this.fmtVisit,
    required this.onView,
    required this.onMore,
  });

  final AdminClientRow client;
  final String therapistLabel;
  final String Function(DateTime? d) fmtVisit;
  final VoidCallback onView;
  final VoidCallback onMore;

  @override
  State<_TableDataRow> createState() => _TableDataRowState();
}

class _TableDataRowState extends State<_TableDataRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.client;
    final bg = _hover
        ? NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.08)
        : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        color: bg,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              flex: 22,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.22),
                    child: Text(
                      _initials(c.punoIme),
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      c.punoIme,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: _AdminClientsDesktopScreenState._textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 22,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    c.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: Colors.white.withValues(alpha: 0.68),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    c.telefon.isEmpty ? '—' : c.telefon,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: Colors.white.withValues(alpha: 0.52),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 8,
              child: c.isVip
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF064E3B).withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: _AdminClientsDesktopScreenState._success.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        'VIP',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _AdminClientsDesktopScreenState._success,
                        ),
                      ),
                    )
                  : Text(
                      '—',
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
            Expanded(
              flex: 14,
              child: Text(
                widget.therapistLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.78),
                ),
              ),
            ),
            Expanded(
              flex: 9,
              child: Text(
                '${c.ukupnoPosjeta}',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
            Expanded(
              flex: 10,
              child: Text(
                '${c.ukupnoPotroseno.toStringAsFixed(0)} KM',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
            Expanded(
              flex: 12,
              child: Text(
                widget.fmtVisit(c.zadnjaPosjeta),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
            ),
            SizedBox(
              width: 88,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _RoundIcon(icon: Icons.visibility_outlined, onTap: widget.onView),
                  const SizedBox(width: 8),
                  _RoundIcon(icon: Icons.more_horiz_rounded, onTap: widget.onMore),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final p = name.trim().split(RegExp(r'\s+'));
    if (p.isEmpty) return '?';
    String ch(String s) =>
        s.isEmpty ? '' : String.fromCharCode(s.runes.first).toUpperCase();
    if (p.length == 1) return ch(p.first);
    return '${ch(p.first)}${ch(p.last)}';
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.78)),
        ),
      ),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.page,
    required this.pageCount,
    required this.pageSize,
    required this.total,
    required this.start,
    required this.end,
    required this.fmtInt,
    required this.onPage,
    required this.onPageSize,
  });

  final int page;
  final int pageCount;
  final int pageSize;
  final int total;
  final int start;
  final int end;
  final String Function(int) fmtInt;
  final ValueChanged<int> onPage;
  final ValueChanged<int> onPageSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _PageNumbers(
          page: page,
          pageCount: pageCount,
          onPage: onPage,
        )),
        Text(
          'Prikaži ',
          style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.55), fontSize: 13),
        ),
        Theme(
          data: Theme.of(context).copyWith(canvasColor: NuaLuxuryTokens.voidViolet),
          child: DropdownButton<int>(
            value: pageSize,
            underline: const SizedBox.shrink(),
            dropdownColor: NuaLuxuryTokens.voidViolet,
            style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.88)),
            items: const [
              DropdownMenuItem(value: 10, child: Text('10')),
              DropdownMenuItem(value: 25, child: Text('25')),
              DropdownMenuItem(value: 50, child: Text('50')),
            ],
            onChanged: (v) {
              if (v != null) onPageSize(v);
            },
          ),
        ),
        const SizedBox(width: 12),
        Text(
          total == 0 ? '0 klijenata' : '$start–$end od ${fmtInt(total)} klijenata',
          style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.55), fontSize: 13),
        ),
      ],
    );
  }
}

class _PageNumbers extends StatelessWidget {
  const _PageNumbers({
    required this.page,
    required this.pageCount,
    required this.onPage,
  });

  final int page;
  final int pageCount;
  final ValueChanged<int> onPage;

  List<int> _visiblePages() {
    if (pageCount <= 7) {
      return List.generate(pageCount, (i) => i);
    }
    const window = 2;
    final pages = <int>{0, pageCount - 1, page};
    for (var d = -window; d <= window; d++) {
      final p = page + d;
      if (p >= 0 && p < pageCount) pages.add(p);
    }
    final sorted = pages.toList()..sort();
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final vis = _visiblePages();
    final chips = <Widget>[];

    Widget numBtn(int p, {bool edge = false}) {
      final sel = p == page;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: sel ? null : () => onPage(p),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: sel
                  ? const LinearGradient(colors: [_AdminClientsDesktopScreenState._purple, _AdminClientsDesktopScreenState._purple2])
                  : null,
              color: sel ? null : Colors.white.withValues(alpha: 0.05),
              border: Border.all(color: Colors.white.withValues(alpha: sel ? 0.0 : 0.08)),
            ),
            child: Text(
              '${p + 1}',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Colors.white.withValues(alpha: sel ? 1 : 0.72),
              ),
            ),
          ),
        ),
      );
    }

    chips.add(
      IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        onPressed: page > 0 ? () => onPage(page - 1) : null,
        icon: Icon(Icons.chevron_left_rounded, color: Colors.white.withValues(alpha: page > 0 ? 0.75 : 0.25)),
      ),
    );

    var last = -2;
    for (final p in vis) {
      if (last >= 0 && p - last > 1) {
        chips.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text('…', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.45))),
          ),
        );
      }
      chips.add(numBtn(p));
      last = p;
    }

    chips.add(
      IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        onPressed: page < pageCount - 1 ? () => onPage(page + 1) : null,
        icon: Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: page < pageCount - 1 ? 0.75 : 0.25)),
      ),
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(children: chips),
      ),
    );
  }
}

class _RightPanel extends StatelessWidget {
  const _RightPanel({
    required this.quickSearch,
    required this.recent,
    required this.therapists,
    required this.countsForTherapist,
    required this.therapistName,
  });

  final TextEditingController quickSearch;
  final List<AdminClientRow> recent;
  final List<Zaposlenik> therapists;
  final int Function(Zaposlenik z) countsForTherapist;
  final String Function(Zaposlenik z) therapistName;

  @override
  Widget build(BuildContext context) {
    final maxC = therapists.fold<int>(0, (a, z) {
      final n = countsForTherapist(z);
      return n > a ? n : a;
    }).clamp(1, 9999);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Glass(
          radius: 20,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Brza pretraga',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: _AdminClientsDesktopScreenState._textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: quickSearch,
                style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.9), fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: 'Ime, email ili broj telefona...',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.38)),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.045),
                  prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.45)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.5)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          flex: 3,
          child: _Glass(
            radius: 20,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nedavni klijenti',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: _AdminClientsDesktopScreenState._textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.separated(
                    itemCount: recent.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.07),
                    ),
                    itemBuilder: (context, i) {
                      final c = recent[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor:
                                  NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.2),
                              child: Text(
                                _ini(c.punoIme),
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.punoIme,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _fmtShort(c.zadnjaPosjeta),
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      color: Colors.white.withValues(alpha: 0.52),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () {},
                    child: Text(
                      'Pogledaj sve',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        color: NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.95),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        _Glass(
          radius: 20,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Klijenti po terapeutima',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: _AdminClientsDesktopScreenState._textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              for (final z in therapists.take(6)) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        therapistName(z),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                      ),
                    ),
                    Text(
                      '${countsForTherapist(z)}',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: SizedBox(
                    height: 7,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: countsForTherapist(z) / maxC,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                gradient: const LinearGradient(
                                  colors: [
                                    _AdminClientsDesktopScreenState._purple,
                                    _AdminClientsDesktopScreenState._purple2,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Glass(
          radius: 20,
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.workspace_premium_outlined, size: 20, color: _AdminClientsDesktopScreenState._gold),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'VIP klijenti imaju pristup posebnim paketima i prioritetnim terminima.',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    height: 1.45,
                    color: Colors.white.withValues(alpha: 0.62),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _ini(String name) {
    final p = name.trim().split(RegExp(r'\s+'));
    if (p.isEmpty) return '?';
    String ch(String s) =>
        s.isEmpty ? '' : String.fromCharCode(s.runes.first).toUpperCase();
    if (p.length == 1) return ch(p.first);
    return '${ch(p.first)}${ch(p.last)}';
  }

  static String _fmtShort(DateTime? d) {
    if (d == null) return '—';
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final loc = d.toLocal();
    return '${months[loc.month - 1]} ${loc.day}, ${loc.year}';
  }
}
