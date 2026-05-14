import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _future = _load();
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
        final filtered = _filter(data.reservations, query);
        final selected =
            _selected != null && filtered.any((r) => r.id == _selected!.id)
            ? _selected!
            : (filtered.isNotEmpty ? filtered.first : null);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 12, 22, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FilterBar(
                      selectedDate: _selectedDate,
                      therapists: data.therapists,
                      services: data.services,
                      therapistId: _therapistId,
                      serviceId: _serviceId,
                      status: _status,
                      view: _view,
                      onPickDate: _pickDate,
                      onTherapistChanged: (v) =>
                          setState(() => _therapistId = v),
                      onServiceChanged: (v) => setState(() => _serviceId = v),
                      onStatusChanged: (v) => setState(() => _status = v),
                      onViewChanged: (v) => setState(() => _view = v),
                      onNew: () => _openCreate(data),
                    ),
                    const SizedBox(height: 20),
                    _KpiCards(reservations: filtered),
                    const SizedBox(height: 22),
                    snap.connectionState == ConnectionState.waiting
                        ? const SizedBox(
                            height: 420,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : _AppointmentsTable(
                            reservations: filtered,
                            selectedId: selected?.id,
                            onSelect: (r) => setState(() => _selected = r),
                            onConfirmToggle: _toggleConfirmed,
                            onCancel: _cancel,
                            onDelete: _delete,
                            onEdit: _edit,
                          ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 360,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 28, 32),
                child: _AppointmentDetailsPanel(
                  appointment: selected,
                  onEdit: selected == null ? null : () => _edit(selected),
                  onConfirmToggle: _toggleConfirmed,
                  onCancel: _cancel,
                  onDelete: _delete,
                ),
              ),
            ),
          ],
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null && mounted) setState(() => _selectedDate = picked);
  }

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

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selectedDate,
    required this.therapists,
    required this.services,
    required this.therapistId,
    required this.serviceId,
    required this.status,
    required this.view,
    required this.onPickDate,
    required this.onTherapistChanged,
    required this.onServiceChanged,
    required this.onStatusChanged,
    required this.onViewChanged,
    required this.onNew,
  });

  final DateTime selectedDate;
  final List<Zaposlenik> therapists;
  final List<Usluga> services;
  final int? therapistId;
  final int? serviceId;
  final String status;
  final _AppointmentView view;
  final VoidCallback onPickDate;
  final ValueChanged<int?> onTherapistChanged;
  final ValueChanged<int?> onServiceChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<_AppointmentView> onViewChanged;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final datePill = _FilterPill(
      icon: Icons.date_range_outlined,
      label: _dateLabel(selectedDate),
      onTap: onPickDate,
    );
    final therapistPill = _DropdownPill<int?>(
      value: therapistId,
      hint: 'All Therapists',
      items: [
        const DropdownMenuItem(value: null, child: Text('All Therapists')),
        for (final t in therapists)
          DropdownMenuItem(value: t.id, child: Text('${t.ime} ${t.prezime}')),
      ],
      onChanged: onTherapistChanged,
    );
    final servicePill = _DropdownPill<int?>(
      value: serviceId,
      hint: 'All Services',
      items: [
        const DropdownMenuItem(value: null, child: Text('All Services')),
        for (final s in services)
          DropdownMenuItem(value: s.id, child: Text(s.naziv)),
      ],
      onChanged: onServiceChanged,
    );
    final statusPill = _DropdownPill<String>(
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
    );
    final viewSwitcher = _ViewSwitcher(value: view, onChanged: onViewChanged);
    final newAppointmentButton = _GradientButton(
      label: '+ New Appointment',
      onTap: onNew,
    );

    // Row 1: all filters including All Status (horizontal scroll).
    // Row 2: Day / Week / Month left, + New Appointment right (unchanged end position).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              datePill,
              const SizedBox(width: 10),
              therapistPill,
              const SizedBox(width: 10),
              servicePill,
              const SizedBox(width: 10),
              statusPill,
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: viewSwitcher,
            ),
            const Spacer(),
            newAppointmentButton,
          ],
        ),
      ],
    );
  }

  String _dateLabel(DateTime d) {
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
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
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
        const gap = 14.0;
        const minCard = 168.0;
        final rawW = c.maxWidth;
        final layoutW = rawW.isFinite && rawW > 0
            ? rawW
            : MediaQuery.sizeOf(context).width;
        final needScroll = layoutW < minCard * 4 + gap * 3;
        if (needScroll) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(width: gap),
                  SizedBox(
                    width: minCard,
                    child: _KpiCard(spec: cards[i]),
                  ),
                ],
              ],
            ),
          );
        }
        return SizedBox(
          width: layoutW,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: gap),
                Expanded(child: _KpiCard(spec: cards[i])),
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
    return LuxuryGlassPanel(
      borderRadius: 24,
      blurSigma: 26,
      opacity: 0.38,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'All Appointments',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 980),
              child: DataTable(
                showCheckboxColumn: false,
                columnSpacing: 22,
                horizontalMargin: 12,
                headingRowColor: WidgetStateProperty.all(
                  Colors.white.withValues(alpha: 0.035),
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
          child: LuxuryGlassPanel(
            borderRadius: 24,
            blurSigma: 28,
            opacity: 0.42,
            padding: const EdgeInsets.all(20),
            child: r == null
                ? const Center(child: Text('Select an appointment.'))
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

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.spec});
  final _KpiSpec spec;
  @override
  Widget build(BuildContext context) => LuxuryGlassPanel(
    borderRadius: 24,
    opacity: 0.38,
    blurSigma: 22,
    padding: const EdgeInsets.all(20),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: spec.color.withValues(alpha: 0.14),
          ),
          child: Icon(spec.icon, color: spec.color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                spec.title,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.58),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                spec.value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFF5F3FA),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                spec.subtitle,
                style: TextStyle(
                  color: spec.color,
                  fontWeight: FontWeight.w800,
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

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(18),
    onTap: onTap,
    child: LuxuryGlassPanel(
      borderRadius: 18,
      opacity: 0.28,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    ),
  );
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
  Widget build(BuildContext context) => LuxuryGlassPanel(
    borderRadius: 18,
    opacity: 0.28,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        hint: Text(hint),
        dropdownColor: NuaLuxuryTokens.voidViolet,
        items: items,
        onChanged: onChanged,
      ),
    ),
  );
}

class _ViewSwitcher extends StatelessWidget {
  const _ViewSwitcher({required this.value, required this.onChanged});
  final _AppointmentView value;
  final ValueChanged<_AppointmentView> onChanged;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final v in _AppointmentView.values)
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: _ViewPill(
            label: v.name[0].toUpperCase() + v.name.substring(1),
            active: value == v,
            onTap: () => onChanged(v),
          ),
        ),
    ],
  );
}

class _ViewPill extends StatelessWidget {
  const _ViewPill({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(999),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: active
            ? NuaLuxuryTokens.softPurpleGlow
            : Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
    ),
  );
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF7B4DFF), Color(0xFF9D6BFF)],
        ),
        boxShadow: [
          BoxShadow(
            color: NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.28),
            blurRadius: 22,
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          color: Color(0xFFF5F3FA),
        ),
      ),
    ),
  );
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
    children: [
      Expanded(
        child: _GradientButton(
          label: 'Edit Appointment',
          onTap: onEdit ?? () {},
        ),
      ),
      const SizedBox(width: 10),
      PopupMenuButton<String>(
        color: NuaLuxuryTokens.voidViolet,
        enabled: appointment != null,
        icon: const Icon(Icons.more_horiz_rounded),
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
