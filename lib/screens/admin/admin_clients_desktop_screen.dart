import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/api_error_messages.dart';
import '../../core/api/services/api_service.dart';
import '../../core/validation/nua_validators.dart';
import '../../widgets/forms/luxury_validated_field.dart';
import '../../models/admin/admin_client_row.dart';
import '../../models/admin/admin_client_stats.dart';
import '../../models/rezervacija_povijest_item.dart';
import '../../models/grad_lookup.dart';
import '../../models/zaposlenik.dart';
import '../../ui/navigation/desktop_nav.dart';
import '../../ui/theme/nua_luxury_tokens.dart';
import 'package:provider/provider.dart';

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
  Timer? _searchDebounce;

  Future<
      ({
        List<AdminClientRow> clients,
        AdminClientStats? stats,
        String? error,
        int? serverTotal,
        bool hitPageCap,
      })>? _payloadFuture;
  Future<List<Zaposlenik>>? _therapistsFuture;

  String _statusFilter = 'all'; // all | active | inactive
  String _vipFilter = 'all'; // all | vip | manual | none
  int? _therapistFilterIndex; // null = all; else index into therapists
  String _sortKey = 'new'; // new | old | visit | name
  int _page = 0;
  int _pageSize = 10;
  int _handledClientAddRequest = 0;
  String? _lastNavSearch;

  @override
  void initState() {
    super.initState();
    _therapistsFuture = widget.api.getZaposlenici();
    _scheduleReload(immediate: true);
    _apiSearch.addListener(_onApiSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final q = Provider.of<DesktopNav>(
        context,
        listen: false,
      ).takePendingClientSearch();
      if (q != null && q.isNotEmpty) {
        _apiSearch.text = q;
        _scheduleReload(immediate: true);
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _apiSearch.removeListener(_onApiSearchChanged);
    _apiSearch.dispose();
    super.dispose();
  }

  void _syncHeaderSearch(String query) {
    if (_apiSearch.text == query) return;
    _apiSearch.text = query;
    _scheduleReload(immediate: true);
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
        try {
          final loaded = await widget.api.getAdminClientsAllWithTotal(
            q: q.isEmpty ? null : q,
          );
          final stats = await widget.api.getAdminClientStats(
            q: q.isEmpty ? null : q,
          );
          return (
            clients: loaded.clients,
            stats: stats,
            error: null,
            serverTotal: loaded.serverTotal,
            hitPageCap: loaded.clients.length >= 5000,
          );
        } catch (e) {
          return (
            clients: <AdminClientRow>[],
            stats: null,
            error: _apiErr(e),
            serverTotal: null,
            hitPageCap: false,
          );
        }
      }();
      _page = 0;
    });
  }

  bool get _useServerStats =>
      _statusFilter == 'all' &&
      _vipFilter == 'all' &&
      _therapistFilterIndex == null;

  String _therapistDisplay(AdminClientRow c) {
    final api = c.terapeutPunoIme;
    if (api != null && api.isNotEmpty) return api;
    return '—';
  }

  int? _therapistIdForRow(AdminClientRow c) => c.terapeutZaposlenikId;

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

  String _apiErr(Object e) => ApiErrorMessages.fromObject(
        e,
        fallback: ApiService.adminClientPatchErrorMessage(e),
      );

  List<AdminClientRow> _applyLocalFilters(
    List<AdminClientRow> raw,
    List<Zaposlenik> therapists,
  ) {
    var xs = List<AdminClientRow>.from(raw);

    if (_statusFilter == 'active') {
      xs = xs.where((c) => c.isActive).toList();
    } else if (_statusFilter == 'inactive') {
      xs = xs.where((c) => !c.isActive).toList();
    }

    if (_vipFilter == 'vip') {
      xs = xs.where((c) => c.isVip).toList();
    } else if (_vipFilter == 'manual') {
      xs = xs.where((c) => c.isVipKlijent).toList();
    } else if (_vipFilter == 'none') {
      xs = xs.where((c) => !c.isVip).toList();
    }

    if (_therapistFilterIndex != null &&
        therapists.isNotEmpty &&
        _therapistFilterIndex! < therapists.length) {
      final z = therapists[_therapistFilterIndex!];
      xs = xs.where((c) => _therapistIdForRow(c) == z.id).toList();
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

  void _openClientSheet(AdminClientRow c) {
    final tName = _therapistDisplay(c);
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, _, _) => _ClientDetailsOverlay(
        client: c,
        api: widget.api,
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
    final gradovi = await widget.api.getGradovi();
    if (!mounted) return;
    if (gradovi.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No cities found. Add a city before creating a client.'),
        ),
      );
      return;
    }

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, _, _) => _ClientCreateOverlay(
        therapists: therapists,
        gradovi: gradovi,
        api: widget.api,
        therapistName: _therapistName,
        onCreated: () {
          _reloadFromApi();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Client created successfully.')),
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

  Future<void> _showEditClientDialog(
    AdminClientRow row,
    List<Zaposlenik> therapists,
  ) async {
    final gradovi = await widget.api.getGradovi();
    if (!mounted) return;
    if (gradovi.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No cities found. Add a city before editing a client.',
          ),
        ),
      );
      return;
    }

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, _, _) => _ClientEditOverlay(
        client: row,
        therapists: therapists,
        gradovi: gradovi,
        api: widget.api,
        therapistName: _therapistName,
        onSaved: () {
          _reloadFromApi();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Client updated successfully.'),
              ),
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
    final nav = context.watch<DesktopNav>();
    if (_lastNavSearch != nav.clientSearchQuery) {
      _lastNavSearch = nav.clientSearchQuery;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _syncHeaderSearch(nav.clientSearchQuery);
      });
    }

    if (nav.clientAddRequest != _handledClientAddRequest) {
      _handledClientAddRequest = nav.clientAddRequest;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final therapists =
            await (_therapistsFuture ?? widget.api.getZaposlenici());
        if (!mounted) return;
        await _showCreateClientDialog(therapists);
      });
    }

    return FutureBuilder<List<Zaposlenik>>(
      future: _therapistsFuture,
      builder: (context, thSnap) {
        final therapists = thSnap.data ?? const <Zaposlenik>[];

        return FutureBuilder<
            ({
              List<AdminClientRow> clients,
              AdminClientStats? stats,
              String? error,
              int? serverTotal,
              bool hitPageCap,
            })>(
          future: _payloadFuture,
          builder: (context, snap) {
            final loading = snap.connectionState == ConnectionState.waiting;
            final payload = snap.data;
            final loadError = payload?.error;
            final raw = payload?.clients ?? const <AdminClientRow>[];
            final serverStats = payload?.stats;
            final serverTotal = payload?.serverTotal;
            final hitPageCap = payload?.hitPageCap ?? false;
            final truncated = serverTotal != null && raw.length < serverTotal;
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
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (loadError != null)
                      _ClientsLoadBanner(
                        message: loadError,
                        isError: true,
                        onRetry: _reloadFromApi,
                      ),
                    if (loadError == null && (truncated || hitPageCap))
                      _ClientsLoadBanner(
                        message: hitPageCap
                            ? 'Showing first 5,000 clients. Narrow your search to see more.'
                            : 'Loaded ${raw.length} of $serverTotal clients. Retry to refresh.',
                        isError: false,
                        onRetry: _reloadFromApi,
                      ),
                    if (loadError == null && !_useServerStats)
                      _ClientsLoadBanner(
                        message:
                            'Metrics reflect your current filters ($totalFiltered shown).',
                        isError: false,
                      ),
                    _ClientsMetricsStrip(
                      totalClients: totalClientsKpi,
                      vipCount: vipN,
                      visitsSum: visitsSum,
                      spendSum: spendSum,
                      loading: loading,
                      fmtInt: _fmtInt,
                    ),
                    const SizedBox(height: 14),
                    _ClientsToolbar(
                      statusFilter: _statusFilter,
                      onStatus: (v) => setState(() {
                        _statusFilter = v;
                        _page = 0;
                      }),
                      vipFilter: _vipFilter,
                      onVip: (v) => setState(() {
                        _vipFilter = v;
                        _page = 0;
                      }),
                      sortKey: _sortKey,
                      onSort: (s) => setState(() {
                        _sortKey = s;
                        _page = 0;
                      }),
                      onAdd: () => _showCreateClientDialog(therapists),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: _ClientsTableCard(
                        loading: loading,
                        hasError: loadError != null,
                        rows: pageSlice,
                        fmtVisit: _fmtVisit,
                        fmtClientSince: _fmtClientSince,
                        onRetry: _reloadFromApi,
                        onView: (row) => _openClientSheet(row),
                        onMore: (row) => _onClientMore(row, therapists),
                      ),
                    ),
                    const SizedBox(height: 12),
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
              },
            );
          },
        );
      },
    );
  }

  String _fmtClientSince(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final loc = d.toLocal();
    return 'Client since ${months[loc.month - 1]} ${loc.year}';
  }
}

