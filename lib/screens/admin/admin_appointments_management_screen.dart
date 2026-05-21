import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/api/services/api_service.dart';
import '../../models/rezervacija.dart';
import '../../models/rezervacija_povijest_item.dart';
import '../../models/admin/admin_client_row.dart';
import '../../models/usluga.dart';
import '../../models/zaposlenik.dart';
import '../../ui/navigation/desktop_nav.dart';
import '../../ui/theme/nua_luxury_tokens.dart';
import '../../ui/widgets/luxury/luxury_glass_panel.dart';

enum _AppointmentView { day, week, month }

class AdminAppointmentsManagementScreen extends StatefulWidget {
  const AdminAppointmentsManagementScreen({super.key});

  @override
  State<AdminAppointmentsManagementScreen> createState() =>
      _AdminAppointmentsManagementScreenState();
}

class _AdminAppointmentsManagementScreenState
    extends State<AdminAppointmentsManagementScreen> {
  final ApiService _api = ApiService();
  late Future<_AppointmentsData> _future;
  DateTime _selectedDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  int? _therapistId;
  int? _serviceId;
  String _status = 'All Status';
  _AppointmentView _view = _AppointmentView.day;
  Rezervacija? _selected;
  int _handledCreateRequest = 0;
  int _lastFiltersPulse = 0;
  final ScrollController _mainScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _mainScrollController.dispose();
    super.dispose();
  }

  Future<_AppointmentsData> _load() async {
    final results = await Future.wait([
      _api.getRezervacijeFiltered(includeOtkazane: true),
      _api.getZaposlenici(),
      _api.getUsluge(),
      _api.getAdminClients(take: 400),
    ]);
    final reservations = results[0] as List<Rezervacija>;
    reservations.sort(
      (a, b) => a.datumRezervacije.compareTo(b.datumRezervacije),
    );
    return _AppointmentsData(
      reservations: reservations,
      therapists: results[1] as List<Zaposlenik>,
      services: results[2] as List<Usluga>,
      clients: results[3] as List<AdminClientRow>,
    );
  }

  void _reload() {
    setState(() => _future = _load());
  }

  Future<void> _showFiltersSheet(_AppointmentsData data) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF140B24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        var therapistId = _therapistId;
        var serviceId = _serviceId;
        var status = _status;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Appointment filters',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFF5F3FA),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int?>(
                      value: therapistId,
                      decoration: const InputDecoration(labelText: 'Therapist'),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All Therapists'),
                        ),
                        for (final t in data.therapists)
                          DropdownMenuItem(
                            value: t.id,
                            child: Text('${t.ime} ${t.prezime}'),
                          ),
                      ],
                      onChanged: (v) => setModalState(() => therapistId = v),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int?>(
                      value: serviceId,
                      decoration: const InputDecoration(labelText: 'Service'),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All Services'),
                        ),
                        for (final s in data.services)
                          DropdownMenuItem(
                            value: s.id,
                            child: Text(s.naziv),
                          ),
                      ],
                      onChanged: (v) => setModalState(() => serviceId = v),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: const [
                        DropdownMenuItem(
                          value: 'All Status',
                          child: Text('All Status'),
                        ),
                        DropdownMenuItem(
                          value: 'Confirmed',
                          child: Text('Confirmed'),
                        ),
                        DropdownMenuItem(
                          value: 'Pending',
                          child: Text('Pending'),
                        ),
                        DropdownMenuItem(
                          value: 'Cancelled',
                          child: Text('Cancelled'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setModalState(() => status = v);
                      },
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          _therapistId = therapistId;
                          _serviceId = serviceId;
                          _status = status;
                        });
                        Navigator.pop(ctx);
                      },
                      child: const Text('Apply filters'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<DesktopNav>();
    final query = nav.appointmentSearchQuery;
    return FutureBuilder<_AppointmentsData>(
      future: _future,
      builder: (context, snap) {
        final data = snap.data ?? const _AppointmentsData.empty();
        _lastServices
          ..clear()
          ..addEntries(data.services.map((s) => MapEntry(s.id, s.naziv)));
        _lastTherapists
          ..clear()
          ..addEntries(
            data.therapists.map(
              (t) => MapEntry(t.id, '${t.ime} ${t.prezime}'.trim()),
            ),
          );
        if (nav.appointmentCreateRequest != _handledCreateRequest &&
            snap.connectionState == ConnectionState.done) {
          _handledCreateRequest = nav.appointmentCreateRequest;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _openCreate(data);
          });
        }
        if (nav.headerFiltersPulse != _lastFiltersPulse &&
            snap.connectionState == ConnectionState.done) {
          _lastFiltersPulse = nav.headerFiltersPulse;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showFiltersSheet(data);
          });
        }
        final filtered = _filter(data.reservations, query);
        final selected =
            _selected != null && filtered.any((r) => r.id == _selected!.id)
            ? _selected!
            : (filtered.isNotEmpty ? filtered.first : null);

        return _ApptScrollbarTheme(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final sidebarW = (constraints.maxWidth * 0.24).clamp(
                _ApptUi.sidebarMinWidth,
                _ApptUi.sidebarMaxWidth,
              );

              return DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF07040F), Color(0xFF120A24)],
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Scrollbar(
                        controller: _mainScrollController,
                        child: SingleChildScrollView(
                          controller: _mainScrollController,
                          primary: false,
                          padding: const EdgeInsets.fromLTRB(32, 24, 20, 40),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _FilterBar(
                                therapists: data.therapists,
                                services: data.services,
                                therapistId: _therapistId,
                                serviceId: _serviceId,
                                status: _status,
                                view: _view,
                                onTherapistChanged: (v) =>
                                    setState(() => _therapistId = v),
                                onServiceChanged: (v) =>
                                    setState(() => _serviceId = v),
                                onStatusChanged: (v) => setState(() => _status = v),
                                onViewChanged: (v) => setState(() => _view = v),
                                onNew: () => _openCreate(data),
                              ),
                              const SizedBox(height: _ApptUi.sectionGap),
                              _KpiCards(reservations: filtered),
                              const SizedBox(height: 36),
                              snap.connectionState == ConnectionState.waiting
                                  ? const SizedBox(
                                      height: 420,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : _AppointmentsTable(
                                      reservations: filtered,
                                      selectedId: selected?.id,
                                      onSelect: (r) =>
                                          setState(() => _selected = r),
                                      onConfirmToggle: _toggleConfirmed,
                                      onCancel: _cancel,
                                      onDelete: _delete,
                                      onEdit: _edit,
                                    ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    SizedBox(
                      width: sidebarW,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 24, 28, 40),
                        child: _AppointmentDetailsPanel(
                          appointment: selected,
                          onEdit: selected == null
                              ? null
                              : () => _edit(selected),
                          onConfirmToggle: _toggleConfirmed,
                          onCancel: _cancel,
                          onDelete: _delete,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  List<Rezervacija> _filter(List<Rezervacija> all, String query) {
    return all.where((r) {
      final q = query.trim().toLowerCase();
      final matchesSearch =
          q.isEmpty ||
          (r.korisnikIme ?? '').toLowerCase().contains(q) ||
          (r.korisnikTelefon ?? '').toLowerCase().contains(q) ||
          (r.uslugaNaziv ?? '').toLowerCase().contains(q) ||
          (r.zaposlenikIme ?? '').toLowerCase().contains(q);
      final matchesDate = switch (_view) {
        _AppointmentView.day => _sameDay(r.datumRezervacije, _selectedDate),
        _AppointmentView.week => _sameWeek(r.datumRezervacije, _selectedDate),
        _AppointmentView.month =>
          r.datumRezervacije.year == _selectedDate.year &&
              r.datumRezervacije.month == _selectedDate.month,
      };
      final matchesTherapist =
          _therapistId == null ||
          _nameMatchesTherapist(r.zaposlenikIme, _therapistId!);
      final matchesService =
          _serviceId == null || _serviceNameById(_serviceId!) == r.uslugaNaziv;
      final matchesStatus =
          _status == 'All Status' ||
          (_status == 'Confirmed' && r.isPotvrdjena && !r.isOtkazana) ||
          (_status == 'Pending' && !r.isPotvrdjena && !r.isOtkazana) ||
          (_status == 'Cancelled' && r.isOtkazana);
      return matchesSearch &&
          matchesDate &&
          matchesTherapist &&
          matchesService &&
          matchesStatus;
    }).toList();
  }

  String? _serviceNameById(int id) {
    return _lastServices[id];
  }

  final Map<int, String> _lastServices = {};
  final Map<int, String> _lastTherapists = {};

  bool _nameMatchesTherapist(String? name, int id) =>
      name != null &&
      (_lastTherapists[id] == name ||
          _lastTherapists[id]?.toLowerCase().contains(name.toLowerCase()) ==
              true ||
          name.toLowerCase().contains(
            _lastTherapists[id]?.toLowerCase() ?? '',
          ));

  Future<void> _openCreate(_AppointmentsData data) async {
    final prefillZaposlenikId =
        context.read<DesktopNav>().takeAppointmentPrefillZaposlenikId();
    final draft = await showDialog<_AdminAppointmentDraft>(
      context: context,
      builder: (_) => _AdminAppointmentCreateDialog(
        data: data,
        initialZaposlenikId: prefillZaposlenikId,
      ),
    );
    if (draft == null || !mounted) return;
    final created = await _api.createRezervacija(
      korisnikId: draft.clientId,
      datumRezervacije: draft.dateTime,
      uslugaId: draft.serviceId,
      zaposlenikId: draft.therapistId,
    );
    if (!mounted) return;
    _toast(
      created == null ? 'Appointment creation failed.' : 'Appointment created.',
    );
    if (created != null) {
      setState(() {
        _selected = created;
        _selectedDate = DateTime(
          created.datumRezervacije.year,
          created.datumRezervacije.month,
          created.datumRezervacije.day,
        );
      });
      _reload();
    }
  }

  Future<void> _toggleConfirmed(Rezervacija r) async {
    final ok = await _api.updateRezervacijaPotvrdjena(r.id, !r.isPotvrdjena);
    if (!mounted) return;
    _toast(ok ? 'Status ažuriran.' : 'Nije moguće ažurirati status.');
    if (ok) _reload();
  }

  Future<void> _cancel(Rezervacija r) async {
    final reasonCtrl = TextEditingController();
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel appointment?'),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Reason (optional)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    final ok = await _api.cancelRezervacija(
      r.id,
      razlogOtkaza: reasonCtrl.text,
    );
    if (!mounted) return;
    _toast(ok ? 'Appointment cancelled.' : 'Cancellation failed.');
    if (ok) _reload();
  }

  Future<void> _delete(Rezervacija r) async {
    if (r.isPlacena) {
      _toast('Paid appointments cannot be deleted.');
      return;
    }
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete appointment?'),
        content: const Text(
          'This permanently removes the appointment from the schedule. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Back'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF5E7A),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    final err = await _api.deleteRezervacijaAdmin(r.id);
    if (!mounted) return;
    if (err != null) {
      _toast(err);
      return;
    }
    _toast('Appointment deleted.');
    setState(() {
      if (_selected?.id == r.id) _selected = null;
      _future = _load();
    });
  }

  Future<void> _edit(Rezervacija r) async {
    final data = await _future;
    if (!mounted) return;
    final draft = await showDialog<_AppointmentEditDraft>(
      context: context,
      builder: (_) => _AppointmentEditDialog(
        appointment: r,
        therapists: data.therapists,
        services: data.services,
      ),
    );
    if (draft == null || !mounted) return;
    final updated = await _api.editRezervacija(
      rezervacijaId: r.id,
      datumRezervacije: draft.dateTime,
      uslugaId: draft.serviceId,
      zaposlenikId: draft.therapistId,
      isVip: draft.isVip,
    );
    if (!mounted) return;
    _toast(updated == null ? 'Edit failed.' : 'Appointment updated.');
    if (updated != null) {
      setState(() => _selected = updated);
      _reload();
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _sameWeek(DateTime a, DateTime b) {
    DateTime start(DateTime d) => DateTime(
      d.year,
      d.month,
      d.day,
    ).subtract(Duration(days: d.weekday - 1));
    return _sameDay(start(a), start(b));
  }
}

// ——— Premium appointments UI tokens ———
abstract final class _ApptUi {
  static const Color textPrimary = Color(0xFFF5F3FA);
  static const Color lavender = Color(0xFFC8B6E8);
  static const Color purple = Color(0xFF7B4DFF);
  static const Color purple2 = Color(0xFF9D6BFF);

  static const double kpiCardHeight = 200;
  static const double kpiCardMinWidth = 220;
  static const double filterControlHeight = 40;
  static const double filterDropdownWidth = 168;
  static const double filterStatusWidth = 148;
  static const double sectionGap = 32;
  static const double sidebarMaxWidth = 360;
  static const double sidebarMinWidth = 300;
}

class _ApptScrollbarTheme extends StatelessWidget {
  const _ApptScrollbarTheme({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ScrollbarTheme(
      data: ScrollbarThemeData(
        thickness: WidgetStateProperty.all(5),
        radius: const Radius.circular(8),
        thumbVisibility: WidgetStateProperty.all(true),
        trackVisibility: WidgetStateProperty.all(false),
        crossAxisMargin: 6,
        mainAxisMargin: 8,
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.dragged)) {
            return _ApptUi.purple2.withValues(alpha: 0.95);
          }
          if (states.contains(WidgetState.hovered)) {
            return _ApptUi.purple.withValues(alpha: 0.82);
          }
          return _ApptUi.purple.withValues(alpha: 0.5);
        }),
        trackColor: WidgetStateProperty.all(Colors.transparent),
      ),
      child: child,
    );
  }
}

class _ApptGlass extends StatelessWidget {
  const _ApptGlass({
    required this.child,
    this.padding,
    this.radius = 26,
    this.minHeight,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: _ApptUi.purple.withValues(alpha: 0.12),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight ?? 0),
            child: Padding(
              padding: padding ?? EdgeInsets.zero,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.therapists,
    required this.services,
    required this.therapistId,
    required this.serviceId,
    required this.status,
    required this.view,
    required this.onTherapistChanged,
    required this.onServiceChanged,
    required this.onStatusChanged,
    required this.onViewChanged,
    required this.onNew,
  });

  final List<Zaposlenik> therapists;
  final List<Usluga> services;
  final int? therapistId;
  final int? serviceId;
  final String status;
  final _AppointmentView view;
  final ValueChanged<int?> onTherapistChanged;
  final ValueChanged<int?> onServiceChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<_AppointmentView> onViewChanged;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    const gap = 10.0;

    final therapistPill = SizedBox(
      width: _ApptUi.filterDropdownWidth,
      child: _DropdownPill<int?>(
        value: therapistId,
        hint: 'All Therapists',
        items: [
          const DropdownMenuItem(value: null, child: Text('All Therapists')),
          for (final t in therapists)
            DropdownMenuItem(
              value: t.id,
              child: Text('${t.ime} ${t.prezime}'),
            ),
        ],
        onChanged: onTherapistChanged,
      ),
    );
    final servicePill = SizedBox(
      width: _ApptUi.filterDropdownWidth,
      child: _DropdownPill<int?>(
        value: serviceId,
        hint: 'All Services',
        items: [
          const DropdownMenuItem(value: null, child: Text('All Services')),
          for (final s in services)
            DropdownMenuItem(value: s.id, child: Text(s.naziv)),
        ],
        onChanged: onServiceChanged,
      ),
    );
    final statusPill = SizedBox(
      width: _ApptUi.filterStatusWidth,
      child: _DropdownPill<String>(
        value: status,
        hint: 'All Status',
        items: const [
          DropdownMenuItem(value: 'All Status', child: Text('All Status')),
          DropdownMenuItem(value: 'Confirmed', child: Text('Confirmed')),
          DropdownMenuItem(value: 'Pending', child: Text('Pending')),
          DropdownMenuItem(value: 'Cancelled', child: Text('Cancelled')),
        ],
        onChanged: (v) {
          if (v != null) onStatusChanged(v);
        },
      ),
    );
    final newBtn = _GradientButton(
      label: 'New Appointment',
      onTap: onNew,
      height: _ApptUi.filterControlHeight,
      borderRadius: 12,
      primary: true,
    );

    return _ApptGlass(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: LayoutBuilder(
        builder: (context, c) {
          final narrow = c.maxWidth < 900;

          if (narrow) {
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                therapistPill,
                servicePill,
                statusPill,
                newBtn,
                _ViewSwitcher(value: view, onChanged: onViewChanged),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              therapistPill,
              const SizedBox(width: gap),
              servicePill,
              const SizedBox(width: gap),
              statusPill,
              const SizedBox(width: 16),
              newBtn,
              const Spacer(),
              _ViewSwitcher(value: view, onChanged: onViewChanged),
            ],
          );
        },
      ),
    );
  }
}

