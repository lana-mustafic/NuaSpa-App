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

  String _apiErr(Object e) =>
      ApiService.adminClientPatchErrorMessage(e) ?? 'Error: $e';

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
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, _, _) => _ClientDetailsOverlay(
        client: c,
        therapistLabel: tName,
        fmtVisit: _fmtVisit,
      ),
      transitionBuilder: (ctx, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
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
                      SnackBar(content: Text(_apiErr(e))),
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

  Future<void> _showEditClientDialog(
    AdminClientRow row,
    List<Zaposlenik> therapists,
  ) async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, _, _) => _ClientEditOverlay(
        client: row,
        therapists: therapists,
        api: widget.api,
        therapistName: _therapistName,
        onSaved: () {
          _reloadFromApi();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Client updated.')),
            );
          }
        },
        formatError: _apiErr,
      ),
      transitionBuilder: (ctx, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _confirmSetClientActive(
    AdminClientRow row, {
    required bool activate,
  }) async {
    final title = activate ? 'Reactivate client?' : 'Deactivate client?';
    final body = activate
        ? '${row.punoIme} will be able to sign in and book again.'
        : '${row.punoIme} will not be able to sign in. Visit and payment history stay in the system.';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NuaLuxuryTokens.voidViolet,
        title: Text(title),
        content: Text(
          body,
          style: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.75),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: activate
                  ? _AdminClientsDesktopScreenState._purple
                  : Colors.red.shade700,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(activate ? 'Reactivate' : 'Deactivate'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    try {
      await widget.api.patchAdminClient(
        id: row.id,
        status: activate,
      );
      if (!mounted) return;
      _reloadFromApi();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(activate ? 'Client reactivated.' : 'Client deactivated.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_apiErr(e))),
      );
    }
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
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit client'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showEditClientDialog(row, therapists);
                },
              ),
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
                      SnackBar(content: Text(_apiErr(e))),
                    );
                  }
                },
              ),
              ListTile(
                leading: Icon(
                  row.isActive ? Icons.person_off_outlined : Icons.person_outline,
                  color: row.isActive ? Colors.red.shade300 : Colors.green.shade300,
                ),
                title: Text(row.isActive ? 'Deactivate account' : 'Reactivate account'),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmSetClientActive(row, activate: !row.isActive);
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
                    _ClientsHeroKpiSection(
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

/// Premium hero + KPI glass section for Clients dashboard.
class _ClientsHeroKpiSection extends StatelessWidget {
  const _ClientsHeroKpiSection({
    required this.totalClients,
    required this.vipCount,
    required this.visitsSum,
    required this.spendSum,
    required this.loading,
    required this.fmtInt,
  });

  final int totalClients;
  final int vipCount;
  final int visitsSum;
  final double spendSum;
  final bool loading;
  final String Function(int) fmtInt;

  static const Color _lavender = Color(0xFFC8B6E8);

  List<({String label, String value, IconData icon})> _cards() => [
        (
          label: 'Total Clients',
          value: loading ? '…' : fmtInt(totalClients),
          icon: Icons.groups_2_outlined,
        ),
        (
          label: 'VIP Clients',
          value: loading ? '…' : fmtInt(vipCount),
          icon: Icons.workspace_premium_outlined,
        ),
        (
          label: 'Total Visits',
          value: loading ? '…' : fmtInt(visitsSum),
          icon: Icons.event_available_outlined,
        ),
        (
          label: 'Spending',
          value: loading ? '…' : '${fmtInt(spendSum.round())} KM',
          icon: Icons.account_balance_wallet_outlined,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final cards = _cards();

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final wide = w >= 1320;
        final titleSize = w >= 1500 ? 64.0 : w >= 1100 ? 52.0 : 40.0;
        final subtitleSize = w >= 1500 ? 24.0 : w >= 1100 ? 20.0 : 16.0;

        Widget kpiRow({bool scroll = false}) {
          final row = Row(
            mainAxisSize: scroll ? MainAxisSize.min : MainAxisSize.max,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 24),
                _ClientsHeroKpiCard(
                  label: cards[i].label,
                  value: cards[i].value,
                  icon: cards[i].icon,
                ),
              ],
            ],
          );
          if (scroll) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: row,
            );
          }
          return row;
        }

        Widget heroBlock() {
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
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
                      color: _AdminClientsDesktopScreenState._purple.withValues(alpha: 0.45),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.people_alt_rounded,
                  size: 52,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 32),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Clients',
                      style: GoogleFonts.inter(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                        color: _AdminClientsDesktopScreenState._textPrimary,
                        letterSpacing: -1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Search, visits and VIP status.',
                      style: GoogleFonts.inter(
                        fontSize: subtitleSize,
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                        color: _lavender.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        Widget verticalDivider() => Container(
              width: 1,
              height: 160,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: Colors.white.withValues(alpha: 0.08),
            );

        Widget horizontalDivider() => Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Divider(
                height: 1,
                thickness: 1,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            );

        return ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF120A24).withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                boxShadow: [
                  BoxShadow(
                    color: _AdminClientsDesktopScreenState._purple.withValues(alpha: 0.14),
                    blurRadius: 36,
                    spreadRadius: -8,
                    offset: const Offset(0, 14),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 28,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: wide ? 42 : 28,
                  vertical: wide ? 36 : 28,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 260),
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            heroBlock(),
                            verticalDivider(),
                            const SizedBox(width: 40),
                            Expanded(child: kpiRow()),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            heroBlock(),
                            horizontalDivider(),
                            kpiRow(scroll: true),
                          ],
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ClientsHeroKpiCard extends StatefulWidget {
  const _ClientsHeroKpiCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  State<_ClientsHeroKpiCard> createState() => _ClientsHeroKpiCardState();
}

class _ClientsHeroKpiCardState extends State<_ClientsHeroKpiCard> {
  static const Color _lavender = Color(0xFFC8B6E8);
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: 260,
        height: 200,
        transform: Matrix4.translationValues(0, _hover ? -4 : 0, 0),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: _hover ? 0.05 : 0.035),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: Colors.white.withValues(alpha: _hover ? 0.14 : 0.08),
          ),
          boxShadow: _hover
              ? [
                  BoxShadow(
                    color: _AdminClientsDesktopScreenState._purple.withValues(alpha: 0.22),
                    blurRadius: 28,
                    spreadRadius: 0,
                    offset: const Offset(0, 12),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxHeight < 140;
                    final iconBox = compact ? 44.0 : 50.0;
                    final valueSize = compact ? 38.0 : 48.0;
                    final labelSize = compact ? 15.0 : 18.0;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: iconBox,
                          height: iconBox,
                          decoration: BoxDecoration(
                            color: _AdminClientsDesktopScreenState._purple
                                .withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _AdminClientsDesktopScreenState._purple
                                  .withValues(alpha: 0.28),
                            ),
                          ),
                          child: Icon(
                            widget.icon,
                            size: iconBox * 0.48,
                            color: _AdminClientsDesktopScreenState._purple2,
                          ),
                        ),
                        const Spacer(),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            widget.value,
                            maxLines: 1,
                            style: GoogleFonts.inter(
                              fontSize: valueSize,
                              fontWeight: FontWeight.w700,
                              height: 1.0,
                              color: _AdminClientsDesktopScreenState._textPrimary,
                              letterSpacing: -1.2,
                            ),
                          ),
                        ),
                        SizedBox(height: compact ? 4 : 6),
                        Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: labelSize,
                            fontWeight: FontWeight.w500,
                            color: _lavender.withValues(alpha: 0.75),
                            height: 1.15,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: 260 * 0.7,
                    height: 3,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: _AdminClientsDesktopScreenState._purple.withValues(
                            alpha: _hover ? 0.75 : 0.5,
                          ),
                          blurRadius: _hover ? 16 : 10,
                          spreadRadius: 1,
                        ),
                      ],
                      gradient: LinearGradient(
                        colors: [
                          _AdminClientsDesktopScreenState._purple.withValues(alpha: 0.0),
                          _AdminClientsDesktopScreenState._purple,
                          _AdminClientsDesktopScreenState._purple2,
                          _AdminClientsDesktopScreenState._purple.withValues(alpha: 0.0),
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
                  DropdownMenuItem(value: 'all', child: Text('All statuses')),
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

/// Full-screen scrim + premium client profile modal.
class _ClientDetailsOverlay extends StatelessWidget {
  const _ClientDetailsOverlay({
    required this.client,
    required this.therapistLabel,
    required this.fmtVisit,
  });

  final AdminClientRow client;
  final String therapistLabel;
  final String Function(DateTime? d) fmtVisit;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.black.withValues(alpha: 0.55)),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: _ClientDetailsDialog(
                client: client,
                therapistLabel: therapistLabel,
                fmtVisit: fmtVisit,
                onClose: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientDetailsDialog extends StatelessWidget {
  const _ClientDetailsDialog({
    required this.client,
    required this.therapistLabel,
    required this.fmtVisit,
    required this.onClose,
  });

  final AdminClientRow client;
  final String therapistLabel;
  final String Function(DateTime? d) fmtVisit;
  final VoidCallback onClose;

  static const Color _bg = Color(0xEB120A24);
  static const double _width = 440;

  @override
  Widget build(BuildContext context) {
    final hasVisit = client.zadnjaPosjeta != null;
    final lastVisitValue = hasVisit ? fmtVisit(client.zadnjaPosjeta) : 'No visits yet';
    final lastVisitMuted = !hasVisit;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: _AdminClientsDesktopScreenState._purple.withValues(alpha: 0.28),
                blurRadius: 40,
                spreadRadius: -6,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 32,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: SizedBox(
            width: _width,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(26, 22, 22, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ClientDetailsHeader(
                    client: client,
                    onClose: onClose,
                  ),
                  const SizedBox(height: 20),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  const SizedBox(height: 20),
                  _ClientInfoRow(
                    icon: Icons.verified_user_outlined,
                    label: 'Account',
                    valueWidget: Text(
                      client.isActive ? 'Active' : 'Inactive',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: client.isActive
                            ? const Color(0xFF22C55E)
                            : Colors.orange.shade300,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _ClientInfoRow(
                    icon: Icons.workspace_premium_rounded,
                    label: 'VIP Status',
                    valueWidget: client.isVip
                        ? _VipBadge()
                        : Text(
                            'Standard',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.55),
                            ),
                          ),
                  ),
                  const SizedBox(height: 18),
                  _ClientInfoRow(
                    icon: Icons.spa_outlined,
                    label: 'Therapist',
                    value: therapistLabel,
                  ),
                  const SizedBox(height: 18),
                  _ClientInfoRow(
                    icon: Icons.event_available_outlined,
                    label: 'Total Visits',
                    value: '${client.ukupnoPosjeta}',
                  ),
                  const SizedBox(height: 18),
                  _ClientInfoRow(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Spending',
                    value: '${client.ukupnoPotroseno.toStringAsFixed(0)} KM',
                  ),
                  const SizedBox(height: 18),
                  _ClientInfoRow(
                    icon: Icons.schedule_rounded,
                    label: 'Last Visit',
                    value: lastVisitValue,
                    valueMuted: lastVisitMuted,
                  ),
                  const SizedBox(height: 24),
                  _ClientDetailsCloseButton(onPressed: onClose),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _initials(String name) {
    final p = name.trim().split(RegExp(r'\s+'));
    if (p.isEmpty) return '?';
    String ch(String s) =>
        s.isEmpty ? '' : String.fromCharCode(s.runes.first).toUpperCase();
    if (p.length == 1) return ch(p.first);
    return '${ch(p.first)}${ch(p.last)}';
  }
}

class _ClientDetailsHeader extends StatelessWidget {
  const _ClientDetailsHeader({
    required this.client,
    required this.onClose,
  });

  final AdminClientRow client;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 72,
          height: 72,
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
                color: _AdminClientsDesktopScreenState._purple.withValues(alpha: 0.45),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            _ClientDetailsDialog._initials(client.punoIme),
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w800,
              fontSize: 22,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2, right: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    client.punoIme,
                    maxLines: 1,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 32,
                      height: 1.1,
                      color: _AdminClientsDesktopScreenState._textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _ContactChip(
                  icon: Icons.mail_outline_rounded,
                  text: client.email,
                ),
                const SizedBox(height: 6),
                _ContactChip(
                  icon: Icons.phone_outlined,
                  text: client.telefon.isEmpty ? '—' : client.telefon,
                ),
              ],
            ),
          ),
        ),
        _ClientDetailsIconClose(onPressed: onClose),
      ],
    );
  }
}