// ——— UI blocks ———

class _ClientsLoadBanner extends StatelessWidget {
  const _ClientsLoadBanner({
    required this.message,
    required this.isError,
    this.onRetry,
  });

  final String message;
  final bool isError;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: isError
            ? Colors.red.withValues(alpha: 0.12)
            : Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.info_outline,
                size: 20,
                color: isError ? Colors.red.shade300 : Colors.amber.shade200,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.88),
                  ),
                ),
              ),
              if (onRetry != null)
                TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}

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

/// Compact horizontal metrics strip for the Clients list view.
class _ClientsMetricsStrip extends StatelessWidget {
  const _ClientsMetricsStrip({
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

  @override
  Widget build(BuildContext context) {
    final tiles = [
      ('Total Clients', loading ? '…' : fmtInt(totalClients)),
      ('VIP Clients', loading ? '…' : fmtInt(vipCount)),
      ('Total Visits', loading ? '…' : fmtInt(visitsSum)),
      ('Total Revenue', loading ? '…' : '${fmtInt(spendSum.round())} KM'),
    ];

    return SizedBox(
      height: 76,
      child: Row(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(
              child: _ClientsMetricTile(
                label: tiles[i].$1,
                value: tiles[i].$2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ClientsMetricTile extends StatelessWidget {
  const _ClientsMetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.48),
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.0,
              letterSpacing: -0.6,
              color: _AdminClientsDesktopScreenState._textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientsToolbar extends StatelessWidget {
  const _ClientsToolbar({
    required this.statusFilter,
    required this.onStatus,
    required this.vipFilter,
    required this.onVip,
    required this.sortKey,
    required this.onSort,
    required this.onAdd,
  });

  final String statusFilter;
  final ValueChanged<String> onStatus;
  final String vipFilter;
  final ValueChanged<String> onVip;
  final String sortKey;
  final ValueChanged<String> onSort;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _ToolbarDropdown<String>(
                width: 148,
                value: statusFilter,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All status')),
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                ],
                onChanged: (v) {
                  if (v != null) onStatus(v);
                },
              ),
              _ToolbarDropdown<String>(
                width: 148,
                value: vipFilter,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All VIP')),
                  DropdownMenuItem(value: 'vip', child: Text('VIP clients')),
                  DropdownMenuItem(value: 'manual', child: Text('Manual VIP')),
                  DropdownMenuItem(value: 'none', child: Text('Non-VIP')),
                ],
                onChanged: (v) {
                  if (v != null) onVip(v);
                },
              ),
              _ToolbarDropdown<String>(
                width: 180,
                value: sortKey,
                items: const [
                  DropdownMenuItem(value: 'new', child: Text('Newest first')),
                  DropdownMenuItem(value: 'old', child: Text('Oldest first')),
                  DropdownMenuItem(value: 'visit', child: Text('Last visit')),
                  DropdownMenuItem(value: 'name', child: Text('Name A–Z')),
                ],
                onChanged: (v) {
                  if (v != null) onSort(v);
                },
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 40,
          child: FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add client'),
            style: FilledButton.styleFrom(
              backgroundColor: _AdminClientsDesktopScreenState._purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ToolbarDropdown<T> extends StatelessWidget {
  const _ToolbarDropdown({
    required this.width,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final double width;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 40,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              isExpanded: true,
              value: value,
              items: items,
              onChanged: onChanged,
              dropdownColor: NuaLuxuryTokens.voidViolet,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _AdminClientsDesktopScreenState._textPrimary,
              ),
              icon: Icon(
                Icons.expand_more_rounded,
                size: 20,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-screen scrim + premium client profile modal.
class _ClientDetailsOverlay extends StatelessWidget {
  const _ClientDetailsOverlay({
    required this.client,
    required this.api,
    required this.therapistLabel,
    required this.fmtVisit,
  });

  final AdminClientRow client;
  final ApiService api;
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
                api: api,
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
    required this.api,
    required this.therapistLabel,
    required this.fmtVisit,
    required this.onClose,
  });

  final AdminClientRow client;
  final ApiService api;
  final String therapistLabel;
  final String Function(DateTime? d) fmtVisit;
  final VoidCallback onClose;

  static const Color _bg = Color(0xEB120A24);
  static const double _width = 480;

  String _vipDetailLabel() {
    final earned = client.isVipFromActivity;
    if (client.isVipKlijent && earned) {
      return 'Manual + earned (10+ visits or 600+ KM)';
    }
    if (client.isVipKlijent) return 'Manual VIP';
    if (client.isVip && earned) return 'Earned (10+ visits or 600+ KM spent)';
    if (client.isVip) return 'VIP';
    return 'Standard';
  }

  @override
  Widget build(BuildContext context) {
    final hasVisit = client.zadnjaPosjeta != null;
    final lastVisitValue = hasVisit ? fmtVisit(client.zadnjaPosjeta) : 'No visits yet';
    final lastVisitMuted = !hasVisit;
    final note = client.napomenaZaTerapeuta?.trim();
    final city = client.gradNaziv?.trim();

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
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.82,
              ),
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
                    const SizedBox(height: 16),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
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
                            const SizedBox(height: 16),
                            _ClientInfoRow(
                              icon: Icons.workspace_premium_rounded,
                              label: 'VIP Status',
                              valueWidget: client.isVip
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _VipBadge(),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            _vipDetailLabel(),
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: Colors.white.withValues(
                                                alpha: 0.65,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Text(
                                      'Standard',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.withValues(
                                          alpha: 0.55,
                                        ),
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 16),
                            _ClientInfoRow(
                              icon: Icons.person_outline_rounded,
                              label: 'Username',
                              value: client.userName.trim().isNotEmpty
                                  ? client.userName.trim()
                                  : '—',
                            ),
                            const SizedBox(height: 16),
                            _ClientInfoRow(
                              icon: Icons.location_city_outlined,
                              label: 'City',
                              value: city != null && city.isNotEmpty
                                  ? city
                                  : '—',
                            ),
                            const SizedBox(height: 16),
                            _ClientInfoRow(
                              icon: Icons.calendar_month_outlined,
                              label: 'Registered',
                              value: fmtVisit(client.datumRegistracije),
                            ),
                            const SizedBox(height: 16),
                            _ClientInfoRow(
                              icon: Icons.spa_outlined,
                              label: 'Preferred therapist',
                              value: therapistLabel,
                            ),
                            const SizedBox(height: 16),
                            _ClientInfoRow(
                              icon: Icons.event_available_outlined,
                              label: 'Total Visits',
                              value: '${client.ukupnoPosjeta}',
                            ),
                            const SizedBox(height: 16),
                            _ClientInfoRow(
                              icon: Icons.account_balance_wallet_outlined,
                              label: 'Spending',
                              value:
                                  '${client.ukupnoPotroseno.toStringAsFixed(0)} KM',
                            ),
                            const SizedBox(height: 16),
                            _ClientInfoRow(
                              icon: Icons.schedule_rounded,
                              label: 'Last Visit',
                              value: lastVisitValue,
                              valueMuted: lastVisitMuted,
                            ),
                            const SizedBox(height: 16),
                            _ClientInfoRow(
                              icon: Icons.notes_outlined,
                              label: 'Notes',
                              value: note != null && note.isNotEmpty
                                  ? note
                                  : 'No notes on file.',
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Recent appointments',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: _AdminClientsDesktopScreenState._textPrimary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            FutureBuilder<List<RezervacijaPovijestItem>>(
                              future: api.getRezervacijaPovijestZaKlijenta(
                                korisnikId: client.id,
                                take: 8,
                              ),
                              builder: (context, histSnap) {
                                if (histSnap.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Center(
                                      child: SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                if (histSnap.hasError) {
                                  return Text(
                                    'Could not load history.',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: Colors.white.withValues(
                                        alpha: 0.55,
                                      ),
                                    ),
                                  );
                                }
                                final history =
                                    histSnap.data ?? const [];
                                if (history.isEmpty) {
                                  return Text(
                                    'No past appointments.',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: Colors.white.withValues(
                                        alpha: 0.55,
                                      ),
                                    ),
                                  );
                                }
                                return Column(
                                  children: [
                                    for (final h in history)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                h.uslugaNaziv ?? 'Service',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.inter(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              fmtVisit(h.datumRezervacije),
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                color: Colors.white.withValues(
                                                  alpha: 0.5,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ClientDetailsCloseButton(onPressed: onClose),
                  ],
                ),
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

/// Full-screen scrim + premium create client modal (matches edit client styling).
class _ClientCreateOverlay extends StatelessWidget {
  const _ClientCreateOverlay({
    required this.therapists,
    required this.gradovi,
    required this.api,
    required this.therapistName,
    required this.onCreated,
    required this.formatError,
  });

  final List<Zaposlenik> therapists;
  final List<GradLookup> gradovi;
  final ApiService api;
  final String Function(Zaposlenik z) therapistName;
  final VoidCallback onCreated;
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
                child: _ClientCreateDialog(
                  therapists: therapists,
                  gradovi: gradovi,
                  api: api,
                  therapistName: therapistName,
                  onClose: () => Navigator.of(context).pop(),
                  onCreated: onCreated,
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

class _ClientCreateDialog extends StatefulWidget {
  const _ClientCreateDialog({
    required this.therapists,
    required this.gradovi,
    required this.api,
    required this.therapistName,
    required this.onClose,
    required this.onCreated,
    required this.formatError,
  });

  final List<Zaposlenik> therapists;
  final List<GradLookup> gradovi;
  final ApiService api;
  final String Function(Zaposlenik z) therapistName;
  final VoidCallback onClose;
  final VoidCallback onCreated;
  final String Function(Object) formatError;

  @override
  State<_ClientCreateDialog> createState() => _ClientCreateDialogState();
}

class _ClientCreateDialogState extends State<_ClientCreateDialog> {
  static const Color _bg = Color(0xEB120A24);
  static const double _width = 480;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameC;
  late final TextEditingController _lastNameC;
  late final TextEditingController _emailC;
  late final TextEditingController _usernameC;
  late final TextEditingController _passwordC;
  late final TextEditingController _confirmPasswordC;
  late final TextEditingController _phoneC;
  late final TextEditingController _noteC;
  late int _gradId;
  int? _therapistId;
  bool _vip = false;
  bool _saving = false;
  bool _attemptedSubmit = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _firstNameC = TextEditingController();
    _lastNameC = TextEditingController();
    _emailC = TextEditingController();
    _usernameC = TextEditingController();
    _passwordC = TextEditingController();
    _confirmPasswordC = TextEditingController();
    _phoneC = TextEditingController();
    _noteC = TextEditingController();
    _gradId = widget.gradovi.first.id;
    for (final c in [_firstNameC, _lastNameC]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _firstNameC.dispose();
    _lastNameC.dispose();
    _emailC.dispose();
    _usernameC.dispose();
    _passwordC.dispose();
    _confirmPasswordC.dispose();
    _phoneC.dispose();
    _noteC.dispose();
    super.dispose();
  }

  String get _displayName {
    final n = '${_firstNameC.text.trim()} ${_lastNameC.text.trim()}'.trim();
    return n.isEmpty ? 'New client' : n;
  }

  Future<void> _save() async {
    setState(() => _attemptedSubmit = true);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await widget.api.createAdminClient(
        ime: _firstNameC.text.trim(),
        prezime: _lastNameC.text.trim(),
        email: _emailC.text.trim(),
        userName: _usernameC.text.trim(),
        password: _passwordC.text,
        gradId: _gradId,
        telefon: _phoneC.text.trim().isEmpty ? null : _phoneC.text.trim(),
        zaposlenikId: _therapistId,
        isVipKlijent: _vip,
        napomenaZaTerapeuta: _noteC.text.trim().isEmpty
            ? null
            : _noteC.text.trim(),
      );
      if (!mounted) return;
      widget.onClose();
      widget.onCreated();
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
    final maxH = MediaQuery.sizeOf(context).height * 0.88;

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
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxH),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(26, 22, 22, 24),
                child: Form(
                  key: _formKey,
                  autovalidateMode: _attemptedSubmit
                      ? AutovalidateMode.onUserInteraction
                      : AutovalidateMode.disabled,
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
                      const SizedBox(height: 16),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              LuxuryValidatedField(
                                icon: Icons.badge_outlined,
                                label: 'First name',
                                controller: _firstNameC,
                                hint: 'Enter first name',
                                enabled: !_saving,
                                validator: (v) => NuaValidators.requiredText(
                                  v,
                                  fieldLabel: 'First name',
                                ),
                              ),
                              const SizedBox(height: 14),
                              LuxuryValidatedField(
                                icon: Icons.badge_outlined,
                                label: 'Last name',
                                controller: _lastNameC,
                                hint: 'Enter last name',
                                enabled: !_saving,
                                validator: (v) => NuaValidators.requiredText(
                                  v,
                                  fieldLabel: 'Last name',
                                ),
                              ),
                              const SizedBox(height: 14),
                              LuxuryValidatedField(
                                icon: Icons.mail_outline_rounded,
                                label: 'Email',
                                controller: _emailC,
                                hint: 'client@email.com',
                                keyboardType: TextInputType.emailAddress,
                                enabled: !_saving,
                                validator: NuaValidators.email,
                              ),
                              const SizedBox(height: 14),
                              LuxuryValidatedField(
                                icon: Icons.phone_outlined,
                                label: 'Phone',
                                controller: _phoneC,
                                hint: 'Optional',
                                keyboardType: TextInputType.phone,
                                enabled: !_saving,
                                validator: NuaValidators.phoneOptional,
                              ),
                              const SizedBox(height: 14),
                              _ClientEditFieldRow(
                                icon: Icons.location_city_outlined,
                                label: 'City',
                                child: Theme(
                                  data: Theme.of(context).copyWith(
                                    canvasColor: NuaLuxuryTokens.voidViolet,
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                      isExpanded: true,
                                      value: widget.gradovi.any(
                                        (g) => g.id == _gradId,
                                      )
                                          ? _gradId
                                          : widget.gradovi.first.id,
                                      dropdownColor: NuaLuxuryTokens.voidViolet,
                                      icon: Icon(
                                        Icons.expand_more_rounded,
                                        color: Colors.white.withValues(alpha: 0.5),
                                      ),
                                      style: fieldStyle,
                                      items: [
                                        for (final g in widget.gradovi)
                                          DropdownMenuItem<int>(
                                            value: g.id,
                                            child: Text(
                                              g.label,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                      ],
                                      onChanged: _saving
                                          ? null
                                          : (v) {
                                              if (v != null) {
                                                setState(() => _gradId = v);
                                              }
                                            },
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              LuxuryValidatedField(
                                icon: Icons.person_outline_rounded,
                                label: 'Username',
                                controller: _usernameC,
                                hint: 'Login username',
                                enabled: !_saving,
                                validator: NuaValidators.userName,
                              ),
                              const SizedBox(height: 14),
                              LuxuryValidatedField(
                                icon: Icons.vpn_key_outlined,
                                label: 'Password',
                                controller: _passwordC,
                                hint: 'Create password',
                                obscureText: _obscurePassword,
                                enabled: !_saving,
                                validator: NuaValidators.password,
                                suffix: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: Colors.white54,
                                    size: 20,
                                  ),
                                  onPressed: _saving
                                      ? null
                                      : () => setState(
                                            () => _obscurePassword =
                                                !_obscurePassword,
                                          ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              LuxuryValidatedField(
                                icon: Icons.vpn_key_outlined,
                                label: 'Confirm password',
                                controller: _confirmPasswordC,
                                hint: 'Re-enter password',
                                obscureText: _obscureConfirm,
                                enabled: !_saving,
                                validator: (v) => NuaValidators.confirmPassword(
                                  v,
                                  _passwordC.text,
                                ),
                                suffix: IconButton(
                                  icon: Icon(
                                    _obscureConfirm
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: Colors.white54,
                                    size: 20,
                                  ),
                                  onPressed: _saving
                                      ? null
                                      : () => setState(
                                            () => _obscureConfirm =
                                                !_obscureConfirm,
                                          ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              _ClientEditFieldRow(
                                icon: Icons.spa_outlined,
                                label: 'Preferred therapist',
                                child: Theme(
                                  data: Theme.of(context).copyWith(
                                    canvasColor: NuaLuxuryTokens.voidViolet,
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int?>(
                                      isExpanded: true,
                                      value: _therapistId,
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
                                          : (v) => setState(() => _therapistId = v),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Notes for therapist',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withValues(alpha: 0.55),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _noteC,
                                enabled: !_saving,
                                maxLines: 3,
                                maxLength: 1200,
                                style: fieldStyle,
                                decoration: InputDecoration(
                                  hintText: 'Preferences, allergies, etc. (optional)',
                                  hintStyle: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.35),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withValues(alpha: 0.04),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: Colors.white.withValues(alpha: 0.1),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: Colors.white.withValues(alpha: 0.1),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              _ClientEditToggleRow(
                                icon: Icons.workspace_premium_rounded,
                                label: 'Manual VIP',
                                value: _vip,
                                onChanged: _saving
                                    ? null
                                    : (v) => setState(() => _vip = v),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Opacity(
                        opacity: _saving ? 0.65 : 1,
                        child: _ClientDetailsCloseButton(
                          onPressed: _saving ? () {} : _save,
                          label: _saving ? 'Creating…' : 'Create client',
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
                  'Add client',
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
                  'Create a new client account',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.55),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                _ContactChip(
                  icon: Icons.person_add_outlined,
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
}

/// Full-screen scrim + premium edit client modal (matches view client styling).
class _ClientEditOverlay extends StatelessWidget {
  const _ClientEditOverlay({
    required this.client,
    required this.therapists,
    required this.gradovi,
    required this.api,
    required this.therapistName,
    required this.onSaved,
    required this.formatError,
  });

  final AdminClientRow client;
  final List<Zaposlenik> therapists;
  final List<GradLookup> gradovi;
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
                  gradovi: gradovi,
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
    required this.gradovi,
    required this.api,
    required this.therapistName,
    required this.onClose,
    required this.onSaved,
    required this.formatError,
  });

  final AdminClientRow client;
  final List<Zaposlenik> therapists;
  final List<GradLookup> gradovi;
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
  static const double _width = 480;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _imeC;
  late final TextEditingController _prezC;
  late final TextEditingController _emailC;
  late final TextEditingController _telC;
  late final TextEditingController _newPassC;
  late final TextEditingController _confirmPassC;
  late final TextEditingController _noteC;
  late int? _zId;
  late int _gradId;
  late bool _vip;
  bool _saving = false;
  bool _changePassword = false;
  bool _attemptedSubmit = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _imeC = TextEditingController(text: widget.client.ime);
    _prezC = TextEditingController(text: widget.client.prezime);
    _emailC = TextEditingController(text: widget.client.email);
    _telC = TextEditingController(text: widget.client.telefon);
    _newPassC = TextEditingController();
    _confirmPassC = TextEditingController();
    _noteC = TextEditingController(
      text: widget.client.napomenaZaTerapeuta ?? '',
    );
    _zId = widget.client.preferiraniZaposlenikId;
    _gradId = widget.client.gradId > 0
        ? widget.client.gradId
        : widget.gradovi.first.id;
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
    _newPassC.dispose();
    _confirmPassC.dispose();
    _noteC.dispose();
    super.dispose();
  }

  String get _displayName {
    final n = '${_imeC.text.trim()} ${_prezC.text.trim()}'.trim();
    return n.isEmpty ? widget.client.punoIme : n;
  }

  Future<void> _save() async {
    setState(() => _attemptedSubmit = true);
    if (!_formKey.currentState!.validate()) return;

    final ime = _imeC.text.trim();
    final prez = _prezC.text.trim();
    final email = _emailC.text.trim();
    setState(() => _saving = true);
    try {
      await widget.api.patchAdminClient(
        id: widget.client.id,
        ime: ime,
        prezime: prez,
        email: email,
        telefon: _telC.text.trim(),
        gradId: _gradId,
        isVipKlijent: _vip,
        setZaposlenik: true,
        zaposlenikId: _zId,
        napomenaZaTerapeuta: _noteC.text.trim(),
        novaLozinka: _changePassword && _newPassC.text.isNotEmpty
            ? _newPassC.text
            : null,
        potvrdaNoveLozinke: _changePassword && _confirmPassC.text.isNotEmpty
            ? _confirmPassC.text
            : null,
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

  String? _newPasswordValidator(String? value) {
    if (!_changePassword) return null;
    if (value == null || value.isEmpty) {
      return 'Enter a new password or turn off Change password.';
    }
    return NuaValidators.passwordOptional(value);
  }

  String? _confirmNewPasswordValidator(String? value) {
    if (!_changePassword) return null;
    if (_newPassC.text.isEmpty && (value == null || value.isEmpty)) {
      return null;
    }
    return NuaValidators.confirmPasswordOptional(value, _newPassC.text);
  }

  @override
  Widget build(BuildContext context) {
    final fieldStyle = GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: _AdminClientsDesktopScreenState._textPrimary,
    );
    final maxH = MediaQuery.sizeOf(context).height * 0.88;

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
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxH),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(26, 22, 22, 24),
                child: Form(
                  key: _formKey,
                  autovalidateMode: _attemptedSubmit
                      ? AutovalidateMode.onUserInteraction
                      : AutovalidateMode.disabled,
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
                      const SizedBox(height: 16),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (!widget.client.isActive) ...[
                                _inactiveBanner(),
                                const SizedBox(height: 18),
                              ],
                              LuxuryValidatedField(
                                icon: Icons.badge_outlined,
                                label: 'First name',
                                controller: _imeC,
                                hint: 'Enter first name',
                                enabled: !_saving,
                                validator: (v) => NuaValidators.requiredText(
                                  v,
                                  fieldLabel: 'First name',
                                ),
                              ),
                              const SizedBox(height: 14),
                              LuxuryValidatedField(
                                icon: Icons.badge_outlined,
                                label: 'Last name',
                                controller: _prezC,
                                hint: 'Enter last name',
                                enabled: !_saving,
                                validator: (v) => NuaValidators.requiredText(
                                  v,
                                  fieldLabel: 'Last name',
                                ),
                              ),
                              const SizedBox(height: 14),
                              LuxuryValidatedField(
                                icon: Icons.mail_outline_rounded,
                                label: 'Email',
                                controller: _emailC,
                                hint: 'client@email.com',
                                keyboardType: TextInputType.emailAddress,
                                enabled: !_saving,
                                validator: NuaValidators.email,
                              ),
                              const SizedBox(height: 14),
                              _ClientEditFieldRow(
                                icon: Icons.person_outline_rounded,
                                label: 'Username',
                                child: Text(
                                  widget.client.userName.trim().isNotEmpty
                                      ? widget.client.userName.trim()
                                      : '—',
                                  style: fieldStyle.copyWith(
                                    color: Colors.white.withValues(alpha: 0.45),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              LuxuryValidatedField(
                                icon: Icons.phone_outlined,
                                label: 'Phone',
                                controller: _telC,
                                hint: 'Optional',
                                keyboardType: TextInputType.phone,
                                enabled: !_saving,
                                validator: NuaValidators.phoneOptional,
                              ),
                              const SizedBox(height: 14),
                              _ClientEditFieldRow(
                                icon: Icons.location_city_outlined,
                                label: 'City',
                                child: Theme(
                                  data: Theme.of(context).copyWith(
                                    canvasColor: NuaLuxuryTokens.voidViolet,
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                      isExpanded: true,
                                      value: widget.gradovi.any((g) => g.id == _gradId)
                                          ? _gradId
                                          : widget.gradovi.first.id,
                                      dropdownColor: NuaLuxuryTokens.voidViolet,
                                      icon: Icon(
                                        Icons.expand_more_rounded,
                                        color: Colors.white.withValues(alpha: 0.5),
                                      ),
                                      style: fieldStyle,
                                      items: [
                                        for (final g in widget.gradovi)
                                          DropdownMenuItem<int>(
                                            value: g.id,
                                            child: Text(
                                              g.label,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                      ],
                                      onChanged: _saving
                                          ? null
                                          : (v) {
                                              if (v != null) {
                                                setState(() => _gradId = v);
                                              }
                                            },
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              _ClientEditFieldRow(
                                icon: Icons.spa_outlined,
                                label: 'Preferred therapist',
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
                              Text(
                                'Notes for therapist',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withValues(alpha: 0.55),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _noteC,
                                enabled: !_saving,
                                maxLines: 3,
                                maxLength: 1200,
                                style: fieldStyle,
                                decoration: InputDecoration(
                                  hintText: 'Preferences, allergies, etc.',
                                  hintStyle: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.35),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withValues(alpha: 0.04),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: Colors.white.withValues(alpha: 0.1),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: Colors.white.withValues(alpha: 0.1),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              _ClientEditToggleRow(
                                icon: Icons.workspace_premium_rounded,
                                label: 'Manual VIP',
                                value: _vip,
                                onChanged: _saving
                                    ? null
                                    : (v) => setState(() => _vip = v),
                              ),
                              const SizedBox(height: 14),
                              _ClientEditToggleRow(
                                icon: Icons.lock_outline_rounded,
                                label: 'Change password',
                                value: _changePassword,
                                onChanged: _saving
                                    ? null
                                    : (v) {
                                        setState(() {
                                          _changePassword = v;
                                          if (!v) {
                                            _newPassC.clear();
                                            _confirmPassC.clear();
                                          }
                                        });
                                      },
                              ),
                              if (_changePassword) ...[
                                const SizedBox(height: 14),
                                LuxuryValidatedField(
                                  icon: Icons.vpn_key_outlined,
                                  label: 'New password',
                                  controller: _newPassC,
                                  hint: 'Enter new password',
                                  obscureText: _obscureNew,
                                  enabled: !_saving,
                                  validator: _newPasswordValidator,
                                  suffix: IconButton(
                                    icon: Icon(
                                      _obscureNew
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: Colors.white54,
                                      size: 20,
                                    ),
                                    onPressed: _saving
                                        ? null
                                        : () => setState(
                                              () => _obscureNew = !_obscureNew,
                                            ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                LuxuryValidatedField(
                                  icon: Icons.vpn_key_outlined,
                                  label: 'Confirm password',
                                  controller: _confirmPassC,
                                  hint: 'Re-enter new password',
                                  obscureText: _obscureConfirm,
                                  enabled: !_saving,
                                  validator: _confirmNewPasswordValidator,
                                  suffix: IconButton(
                                    icon: Icon(
                                      _obscureConfirm
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: Colors.white54,
                                      size: 20,
                                    ),
                                    onPressed: _saving
                                        ? null
                                        : () => setState(
                                              () => _obscureConfirm =
                                                  !_obscureConfirm,
                                            ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
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
    required this.hasError,
    required this.rows,
    required this.fmtVisit,
    required this.fmtClientSince,
    required this.onView,
    required this.onMore,
    this.onRetry,
  });

  final bool loading;
  final bool hasError;
  final List<AdminClientRow> rows;
  final String Function(DateTime? d) fmtVisit;
  final String Function(DateTime d) fmtClientSince;
  final void Function(AdminClientRow) onView;
  final void Function(AdminClientRow) onMore;
  final VoidCallback? onRetry;

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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hasError
                      ? 'Could not load clients.'
                      : 'No clients to display.',
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                if (hasError && onRetry != null) ...[
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: onRetry,
                    child: const Text('Retry'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const headerH = 44.0;
        final listH =
            (constraints.maxHeight - headerH).clamp(0.0, double.infinity);

        return _ClientsTableShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _TableHeaderRow(),
              if (listH > 0)
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                    itemBuilder: (context, i) {
                      final c = rows[i];
                      return _TableDataRow(
                        client: c,
                        fmtVisit: fmtVisit,
                        fmtClientSince: fmtClientSince,
                        onView: () => onView(c),
                        onMore: () => onMore(c),
                      );
                    },
                  ),
                )
              else
                const SizedBox.shrink(),
            ],
          ),
        );
      },
    );
  }
}

/// Minimal table container.
class _ClientsTableShell extends StatelessWidget {
  const _ClientsTableShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.025),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: child,
      ),
    );
  }
}

class _TableHeaderRow extends StatelessWidget {
  const _TableHeaderRow();

  @override
  Widget build(BuildContext context) {
    final s = GoogleFonts.inter(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: Colors.white.withValues(alpha: 0.42),
      letterSpacing: 0.6,
    );
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          Expanded(flex: 28, child: Text('CLIENT', style: s)),
          Expanded(flex: 22, child: Text('CONTACT', style: s)),
          Expanded(flex: 10, child: Text('VISITS', style: s)),
          Expanded(flex: 12, child: Text('SPENT', style: s)),
          Expanded(flex: 14, child: Text('LAST VISIT', style: s)),
          Expanded(flex: 12, child: Text('STATUS', style: s)),
          SizedBox(
            width: 88,
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
    required this.fmtVisit,
    required this.fmtClientSince,
    required this.onView,
    required this.onMore,
  });

  final AdminClientRow client;
  final String Function(DateTime? d) fmtVisit;
  final String Function(DateTime d) fmtClientSince;
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
    final hasVisit = c.zadnjaPosjeta != null;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        color: _hover ? Colors.white.withValues(alpha: 0.03) : Colors.transparent,
        child: Row(
          children: [
            Expanded(flex: 28, child: _clientCell(c)),
            Expanded(flex: 22, child: _contactCell(c)),
            Expanded(flex: 10, child: _metricCell('${c.ukupnoPosjeta}', 'Visits')),
            Expanded(
              flex: 12,
              child: _metricCell(
                '${c.ukupnoPotroseno.toStringAsFixed(0)} KM',
                'Spent',
              ),
            ),
            Expanded(
              flex: 14,
              child: Text(
                hasVisit ? widget.fmtVisit(c.zadnjaPosjeta) : '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: hasVisit
                      ? Colors.white.withValues(alpha: 0.78)
                      : Colors.white.withValues(alpha: 0.35),
                ),
              ),
            ),
            Expanded(flex: 12, child: _ClientRowStatus(client: c)),
            SizedBox(
              width: 88,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _ActionIconButton(
                    icon: Icons.visibility_outlined,
                    tooltip: 'View client',
                    compact: true,
                    onTap: widget.onView,
                  ),
                  const SizedBox(width: 6),
                  _ActionIconButton(
                    icon: Icons.more_horiz_rounded,
                    tooltip: 'More actions',
                    compact: true,
                    onTap: widget.onMore,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _clientCell(AdminClientRow c) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _AdminClientsDesktopScreenState._purple.withValues(alpha: 0.22),
            border: Border.all(
              color: _AdminClientsDesktopScreenState._purple.withValues(alpha: 0.35),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            _initials(c.punoIme),
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      c.punoIme,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: _AdminClientsDesktopScreenState._textPrimary,
                      ),
                    ),
                  ),
                  if (c.isVip) ...[
                    const SizedBox(width: 8),
                    _CompactStatusBadge(
                      label: 'VIP',
                      color: NuaLuxuryTokens.champagneGold,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 3),
              Text(
                widget.fmtClientSince(c.datumRegistracije),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.42),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _contactCell(AdminClientRow c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          c.email,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.82),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          c.telefon.isEmpty ? '—' : c.telefon,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.45),
          ),
        ),
      ],
    );
  }

  Widget _metricCell(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            height: 1.0,
            letterSpacing: -0.4,
            color: _AdminClientsDesktopScreenState._textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ],
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

class _ClientRowStatus extends StatelessWidget {
  const _ClientRowStatus({required this.client});

  final AdminClientRow client;

  @override
  Widget build(BuildContext context) {
    if (!client.isActive) {
      return const _CompactStatusBadge(
        label: 'Inactive',
        color: Color(0xFF94A3B8),
      );
    }
    return const _CompactStatusBadge(
      label: 'Active',
      color: Color(0xFF22C55E),
    );
  }
}

class _CompactStatusBadge extends StatelessWidget {
  const _CompactStatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _ActionIconButton extends StatefulWidget {
  const _ActionIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.compact = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool compact;

  @override
  State<_ActionIconButton> createState() => _ActionIconButtonState();
}

class _ActionIconButtonState extends State<_ActionIconButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final size = widget.compact ? 34.0 : 48.0;
    final iconSize = widget.compact ? 17.0 : 20.0;
    final btn = MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: _hover ? 0.09 : 0.05),
          borderRadius: BorderRadius.circular(widget.compact ? 10 : 16),
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
            borderRadius: BorderRadius.circular(widget.compact ? 10 : 16),
            onTap: widget.onTap,
            child: Icon(
              widget.icon,
              size: iconSize,
              color: Colors.white.withValues(alpha: _hover ? 0.95 : 0.72),
            ),
          ),
        ),
      ),
    );
    if (widget.tooltip == null) return btn;
    return Tooltip(message: widget.tooltip!, child: btn);
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
