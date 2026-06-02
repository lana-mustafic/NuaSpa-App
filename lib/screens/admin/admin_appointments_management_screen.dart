import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/api/services/api_service.dart';
import '../../core/format/km_format.dart';
import '../../core/reservations/cancel_rezervacija_messages.dart';
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
      _api.getRezervacijeFilteredAll(includeOtkazane: true),
      _api.getZaposlenici(),
      _api.getUsluge(),
      _api.getAdminClientsAll(pageSize: 100),
    ]);
    final reservations = results[0] as List<Rezervacija>;
    reservations.sort(
      (a, b) => b.datumRezervacije.compareTo(a.datumRezervacije),
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

        return _ApptScrollbarTheme(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF07040F), Color(0xFF120A24)],
              ),
            ),
            child: Scrollbar(
              controller: _mainScrollController,
              child: SingleChildScrollView(
                controller: _mainScrollController,
                primary: false,
                          padding: const EdgeInsets.fromLTRB(28, 32, 28, 40),
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
                      onServiceChanged: (v) => setState(() => _serviceId = v),
                      onStatusChanged: (v) => setState(() => _status = v),
                      onViewChanged: (v) => setState(() => _view = v),
                      onNew: () => _openCreate(data),
                    ),
                    const SizedBox(height: 22),
                    _AppointmentsSummaryBar(
                      reservations: data.reservations,
                    ),
                    const SizedBox(height: 22),
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
                            services: data.services,
                            onViewDetails: (r) =>
                                _showAppointmentDetails(r, data.services),
                            onEdit: _edit,
                            onConfirmToggle: _toggleConfirmed,
                            onComplete: _complete,
                            onCancel: _cancel,
                          ),
                  ],
                ),
              ),
            ),
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
          _therapistId == null || r.zaposlenikId == _therapistId;
      final matchesService = _serviceId == null || r.uslugaId == _serviceId;
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
  final Map<int, String> _lastServices = {};
  final Map<int, String> _lastTherapists = {};

  Widget _appointmentDialogOverlay({
    required Animation<double> animation,
    required Widget dialog,
  }) {
    return Stack(
      fit: StackFit.expand,
      children: [
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: const SizedBox.expand(),
        ),
        FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
              child: dialog,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openCreate(_AppointmentsData data) async {
    final prefillZaposlenikId =
        context.read<DesktopNav>().takeAppointmentPrefillZaposlenikId();
    final draft = await showGeneralDialog<_AdminAppointmentDraft>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return _appointmentDialogOverlay(
          animation: animation,
          dialog: _AdminAppointmentCreateDialog(
            data: data,
            initialZaposlenikId: prefillZaposlenikId,
          ),
        );
      },
    );
    if (draft == null || !mounted) return;
    final created = await _api.createRezervacija(
      korisnikId: draft.clientId,
      datumRezervacije: draft.dateTime,
      uslugaId: draft.serviceId,
      zaposlenikId: draft.therapistId,
      isVip: draft.isVip,
    );
    if (!mounted) return;
    _toast(
      created == null
          ? 'Unable to create appointment.'
          : 'Appointment created.',
    );
    if (created != null) {
      setState(() {
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
    _toast(ok ? 'Status updated.' : 'Unable to update status.');
    if (ok) _reload();
  }

  Future<void> _complete(Rezervacija r) async {
    final ok = await _api.completeRezervacija(r.id);
    if (!mounted) return;
    _toast(ok ? 'Appointment marked as completed.' : 'Unable to complete.');
    if (ok) _reload();
  }

  Future<void> _cancel(Rezervacija r) async {
    final reasonCtrl = TextEditingController();
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel appointment?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (r.isPlacena)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Paid booking — cancellation includes a Stripe refund.',
                  style: TextStyle(color: Colors.amber.shade200),
                ),
              ),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Cancellation reason',
                hintText: 'Reason is required',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    final reason = reasonCtrl.text.trim();
    if (reason.isEmpty) {
      _toast('Cancellation reason is required.');
      return;
    }
    final result = await _api.cancelRezervacija(
      r.id,
      razlogOtkaza: reason,
    );
    if (!mounted) return;
    _toast(
      result?.otkazana == true
          ? cancelRezervacijaSuccessMessage(result!)
          : 'Cancellation failed.',
    );
    if (result?.otkazana == true) _reload();
  }

  Future<void> _edit(Rezervacija r) async {
    final data = await _future;
    if (!mounted) return;
    final draft = await showGeneralDialog<_AdminAppointmentDraft>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return _appointmentDialogOverlay(
          animation: animation,
          dialog: _AdminAppointmentCreateDialog(
            data: data,
            appointment: r,
          ),
        );
      },
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
    _toast(
      updated == null
          ? 'Unable to update appointment.'
          : 'Appointment updated.',
    );
    if (updated != null) {
      _reload();
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showAppointmentDetails(Rezervacija r, List<Usluga> services) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (dialogContext) => _AppointmentDetailsModal(
        appointment: r,
        services: services,
        onEdit: () {
          Navigator.pop(dialogContext);
          _edit(r);
        },
        onConfirmToggle: (appt) {
          Navigator.pop(dialogContext);
          _toggleConfirmed(appt);
        },
        onComplete: (appt) {
          Navigator.pop(dialogContext);
          _complete(appt);
        },
        onCancel: (appt) {
          Navigator.pop(dialogContext);
          _cancel(appt);
        },
      ),
    );
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

  static const double tableDataRowHeight = 68;
  static const double tableRadius = 20;
  static const Color tableBg = Color(0x06FFFFFF);
  static const Color tableBorder = Color(0x14FFFFFF);

  static const double filterControlHeight = 40;
  static const double filterDropdownWidth = 168;
  static const double filterStatusWidth = 148;
}