class _ContactChip extends StatelessWidget {
  const _ContactChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  static const Color _lavender = Color(0xFFC8B6E8);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 15,
          color: _lavender.withValues(alpha: 0.88),
          shadows: [
            Shadow(
              color: _AdminClientsDesktopScreenState._purple.withValues(alpha: 0.35),
              blurRadius: 8,
            ),
          ],
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.65),
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}

class _ClientDetailsIconClose extends StatefulWidget {
  const _ClientDetailsIconClose({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_ClientDetailsIconClose> createState() => _ClientDetailsIconCloseState();
}

class _ClientDetailsIconCloseState extends State<_ClientDetailsIconClose> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: _hover ? 0.1 : 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: _hover
              ? [
                  BoxShadow(
                    color: _AdminClientsDesktopScreenState._purple.withValues(alpha: 0.4),
                    blurRadius: 14,
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: widget.onPressed,
            child: Icon(
              Icons.close_rounded,
              size: 20,
              color: Colors.white.withValues(alpha: _hover ? 0.95 : 0.7),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClientInfoRow extends StatelessWidget {
  const _ClientInfoRow({
    required this.icon,
    required this.label,
    this.value,
    this.valueWidget,
    this.valueMuted = false,
  }) : assert(value != null || valueWidget != null);

  final IconData icon;
  final String label;
  final String? value;
  final Widget? valueWidget;
  final bool valueMuted;

  static const Color _lavender = Color(0xFFC8B6E8);

  @override
  Widget build(BuildContext context) {
    final valueChild = valueWidget ??
        Text(
          value!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueMuted
                ? _lavender.withValues(alpha: 0.75)
                : _AdminClientsDesktopScreenState._textPrimary,
          ),
        );

    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: _lavender.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ),
          Flexible(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: valueChild,
            ),
          ),
        ],
      ),
    );
  }
}