class _KpiCards extends StatelessWidget {
  const _KpiCards({required this.reservations});

  final List<Rezervacija> reservations;

  @override
  Widget build(BuildContext context) {
    final total = reservations.length;
    final confirmed = reservations
        .where((r) => r.isPotvrdjena && !r.isOtkazana)
        .length;
    final pending = reservations
        .where((r) => !r.isPotvrdjena && !r.isOtkazana)
        .length;
    final cancelled = reservations.where((r) => r.isOtkazana).length;
    final cards = [
      _KpiSpec(
        "Today's Appointments",
        '$total',
        '+12% vs yesterday',
        Icons.calendar_today_outlined,
        NuaLuxuryTokens.softPurpleGlow,
      ),
      _KpiSpec(
        'Confirmed',
        '$confirmed',
        _pct(confirmed, total),
        Icons.check_circle_outline,
        const Color(0xFF4ADE80),
      ),
      _KpiSpec(
        'Pending',
        '$pending',
        _pct(pending, total),
        Icons.schedule_outlined,
        const Color(0xFFF5B942),
      ),
      _KpiSpec(
        'Cancelled',
        '$cancelled',
        _pct(cancelled, total),
        Icons.cancel_outlined,
        const Color(0xFFFF5E7A),
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 22.0;
        final minCard = _ApptUi.kpiCardMinWidth;
        final cardH = _ApptUi.kpiCardHeight;
        final rawW = c.maxWidth;
        final layoutW = rawW.isFinite && rawW > 0
            ? rawW
            : MediaQuery.sizeOf(context).width;
        final fourCol = layoutW >= minCard * 4 + gap * 3;
        final twoCol = layoutW >= minCard * 2 + gap;

        if (fourCol) {
          return SizedBox(
            height: cardH,
            child: Row(
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(width: gap),
                  Expanded(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: minCard),
                      child: _KpiCard(spec: cards[i]),
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        if (twoCol) {
          final cellW = (layoutW - gap) / 2;
          return Column(
            children: [
              SizedBox(
                height: cardH,
                child: Row(
                  children: [
                    SizedBox(
                      width: cellW,
                      child: _KpiCard(spec: cards[0]),
                    ),
                    const SizedBox(width: gap),
                    SizedBox(
                      width: cellW,
                      child: _KpiCard(spec: cards[1]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: gap),
              SizedBox(
                height: cardH,
                child: Row(
                  children: [
                    SizedBox(
                      width: cellW,
                      child: _KpiCard(spec: cards[2]),
                    ),
                    const SizedBox(width: gap),
                    SizedBox(
                      width: cellW,
                      child: _KpiCard(spec: cards[3]),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            primary: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(width: gap),
                  SizedBox(
                    width: minCard,
                    height: cardH,
                    child: _KpiCard(spec: cards[i]),
                  ),
                ],
              ],
            ),
          );
      },
    );
  }

  static String _pct(int value, int total) => total == 0
      ? '0% of total'
      : '${((value / total) * 100).toStringAsFixed(1)}% of total';
}

class _AppointmentsTable extends StatelessWidget {
  const _AppointmentsTable({
    required this.reservations,
    required this.selectedId,
    required this.onSelect,
    required this.onConfirmToggle,
    required this.onCancel,
    required this.onDelete,
    required this.onEdit,
  });

  final List<Rezervacija> reservations;
  final int? selectedId;
  final ValueChanged<Rezervacija> onSelect;
  final ValueChanged<Rezervacija> onConfirmToggle;
  final ValueChanged<Rezervacija> onCancel;
  final ValueChanged<Rezervacija> onDelete;
  final ValueChanged<Rezervacija> onEdit;

  @override
  Widget build(BuildContext context) {
    if (reservations.isEmpty) {
      return _ApptGlass(
        radius: 28,
        padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 32),
        child: Column(
          children: [
            Text(
              'All Appointments',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _ApptUi.textPrimary,
              ),
            ),
            const SizedBox(height: 32),
            _ApptEmptyIllustration(icon: Icons.calendar_month_outlined),
            const SizedBox(height: 24),
            Text(
              'No appointments found',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _ApptUi.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'There are no appointments for the selected date and filters.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 15,
                height: 1.45,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      );
    }

    return _ApptGlass(
      radius: 28,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              'All Appointments',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _ApptUi.textPrimary,
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                primary: false,
                child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 980),
              child: DataTable(
                showCheckboxColumn: false,
                columnSpacing: 22,
                horizontalMargin: 12,
                headingRowHeight: 64,
                dataRowMinHeight: 72,
                dataRowMaxHeight: 88,
                headingRowColor: WidgetStateProperty.all(
                  Colors.white.withValues(alpha: 0.05),
                ),
                headingTextStyle: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.35,
                  color: _ApptUi.lavender.withValues(alpha: 0.75),
                ),
                columns: const [
                  DataColumn(label: Text('TIME')),
                  DataColumn(label: Text('CLIENT')),
                  DataColumn(label: Text('SERVICE')),
                  DataColumn(label: Text('THERAPIST')),
                  DataColumn(label: Text('DURATION')),
                  DataColumn(label: Text('STATUS')),
                  DataColumn(label: Text('PAYMENT')),
                  DataColumn(label: Text('ACTIONS')),
                ],
                rows: [
                  for (final r in reservations)
                    DataRow(
                      selected: selectedId == r.id,
                      color: WidgetStateProperty.resolveWith((states) {
                        if (selectedId == r.id) {
                          return NuaLuxuryTokens.softPurpleGlow.withValues(
                            alpha: 0.08,
                          );
                        }
                        if (states.contains(WidgetState.hovered)) {
                          return Colors.white.withValues(alpha: 0.04);
                        }
                        return null;
                      }),
                      onSelectChanged: (_) => onSelect(r),
                      cells: [
                        DataCell(
                          Text(
                            _time(r.datumRezervacije),
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        DataCell(
                          _PersonCell(
                            name: r.korisnikIme ?? 'Nua Guest',
                            subtitle: r.korisnikTelefon ?? '+387 61 000 000',
                          ),
                        ),
                        DataCell(
                          _TwoLine(
                            title: r.uslugaNaziv ?? 'Spa Ritual',
                            subtitle: _category(r.uslugaNaziv),
                          ),
                        ),
                        DataCell(
                          _PersonCell(
                            name: r.zaposlenikIme ?? 'Nua Therapist',
                            subtitle: 'Senior Therapist',
                            compact: true,
                          ),
                        ),
                        DataCell(
                          Text(
                            '${r.uslugaTrajanjeMinuta > 0 ? r.uslugaTrajanjeMinuta : 60} min',
                          ),
                        ),
                        DataCell(
                          _StatusBadge(
                            label: _status(r),
                            color: _statusColor(r),
                          ),
                        ),
                        DataCell(
                          _StatusBadge(
                            label: r.isPlacena ? 'Paid' : 'Unpaid',
                            color: r.isPlacena
                                ? const Color(0xFF4ADE80)
                                : const Color(0xFFFF5E7A),
                          ),
                        ),
                        DataCell(
                          _ActionsMenu(
                            appointment: r,
                            onConfirmToggle: onConfirmToggle,
                            onCancel: onCancel,
                            onDelete: onDelete,
                            onEdit: onEdit,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
        ],
      ),
    );
  }

  static String _time(DateTime d) {
    final l = d.toLocal();
    final hour = l.hour % 12 == 0 ? 12 : l.hour % 12;
    return '$hour:${l.minute.toString().padLeft(2, '0')} ${l.hour >= 12 ? 'PM' : 'AM'}';
  }

  static String _status(Rezervacija r) =>
      r.isOtkazana ? 'Cancelled' : (r.isPotvrdjena ? 'Confirmed' : 'Pending');
  static Color _statusColor(Rezervacija r) => r.isOtkazana
      ? const Color(0xFFFF5E7A)
      : (r.isPotvrdjena
            ? NuaLuxuryTokens.softPurpleGlow
            : const Color(0xFFF5B942));
  static String _category(String? service) =>
      (service ?? '').toLowerCase().contains('massage')
      ? 'Relaxation'
      : 'Wellness';
}

class _AppointmentDetailsPanel extends StatelessWidget {
  const _AppointmentDetailsPanel({
    required this.appointment,
    required this.onEdit,
    required this.onConfirmToggle,
    required this.onCancel,
    required this.onDelete,
  });

  final Rezervacija? appointment;
  final VoidCallback? onEdit;
  final ValueChanged<Rezervacija> onConfirmToggle;
  final ValueChanged<Rezervacija> onCancel;
  final ValueChanged<Rezervacija> onDelete;

  @override
  Widget build(BuildContext context) {
    final r = appointment;
    return Column(
      children: [
        Expanded(
          child: _ApptGlass(
            radius: 28,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: r == null
                ? _AppointmentSidebarEmpty()
                : _AppointmentDetailsContent(appointment: r),
          ),
        ),
        const SizedBox(height: 16),
        _BottomEditBar(
          appointment: r,
          onEdit: onEdit,
          onConfirmToggle: onConfirmToggle,
          onCancel: onCancel,
          onDelete: onDelete,
        ),
      ],
    );
  }
}

class _AppointmentDetailsContent extends StatelessWidget {
  const _AppointmentDetailsContent({required this.appointment});

  final Rezervacija appointment;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RezervacijaPovijestItem>>(
      future: appointment.korisnikId <= 0
          ? Future.value(const [])
          : ApiService().getRezervacijaPovijestZaKlijenta(
              korisnikId: appointment.korisnikId,
              excludeRezervacijaId: appointment.id,
              take: 20,
            ),
      builder: (context, snap) {
        final history = snap.data ?? const <RezervacijaPovijestItem>[];
        final spent = appointment.uslugaCijena * (history.length + 1);
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Appointment Details',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 18),
              Center(
                child: _LargeAvatar(
                  name: appointment.korisnikIme ?? 'Nua Guest',
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Column(
                  children: [
                    Text(
                      appointment.korisnikIme ?? 'Nua Guest',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (appointment.premiumKlijent) ...[
                      const SizedBox(height: 6),
                      const _StatusBadge(
                        label: 'VIP',
                        color: NuaLuxuryTokens.champagneGold,
                      ),
                    ],
                    Text(
                      appointment.korisnikTelefon ?? '+387 61 000 000',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                      ),
                    ),
                    Text(
                      appointment.korisnikEmail ?? 'No email on file',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.42),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              _DetailRow(
                icon: Icons.event_outlined,
                label: 'Date & Time',
                value:
                    '${_date(appointment.datumRezervacije)} at ${_AppointmentsTable._time(appointment.datumRezervacije)}',
              ),
              _DetailRow(
                icon: Icons.spa_outlined,
                label: 'Service',
                value: appointment.uslugaNaziv ?? 'Spa Ritual',
                helper: _AppointmentsTable._category(appointment.uslugaNaziv),
              ),
              _DetailRow(
                icon: Icons.person_outline,
                label: 'Therapist',
                value: appointment.zaposlenikIme ?? 'Nua Therapist',
                helper: 'Senior Therapist',
              ),
              _DetailRow(
                icon: Icons.timer_outlined,
                label: 'Duration',
                value:
                    '${appointment.uslugaTrajanjeMinuta > 0 ? appointment.uslugaTrajanjeMinuta : 60} min',
              ),
              _DetailRow(
                icon: Icons.verified_outlined,
                label: 'Status',
                customValue: _StatusBadge(
                  label: _AppointmentsTable._status(appointment),
                  color: _AppointmentsTable._statusColor(appointment),
                ),
              ),
              _DetailRow(
                icon: Icons.payments_outlined,
                label: 'Payment',
                customValue: _StatusBadge(
                  label: appointment.isPlacena ? 'Paid' : 'Unpaid',
                  color: appointment.isPlacena
                      ? const Color(0xFF4ADE80)
                      : const Color(0xFFFF5E7A),
                ),
              ),
              const _DetailRow(
                icon: Icons.language_outlined,
                label: 'Booking Source',
                value: 'Website',
              ),
              _DetailRow(
                icon: Icons.notes_outlined,
                label: 'Notes',
                value: appointment.napomenaZaTerapeuta?.isNotEmpty == true
                    ? appointment.napomenaZaTerapeuta!
                    : 'No notes on file.',
              ),
              const SizedBox(height: 16),
              _ClientHistoryCard(
                total: history.length + 1,
                spent: spent,
                last: history.isEmpty
                    ? '—'
                    : _date(history.first.datumRezervacije),
                history: history,
              ),
            ],
          ),
        );
      },
    );
  }

  static String _date(DateTime d) {
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
    final l = d.toLocal();
    return '${months[l.month - 1]} ${l.day}, ${l.year}';
  }
}

// Small UI building blocks
class _KpiSpec {
  const _KpiSpec(this.title, this.value, this.subtitle, this.icon, this.color);
  final String title, value, subtitle;
  final IconData icon;
  final Color color;
}

class _KpiCard extends StatefulWidget {
  const _KpiCard({required this.spec});
  final _KpiSpec spec;

  @override
  State<_KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<_KpiCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    return LayoutBuilder(
      builder: (context, constraints) {
        final valueSize = constraints.maxWidth < 200 ? 36.0 : 42.0;

        return MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            height: _ApptUi.kpiCardHeight,
            transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: _hover ? 0.05 : 0.035),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: Colors.white.withValues(alpha: _hover ? 0.14 : 0.08),
              ),
              boxShadow: _hover
                  ? [
                      BoxShadow(
                        color: spec.color.withValues(alpha: 0.22),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: spec.color.withValues(alpha: 0.16),
                              border: Border.all(
                                color: spec.color.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Icon(spec.icon, color: spec.color, size: 24),
                          ),
                        ),
                        Text(
                          spec.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: valueSize,
                            fontWeight: FontWeight.w700,
                            color: _ApptUi.textPrimary,
                            height: 1,
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              spec.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _ApptUi.lavender.withValues(alpha: 0.85),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              spec.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: spec.color.withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        widthFactor: 0.55,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            gradient: LinearGradient(
                              colors: [
                                spec.color.withValues(alpha: 0),
                                spec.color.withValues(alpha: 0.85),
                                spec.color.withValues(alpha: 0),
                              ],
                            ),
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
      },
    );
  }
}

class _AppointmentSidebarEmpty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const _ApptEmptyIllustration(
              icon: Icons.event_note_outlined,
              compact: true,
            ),
            const SizedBox(height: 22),
            Text(
              'No appointment selected',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _ApptUi.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(
                'Select an appointment from the list to view details.',
                textAlign: TextAlign.center,
                maxLines: 3,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.45,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApptEmptyIllustration extends StatelessWidget {
  const _ApptEmptyIllustration({required this.icon, this.compact = false});
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 64.0 : 88.0;
    final iconSize = compact ? 28.0 : 40.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _ApptUi.purple.withValues(alpha: 0.12),
        boxShadow: [
          BoxShadow(
            color: _ApptUi.purple.withValues(alpha: compact ? 0.28 : 0.35),
            blurRadius: compact ? 20 : 32,
            spreadRadius: compact ? 2 : 4,
          ),
        ],
      ),
      child: Icon(icon, size: iconSize, color: _ApptUi.purple2),
    );
  }
}

class _DropdownPill<T> extends StatelessWidget {
  const _DropdownPill({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final String hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canExpand = constraints.maxWidth.isFinite && constraints.maxWidth > 0;

        return Container(
          height: _ApptUi.filterControlHeight,
          width: canExpand ? constraints.maxWidth : null,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              isExpanded: canExpand,
              value: value,
              hint: Text(
                hint,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: _ApptUi.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              dropdownColor: NuaLuxuryTokens.voidViolet,
              icon: Icon(
                Icons.expand_more_rounded,
                color: Colors.white.withValues(alpha: 0.5),
                size: 20,
              ),
              style: GoogleFonts.inter(
                color: _ApptUi.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              items: items,
              onChanged: onChanged,
            ),
          ),
        );
      },
    );
  }
}

class _ViewSwitcher extends StatelessWidget {
  const _ViewSwitcher({required this.value, required this.onChanged});
  final _AppointmentView value;
  final ValueChanged<_AppointmentView> onChanged;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: _ApptUi.filterControlHeight,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _AppointmentView.values.length; i++) ...[
              if (i > 0) const SizedBox(width: 2),
              _ViewPill(
                label: _AppointmentView.values[i].name[0].toUpperCase() +
                    _AppointmentView.values[i].name.substring(1),
                active: value == _AppointmentView.values[i],
                onTap: () => onChanged(_AppointmentView.values[i]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ViewPill extends StatefulWidget {
  const _ViewPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_ViewPill> createState() => _ViewPillState();
}

class _ViewPillState extends State<_ViewPill> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: widget.active
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_ApptUi.purple, _ApptUi.purple2],
                    )
                  : null,
              color: widget.active
                  ? null
                  : (_hover
                        ? _ApptUi.purple.withValues(alpha: 0.12)
                        : Colors.transparent),
              borderRadius: BorderRadius.circular(9),
              border: widget.active
                  ? Border.all(color: Colors.white.withValues(alpha: 0.12))
                  : null,
              boxShadow: widget.active
                  ? [
                      BoxShadow(
                        color: _ApptUi.purple.withValues(alpha: 0.42),
                        blurRadius: 16,
                      ),
                    ]
                  : null,
            ),
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: widget.active
                    ? Colors.white
                    : _ApptUi.lavender.withValues(alpha: _hover ? 0.95 : 0.55),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientButton extends StatefulWidget {
  const _GradientButton({
    required this.label,
    required this.onTap,
    this.compact = false,
    this.primary = false,
    this.height = _ApptUi.filterControlHeight,
    this.borderRadius = 18,
    this.showIcon = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool compact;
  final bool primary;
  final double height;
  final double borderRadius;
  final bool showIcon;

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.borderRadius);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: radius,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: widget.height,
            padding: EdgeInsets.symmetric(
              horizontal: widget.primary ? 18 : (widget.compact ? 14 : 16),
            ),
            transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_ApptUi.purple, _ApptUi.purple2],
              ),
              boxShadow: [
                BoxShadow(
                  color: _ApptUi.purple.withValues(alpha: _hover ? 0.48 : 0.28),
                  blurRadius: _hover ? 22 : 14,
                  offset: Offset(0, _hover ? 8 : 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.showIcon) ...[
                  Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: widget.primary ? 18 : 16,
                  ),
                  SizedBox(width: widget.primary ? 8 : 6),
                ],
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: widget.primary ? 13 : 13,
                      color: Colors.white,
                    ),
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

class _PersonCell extends StatelessWidget {
  const _PersonCell({
    required this.name,
    required this.subtitle,
    this.compact = false,
  });
  final String name, subtitle;
  final bool compact;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      CircleAvatar(
        radius: compact ? 15 : 18,
        backgroundColor: NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.35),
        child: Text(
          _ini(name),
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
        ),
      ),
      const SizedBox(width: 10),
      _TwoLine(title: name, subtitle: subtitle),
    ],
  );
  String _ini(String s) => s
      .trim()
      .split(RegExp(r'\s+'))
      .take(2)
      .map((p) => p.isEmpty ? '' : p[0])
      .join()
      .toUpperCase();
}

class _TwoLine extends StatelessWidget {
  const _TwoLine({required this.title, required this.subtitle});
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 150,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.48),
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.13),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withValues(alpha: 0.38)),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12),
    ),
  );
}

class _ActionsMenu extends StatelessWidget {
  const _ActionsMenu({
    required this.appointment,
    required this.onConfirmToggle,
    required this.onCancel,
    required this.onDelete,
    required this.onEdit,
  });
  final Rezervacija appointment;
  final ValueChanged<Rezervacija> onConfirmToggle, onCancel, onDelete, onEdit;
  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    color: NuaLuxuryTokens.voidViolet,
    icon: const Icon(Icons.more_horiz_rounded),
    onSelected: (v) {
      if (v == 'edit') onEdit(appointment);
      if (v == 'toggle') onConfirmToggle(appointment);
      if (v == 'cancel') onCancel(appointment);
      if (v == 'delete') onDelete(appointment);
    },
    itemBuilder: (_) => [
      const PopupMenuItem(value: 'edit', child: Text('Edit')),
      const PopupMenuItem(value: 'toggle', child: Text('Confirm / Pending')),
      const PopupMenuItem(value: 'cancel', child: Text('Cancel')),
      PopupMenuItem(
        value: 'delete',
        enabled: !appointment.isPlacena,
        child: Text(
          'Delete permanently',
          style: TextStyle(
            color: appointment.isPlacena
                ? Colors.white.withValues(alpha: 0.35)
                : const Color(0xFFFF5E7A),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ],
  );
}

class _LargeAvatar extends StatelessWidget {
  const _LargeAvatar({required this.name});
  final String name;
  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 42,
    backgroundColor: NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.45),
    child: Text(
      name.split(' ').take(2).map((p) => p[0]).join().toUpperCase(),
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    this.value,
    this.helper,
    this.customValue,
  });
  final IconData icon;
  final String label;
  final String? value, helper;
  final Widget? customValue;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      border: Border(
        top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: NuaLuxuryTokens.lavenderWhisper),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.46),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              customValue ??
                  Text(
                    value ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
              if (helper != null)
                Text(
                  helper!,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.46),
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ClientHistoryCard extends StatelessWidget {
  const _ClientHistoryCard({
    required this.total,
    required this.spent,
    required this.last,
    required this.history,
  });
  final int total;
  final double spent;
  final String last;
  final List<RezervacijaPovijestItem> history;
  @override
  Widget build(BuildContext context) => LuxuryGlassPanel(
    borderRadius: 20,
    opacity: 0.24,
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Client History',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => _showHistory(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  'View All',
                  style: TextStyle(
                    color: NuaLuxuryTokens.champagneGold,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _HistoryMetric('Total Appointments', '$total'),
        _HistoryMetric('Total Spent', '${spent.toStringAsFixed(0)} KM'),
        _HistoryMetric('Last Appointment', last),
      ],
    ),
  );

  void _showHistory(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Client History'),
        content: SizedBox(
          width: 520,
          child: history.isEmpty
              ? const Text('No previous appointments.')
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final item in history.take(12))
                      ListTile(
                        leading: Icon(
                          item.isOtkazana
                              ? Icons.cancel_outlined
                              : item.isPotvrdjena
                              ? Icons.check_circle_outline
                              : Icons.schedule_outlined,
                        ),
                        title: Text(item.uslugaNaziv ?? 'Spa appointment'),
                        subtitle: Text(
                          item.datumRezervacije
                              .toLocal()
                              .toString()
                              .split('.')
                              .first,
                        ),
                        trailing: Text(item.isPlacena ? 'Paid' : 'Unpaid'),
                      ),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _HistoryMetric extends StatelessWidget {
  const _HistoryMetric(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.52)),
          ),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
    ),
  );
}

class _BottomEditBar extends StatelessWidget {
  const _BottomEditBar({
    required this.appointment,
    required this.onEdit,
    required this.onConfirmToggle,
    required this.onCancel,
    required this.onDelete,
  });
  final Rezervacija? appointment;
  final VoidCallback? onEdit;
  final ValueChanged<Rezervacija> onConfirmToggle;
  final ValueChanged<Rezervacija> onCancel;
  final ValueChanged<Rezervacija> onDelete;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(
        child: _GradientButton(
          label: 'Edit Appointment',
          onTap: onEdit ?? () {},
          height: 58,
          borderRadius: 18,
          showIcon: false,
        ),
      ),
      const SizedBox(width: 12),
      _MoreMenuButton(
        enabled: appointment != null,
        onSelected: (v) {
          final r = appointment;
          if (r == null) return;
          if (v == 'toggle') onConfirmToggle(r);
          if (v == 'cancel') onCancel(r);
          if (v == 'delete') onDelete(r);
        },
        itemBuilder: (ctx) {
          final r = appointment;
          final paid = r?.isPlacena ?? true;
          return [
            const PopupMenuItem(value: 'toggle', child: Text('Confirm / Pending')),
            const PopupMenuItem(value: 'cancel', child: Text('Cancel')),
            PopupMenuItem(
              value: 'delete',
              enabled: !paid,
              child: Text(
                'Delete permanently',
                style: TextStyle(
                  color: paid
                      ? Colors.white.withValues(alpha: 0.35)
                      : const Color(0xFFFF5E7A),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ];
        },
      ),
    ],
  );
}

class _MoreMenuButton extends StatefulWidget {
  const _MoreMenuButton({
    required this.enabled,
    required this.onSelected,
    required this.itemBuilder,
  });

