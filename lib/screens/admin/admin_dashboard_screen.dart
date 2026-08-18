import 'package:flutter/material.dart';
import '../../core/api/services/api_service.dart';
import '../../core/reservations/cancel_rezervacija_messages.dart';
import '../../models/rezervacija.dart';
import '../../models/usluga.dart';
import '../../models/zaposlenik.dart';
import '../../ui/widgets/page_header.dart';
import '../catalog/service_category_manager_panel.dart';
import '../catalog/service_editor_dialog.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 22, 26, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          PageHeader(
            title: 'Admin panel',
            subtitle: 'Manage categories, services, bookings, and reports.',
            trailing: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Categories'), icon: Icon(Icons.category_outlined)),
                ButtonSegment(value: 1, label: Text('Services'), icon: Icon(Icons.spa_outlined)),
                ButtonSegment(value: 2, label: Text('Bookings'), icon: Icon(Icons.event_note_outlined)),
                ButtonSegment(value: 3, label: Text('Report'), icon: Icon(Icons.picture_as_pdf_outlined)),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() => _tab = s.first),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: const [
                _AdminCategoriesPage(),
                _AdminServicesPage(),
                _AdminReservationsPage(),
                _AdminReportPage(),
              ],
            ),
          ),
          ],
        ),
      ),
    );
  }
}

class _AdminCategoriesPage extends StatelessWidget {
  const _AdminCategoriesPage();

  @override
  Widget build(BuildContext context) {
    return const ServiceCategoryManagerPanel(showInlineHeader: true);
  }
}

class _AdminServicesPage extends StatefulWidget {
  const _AdminServicesPage();

  @override
  State<_AdminServicesPage> createState() => _AdminServicesPageState();
}

class _AdminServicesPageState extends State<_AdminServicesPage> {
  final ApiService _api = ApiService();
  Future<List<Usluga>>? _futureUsluge;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _reloadAll();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _reloadAll() async {
    if (!mounted) return;
    setState(() {
      _futureUsluge = _api.getUsluge();
    });
  }

  Future<void> _editService(Usluga? existing) async {
    final ok = await showServiceEditorDialog(context, existing: existing);
    if (ok && mounted) _reloadAll();
  }