class _VipBadge extends StatelessWidget {
  static const Color _vipGreen = Color(0xFF22C55E);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _vipGreen.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _vipGreen.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: _vipGreen.withValues(alpha: 0.25),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.workspace_premium_rounded,
            size: 13,
            color: _vipGreen.withValues(alpha: 0.95),
          ),
          const SizedBox(width: 5),
          Text(
            'VIP',
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: _vipGreen,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen scrim + premium edit client modal (matches view client styling).
class _ClientEditOverlay extends StatelessWidget {
  const _ClientEditOverlay({
    required this.client,
    required this.therapists,
    required this.api,
    required this.therapistName,
    required this.onSaved,
    required this.formatError,
  });

  final AdminClientRow client;
  final List<Zaposlenik> therapists;
  final ApiService api;
  final String Function(Zaposlenik z) therapistName;
  final VoidCallback onSaved;
  final String Function(Object) formatError;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.black.withValues(alpha: 0.55)),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: GestureDetector(
                onTap: () {},
                child: _ClientEditDialog(
                  client: client,
                  therapists: therapists,
                  api: api,
                  therapistName: therapistName,
                  onClose: () => Navigator.of(context).pop(),
                  onSaved: onSaved,
                  formatError: formatError,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientEditDialog extends StatefulWidget {
  const _ClientEditDialog({
    required this.client,
    required this.therapists,
    required this.api,
    required this.therapistName,
    required this.onClose,
    required this.onSaved,
    required this.formatError,
  });

  final AdminClientRow client;
  final List<Zaposlenik> therapists;
  final ApiService api;
  final String Function(Zaposlenik z) therapistName;
  final VoidCallback onClose;
  final VoidCallback onSaved;
  final String Function(Object) formatError;

  @override
  State<_ClientEditDialog> createState() => _ClientEditDialogState();
}

class _ClientEditDialogState extends State<_ClientEditDialog> {
  static const Color _bg = Color(0xEB120A24);
  static const double _width = 440;

  late final TextEditingController _imeC;
  late final TextEditingController _prezC;
  late final TextEditingController _emailC;
  late final TextEditingController _telC;
  late int? _zId;
  late bool _vip;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _imeC = TextEditingController(text: widget.client.ime);
    _prezC = TextEditingController(text: widget.client.prezime);
    _emailC = TextEditingController(text: widget.client.email);
    _telC = TextEditingController(text: widget.client.telefon);
    _zId = widget.client.preferiraniZaposlenikId;
    _vip = widget.client.isVipKlijent;
    for (final c in [_imeC, _prezC]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _imeC.dispose();
    _prezC.dispose();
    _emailC.dispose();
    _telC.dispose();
    super.dispose();
  }

  String get _displayName {
    final n = '${_imeC.text.trim()} ${_prezC.text.trim()}'.trim();
    return n.isEmpty ? widget.client.punoIme : n;
  }

  Future<void> _save() async {
    final ime = _imeC.text.trim();
    final prez = _prezC.text.trim();
    final email = _emailC.text.trim();
    if (ime.isEmpty || prez.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('First name, last name and email are required.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.api.patchAdminClient(
        id: widget.client.id,
        ime: ime,
        prezime: prez,
        email: email,
        telefon: _telC.text.trim(),
        isVipKlijent: _vip,
        setZaposlenik: true,
        zaposlenikId: _zId,
      );
      if (!mounted) return;
      widget.onClose();
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.formatError(e))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fieldStyle = GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: _AdminClientsDesktopScreenState._textPrimary,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: _AdminClientsDesktopScreenState._purple.withValues(alpha: 0.28),
                blurRadius: 40,
                spreadRadius: -6,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 32,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: SizedBox(
            width: _width,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(26, 22, 22, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  const SizedBox(height: 20),
                  if (!widget.client.isActive) ...[
                    _inactiveBanner(),
                    const SizedBox(height: 18),
                  ],
                  _ClientEditFieldRow(
                    icon: Icons.badge_outlined,
                    label: 'First name',
                    child: TextField(
                      controller: _imeC,
                      style: fieldStyle,
                      decoration: _fieldDecoration('Enter first name'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ClientEditFieldRow(
                    icon: Icons.badge_outlined,
                    label: 'Last name',
                    child: TextField(
                      controller: _prezC,
                      style: fieldStyle,
                      decoration: _fieldDecoration('Enter last name'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ClientEditFieldRow(
                    icon: Icons.mail_outline_rounded,
                    label: 'Email',
                    child: TextField(
                      controller: _emailC,
                      style: fieldStyle,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _fieldDecoration('client@email.com'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ClientEditFieldRow(
                    icon: Icons.phone_outlined,
                    label: 'Phone',
                    child: TextField(
                      controller: _telC,
                      style: fieldStyle,
                      keyboardType: TextInputType.phone,
                      decoration: _fieldDecoration('Optional'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ClientEditFieldRow(
                    icon: Icons.spa_outlined,
                    label: 'Therapist',
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        canvasColor: NuaLuxuryTokens.voidViolet,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int?>(
                          isExpanded: true,
                          value: _zId,
                          hint: Text(
                            'None',
                            style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 14,
                            ),
                          ),
                          dropdownColor: NuaLuxuryTokens.voidViolet,
                          icon: Icon(
                            Icons.expand_more_rounded,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                          style: fieldStyle,
                          items: [
                            DropdownMenuItem<int?>(
                              value: null,
                              child: Text(
                                'None',
                                style: GoogleFonts.inter(fontSize: 14),
                              ),
                            ),
                            ...widget.therapists.map(
                              (z) => DropdownMenuItem<int?>(
                                value: z.id,
                                child: Text(
                                  widget.therapistName(z),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: _saving
                              ? null
                              : (v) => setState(() => _zId = v),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ClientEditToggleRow(
                    icon: Icons.workspace_premium_rounded,
                    label: 'VIP client',
                    value: _vip,
                    onChanged: _saving ? null : (v) => setState(() => _vip = v),
                  ),
                  const SizedBox(height: 24),
                  Opacity(
                    opacity: _saving ? 0.65 : 1,
                    child: _ClientDetailsCloseButton(
                      onPressed: _saving ? () {} : _save,
                      label: _saving ? 'Saving…' : 'Save changes',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Opacity(
                    opacity: _saving ? 0.45 : 1,
                    child: _ClientEditCancelButton(
                      onPressed: _saving ? () {} : widget.onClose,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 72,
          height: 72,
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
                color: _AdminClientsDesktopScreenState._purple.withValues(alpha: 0.45),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            _ClientDetailsDialog._initials(_displayName),
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w800,
              fontSize: 22,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4, right: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit client',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 26,
                    height: 1.1,
                    color: _AdminClientsDesktopScreenState._textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Update profile and preferences',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.55),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                _ContactChip(
                  icon: Icons.edit_outlined,
                  text: _displayName,
                ),
              ],
            ),
          ),
        ),
        _ClientDetailsIconClose(onPressed: widget.onClose),
      ],
    );
  }

  Widget _inactiveBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: Colors.orange.shade200),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Account is deactivated. Saving does not reactivate it.',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: Colors.orange.shade100,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static InputDecoration _fieldDecoration(String hint) => InputDecoration(
        isDense: true,
        border: InputBorder.none,
        hintText: hint,
        hintStyle: GoogleFonts.inter(
          color: Colors.white.withValues(alpha: 0.32),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 2),
      );
}

class _ClientEditFieldRow extends StatelessWidget {
  const _ClientEditFieldRow({
    required this.icon,
    required this.label,
    required this.child,
  });

  final IconData icon;
  final String label;
  final Widget child;

  static const Color _lavender = Color(0xFFC8B6E8);

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: _lavender.withValues(alpha: 0.7)),
          const SizedBox(width: 12),
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _ClientEditToggleRow extends StatelessWidget {
  const _ClientEditToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  static const Color _lavender = Color(0xFFC8B6E8);
  static const Color _vipGreen = Color(0xFF22C55E);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _lavender.withValues(alpha: 0.7)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ),
          if (value) _VipBadge(),
          const SizedBox(width: 10),
          Switch(
            value: value,
            onChanged: onChanged == null
                ? null
                : (v) => onChanged!(v),
            activeThumbColor: Colors.white,
            activeTrackColor: _vipGreen.withValues(alpha: 0.55),
            inactiveThumbColor: Colors.white.withValues(alpha: 0.85),
            inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
          ),
        ],
      ),
    );
  }
}

class _ClientEditCancelButton extends StatefulWidget {
  const _ClientEditCancelButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_ClientEditCancelButton> createState() => _ClientEditCancelButtonState();
}

class _ClientEditCancelButtonState extends State<_ClientEditCancelButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: _hover ? 0.08 : 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: _hover ? 0.14 : 0.08),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: widget.onPressed,
            child: Center(
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: _hover ? 0.88 : 0.62),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClientDetailsCloseButton extends StatefulWidget {
  const _ClientDetailsCloseButton({
    required this.onPressed,
    this.label = 'Close',
  });

  final VoidCallback onPressed;
  final String label;

  @override
  State<_ClientDetailsCloseButton> createState() =>
      _ClientDetailsCloseButtonState();
}

class _ClientDetailsCloseButtonState extends State<_ClientDetailsCloseButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        height: 54,
        transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [
              _AdminClientsDesktopScreenState._purple,
              _AdminClientsDesktopScreenState._purple2,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: _AdminClientsDesktopScreenState._purple
                  .withValues(alpha: _hover ? 0.55 : 0.38),
              blurRadius: _hover ? 24 : 16,
              offset: Offset(0, _hover ? 10 : 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: widget.onPressed,
            child: Center(
              child: Text(
                widget.label,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
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

    return Opacity(
      opacity: c.isActive ? 1.0 : 0.58,
      child: Padding(
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
              if (!c.isActive) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    'Inactive',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.orange.shade200,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
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