  final bool enabled;
  final ValueChanged<String> onSelected;
  final List<PopupMenuEntry<String>> Function(BuildContext) itemBuilder;

  @override
  State<_MoreMenuButton> createState() => _MoreMenuButtonState();
}

class _MoreMenuButtonState extends State<_MoreMenuButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: widget.enabled && _hover ? 0.1 : 0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(
              alpha: widget.enabled && _hover ? 0.18 : 0.08,
            ),
          ),
          boxShadow: widget.enabled && _hover
              ? [
                  BoxShadow(
                    color: _ApptUi.purple.withValues(alpha: 0.25),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: PopupMenuButton<String>(
          padding: EdgeInsets.zero,
          enabled: widget.enabled,
          color: NuaLuxuryTokens.voidViolet,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          onSelected: widget.onSelected,
          itemBuilder: widget.itemBuilder,
          icon: Icon(
            Icons.more_horiz_rounded,
            color: Colors.white.withValues(alpha: widget.enabled ? 0.85 : 0.35),
          ),
        ),
      ),
    );
  }
}

class _AdminAppointmentDraft {
  const _AdminAppointmentDraft({
    required this.clientId,
    required this.dateTime,
    required this.serviceId,
    required this.therapistId,
  });

  final int clientId;
  final DateTime dateTime;
  final int serviceId;
  final int therapistId;
}