  Future<void> _delete(Usluga u) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete service'),
        content: Text('Delete "${u.naziv}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;

    final err = await _api.deleteUsluga(u.id);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service deleted.')),
      );
      _reloadAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Usluga>>(
      future: _futureUsluge,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snap.data ?? [];
        return Stack(
          children: [
            RefreshIndicator(
              onRefresh: _reloadAll,
              child: Scrollbar(
                controller: _scrollController,
                child: ListView.builder(
                  controller: _scrollController,
                  primary: false,
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final u = list[i];
                    return ListTile(
                      leading: const Icon(Icons.spa_outlined),
                      title: Text(u.naziv),
                      subtitle: Text(
                        '${u.cijenaKm} · ${u.kategorija}',
                        style:
                            TextStyle(color: Colors.white.withValues(alpha: 0.70)),
                      ),
                      trailing: PopupMenuButton<String>(
                        tooltip: 'Service actions',
                        onSelected: (v) {
                          if (v == 'edit') _editService(u);
                          if (v == 'delete') _delete(u);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                      onTap: () => _editService(u),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: FloatingActionButton(
                tooltip: 'New service',
                onPressed: () => _editService(null),
                child: const Icon(Icons.add),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AdminReservationsPage extends StatefulWidget {
  const _AdminReservationsPage();

  @override
  State<_AdminReservationsPage> createState() =>
      _AdminReservationsPageState();
}

class _AdminReservationsPageState extends State<_AdminReservationsPage> {
  final ApiService _api = ApiService();
  Future<List<Rezervacija>>? _future;
  final ScrollController _scrollController = ScrollController();
  bool _includeOtkazane = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = _api.getRezervacijeFiltered(includeOtkazane: _includeOtkazane);
    });
  }

  Future<void> _cancel(Rezervacija r) async {
    final reasonCtrl = TextEditingController(text: r.razlogOtkaza ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel booking'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(r.uslugaNaziv ?? 'Service'),
            const SizedBox(height: 6),
            Text(
              r.datumRezervacije.toLocal().toString().split('.').first,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.70)),
            ),
            if (r.isPlacena) ...[
              const SizedBox(height: 10),
              Text(
                'Paid booking — cancellation includes a Stripe refund.',
                style: TextStyle(color: Colors.amber.shade200),
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: reasonCtrl,
              maxLength: 400,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Cancellation reason (optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Back'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.cancel_outlined),
            label: Text(r.isPlacena ? 'Cancel & refund' : 'Cancel'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final result = await _api.cancelRezervacija(
      r.id,
      razlogOtkaza: reasonCtrl.text,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result?.otkazana == true
              ? cancelRezervacijaSuccessMessage(result!)
              : 'Cancellation failed.',
        ),
      ),
    );
    _reload();
  }

  Future<void> _edit(Rezervacija r) async {
    final selectedDate = DateTime(
      r.datumRezervacije.year,
      r.datumRezervacije.month,
      r.datumRezervacije.day,
    );
    final dateCtrl = ValueNotifier<DateTime>(selectedDate);

    final slotCtrl = ValueNotifier<DateTime>(r.datumRezervacije);
    final therapistCtrl = ValueNotifier<int?>(null);
    final serviceCtrl = ValueNotifier<int?>(null);
    final vipCtrl = ValueNotifier<bool>(r.isVip);

    final services = await _api.getUsluge();
    if (!mounted) return;

    serviceCtrl.value = r.uslugaId > 0
        ? r.uslugaId
        : _findServiceIdFromName(services, r.uslugaNaziv);

    var eligibleTherapists = <Zaposlenik>[];
    if (serviceCtrl.value != null) {
      eligibleTherapists = (await _api.getZaposleniciForService(
        serviceCtrl.value!,
      ))
          .items;
    }
    if (!mounted) return;

    therapistCtrl.value = r.zaposlenikId > 0
        ? r.zaposlenikId
        : _findTherapistIdFromName(eligibleTherapists, r.zaposlenikIme);
    if (therapistCtrl.value != null &&
        !eligibleTherapists.any((t) => t.id == therapistCtrl.value)) {
      therapistCtrl.value =
          eligibleTherapists.length == 1 ? eligibleTherapists.first.id : null;
    }

    Future<void> pickDate() async {
      final picked = await showDatePicker(
        context: context,
        initialDate: dateCtrl.value,
        firstDate: DateTime.now().subtract(const Duration(days: 365)),
        lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      );
      if (picked == null || !context.mounted) return;
      dateCtrl.value = DateTime(picked.year, picked.month, picked.day);
    }

    Future<void> pickTime() async {
      final base = TimeOfDay.fromDateTime(slotCtrl.value);
      final t = await showTimePicker(context: context, initialTime: base);
      if (t == null || !context.mounted) return;
      final d = dateCtrl.value;
      slotCtrl.value = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit booking'),
        content: SizedBox(
          width: 720,
          child: StatefulBuilder(
            builder: (ctx, setLocal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          await pickDate();
                          if (!ctx.mounted) return;
                          final d = dateCtrl.value;
                          final t = slotCtrl.value;
                          slotCtrl.value =
                              DateTime(d.year, d.month, d.day, t.hour, t.minute);
                          setLocal(() {});
                        },
                        icon: const Icon(Icons.date_range_outlined),
                        label: Text(
                          '${dateCtrl.value.year}-${dateCtrl.value.month.toString().padLeft(2, '0')}-${dateCtrl.value.day.toString().padLeft(2, '0')}',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await pickTime();
                          if (!ctx.mounted) return;
                          setLocal(() {});
                        },
                        icon: const Icon(Icons.schedule_outlined),
                        label: Text(
                          '${slotCtrl.value.hour.toString().padLeft(2, '0')}:${slotCtrl.value.minute.toString().padLeft(2, '0')}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Service',
                      border: OutlineInputBorder(),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        isExpanded: true,
                        value: serviceCtrl.value,
                        hint: const Text('Select service'),
                        items: services
                            .map(
                              (s) => DropdownMenuItem(
                                value: s.id,
                                child: Text(s.naziv),
                              ),
                            )
                            .toList(),
                        onChanged: (v) async {
                          serviceCtrl.value = v;
                          therapistCtrl.value = null;
                          if (v != null) {
                            eligibleTherapists = (await _api
                                    .getZaposleniciForService(v))
                                .items;
                            if (eligibleTherapists.length == 1) {
                              therapistCtrl.value =
                                  eligibleTherapists.first.id;
                            }
                          } else {
                            eligibleTherapists = [];
                          }
                          if (ctx.mounted) setLocal(() {});
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Therapist',
                      border: OutlineInputBorder(),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        isExpanded: true,
                        value: therapistCtrl.value,
                        hint: Text(
                          eligibleTherapists.isEmpty
                              ? 'No therapists for this service'
                              : 'Select therapist',
                        ),
                        items: eligibleTherapists
                            .map(
                              (t) => DropdownMenuItem(
                                value: t.id,
                                child: Text('${t.ime} ${t.prezime}'),
                              ),
                            )
                            .toList(),
                        onChanged: eligibleTherapists.isEmpty
                            ? null
                            : (v) => setLocal(() => therapistCtrl.value = v),
                      ),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('VIP appointment'),
                    value: vipCtrl.value,
                    onChanged: (v) => setLocal(() => vipCtrl.value = v),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );

    if (ok != true || !mounted) return;
    if (therapistCtrl.value == null || serviceCtrl.value == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Therapist and service are required.')),
      );
      return;
    }

    final updated = await _api.editRezervacija(
      rezervacijaId: r.id,
      datumRezervacije: slotCtrl.value,
      uslugaId: serviceCtrl.value!,
      zaposlenikId: therapistCtrl.value!,
      isVip: vipCtrl.value,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(updated != null ? 'Saved.' : 'Error while saving.')),
    );
    _reload();
  }

  int? _findTherapistIdFromName(List<Zaposlenik> list, String? ime) {
    if (ime == null) return null;
    final norm = ime.trim().toLowerCase();
    for (final t in list) {
      final label = '${t.ime} ${t.prezime}'.trim().toLowerCase();
      if (label == norm) return t.id;
    }
    return null;
  }

  int? _findServiceIdFromName(List<Usluga> list, String? naziv) {
    if (naziv == null) return null;
    final norm = naziv.trim().toLowerCase();
    for (final s in list) {
      if (s.naziv.trim().toLowerCase() == norm) return s.id;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Rezervacija>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snap.data ?? [];
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Show cancelled'),
                value: _includeOtkazane,
                onChanged: (v) {
                  setState(() => _includeOtkazane = v);
                  _reload();
                },
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Scrollbar(
                  controller: _scrollController,
                  child: ListView.builder(
                    controller: _scrollController,
                    primary: false,
                    padding: const EdgeInsets.only(bottom: 88),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final r = list[i];
                      final statusIcon = r.isOtkazana
                          ? Icons.cancel_outlined
                          : (r.isPotvrdjena
                              ? Icons.check_circle
                              : Icons.schedule);
                      final statusColor = r.isOtkazana
                          ? Colors.redAccent
                          : (r.isPotvrdjena ? Colors.green : Colors.orange);

                      return ListTile(
                        leading: Icon(statusIcon, color: statusColor),
                        title: Row(
                          children: [
                            Expanded(child: Text(r.uslugaNaziv ?? 'Service')),
                            if (r.isOtkazana)
                              const Padding(
                                padding: EdgeInsets.only(left: 10),
                                child: Chip(label: Text('Cancelled')),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          '${r.datumRezervacije.toLocal().toString().split(".").first} · '
                          '${r.korisnikIme ?? ''} · ${r.zaposlenikIme ?? ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.70),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!r.isOtkazana)
                              Tooltip(
                                message: 'Edit',
                                child: IconButton(
                                  onPressed: r.isPlacena ? null : () => _edit(r),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                              ),
                            if (!r.isOtkazana)
                              Tooltip(
                                message: 'Cancel',
                                child: IconButton(
                                  onPressed: r.isOtkazana ? null : () => _cancel(r),
                                  icon: const Icon(Icons.cancel_outlined),
                                ),
                              ),
                            Tooltip(
                              message: 'Confirm/deny',
                              child: Switch(
                                value: r.isPotvrdjena,
                                onChanged: (r.isOtkazana)
                                    ? null
                                    : (v) async {
                                        final ok = await _api
                                            .updateRezervacijaPotvrdjena(r.id, v);
                                        if (!context.mounted) return;
                                        if (!ok) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Unable to update booking.'),
                                            ),
                                          );
                                        }
                                        _reload();
                                      },
                              ),
                            ),
                          ],
                        ),
                        onTap: () async {
                          if (!r.isOtkazana) return;
                          final reason = r.razlogOtkaza?.trim();
                          if (reason == null || reason.isEmpty) return;
                          if (!context.mounted) return;
                          showDialog<void>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Cancellation reason'),
                              content: Text(reason),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AdminReportPage extends StatelessWidget {
  const _AdminReportPage();

  @override
  Widget build(BuildContext context) {
    final api = ApiService();
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Reports',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Download a PDF with top services (same backend endpoint).',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.70)),
          ),
          const SizedBox(height: 24),
          Tooltip(
            message: 'Download PDF report (top services)',
            child: FilledButton.icon(
              onPressed: () async {
                final now = DateTime.now();
                final end = DateTime(now.year, now.month, now.day);
                final start = end.subtract(const Duration(days: 29));
                final ok = await api.downloadReport(from: start, to: end);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ok
                            ? 'PDF report downloaded.'
                            : 'PDF export failed.',
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.download),
              label: const Text('Download top services (PDF)'),
            ),
          ),
        ],
      ),
    );
  }
}
