import 'package:flutter/material.dart';

import '../../core/api/services/api_service.dart';
import '../../models/admin/radno_vrijeme.dart';
import '../../models/admin/spa_centar.dart';
import '../../ui/widgets/page_header.dart';

class AdminResourcesScreen extends StatefulWidget {
  const AdminResourcesScreen({super.key});

  @override
  State<AdminResourcesScreen> createState() => _AdminResourcesScreenState();
}

enum _ResTab { spa, workingHours }

class _AdminResourcesScreenState extends State<AdminResourcesScreen> {
  final ApiService _api = ApiService();
  _ResTab _tab = _ResTab.spa;

  Future<SpaCentar?>? _spaFuture;
  Future<List<RadnoVrijeme>>? _hoursFuture;

  @override
  void initState() {
    super.initState();
    _reloadAll();
  }

  void _reloadAll() {
    setState(() {
      _spaFuture = _api.getSpaCentar();
      _hoursFuture = _api.getRadnoVrijeme();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: 'Resursi objekta',
          subtitle: 'Spa centar i radno vrijeme.',
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