class _AdminAppointmentCreateDialog extends StatefulWidget {
  const _AdminAppointmentCreateDialog({
    required this.data,
    this.initialZaposlenikId,
  });

  final _AppointmentsData data;
  final int? initialZaposlenikId;

  @override
  State<_AdminAppointmentCreateDialog> createState() =>
      _AdminAppointmentCreateDialogState();
}

class _AdminAppointmentCreateDialogState
    extends State<_AdminAppointmentCreateDialog> {
  late DateTime _dateTime = DateTime.now().add(const Duration(hours: 1));
  late int? _clientId;
  late int? _serviceId;
  late int? _therapistId;

  @override
  void initState() {
    super.initState();
    final d = widget.data;
    _clientId = d.clients.isEmpty ? null : d.clients.first.id;
    _serviceId = d.services.isEmpty ? null : d.services.first.id;
    final pre = widget.initialZaposlenikId;
    if (pre != null && d.therapists.any((t) => t.id == pre)) {
      _therapistId = pre;
    } else {
      _therapistId = d.therapists.isEmpty ? null : d.therapists.first.id;
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('New Appointment'),
    content: SizedBox(
      width: 560,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<int>(
            value: _clientId,
            decoration: const InputDecoration(labelText: 'Client'),
            items: [
              for (final client in widget.data.clients)
                DropdownMenuItem(
                  value: client.id,
                  child: Text(
                    client.punoIme.isEmpty ? client.email : client.punoIme,
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _clientId = v),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.schedule_outlined),
            title: Text(_dateTime.toLocal().toString().split('.').first),
            subtitle: const Text('Date & time'),
            onTap: _pickDateTime,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _serviceId,
            decoration: const InputDecoration(labelText: 'Service'),
            items: [
              for (final s in widget.data.services)
                DropdownMenuItem(
                  value: s.id,
                  child: Text('${s.naziv} · ${s.trajanjeMinuta} min'),
                ),
            ],
            onChanged: (v) => setState(() => _serviceId = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _therapistId,
            decoration: const InputDecoration(labelText: 'Therapist'),
            items: [
              for (final t in widget.data.therapists)
                DropdownMenuItem(
                  value: t.id,
                  child: Text('${t.ime} ${t.prezime}'),
                ),
            ],
            onChanged: (v) => setState(() => _therapistId = v),
          ),
          if (widget.data.clients.isEmpty ||
              widget.data.services.isEmpty ||
              widget.data.therapists.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 14),
              child: Text(
                'Clients, services and therapists must be loaded before creating an appointment.',
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed:
            _clientId == null || _serviceId == null || _therapistId == null
            ? null
            : () => Navigator.pop(
                context,
                _AdminAppointmentDraft(
                  clientId: _clientId!,
                  dateTime: _dateTime,
                  serviceId: _serviceId!,
                  therapistId: _therapistId!,
                ),
              ),
        child: const Text('Create'),
      ),
    ],
  );

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateTime,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );
    if (time == null || !mounted) return;
    setState(
      () => _dateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }
}

class _AppointmentEditDraft {
  const _AppointmentEditDraft({
    required this.dateTime,
    required this.serviceId,
    required this.therapistId,
    required this.isVip,
  });
  final DateTime dateTime;
  final int serviceId, therapistId;
  final bool isVip;
}

class _AppointmentEditDialog extends StatefulWidget {
  const _AppointmentEditDialog({
    required this.appointment,
    required this.therapists,
    required this.services,
  });
  final Rezervacija appointment;
  final List<Zaposlenik> therapists;
  final List<Usluga> services;
  @override
  State<_AppointmentEditDialog> createState() => _AppointmentEditDialogState();
}

class _AppointmentEditDialogState extends State<_AppointmentEditDialog> {
  late DateTime _dateTime = widget.appointment.datumRezervacije;
  late int? _serviceId = _initialServiceId();
  late int? _therapistId = _initialTherapistId();
  late bool _isVip = widget.appointment.isVip;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit Appointment'),
    content: SizedBox(
      width: 520,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.schedule_outlined),
            title: Text(_dateTime.toLocal().toString().split('.').first),
            onTap: _pickDateTime,
          ),
          DropdownButtonFormField<int>(
            value: _serviceId,
            decoration: const InputDecoration(labelText: 'Service'),
            items: [
              for (final s in widget.services)
                DropdownMenuItem(value: s.id, child: Text(s.naziv)),
            ],
            onChanged: (v) => setState(() => _serviceId = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _therapistId,
            decoration: const InputDecoration(labelText: 'Therapist'),
            items: [
              for (final t in widget.therapists)
                DropdownMenuItem(
                  value: t.id,
                  child: Text('${t.ime} ${t.prezime}'),
                ),
            ],
            onChanged: (v) => setState(() => _therapistId = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('VIP appointment'),
            value: _isVip,
            onChanged: (v) => setState(() => _isVip = v),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _serviceId == null || _therapistId == null
            ? null
            : () => Navigator.pop(
                context,
                _AppointmentEditDraft(
                  dateTime: _dateTime,
                  serviceId: _serviceId!,
                  therapistId: _therapistId!,
                  isVip: _isVip,
                ),
              ),
        child: const Text('Save'),
      ),
    ],
  );

  int? _initialServiceId() {
    if (widget.appointment.uslugaId > 0) {
      for (final service in widget.services) {
        if (service.id == widget.appointment.uslugaId) return service.id;
      }
    }
    for (final service in widget.services) {
      if (service.naziv == widget.appointment.uslugaNaziv) return service.id;
    }
    return widget.services.isEmpty ? null : widget.services.first.id;
  }

  int? _initialTherapistId() {
    if (widget.appointment.zaposlenikId > 0) {
      for (final therapist in widget.therapists) {
        if (therapist.id == widget.appointment.zaposlenikId) {
          return therapist.id;
        }
      }
    }
    for (final therapist in widget.therapists) {
      if (widget.appointment.zaposlenikIme?.contains(therapist.ime) == true) {
        return therapist.id;
      }
    }
    return widget.therapists.isEmpty ? null : widget.therapists.first.id;
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateTime,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );
    if (time == null || !mounted) return;
    setState(
      () => _dateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }
}

class _AppointmentsData {
  const _AppointmentsData({
    required this.reservations,
    required this.therapists,
    required this.services,
    required this.clients,
  });
  const _AppointmentsData.empty()
    : reservations = const [],
      therapists = const [],
      services = const [],
      clients = const [];
  final List<Rezervacija> reservations;
  final List<Zaposlenik> therapists;
  final List<Usluga> services;
  final List<AdminClientRow> clients;
}