/// Compact appointment create/edit modal (fits without scrolling).
abstract final class _ApptDialogLayout {
  static const double maxWidth = 440;
  static const double minWidth = 380;
  static const EdgeInsets padding = EdgeInsets.fromLTRB(20, 18, 20, 18);
  static const double borderRadius = 20;
  static const double fieldGap = 6;
  static const double sectionGap = 12;
  static const double fieldHeight = 56;
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

class _AppointmentsSummaryBar extends StatelessWidget {
  const _AppointmentsSummaryBar({required this.reservations});

  final List<Rezervacija> reservations;

  static bool _isToday(DateTime d) {
    final l = d.toLocal();
    final n = DateTime.now();
    return l.year == n.year && l.month == n.month && l.day == n.day;
  }

  @override
  Widget build(BuildContext context) {
    final today = reservations.where((r) => _isToday(r.datumRezervacije)).toList();
    final total = today.length;
    final confirmed =
        today.where((r) => r.isPotvrdjena && !r.isOtkazana).length;
    final pending =
        today.where((r) => !r.isPotvrdjena && !r.isOtkazana).length;
    final cancelled = today.where((r) => r.isOtkazana).length;

    final label = total == 1 ? 'appointment' : 'appointments';
    final text =
        'Today: $total $label • Confirmed: $confirmed • Pending: $pending • Cancelled: $cancelled';

    return _ApptGlass(
      radius: 17,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      minHeight: 52,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            height: 1.35,
            color: _ApptUi.textPrimary.withValues(alpha: 0.88),
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}

class _AppointmentsTable extends StatelessWidget {
  const _AppointmentsTable({
    required this.reservations,
    required this.services,
    required this.onViewDetails,
    required this.onEdit,
    required this.onConfirmToggle,
    required this.onComplete,
    required this.onCancel,
  });

  final List<Rezervacija> reservations;
  final List<Usluga> services;
  final ValueChanged<Rezervacija> onViewDetails;
  final ValueChanged<Rezervacija> onEdit;
  final ValueChanged<Rezervacija> onConfirmToggle;
  final ValueChanged<Rezervacija> onComplete;
  final ValueChanged<Rezervacija> onCancel;

  @override
  Widget build(BuildContext context) {
    final sorted = [...reservations]
      ..sort((a, b) => a.datumRezervacije.compareTo(b.datumRezervacije));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _ApptUi.tableBg,
        borderRadius: BorderRadius.circular(_ApptUi.tableRadius),
        border: Border.all(color: _ApptUi.tableBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'All Appointments',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _ApptUi.textPrimary,
                  ),
                ),
              ),
              Text(
                '${sorted.length} shown',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.42),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (sorted.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(
                children: [
                  const _ApptEmptyIllustration(
                    icon: Icons.calendar_month_outlined,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No appointments found',
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _ApptUi.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'There are no appointments for the selected date and filters.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.45,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.white.withValues(alpha: 0.08),
                      ),
                      child: DataTable(
                        headingRowHeight: 44,
                        dataRowMinHeight: _ApptUi.tableDataRowHeight,
                        dataRowMaxHeight: _ApptUi.tableDataRowHeight,
                        columnSpacing: 24,
                        horizontalMargin: 0,
                        headingTextStyle: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                        dataTextStyle: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _ApptUi.textPrimary,
                        ),
                        columns: const [
                          DataColumn(label: Text('TIME')),
                          DataColumn(label: Text('CLIENT')),
                          DataColumn(label: Text('SERVICE')),
                          DataColumn(label: Text('THERAPIST')),
                          DataColumn(label: Text('STATUS')),
                          DataColumn(label: Text('ACTIONS')),
                        ],
                        rows: [
                          for (final r in sorted)
                            DataRow(
                              cells: [
                                DataCell(_TimeTableCell(datetime: r.datumRezervacije)),
                                DataCell(Text(
                                  _clientName(r),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )),
                                DataCell(Text(
                                  r.uslugaNaziv ?? '—',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )),
                                DataCell(Text(
                                  _therapistLabel(r),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )),
                                DataCell(_ApptRowStatusBadges(rezervacija: r)),
                                DataCell(
                                  _ApptTableRowActions(
                                    appointment: r,
                                    onViewDetails: onViewDetails,
                                    onEdit: onEdit,
                                    onConfirmToggle: onConfirmToggle,
                                    onComplete: onComplete,
                                    onCancel: onCancel,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  static String _clientName(Rezervacija r) {
    final name = r.korisnikIme?.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'Guest';
  }

  static String _therapistLabel(Rezervacija r) {
    final name = r.zaposlenikIme?.trim();
    if (name != null && name.isNotEmpty) return name;
    if (r.zaposlenikId > 0) return 'Assigned';
    return 'Not assigned';
  }

  static String timeLabel(DateTime d) {
    final l = d.toLocal();
    final hour = l.hour % 12 == 0 ? 12 : l.hour % 12;
    return '$hour:${l.minute.toString().padLeft(2, '0')} ${l.hour >= 12 ? 'PM' : 'AM'}';
  }

  static String shortDateLabel(DateTime d) {
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
    return '${months[l.month - 1]} ${l.day}';
  }

  static bool isToday(DateTime d) {
    final l = d.toLocal();
    final n = DateTime.now();
    return l.year == n.year && l.month == n.month && l.day == n.day;
  }

  static String statusLabel(Rezervacija r) {
    switch (r.status) {
      case 'Completed':
        return 'Completed';
      case 'Cancelled':
        return 'Cancelled';
      case 'Confirmed':
        return 'Confirmed';
      default:
        break;
    }
    if (r.isOtkazana) return 'Cancelled';
    if (r.isPotvrdjena) return 'Confirmed';
    return 'Pending';
  }

  static Color statusColor(Rezervacija r) {
    switch (statusLabel(r)) {
      case 'Pending':
        return const Color(0xFFF5B942);
      case 'Confirmed':
        return const Color(0xFF2DD4BF);
      case 'Cancelled':
        return const Color(0xFFE87997);
      case 'Completed':
        return const Color(0xFFC8B6E8);
      default:
        return _ApptUi.lavender;
    }
  }

  static String categoryLabel(String? service) =>
      (service ?? '').toLowerCase().contains('massage')
      ? 'Relaxation'
      : 'Wellness';

  static String serviceCategoryLabel(List<Usluga> services, Rezervacija r) {
    for (final s in services) {
      if (s.id == r.uslugaId) {
        final k = s.kategorija.trim();
        if (k.isNotEmpty) return k;
        break;
      }
    }
    return categoryLabel(r.uslugaNaziv);
  }
}

class _ApptTableRowActions extends StatelessWidget {
  const _ApptTableRowActions({
    required this.appointment,
    required this.onViewDetails,
    required this.onEdit,
    required this.onConfirmToggle,
    required this.onComplete,
    required this.onCancel,
  });

  final Rezervacija appointment;
  final ValueChanged<Rezervacija> onViewDetails;
  final ValueChanged<Rezervacija> onEdit;
  final ValueChanged<Rezervacija> onConfirmToggle;
  final ValueChanged<Rezervacija> onComplete;
  final ValueChanged<Rezervacija> onCancel;

  @override
  Widget build(BuildContext context) {
    final r = appointment;
    final canComplete = !r.isOtkazana && r.status == 'Confirmed';
    final canManageStatus = !r.isOtkazana;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ApptTableActionIcon(
          tooltip: 'View details',
          icon: Icons.visibility_outlined,
          onPressed: () => onViewDetails(r),
        ),
        _ApptTableActionIcon(
          tooltip: 'Edit appointment',
          icon: Icons.edit_outlined,
          onPressed: () => onEdit(r),
        ),
        if (canManageStatus)
          _ApptTableActionIcon(
            tooltip: 'Cancel appointment',
            icon: Icons.cancel_outlined,
            color: const Color(0xFFE87997),
            onPressed: () => onCancel(r),
          ),
        if (canManageStatus || canComplete)
          _ApptOverflowMenu(
            appointment: r,
            onConfirmToggle: onConfirmToggle,
            onComplete: onComplete,
            onCancel: onCancel,
            iconColor: Colors.white.withValues(alpha: 0.72),
            includeCancelInMenu: false,
          ),
      ],
    );
  }
}

class _ApptTableActionIcon extends StatelessWidget {
  const _ApptTableActionIcon({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.color,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(
        icon,
        size: 18,
        color: color ?? Colors.white.withValues(alpha: 0.72),
      ),
      style: IconButton.styleFrom(
        minimumSize: const Size(34, 34),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _TimeTableCell extends StatelessWidget {
  const _TimeTableCell({required this.datetime});

  final DateTime datetime;

  @override
  Widget build(BuildContext context) {
    final showDate = !_AppointmentsTable.isToday(datetime);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _AppointmentsTable.timeLabel(datetime),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (showDate)
          Text(
            _AppointmentsTable.shortDateLabel(datetime),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.42),
            ),
          ),
      ],
    );
  }
}

class _ApptRowStatusBadges extends StatelessWidget {
  const _ApptRowStatusBadges({required this.rezervacija});

  final Rezervacija rezervacija;

  @override
  Widget build(BuildContext context) {
    final statusNorm = rezervacija.status.trim().toLowerCase();
    final isCompleted =
        statusNorm == 'completed' || statusNorm == 'zavrsena';

    late final String primary;
    late final Color color;
    if (rezervacija.isOtkazana) {
      primary = 'Cancelled';
      color = const Color(0xFFE87997);
    } else if (isCompleted) {
      primary = 'Completed';
      color = const Color(0xFF94A3B8);
    } else if (!rezervacija.isPotvrdjena) {
      primary = 'Pending';
      color = const Color(0xFFF5B942);
    } else {
      primary = 'Confirmed';
      color = const Color(0xFF2DD4BF);
    }

    final chips = <Widget>[
      _ApptStatusChip(label: primary, color: color),
      if (rezervacija.isVip)
        const _ApptStatusChip(
          label: 'VIP',
          color: NuaLuxuryTokens.champagneGold,
        ),
      if (rezervacija.isPlacena)
        const _ApptStatusChip(label: 'Paid', color: Color(0xFF2DD4BF))
      else if (!rezervacija.isOtkazana)
        const _ApptStatusChip(label: 'Unpaid', color: Color(0xFFF5B942)),
    ];

    return Wrap(spacing: 6, runSpacing: 4, children: chips);
  }
}

class _ApptStatusChip extends StatelessWidget {
  const _ApptStatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _AppointmentDetailsModal extends StatelessWidget {
  const _AppointmentDetailsModal({
    required this.appointment,
    required this.services,
    required this.onEdit,
    required this.onConfirmToggle,
    required this.onComplete,
    required this.onCancel,
  });

  final Rezervacija appointment;
  final List<Usluga> services;
  final VoidCallback onEdit;
  final ValueChanged<Rezervacija> onConfirmToggle;
  final ValueChanged<Rezervacija> onComplete;
  final ValueChanged<Rezervacija> onCancel;

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.8;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFA120A24),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: _ApptUi.purple.withValues(alpha: 0.22),
                blurRadius: 48,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 80,
                offset: const Offset(0, 24),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Appointment Details',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: _ApptUi.textPrimary,
                        ),
                      ),
                    ),
                    _DetailsModalMoreMenu(
                      appointment: appointment,
                      onConfirmToggle: onConfirmToggle,
                      onComplete: onComplete,
                      onCancel: onCancel,
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxH - 140),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                    child: _AppointmentDetailsContent(
                      appointment: appointment,
                      services: services,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit Appointment'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _ApptUi.purple,
                        foregroundColor: Colors.white,
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ApptOverflowMenu extends StatelessWidget {
  const _ApptOverflowMenu({
    required this.appointment,
    required this.onConfirmToggle,
    required this.onComplete,
    required this.onCancel,
    this.iconColor,
    this.includeCancelInMenu = true,
  });

  final Rezervacija appointment;
  final ValueChanged<Rezervacija> onConfirmToggle;
  final ValueChanged<Rezervacija> onComplete;
  final ValueChanged<Rezervacija> onCancel;
  final Color? iconColor;
  final bool includeCancelInMenu;

  @override
  Widget build(BuildContext context) {
    final canComplete =
        !appointment.isOtkazana && appointment.status == 'Confirmed';
    return PopupMenuButton<String>(
      color: NuaLuxuryTokens.voidViolet,
      padding: EdgeInsets.zero,
      icon: Icon(
        Icons.more_horiz_rounded,
        size: 20,
        color: iconColor ?? Colors.white.withValues(alpha: 0.65),
      ),
      tooltip: 'More actions',
      onSelected: (v) {
        if (v == 'toggle') onConfirmToggle(appointment);
        if (v == 'complete') onComplete(appointment);
        if (v == 'cancel') onCancel(appointment);
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'toggle',
          child: Text(
            appointment.isPotvrdjena ? 'Mark as pending' : 'Confirm appointment',
          ),
        ),
        if (canComplete)
          const PopupMenuItem(
            value: 'complete',
            child: Text('Mark as completed'),
          ),
        if (includeCancelInMenu && !appointment.isOtkazana)
          const PopupMenuItem(
            value: 'cancel',
            child: Text('Cancel appointment'),
          ),
      ],
    );
  }
}

class _DetailsModalMoreMenu extends StatelessWidget {
  const _DetailsModalMoreMenu({
    required this.appointment,
    required this.onConfirmToggle,
    required this.onComplete,
    required this.onCancel,
  });

  final Rezervacija appointment;
  final ValueChanged<Rezervacija> onConfirmToggle;
  final ValueChanged<Rezervacija> onComplete;
  final ValueChanged<Rezervacija> onCancel;

  @override
  Widget build(BuildContext context) {
    return _ApptOverflowMenu(
      appointment: appointment,
      onConfirmToggle: onConfirmToggle,
      onComplete: onComplete,
      onCancel: onCancel,
    );
  }
}

class _AppointmentDetailsContent extends StatelessWidget {
  const _AppointmentDetailsContent({
    required this.appointment,
    required this.services,
  });

  final Rezervacija appointment;
  final List<Usluga> services;

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
        final phone = appointment.korisnikTelefon?.trim();
        final email = appointment.korisnikEmail?.trim();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailsSectionTitle(title: 'Client information'),
            _DetailRow(
              icon: Icons.person_outline,
              label: 'Name',
              value: appointment.korisnikIme?.trim().isNotEmpty == true
                  ? appointment.korisnikIme!.trim()
                  : 'Guest',
            ),
            _DetailRow(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: phone != null && phone.isNotEmpty ? phone : '—',
            ),
            _DetailRow(
              icon: Icons.email_outlined,
              label: 'Email',
              value: email != null && email.isNotEmpty ? email : '—',
            ),
            if (appointment.isVip || appointment.premiumKlijent)
              Padding(
                padding: const EdgeInsets.only(left: 30, bottom: 8),
                child: Wrap(
                  spacing: 6,
                  children: [
                    if (appointment.isVip)
                      const _StatusBadge(
                        label: 'VIP',
                        color: NuaLuxuryTokens.champagneGold,
                      ),
                    if (appointment.premiumKlijent)
                      const _StatusBadge(
                        label: 'Loyal client',
                        color: NuaLuxuryTokens.champagneGold,
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            _DetailsSectionTitle(title: 'Appointment information'),
            _DetailRow(
              icon: Icons.event_outlined,
              label: 'Date & time',
              value:
                  '${_date(appointment.datumRezervacije)} at ${_AppointmentsTable.timeLabel(appointment.datumRezervacije)}',
            ),
            _DetailRow(
              icon: Icons.spa_outlined,
              label: 'Service',
              value: appointment.uslugaNaziv ?? 'Spa Ritual',
            ),
            _DetailRow(
              icon: Icons.category_outlined,
              label: 'Category',
              value: _AppointmentsTable.serviceCategoryLabel(
                services,
                appointment,
              ),
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
                label: _AppointmentsTable.statusLabel(appointment),
                color: _AppointmentsTable.statusColor(appointment),
              ),
            ),
            _DetailRow(
              icon: Icons.payments_outlined,
              label: 'Payment',
              customValue: _StatusBadge(
                label: appointment.isPlacena ? 'Paid' : 'Unpaid',
                color: appointment.isPlacena
                    ? const Color(0xFF2DD4BF)
                    : const Color(0xFFF5B942),
              ),
            ),
            _DetailRow(
              icon: Icons.sell_outlined,
              label: 'Price',
              value: formatKm(appointment.uslugaCijena),
            ),
            const SizedBox(height: 8),
            _DetailsSectionTitle(title: 'Therapist'),
            _DetailRow(
              icon: Icons.badge_outlined,
              label: 'Assigned therapist',
              value: _therapistDetailLabel(appointment),
            ),
            const SizedBox(height: 8),
            _DetailsSectionTitle(title: 'Notes'),
            _DetailRow(
              icon: Icons.notes_outlined,
              label: 'Client notes',
              value: appointment.napomenaZaTerapeuta?.trim().isNotEmpty == true
                  ? appointment.napomenaZaTerapeuta!.trim()
                  : 'No notes on file.',
            ),
            if (appointment.isOtkazana &&
                appointment.razlogOtkaza?.trim().isNotEmpty == true)
              _DetailRow(
                icon: Icons.cancel_outlined,
                label: 'Cancellation reason',
                value: appointment.razlogOtkaza!.trim(),
              ),
            const SizedBox(height: 12),
            _DetailsSectionTitle(title: 'Client history'),
            _ClientHistoryCard(
              total: history.length + 1,
              spent: spent,
              last: history.isEmpty
                  ? '—'
                  : _date(history.first.datumRezervacije),
              history: history,
            ),
          ],
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

  static String _therapistDetailLabel(Rezervacija r) {
    final name = r.zaposlenikIme?.trim();
    if (name != null && name.isNotEmpty) return name;
    if (r.zaposlenikId > 0) return 'Assigned';
    return 'Not assigned';
  }
}

class _DetailsSectionTitle extends StatelessWidget {
  const _DetailsSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
          color: Colors.white.withValues(alpha: 0.52),
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        constraints: const BoxConstraints(minWidth: 72),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.38)),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.visible,
          softWrap: false,
          style: GoogleFonts.inter(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 11.5,
            letterSpacing: 0.15,
          ),
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

class _AdminAppointmentDraft {
  const _AdminAppointmentDraft({
    this.clientId,
    required this.dateTime,
    required this.serviceId,
    required this.therapistId,
    this.isVip = false,
  });

  /// Set when creating; null when editing (client unchanged).
  final int? clientId;
  final DateTime dateTime;
  final int serviceId;
  final int therapistId;
  final bool isVip;
}

class _AdminAppointmentCreateDialog extends StatefulWidget {
  const _AdminAppointmentCreateDialog({
    required this.data,
    this.initialZaposlenikId,
    this.appointment,
  });

  final _AppointmentsData data;
  final int? initialZaposlenikId;

  /// When set, dialog opens in edit mode with the same layout as create.
  final Rezervacija? appointment;

  @override
  State<_AdminAppointmentCreateDialog> createState() =>
      _AdminAppointmentCreateDialogState();
}

class _AdminAppointmentCreateDialogState
    extends State<_AdminAppointmentCreateDialog> {
  final ApiService _api = ApiService();

  late DateTime _dateTime;
  late int? _clientId;
  late int? _serviceId;
  late int? _therapistId;
  late bool _isVip;
  String? _formError;

  List<Zaposlenik> _eligibleTherapists = [];
  bool _loadingTherapists = false;

  bool get _isEdit => widget.appointment != null;

  static const _months = [
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

  bool get _canSubmit {
    if (_serviceId == null || _therapistId == null) return false;
    if (_isEdit) return true;
    return _clientId != null;
  }

  @override
  void initState() {
    super.initState();
    final d = widget.data;
    final appt = widget.appointment;
    if (appt != null) {
      _dateTime = appt.datumRezervacije;
      _clientId = appt.korisnikId > 0 ? appt.korisnikId : null;
      _serviceId = _initialServiceId(appt, d.services);
      _therapistId = _initialTherapistId(appt, d.therapists);
      _isVip = appt.isVip;
    } else {
      _dateTime = DateTime.now().add(const Duration(hours: 1));
      _clientId = d.clients.isEmpty ? null : d.clients.first.id;
      _serviceId = d.services.isEmpty ? null : d.services.first.id;
      final pre = widget.initialZaposlenikId;
      if (pre != null && d.therapists.any((t) => t.id == pre)) {
        _therapistId = pre;
      } else {
        _therapistId = d.therapists.isEmpty ? null : d.therapists.first.id;
      }
      _isVip = false;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEligibleTherapists(preserveTherapistId: _therapistId);
    });
  }

  Future<void> _loadEligibleTherapists({int? preserveTherapistId}) async {
    final serviceId = _serviceId;
    if (serviceId == null) {
      if (!mounted) return;
      setState(() {
        _eligibleTherapists = [];
        _therapistId = null;
        _loadingTherapists = false;
      });
      return;
    }

    setState(() => _loadingTherapists = true);
    final list = await _api.getZaposleniciForService(serviceId);
    if (!mounted) return;

    int? nextTherapist = preserveTherapistId;
    if (nextTherapist != null &&
        !list.any((t) => t.id == nextTherapist)) {
      nextTherapist = list.length == 1 ? list.first.id : null;
    } else if (nextTherapist == null && list.length == 1) {
      nextTherapist = list.first.id;
    }

    setState(() {
      _eligibleTherapists = list;
      _therapistId = nextTherapist;
      _loadingTherapists = false;
    });
  }

  int? _initialServiceId(Rezervacija appt, List<Usluga> services) {
    if (appt.uslugaId > 0) {
      for (final s in services) {
        if (s.id == appt.uslugaId) return s.id;
      }
    }
    for (final s in services) {
      if (s.naziv == appt.uslugaNaziv) return s.id;
    }
    return services.isEmpty ? null : services.first.id;
  }

  int? _initialTherapistId(Rezervacija appt, List<Zaposlenik> therapists) {
    if (appt.zaposlenikId > 0) {
      for (final t in therapists) {
        if (t.id == appt.zaposlenikId) return t.id;
      }
    }
    for (final t in therapists) {
      if (appt.zaposlenikIme?.contains(t.ime) == true) return t.id;
    }
    return therapists.isEmpty ? null : therapists.first.id;
  }

  String _fmtDateTime(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour;
    final hour12 = h % 12 == 0 ? 12 : h % 12;
    final ampm = h >= 12 ? 'PM' : 'AM';
    final min = local.minute.toString().padLeft(2, '0');
    return '${_months[local.month - 1]} ${local.day}, ${local.year} at $hour12:$min $ampm';
  }

  String _clientLabel() {
    if (_isEdit) {
      final appt = widget.appointment!;
      if (appt.korisnikIme != null && appt.korisnikIme!.trim().isNotEmpty) {
        return appt.korisnikIme!.trim();
      }
      if (_clientId != null) {
        for (final c in widget.data.clients) {
          if (c.id == _clientId) {
            final name = c.punoIme.isEmpty ? c.email : c.punoIme;
            return name.isEmpty ? 'Unknown client' : name;
          }
        }
      }
      return 'Unknown client';
    }
    if (_clientId == null) return 'Select a client';
    for (final c in widget.data.clients) {
      if (c.id == _clientId) {
        final name = c.punoIme.isEmpty ? c.email : c.punoIme;
        return name.isEmpty ? 'Unknown client' : name;
      }
    }
    return 'Select a client';
  }

  String _serviceLabel() {
    if (_serviceId == null) return 'Select a service';
    for (final s in widget.data.services) {
      if (s.id == _serviceId) {
        return '${s.naziv} • ${s.trajanjeMinuta} min';
      }
    }
    return 'Select a service';
  }

  String _therapistLabel() {
    if (_loadingTherapists) return 'Loading therapists…';
    if (_therapistId == null) {
      return _eligibleTherapists.isEmpty
          ? 'No therapists for this service'
          : 'Select a therapist';
    }
    for (final t in _eligibleTherapists) {
      if (t.id == _therapistId) {
        return '${t.ime} ${t.prezime}'.trim();
      }
    }
    return 'Select a therapist';
  }

  Future<void> _pickFromList<T>({
    required String title,
    required List<({int id, String label})> options,
    required int? currentId,
    required ValueChanged<int> onPick,
  }) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: const Color(0xFF120A24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _ApptUi.textPrimary,
                ),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, i) {
                  final o = options[i];
                  final selected = o.id == currentId;
                  return ListTile(
                    title: Text(
                      o.label,
                      style: TextStyle(
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w600,
                        color: _ApptUi.textPrimary,
                      ),
                    ),
                    trailing: selected
                        ? const Icon(
                            Icons.check_rounded,
                            color: _ApptUi.purple2,
                          )
                        : null,
                    onTap: () => Navigator.pop(ctx, o.id),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) onPick(picked);
  }

  @override
  Widget build(BuildContext context) {
    final missingData = _isEdit
        ? widget.data.services.isEmpty
        : widget.data.clients.isEmpty || widget.data.services.isEmpty;

    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: _ApptDialogLayout.minWidth,
          maxWidth: _ApptDialogLayout.maxWidth,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_ApptDialogLayout.borderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xEB120A24),
                borderRadius:
                    BorderRadius.circular(_ApptDialogLayout.borderRadius),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                boxShadow: [
                  BoxShadow(
                    color: _ApptUi.purple.withValues(alpha: 0.22),
                    blurRadius: 48,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Padding(
                padding: _ApptDialogLayout.padding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: const LinearGradient(
                              colors: [_ApptUi.purple, _ApptUi.purple2],
                            ),
                          ),
                          child: const Icon(
                            Icons.event_available_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _isEdit ? 'Edit Appointment' : 'New Appointment',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: _ApptUi.textPrimary,
                            ),
                          ),
                        ),
                        _PremiumModalCloseButton(
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: _ApptDialogLayout.sectionGap),
                    _PremiumApptFieldCard(
                      icon: Icons.person_outline_rounded,
                      label: 'Client',
                      value: _clientLabel(),
                      trailing: _isEdit
                          ? Icon(
                              Icons.lock_outline_rounded,
                              color: _ApptUi.lavender.withValues(alpha: 0.5),
                            )
                          : const Icon(
                              Icons.expand_more_rounded,
                              color: Color(0x99FFFFFF),
                            ),
                      enabled: !_isEdit && widget.data.clients.isNotEmpty,
                      disabledReason: _isEdit
                          ? 'Client cannot be changed when editing an appointment.'
                          : widget.data.clients.isEmpty
                              ? 'No clients found. Create a client before adding appointments.'
                              : null,
                      onTap: _isEdit || widget.data.clients.isEmpty
                          ? null
                          : () => _pickFromList(
                                title: 'Select client',
                                currentId: _clientId,
                                options: [
                                  for (final c in widget.data.clients)
                                    (
                                      id: c.id,
                                      label: c.punoIme.isEmpty
                                          ? c.email
                                          : c.punoIme,
                                    ),
                                ],
                                onPick: (id) => setState(() {
                                  _clientId = id;
                                  _formError = null;
                                }),
                              ),
                    ),
                    const SizedBox(height: _ApptDialogLayout.fieldGap),
                    _PremiumApptFieldCard(
                      icon: Icons.schedule_rounded,
                      label: 'Date & Time',
                      value: _fmtDateTime(_dateTime),
                      trailing: Icon(
                        Icons.calendar_month_outlined,
                        color: _ApptUi.purple2.withValues(alpha: 0.9),
                      ),
                      onTap: _pickDateTime,
                    ),
                    const SizedBox(height: _ApptDialogLayout.fieldGap),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _PremiumApptFieldCard(
                            icon: Icons.spa_outlined,
                            label: 'Service',
                            value: _serviceLabel(),
                            trailing: const Icon(
                              Icons.expand_more_rounded,
                              color: Color(0x99FFFFFF),
                              size: 20,
                            ),
                            enabled: widget.data.services.isNotEmpty,
                            disabledReason: widget.data.services.isEmpty
                                ? 'No services found.'
                                : null,
                            onTap: widget.data.services.isEmpty
                                ? null
                                : () => _pickFromList(
                                      title: 'Select service',
                                      currentId: _serviceId,
                                      options: [
                                        for (final s in widget.data.services)
                                          (
                                            id: s.id,
                                            label:
                                                '${s.naziv} • ${s.trajanjeMinuta}m',
                                          ),
                                      ],
                                      onPick: (id) {
                                        setState(() {
                                          _serviceId = id;
                                          _therapistId = null;
                                          _formError = null;
                                        });
                                        _loadEligibleTherapists();
                                      },
                                    ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _PremiumApptFieldCard(
                            icon: Icons.badge_outlined,
                            label: 'Therapist',
                            value: _therapistLabel(),
                            trailing: const Icon(
                              Icons.expand_more_rounded,
                              color: Color(0x99FFFFFF),
                              size: 20,
                            ),
                            enabled: !_loadingTherapists &&
                                _eligibleTherapists.isNotEmpty,
                            disabledReason: _loadingTherapists
                                ? 'Loading therapists for this service…'
                                : _eligibleTherapists.isEmpty
                                    ? 'No therapists are assigned to perform this service.'
                                    : null,
                            onTap: _loadingTherapists ||
                                    _eligibleTherapists.isEmpty
                                ? null
                                : () => _pickFromList(
                                      title: 'Select therapist',
                                      currentId: _therapistId,
                                      options: [
                                        for (final t in _eligibleTherapists)
                                          (
                                            id: t.id,
                                            label:
                                                '${t.ime} ${t.prezime}'.trim(),
                                          ),
                                      ],
                                      onPick: (id) => setState(() {
                                        _therapistId = id;
                                        _formError = null;
                                      }),
                                    ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: _ApptDialogLayout.fieldGap),
                    _PremiumApptVipStrip(
                      value: _isVip,
                      onChanged: (v) => setState(() => _isVip = v),
                    ),
                    if (missingData) ...[
                      const SizedBox(height: 8),
                      Text(
                        _isEdit
                            ? 'Load services before editing.'
                            : 'Load clients and services before creating appointments.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                    if (_formError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _formError!,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: Color(0xFFFF6B8A),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: _ApptDialogLayout.sectionGap),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _PremiumModalCancelButton(
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 12),
                        _PremiumModalCreateButton(
                          label: _isEdit ? 'Save' : 'Create',
                          icon: _isEdit
                              ? Icons.save_rounded
                              : Icons.event_available_rounded,
                          enabled: !missingData,
                          disabledTooltip: missingData
                              ? (_isEdit
                                  ? 'Load services before editing.'
                                  : 'Load clients and services before creating appointments.')
                              : null,
                          onPressed: missingData
                              ? null
                              : () {
                                  if (!_canSubmit) {
                                    setState(() {
                                      _formError = _isEdit
                                          ? 'Select a service and therapist.'
                                          : 'Select a client, service, and therapist.';
                                    });
                                    return;
                                  }
                                  Navigator.pop(
                                    context,
                                    _AdminAppointmentDraft(
                                      clientId: _isEdit ? null : _clientId,
                                      dateTime: _dateTime,
                                      serviceId: _serviceId!,
                                      therapistId: _therapistId!,
                                      isVip: _isVip,
                                    ),
                                  );
                                },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateTime,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: NuaLuxuryTokens.softPurpleGlow,
            surface: NuaLuxuryTokens.voidViolet,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: NuaLuxuryTokens.softPurpleGlow,
            surface: NuaLuxuryTokens.voidViolet,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
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

class _PremiumApptFieldCard extends StatefulWidget {
  const _PremiumApptFieldCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.trailing,
    this.onTap,
    this.enabled = true,
    this.disabledReason,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget trailing;
  final VoidCallback? onTap;
  final bool enabled;
  final String? disabledReason;

  @override
  State<_PremiumApptFieldCard> createState() => _PremiumApptFieldCardState();
}

class _PremiumApptFieldCardState extends State<_PremiumApptFieldCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && widget.onTap != null;
    final card = MouseRegion(
      onEnter: (_) {
        if (active) setState(() => _hover = true);
      },
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: active ? widget.onTap : null,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: _ApptDialogLayout.fieldHeight,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.035),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _hover
                    ? _ApptUi.purple.withValues(alpha: 0.45)
                    : Colors.white.withValues(alpha: 0.08),
              ),
              boxShadow: _hover
                  ? [
                      BoxShadow(
                        color: _ApptUi.purple.withValues(alpha: 0.12),
                        blurRadius: 24,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: _ApptUi.purple.withValues(alpha: 0.18),
                  ),
                  child: Icon(
                    widget.icon,
                    size: 20,
                    color: _ApptUi.purple2,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _ApptUi.lavender.withValues(alpha: 0.75),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: active
                              ? _ApptUi.textPrimary
                              : _ApptUi.textPrimary.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                ),
                widget.trailing,
              ],
            ),
          ),
        ),
      ),
    );
    final reason = widget.disabledReason?.trim();
    if (!widget.enabled && reason != null && reason.isNotEmpty) {
      return Tooltip(message: reason, child: card);
    }
    return card;
  }
}

class _PremiumModalCloseButton extends StatefulWidget {
  const _PremiumModalCloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_PremiumModalCloseButton> createState() =>
      _PremiumModalCloseButtonState();
}

class _PremiumModalCloseButtonState extends State<_PremiumModalCloseButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: _hover ? 0.1 : 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
              boxShadow: _hover
                  ? [
                      BoxShadow(
                        color: _ApptUi.purple.withValues(alpha: 0.35),
                        blurRadius: 20,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              Icons.close_rounded,
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumModalCancelButton extends StatefulWidget {
  const _PremiumModalCancelButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_PremiumModalCancelButton> createState() =>
      _PremiumModalCancelButtonState();
}

class _PremiumModalCancelButtonState extends State<_PremiumModalCancelButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 100,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: _hover ? 0.08 : 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumApptVipStrip extends StatelessWidget {
  const _PremiumApptVipStrip({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.star_rounded,
                size: 18,
                color: value ? _ApptUi.purple2 : _ApptUi.lavender,
              ),
              const SizedBox(width: 8),
              Text(
                'VIP appointment',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _ApptUi.lavender.withValues(alpha: 0.85),
                ),
              ),
              const Spacer(),
              Text(
                value ? 'On' : 'Off',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: value
                      ? _ApptUi.purple2
                      : _ApptUi.textPrimary.withValues(alpha: 0.5),
                ),
              ),
              Switch.adaptive(
                value: value,
                onChanged: onChanged,
                activeThumbColor: _ApptUi.purple2,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumModalCreateButton extends StatefulWidget {
  const _PremiumModalCreateButton({
    required this.enabled,
    required this.onPressed,
    this.disabledTooltip,
    this.label = 'Create Appointment',
    this.icon = Icons.event_available_rounded,
  });

  final bool enabled;
  final VoidCallback? onPressed;
  final String? disabledTooltip;
  final String label;
  final IconData icon;

  @override
  State<_PremiumModalCreateButton> createState() =>
      _PremiumModalCreateButtonState();
}

class _PremiumModalCreateButtonState extends State<_PremiumModalCreateButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && widget.onPressed != null;
    final button = MouseRegion(
      onEnter: (_) {
        if (active) setState(() => _hover = true);
      },
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                colors: active
                    ? const [_ApptUi.purple, _ApptUi.purple2]
                    : [
                        _ApptUi.purple.withValues(alpha: 0.35),
                        _ApptUi.purple2.withValues(alpha: 0.35),
                      ],
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: _ApptUi.purple.withValues(
                          alpha: _hover ? 0.55 : 0.38,
                        ),
                        blurRadius: _hover ? 32 : 22,
                        offset: Offset(0, _hover ? 10 : 6),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.icon,
                  color: Colors.white.withValues(alpha: active ? 1 : 0.5),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withValues(alpha: active ? 1 : 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final tip = widget.disabledTooltip?.trim();
    if (!widget.enabled && tip != null && tip.isNotEmpty) {
      return Tooltip(message: tip, child: button);
    }
    return button;
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
