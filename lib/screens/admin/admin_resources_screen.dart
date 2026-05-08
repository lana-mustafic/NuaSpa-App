import 'package:flutter/material.dart';

import '../../core/api/services/api_service.dart';
import '../../models/admin/oprema.dart';
import '../../models/admin/prostorija.dart';
import '../../models/admin/radno_vrijeme.dart';
import '../../models/admin/spa_centar.dart';
import '../../ui/widgets/page_header.dart';

class AdminResourcesScreen extends StatefulWidget {
  const AdminResourcesScreen({super.key});

  @override
  State<AdminResourcesScreen> createState() => _AdminResourcesScreenState();
}

enum _ResTab { spa, workingHours, rooms, equipment }

class _AdminResourcesScreenState extends State<AdminResourcesScreen> {
  final ApiService _api = ApiService();
  _ResTab _tab = _ResTab.spa;

  Future<SpaCentar?>? _spaFuture;
  Future<List<RadnoVrijeme>>? _hoursFuture;
  Future<List<Prostorija>>? _roomsFuture;
  Future<List<Oprema>>? _equipmentFuture;

  @override
  void initState() {
    super.initState();
    _reloadAll();
  }

  void _reloadAll() {
    setState(() {
      _spaFuture = _api.getSpaCentar();
      _hoursFuture = _api.getRadnoVrijeme();
      _roomsFuture = _api.getProstorije();
      _equipmentFuture = _api.getOprema();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: 'Resursi objekta',
          subtitle: 'Spa centar, radno vrijeme, prostorije i oprema.',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<_ResTab>(
                segments: const [
                  ButtonSegment(
                    value: _ResTab.spa,
                    label: Text('Spa centar'),
                    icon: Icon(Icons.apartment_outlined),
                  ),
                  ButtonSegment(
                    value: _ResTab.workingHours,
                    label: Text('Radno vrijeme'),
                    icon: Icon(Icons.schedule_outlined),
                  ),
                  ButtonSegment(
                    value: _ResTab.rooms,
                    label: Text('Prostorije'),
                    icon: Icon(Icons.meeting_room_outlined),
                  ),
                  ButtonSegment(
                    value: _ResTab.equipment,
                    label: Text('Oprema'),
                    icon: Icon(Icons.handyman_outlined),
                  ),
                ],
                selected: {_tab},
                onSelectionChanged: (s) => setState(() => _tab = s.first),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _reloadAll,
                icon: const Icon(Icons.refresh),
                label: const Text('Osvježi'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: IndexedStack(
            index: _tab.index,
            children: [
              _SpaCentarTab(api: _api, future: _spaFuture, onSaved: _reloadAll),
              _WorkingHoursTab(
                api: _api,
                future: _hoursFuture,
                onSaved: _reloadAll,
              ),
              _RoomsTab(api: _api, future: _roomsFuture, onChanged: _reloadAll),
              _EquipmentTab(
                api: _api,
                future: _equipmentFuture,
                onChanged: _reloadAll,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SpaCentarTab extends StatefulWidget {
  const _SpaCentarTab({
    required this.api,
    required this.future,
    required this.onSaved,
  });

  final ApiService api;
  final Future<SpaCentar?>? future;
  final VoidCallback onSaved;

  @override
  State<_SpaCentarTab> createState() => _SpaCentarTabState();
}

class _SpaCentarTabState extends State<_SpaCentarTab> {
  final _formKey = GlobalKey<FormState>();
  final _naziv = TextEditingController();
  final _adresa = TextEditingController();
  final _email = TextEditingController();
  final _telefon = TextEditingController();
  final _opis = TextEditingController();
  int _id = 1;

  @override
  void dispose() {
    _naziv.dispose();
    _adresa.dispose();
    _email.dispose();
    _telefon.dispose();
    _opis.dispose();
    super.dispose();
  }

  void _fill(SpaCentar s) {
    _id = s.id;
    _naziv.text = s.naziv;
    _adresa.text = s.adresa ?? '';
    _email.text = s.email ?? '';
    _telefon.text = s.telefon ?? '';
    _opis.text = s.opis ?? '';
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final dto = SpaCentar(
      id: _id,
      naziv: _naziv.text.trim(),
      adresa: _adresa.text.trim().isEmpty ? null : _adresa.text.trim(),
      email: _email.text.trim().isEmpty ? null : _email.text.trim(),
      telefon: _telefon.text.trim().isEmpty ? null : _telefon.text.trim(),
      opis: _opis.text.trim().isEmpty ? null : _opis.text.trim(),
    );
    final saved = await widget.api.updateSpaCentar(dto);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(saved != null ? 'Sačuvano.' : 'Greška pri čuvanju.')),
    );
    if (saved != null) widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SpaCentar?>(
      future: widget.future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final s = snap.data;
        if (s == null) return const Center(child: Text('Nije moguće učitati Spa centar.'));
        _fill(s);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: ListView(
                primary: false,
                children: [
                  TextFormField(
                    controller: _naziv,
                    decoration: const InputDecoration(labelText: 'Naziv'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Obavezno' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _adresa,
                    decoration: const InputDecoration(labelText: 'Adresa'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _email,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _telefon,
                    decoration: const InputDecoration(labelText: 'Telefon'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _opis,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(labelText: 'Opis'),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Sačuvaj'),
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

class _WorkingHoursTab extends StatefulWidget {
  const _WorkingHoursTab({
    required this.api,
    required this.future,
    required this.onSaved,
  });

  final ApiService api;
  final Future<List<RadnoVrijeme>>? future;
  final VoidCallback onSaved;

  @override
  State<_WorkingHoursTab> createState() => _WorkingHoursTabState();
}

class _WorkingHoursTabState extends State<_WorkingHoursTab> {
  final Map<int, RadnoVrijeme> _draft = {};

  String _dayName(int d) {
    const names = {1: 'Ponedjeljak', 2: 'Utorak', 3: 'Srijeda', 4: 'Četvrtak', 5: 'Petak', 6: 'Subota', 7: 'Nedjelja'};
    return names[d] ?? 'Dan $d';
  }

  String _fmtMin(int? m) {
    if (m == null) return '--:--';
    final hh = (m ~/ 60).toString().padLeft(2, '0');
    final mm = (m % 60).toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Future<void> _pickTime(int day, {required bool isOpen}) async {
    final current = _draft[day];
    final baseMin = isOpen ? current?.otvaraMin : current?.zatvaraMin;
    final base = TimeOfDay(hour: (baseMin ?? 540) ~/ 60, minute: (baseMin ?? 540) % 60);
    final t = await showTimePicker(context: context, initialTime: base);
    if (t == null) return;
    setState(() {
      final old = _draft[day]!;
      final min = t.hour * 60 + t.minute;
      _draft[day] = RadnoVrijeme(
        id: old.id,
        spaCentarId: old.spaCentarId,
        danUSedmici: old.danUSedmici,
        isClosed: old.isClosed,
        otvaraMin: isOpen ? min : old.otvaraMin,
        zatvaraMin: isOpen ? old.zatvaraMin : min,
      );
    });
  }

  Future<void> _save() async {
    final items = _draft.values.toList()..sort((a, b) => a.danUSedmici.compareTo(b.danUSedmici));
    final saved = await widget.api.updateRadnoVrijeme(items);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(saved.isNotEmpty ? 'Sačuvano.' : 'Greška pri čuvanju.')),
    );
    if (saved.isNotEmpty) widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RadnoVrijeme>>(
      future: widget.future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snap.data ?? [];
        if (list.isEmpty) return const Center(child: Text('Nema radnog vremena.'));
        if (_draft.isEmpty) {
          for (final it in list) {
            _draft[it.danUSedmici] = it;
          }
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    primary: false,
                    children: [
                      for (final d in List.generate(7, (i) => i + 1))
                        _WorkingHourRow(
                          dayLabel: _dayName(d),
                          value: _draft[d]!,
                          openLabel: _fmtMin(_draft[d]!.otvaraMin),
                          closeLabel: _fmtMin(_draft[d]!.zatvaraMin),
                          onToggleClosed: (v) => setState(() {
                            final old = _draft[d]!;
                            _draft[d] = RadnoVrijeme(
                              id: old.id,
                              spaCentarId: old.spaCentarId,
                              danUSedmici: old.danUSedmici,
                              isClosed: v,
                              otvaraMin: v ? null : (old.otvaraMin ?? 540),
                              zatvaraMin: v ? null : (old.zatvaraMin ?? 1020),
                            );
                          }),
                          onPickOpen: () => _pickTime(d, isOpen: true),
                          onPickClose: () => _pickTime(d, isOpen: false),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Sačuvaj radno vrijeme'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WorkingHourRow extends StatelessWidget {
  const _WorkingHourRow({
    required this.dayLabel,
    required this.value,
    required this.openLabel,
    required this.closeLabel,
    required this.onToggleClosed,
    required this.onPickOpen,
    required this.onPickClose,
  });

  final String dayLabel;
  final RadnoVrijeme value;
  final String openLabel;
  final String closeLabel;
  final ValueChanged<bool> onToggleClosed;
  final VoidCallback onPickOpen;
  final VoidCallback onPickClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(dayLabel)),
          const SizedBox(width: 12),
          FilterChip(
            label: const Text('Zatvoreno'),
            selected: value.isClosed,
            onSelected: onToggleClosed,
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: value.isClosed ? null : onPickOpen,
            child: Text('Otvara: $openLabel'),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: value.isClosed ? null : onPickClose,
            child: Text('Zatvara: $closeLabel'),
          ),
        ],
      ),
    );
  }
}

class _RoomsTab extends StatelessWidget {
  const _RoomsTab({
    required this.api,
    required this.future,
    required this.onChanged,
  });

  final ApiService api;
  final Future<List<Prostorija>>? future;
  final VoidCallback onChanged;

  Future<void> _edit(BuildContext context, Prostorija? existing) async {
    final name = TextEditingController(text: existing?.naziv ?? '');
    final desc = TextEditingController(text: existing?.opis ?? '');
    final cap = TextEditingController(text: '${existing?.kapacitet ?? 1}');
    var active = existing?.isAktivna ?? true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Nova prostorija' : 'Uredi prostoriju'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Naziv')),
              const SizedBox(height: 10),
              TextField(controller: cap, decoration: const InputDecoration(labelText: 'Kapacitet')),
              const SizedBox(height: 10),
              TextField(controller: desc, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Opis')),
              const SizedBox(height: 10),
              SwitchListTile(
                title: const Text('Aktivna'),
                value: active,
                onChanged: (v) => active = v,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Otkaži')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sačuvaj')),
        ],
      ),
    );
    if (ok != true) return;

    final dto = Prostorija(
      id: existing?.id ?? 0,
      spaCentarId: existing?.spaCentarId ?? 1,
      naziv: name.text.trim(),
      opis: desc.text.trim().isEmpty ? null : desc.text.trim(),
      kapacitet: int.tryParse(cap.text.trim()) ?? 1,
      isAktivna: active,
    );

    if (existing == null) {
      await api.createProstorija(dto);
    } else {
      await api.updateProstorija(dto);
    }
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Prostorija>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snap.data ?? [];
        return Stack(
          children: [
            Card(
              child: ListView.separated(
                primary: false,
                padding: const EdgeInsets.only(bottom: 72),
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final r = list[i];
                  return ListTile(
                    leading: Icon(r.isAktivna ? Icons.meeting_room_outlined : Icons.do_not_disturb_on_outlined),
                    title: Text(r.naziv),
                    subtitle: Text('Kapacitet: ${r.kapacitet}${r.opis == null ? '' : ' · ${r.opis}'}'),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'edit') {
                          await _edit(context, r);
                          if (!context.mounted) return;
                        }
                        if (v == 'delete') {
                          final yes = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Brisanje'),
                              content: Text('Obrisati „${r.naziv}“?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Ne')),
                                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Obriši')),
                              ],
                            ),
                          );
                          if (!context.mounted) return;
                          if (yes == true) {
                            await api.deleteProstorija(r.id);
                            if (!context.mounted) return;
                            onChanged();
                          }
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Uredi')),
                        PopupMenuItem(value: 'delete', child: Text('Obriši')),
                      ],
                    ),
                    onTap: () => _edit(context, r),
                  );
                },
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: FloatingActionButton(
                tooltip: 'Nova prostorija',
                onPressed: () => _edit(context, null),
                child: const Icon(Icons.add),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EquipmentTab extends StatelessWidget {
  const _EquipmentTab({
    required this.api,
    required this.future,
    required this.onChanged,
  });

  final ApiService api;
  final Future<List<Oprema>>? future;
  final VoidCallback onChanged;

  Future<void> _edit(BuildContext context, Oprema? existing) async {
    final name = TextEditingController(text: existing?.naziv ?? '');
    final note = TextEditingController(text: existing?.napomena ?? '');
    final qty = TextEditingController(text: '${existing?.kolicina ?? 1}');
    var okState = existing?.isIspravna ?? true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Nova oprema' : 'Uredi opremu'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Naziv')),
              const SizedBox(height: 10),
              TextField(controller: qty, decoration: const InputDecoration(labelText: 'Količina')),
              const SizedBox(height: 10),
              TextField(controller: note, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Napomena')),
              const SizedBox(height: 10),
              SwitchListTile(
                title: const Text('Ispravna'),
                value: okState,
                onChanged: (v) => okState = v,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Otkaži')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sačuvaj')),
        ],
      ),
    );
    if (ok != true) return;

    final dto = Oprema(
      id: existing?.id ?? 0,
      spaCentarId: existing?.spaCentarId ?? 1,
      naziv: name.text.trim(),
      napomena: note.text.trim().isEmpty ? null : note.text.trim(),
      kolicina: int.tryParse(qty.text.trim()) ?? 1,
      isIspravna: okState,
    );

    if (existing == null) {
      await api.createOprema(dto);
    } else {
      await api.updateOprema(dto);
    }
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Oprema>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snap.data ?? [];
        return Stack(
          children: [
            Card(
              child: ListView.separated(
                primary: false,
                padding: const EdgeInsets.only(bottom: 72),
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final e = list[i];
                  return ListTile(
                    leading: Icon(e.isIspravna ? Icons.handyman_outlined : Icons.report_problem_outlined),
                    title: Text(e.naziv),
                    subtitle: Text('Količina: ${e.kolicina}${e.napomena == null ? '' : ' · ${e.napomena}'}'),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'edit') {
                          await _edit(context, e);
                          if (!context.mounted) return;
                        }
                        if (v == 'delete') {
                          final yes = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Brisanje'),
                              content: Text('Obrisati „${e.naziv}“?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Ne')),
                                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Obriši')),
                              ],
                            ),
                          );
                          if (!context.mounted) return;
                          if (yes == true) {
                            await api.deleteOprema(e.id);
                            if (!context.mounted) return;
                            onChanged();
                          }
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Uredi')),
                        PopupMenuItem(value: 'delete', child: Text('Obriši')),
                      ],
                    ),
                    onTap: () => _edit(context, e),
                  );
                },
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: FloatingActionButton(
                tooltip: 'Nova oprema',
                onPressed: () => _edit(context, null),
                child: const Icon(Icons.add),
              ),
            ),
          ],
        );
      },
    );
  }
}

