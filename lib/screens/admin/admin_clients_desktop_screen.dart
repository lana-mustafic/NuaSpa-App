import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/services/api_service.dart';
import '../../models/admin/admin_client_row.dart';
import '../../models/admin/admin_client_stats.dart';
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

  Future<({List<AdminClientRow> clients, AdminClientStats? stats})>? _payloadFuture;
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
    final q = _apiSearch.text.trim();
    setState(() {
      _payloadFuture = () async {
        final clients = await widget.api.getAdminClients(q: q, take: 500);
        final stats = await widget.api.getAdminClientStats(q: q.isEmpty ? null : q);
        return (clients: clients, stats: stats);
      }();
      _page = 0;
    });
  }

  bool get _useServerStats =>
      _vipFilter == 'all' &&
      _therapistFilterIndex == null &&
      _quickSearch.text.trim().isEmpty;

  String _therapistDisplay(AdminClientRow c, List<Zaposlenik> th) {
    final api = c.terapeutPunoIme;
    if (api != null && api.isNotEmpty) return api;
    final z = _therapistFor(c, th);
    return z == null ? '—' : _therapistName(z);
  }

  int? _therapistIdForRow(AdminClientRow c, List<Zaposlenik> th) =>
      c.terapeutZaposlenikId ?? _therapistFor(c, th)?.id;

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
      xs = xs.where((c) => _therapistIdForRow(c, therapists) == z.id).toList();
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
    final tName = _therapistDisplay(c, th);
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
              Text('VIP: ${c.isVip ? "Yes" : "No"}'),
              Text('Therapist: $tName'),
              Text('Visits: ${c.ukupnoPosjeta}'),
              Text('Spending: ${c.ukupnoPotroseno.toStringAsFixed(0)} KM'),
              Text('Last visit: ${_fmtVisit(c.zadnjaPosjeta)}'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _showCreateClientDialog(List<Zaposlenik> therapists) async {
    final imeC = TextEditingController();
    final prezC = TextEditingController();
    final emailC = TextEditingController();
    final userC = TextEditingController();
    final passC = TextEditingController(text: 'NuaSpaKlijent1!');
    final telC = TextEditingController();
    int? zId;
    var vip = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            backgroundColor: NuaLuxuryTokens.voidViolet,
            title: const Text('New client'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: imeC,
                      decoration: const InputDecoration(labelText: 'First name'),
                    ),
                    TextField(
                      controller: prezC,
                      decoration: const InputDecoration(labelText: 'Last name'),
                    ),
                    TextField(
                      controller: emailC,
                      decoration: const InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    TextField(
                      controller: userC,
                      decoration: const InputDecoration(labelText: 'Username'),
                    ),
                    TextField(
                      controller: passC,
                      decoration: const InputDecoration(labelText: 'Password'),
                      obscureText: true,
                    ),
                    TextField(
                      controller: telC,
                      decoration: const InputDecoration(labelText: 'Phone (optional)'),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int?>(
                      value: zId,
                      decoration: const InputDecoration(labelText: 'Preferred therapist'),
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('—')),
                        ...therapists.map(
                          (z) => DropdownMenuItem<int?>(
                            value: z.id,
                            child: Text(_therapistName(z)),
                          ),
                        ),
                      ],
                      onChanged: (v) => setLocal(() => zId = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('VIP client'),
                      value: vip,
                      onChanged: (v) => setLocal(() => vip = v),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  final ime = imeC.text.trim();
                  final prez = prezC.text.trim();
                  final email = emailC.text.trim();
                  final user = userC.text.trim();
                  final pass = passC.text;
                  if (ime.isEmpty || prez.isEmpty || email.isEmpty || user.isEmpty || pass.length < 6) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Fill in required fields (password min. 6 characters).')),
                    );
                    return;
                  }
                  try {
                    await widget.api.createAdminClient(
                      ime: ime,
                      prezime: prez,
                      email: email,
                      userName: user,
                      password: pass,
                      telefon: telC.text.trim().isEmpty ? null : telC.text.trim(),
                      zaposlenikId: zId,
                      isVipKlijent: vip,
                    );
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    _reloadFromApi();
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Client created.')),
                    );
                  } catch (e) {
                    if (!ctx.mounted) return;
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    imeC.dispose();
    prezC.dispose();
    emailC.dispose();
    userC.dispose();
    passC.dispose();
    telC.dispose();
  }

  Future<void> _onClientMore(
    AdminClientRow row,
    List<Zaposlenik> therapists,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: NuaLuxuryTokens.voidViolet,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.workspace_premium_outlined),
                title: Text(row.isVipKlijent ? 'Remove manual VIP' : 'Set manual VIP'),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await widget.api.patchAdminClient(
                      id: row.id,
                      isVipKlijent: !row.isVipKlijent,
                    );
                    if (!mounted) return;
                    _reloadFromApi();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          row.isVipKlijent ? 'Manual VIP removed.' : 'Manual VIP set.',
                        ),
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Change preferred therapist'),
                onTap: () async {
                  Navigator.pop(ctx);
                  int? picked = row.preferiraniZaposlenikId;
                  await showDialog<void>(
                    context: context,
                    builder: (dCtx) => StatefulBuilder(
                      builder: (dCtx, setL) {
                        return AlertDialog(
                          backgroundColor: NuaLuxuryTokens.voidViolet,
                          title: const Text('Preferred therapist'),
                          content: DropdownButtonFormField<int?>(
                            value: picked,
                            items: [
                              const DropdownMenuItem<int?>(value: null, child: Text('None')),
                              ...therapists.map(
                                (z) => DropdownMenuItem<int?>(
                                  value: z.id,
                                  child: Text(_therapistName(z)),
                                ),
                              ),
                            ],
                            onChanged: (v) => setL(() => picked = v),
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
                            FilledButton(
                              onPressed: () async {
                                try {
                                  await widget.api.patchAdminClient(
                                    id: row.id,
                                    setZaposlenik: true,
                                    zaposlenikId: picked,
                                  );
                                  if (!dCtx.mounted) return;
                                  Navigator.pop(dCtx);
                                  if (!mounted) return;
                                  _reloadFromApi();
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                }
                              },
                              child: const Text('Save'),
                            ),
                          ],
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseText = Theme.of(context).textTheme;

    return FutureBuilder<List<Zaposlenik>>(
      future: _therapistsFuture,
      builder: (context, thSnap) {
        final therapists = thSnap.data ?? const <Zaposlenik>[];

        return FutureBuilder<({List<AdminClientRow> clients, AdminClientStats? stats})>(
          future: _payloadFuture,
          builder: (context, snap) {
            final loading = snap.connectionState == ConnectionState.waiting;
            final payload = snap.data;
            final raw = payload?.clients ?? const <AdminClientRow>[];
            final serverStats = payload?.stats;
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

            final int vipN;
            final int visitsSum;
            final double spendSum;
            final int totalClientsKpi;
            if (_useServerStats && serverStats != null) {
              final st = serverStats;
              vipN = st.vipKlijenata;
              visitsSum = st.ukupnoPosjeta;
              spendSum = st.ukupnaPotrosnja;
              totalClientsKpi = st.ukupnoKlijenata;
            } else {
              vipN = filtered.where((e) => e.isVip).length;
              visitsSum = filtered.fold<int>(0, (a, b) => a + b.ukupnoPosjeta);
              spendSum = filtered.fold<double>(0, (a, b) => a + b.ukupnoPotroseno);
              totalClientsKpi = totalFiltered;
            }

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
                      totalClients: totalClientsKpi,
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
                      onAdd: () => _showCreateClientDialog(therapists),
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: _ClientsTableCard(
                        loading: loading,
                        rows: pageSlice,
                        therapistLabel: (c) => _therapistDisplay(c, therapists),
                        fmtVisit: _fmtVisit,
                        onView: (row) => _openClientSheet(row, therapists),
                        onMore: (row) => _onClientMore(row, therapists),
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
                          .where((c) => _therapistIdForRow(c, therapists) == z.id)
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
                      Text('Clients', style: titleStyle),
                      const SizedBox(height: 4),
                      Text('Search, visits and VIP status.', style: subStyle),
                    ],
                  ),
                ),
                if (!stackKpi) ...[
                  const SizedBox(width: 12),
                  _KpiMini(
                    label: 'Total clients',
                    value: loading ? '…' : fmtInt(totalClients),
                    icon: Icons.groups_2_outlined,
                  ),
                  const SizedBox(width: 12),
                  _KpiMini(
                    label: 'VIP clients',
                    value: loading ? '…' : fmtInt(vipCount),
                    icon: Icons.workspace_premium_outlined,
                  ),
                  const SizedBox(width: 12),
                  _KpiMini(
                    label: 'Total visits',
                    value: loading ? '…' : fmtInt(visitsSum),
                    icon: Icons.bar_chart_rounded,
                  ),
                  const SizedBox(width: 12),
                  _KpiMini(
                    label: 'Spending',
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
                    label: 'Total clients',
                    value: loading ? '…' : fmtInt(totalClients),
                    icon: Icons.groups_2_outlined,
                  ),
                  _KpiMini(
                    label: 'VIP clients',
                    value: loading ? '…' : fmtInt(vipCount),
                    icon: Icons.workspace_premium_outlined,
                  ),
                  _KpiMini(
                    label: 'Total visits',
                    value: loading ? '…' : fmtInt(visitsSum),
                    icon: Icons.bar_chart_rounded,
                  ),
                  _KpiMini(
                    label: 'Spending',
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
                decoration: deco('Search clients...').copyWith(
                  prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.45)),
                ),
              ),
            ),
            SizedBox(
              width: narrow ? double.infinity : 168,
              child: dropdown<String>(
                value: vipFilter,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All VIP statuses')),
                  DropdownMenuItem(value: 'vip', child: Text('VIP only')),
                  DropdownMenuItem(value: 'none', child: Text('Non-VIP')),
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
                  const DropdownMenuItem<int?>(value: null, child: Text('All therapists')),
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
                  DropdownMenuItem(value: 'new', child: Text('Sort: Newest first')),
                  DropdownMenuItem(value: 'old', child: Text('Sort: Oldest first')),
                  DropdownMenuItem(value: 'visit', child: Text('Sort: Last visit')),
                  DropdownMenuItem(value: 'name', child: Text('Sort: Name A–Z')),
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
                        '+ Add client',
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
    required this.therapistLabel,
    required this.fmtVisit,
    required this.onView,
    required this.onMore,
  });

  final bool loading;
  final List<AdminClientRow> rows;
  final String Function(AdminClientRow c) therapistLabel;
  final String Function(DateTime? d) fmtVisit;
  final void Function(AdminClientRow) onView;
  final void Function(AdminClientRow) onMore;

  @override
  Widget build(BuildContext context) {
    if (loading && rows.isEmpty) {
      return const _ClientsTableShell(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(48),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (!loading && rows.isEmpty) {
      return _ClientsTableShell(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(48),
            child: Text(
              'No clients to display.',
              style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.6)),
            ),
          ),
        ),
      );
    }

    return _ClientsTableShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _TableHeaderRow(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
              itemCount: rows.length,
              itemBuilder: (context, i) {
                final c = rows[i];
                final tLabel = therapistLabel(c);
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

/// Dark glassmorphism CRM table container.
class _ClientsTableShell extends StatelessWidget {
  const _ClientsTableShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7B4DFF).withValues(alpha: 0.14),
                blurRadius: 32,
                spreadRadius: -4,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _TableHeaderRow extends StatelessWidget {
  const _TableHeaderRow();

  static const double _height = 64;
  static const double _hPad = 28;

  @override
  Widget build(BuildContext context) {
    final s = GoogleFonts.inter(
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      color: Colors.white.withValues(alpha: 0.55),
      letterSpacing: 0.35,
    );
    return Container(
      height: _height,
      padding: const EdgeInsets.symmetric(horizontal: _hPad),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          Expanded(flex: 26, child: Text('CLIENT', style: s)),
          const SizedBox(width: 20),
          Expanded(flex: 24, child: Text('CONTACT', style: s)),
          const SizedBox(width: 16),
          Expanded(flex: 11, child: Text('VIP STATUS', style: s)),
          const SizedBox(width: 16),
          Expanded(flex: 17, child: Text('THERAPIST', style: s)),
          const SizedBox(width: 16),
          Expanded(flex: 10, child: Text('TOTAL VISITS', style: s)),
          const SizedBox(width: 16),
          Expanded(flex: 11, child: Text('SPENDING', style: s)),
          const SizedBox(width: 16),
          Expanded(flex: 14, child: Text('LAST VISIT', style: s)),
          const SizedBox(width: 16),
          SizedBox(
            width: 112,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('ACTIONS', style: s),
            ),
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
  static const double _rowHeight = 120;
  static const double _hPad = 28;
  static const Color _vipGreen = Color(0xFF22C55E);
  static const Color _lavender = Color(0xFFC8B6E8);

  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.client;
    final hasVisit = c.zadnjaPosjeta != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          height: _rowHeight,
          padding: const EdgeInsets.symmetric(horizontal: _hPad),
          decoration: BoxDecoration(
            color: _hover
                ? const Color(0xFF7B4DFF).withValues(alpha: 0.07)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hover
                  ? const Color(0xFF7B4DFF).withValues(alpha: 0.25)
                  : Colors.transparent,
              width: 1,
            ),
            boxShadow: _hover
                ? [
                    BoxShadow(
                      color: const Color(0xFF7B4DFF).withValues(alpha: 0.12),
                      blurRadius: 20,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Expanded(flex: 26, child: _clientColumn(c)),
              const SizedBox(width: 20),
              Expanded(flex: 24, child: _contactColumn(c)),
              const SizedBox(width: 16),
              Expanded(flex: 11, child: _vipColumn(c)),
              const SizedBox(width: 16),
              Expanded(flex: 17, child: _therapistColumn()),
              const SizedBox(width: 16),
              Expanded(flex: 10, child: _statColumn('${c.ukupnoPosjeta}', 'visits')),
              const SizedBox(width: 16),
              Expanded(
                flex: 11,
                child: _statColumn(
                  '${c.ukupnoPotroseno.toStringAsFixed(0)} KM',
                  'total spent',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(flex: 14, child: _lastVisitColumn(hasVisit)),
              const SizedBox(width: 16),
              SizedBox(
                width: 112,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _ActionIconButton(
                      icon: Icons.visibility_outlined,
                      onTap: widget.onView,
                    ),
                    const SizedBox(width: 10),
                    _ActionIconButton(
                      icon: Icons.more_horiz_rounded,
                      onTap: widget.onMore,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _clientColumn(AdminClientRow c) {
    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _AdminClientsDesktopScreenState._purple,
                _AdminClientsDesktopScreenState._purple2,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: _AdminClientsDesktopScreenState._purple.withValues(alpha: 0.38),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            _initials(c.punoIme),
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                c.punoIme,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 15.5,
                  color: _AdminClientsDesktopScreenState._textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.person_outline_rounded,
                    size: 13,
                    color: _lavender.withValues(alpha: 0.75),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      _fmtClientSince(c.datumRegistracije),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.48),
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _contactColumn(AdminClientRow c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _contactLine(Icons.mail_outline_rounded, c.email),
        const SizedBox(height: 10),
        _contactLine(
          Icons.phone_outlined,
          c.telefon.isEmpty ? '—' : c.telefon,
        ),
      ],
    );
  }

  Widget _contactLine(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 15, color: _lavender.withValues(alpha: 0.9)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.78),
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _vipColumn(AdminClientRow c) {
    if (!c.isVip) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '—',
          style: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.32),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: _vipGreen.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _vipGreen.withValues(alpha: 0.45)),
          boxShadow: [
            BoxShadow(
              color: _vipGreen.withValues(alpha: 0.22),
              blurRadius: 12,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.workspace_premium_rounded,
              size: 14,
              color: _vipGreen.withValues(alpha: 0.95),
            ),
            const SizedBox(width: 6),
            Text(
              'VIP',
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: _vipGreen,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _therapistColumn() {
    return Row(
      children: [
        Icon(
          Icons.spa_outlined,
          size: 16,
          color: _lavender.withValues(alpha: 0.65),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            widget.therapistLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: _lavender.withValues(alpha: 0.82),
            ),
          ),
        ),
      ],
    );
  }

  Widget _statColumn(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _AdminClientsDesktopScreenState._textPrimary,
            letterSpacing: -0.3,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.42),
            height: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _lastVisitColumn(bool hasVisit) {
    if (!hasVisit) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '—',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.38),
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'No visits yet',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.38),
              height: 1.2,
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          widget.fmtVisit(widget.client.zadnjaPosjeta),
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.72),
            height: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Last visit',
          style: GoogleFonts.inter(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.38),
            height: 1.2,
          ),
        ),
      ],
    );
  }

  String _fmtClientSince(DateTime d) {
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
    return 'Client since ${months[loc.month - 1]} ${loc.day}, ${loc.year}';
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

class _ActionIconButton extends StatefulWidget {
  const _ActionIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_ActionIconButton> createState() => _ActionIconButtonState();
}

class _ActionIconButtonState extends State<_ActionIconButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: _hover ? 0.09 : 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
          boxShadow: _hover
              ? [
                  BoxShadow(
                    color: const Color(0xFF7B4DFF).withValues(alpha: 0.35),
                    blurRadius: 14,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: widget.onTap,
            child: Icon(
              widget.icon,
              size: 20,
              color: Colors.white.withValues(alpha: _hover ? 0.95 : 0.72),
            ),
          ),
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
          'Show ',
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
          total == 0 ? '0 clients' : '$start–$end of ${fmtInt(total)} clients',
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
                'Quick search',
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
                  hintText: 'Name, email or phone number...',
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
                  'Recent clients',
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
                      'View all',
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
                'Clients by therapist',
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
                  'VIP clients have access to special packages and priority appointments.',
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
    if (d == null) return 'No visits yet';
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final loc = d.toLocal();
    return '${months[loc.month - 1]} ${loc.day}, ${loc.year}';
  }
}
