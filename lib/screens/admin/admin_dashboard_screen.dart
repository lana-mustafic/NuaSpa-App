import 'package:flutter/material.dart';
import '../../core/api/services/api_service.dart';
import '../../models/kategorija_usluga.dart';
import '../../models/rezervacija.dart';
import '../../models/usluga.dart';
import '../../models/zaposlenik.dart';
import '../../ui/widgets/page_header.dart';

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
            subtitle: 'Upravljanje kategorijama, uslugama, rezervacijama i izvještajima.',
            trailing: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Kategorije'), icon: Icon(Icons.category_outlined)),
                ButtonSegment(value: 1, label: Text('Usluge'), icon: Icon(Icons.spa_outlined)),
                ButtonSegment(value: 2, label: Text('Rezervacije'), icon: Icon(Icons.event_note_outlined)),
                ButtonSegment(value: 3, label: Text('Izvještaj'), icon: Icon(Icons.picture_as_pdf_outlined)),
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

class _AdminCategoriesPage extends StatefulWidget {
  const _AdminCategoriesPage();

  @override
  State<_AdminCategoriesPage> createState() => _AdminCategoriesPageState();
}

class _AdminCategoriesPageState extends State<_AdminCategoriesPage> {
  final ApiService _api = ApiService();
  Future<List<KategorijaUsluga>>? _future;
  final ScrollController _scrollController = ScrollController();

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
      _future = _api.getKategorijeUsluga();
    });
  }

  Future<void> _editCategory(KategorijaUsluga? existing) async {
    final ctrl = TextEditingController(text: existing?.naziv ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Nova kategorija' : 'Uredi kategoriju'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Naziv'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Otkaži'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sačuvaj'),
          ),
        ],
      ),
    );

    if (saved != true || !mounted) return;

    final naziv = ctrl.text.trim();
    if (naziv.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Naziv je obavezan.')),
      );
      return;
    }

    final ok = existing == null
        ? await _api.createKategorijaUsluga(naziv) != null
        : await _api.updateKategorijaUsluga(
                KategorijaUsluga(id: existing.id, naziv: naziv),
              ) !=
              null;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Sačuvano.' : 'Greška pri čuvanju.')),
    );
    if (ok) _reload();
  }

  Future<void> _delete(KategorijaUsluga k) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Brisanje kategorije'),
        content: Text('Obrisati „${k.naziv}“?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ne'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Obriši'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;

    final err = await _api.deleteKategorijaUsluga(k.id);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kategorija obrisana.')),
      );
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<KategorijaUsluga>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snap.data ?? [];
        return Stack(
          children: [
            RefreshIndicator(
              onRefresh: () async => _reload(),
              child: Scrollbar(
                controller: _scrollController,
                child: ListView.builder(
                  controller: _scrollController,
                  primary: false,
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final k = list[i];
                    return ListTile(
                      leading: const Icon(Icons.folder_outlined),
                      title: Text(k.naziv),
                      trailing: PopupMenuButton<String>(
                        tooltip: 'Akcije za kategoriju',
                        onSelected: (v) {
                          if (v == 'edit') _editCategory(k);
                          if (v == 'delete') _delete(k);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Uredi')),
                          PopupMenuItem(value: 'delete', child: Text('Obriši')),
                        ],
                      ),
                      onTap: () => _editCategory(k),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: FloatingActionButton(
                tooltip: 'Nova kategorija',
                onPressed: () => _editCategory(null),
                child: const Icon(Icons.add),
              ),
            ),
          ],
        );
      },
    );
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
  List<KategorijaUsluga> _katCache = [];
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
    final kat = await _api.getKategorijeUsluga();
    if (!mounted) return;
    setState(() {
      _katCache = kat;
      _futureUsluge = _api.getUsluge();
    });
  }

  Future<void> _editService(Usluga? existing) async {
    if (_katCache.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prvo dodajte barem jednu kategoriju.'),
        ),
      );
      return;
    }

    final nazivCtrl = TextEditingController(text: existing?.naziv ?? '');
    final cijenaCtrl = TextEditingController(
      text: existing != null ? existing.cijena.toStringAsFixed(2) : '',
    );
    final trajanjeCtrl = TextEditingController(
      text: '${existing?.trajanjeMinuta ?? 60}',
    );
    final opisCtrl = TextEditingController(text: existing?.opis ?? '');
    final slikaCtrl = TextEditingController(
      text: existing != null && !existing.slikaUrl.contains('picsum.photos')
          ? existing.slikaUrl
          : '',
    );

    var katId = existing?.kategorijaUslugaId ?? _katCache.first.id;
    if (!_katCache.any((k) => k.id == katId)) {
      katId = _katCache.first.id;
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Nova usluga' : 'Uredi uslugu'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nazivCtrl,
                  decoration: const InputDecoration(labelText: 'Naziv'),
                ),
                TextField(
                  controller: cijenaCtrl,
                  decoration: const InputDecoration(labelText: 'Cijena (KM)'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: trajanjeCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Trajanje (minute)'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: opisCtrl,
                  decoration: const InputDecoration(labelText: 'Opis'),
                  maxLines: 3,
                ),
                TextField(
                  controller: slikaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Slika URL (opcionalno)',
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: DropdownButton<int>(
                    value: katId,
                    hint: const Text('Kategorija'),
                    isExpanded: true,
                    items: _katCache
                        .map(
                          (k) => DropdownMenuItem(
                            value: k.id,
                            child: Text(k.naziv),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setDialogState(() => katId = v);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Otkaži'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sačuvaj'),
            ),
          ],
        ),
      ),
    );

    if (saved != true || !mounted) return;

    final cijena = double.tryParse(
          cijenaCtrl.text.replaceAll(',', '.'),
        ) ??
        0;
    final trajanje = int.tryParse(trajanjeCtrl.text.trim()) ?? 60;

    if (nazivCtrl.text.trim().isEmpty || cijena <= 0 || katId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Provjerite naziv, cijenu i kategoriju.')),
      );
      return;
    }

    final slika = slikaCtrl.text.trim();
    final draft = Usluga(
      id: existing?.id ?? 0,
      naziv: nazivCtrl.text.trim(),
      cijena: cijena,
      trajanje: '$trajanje min',
      slikaUrl: slika.isNotEmpty
          ? slika
          : (existing?.slikaUrl ??
              'https://picsum.photos/seed/new/400/300'),
      kategorija: _katCache.firstWhere((k) => k.id == katId).naziv,
      trajanjeMinuta: trajanje,
      opis: opisCtrl.text.trim(),
      kategorijaUslugaId: katId,
    );

    final ok = existing == null
        ? await _api.createUsluga(draft) != null
        : await _api.updateUsluga(draft) != null;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Sačuvano.' : 'Greška pri čuvanju.')),
    );
    if (ok) _reloadAll();
  }

  Future<void> _delete(Usluga u) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Brisanje usluge'),
        content: Text('Obrisati „${u.naziv}“?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ne'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Obriši'),
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
        const SnackBar(content: Text('Usluga obrisana.')),
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
                        '${u.cijena.toStringAsFixed(2)} KM · ${u.kategorija}',
                        style:
                            TextStyle(color: Colors.white.withValues(alpha: 0.70)),
                      ),
                      trailing: PopupMenuButton<String>(
                        tooltip: 'Akcije za uslugu',
                        onSelected: (v) {
                          if (v == 'edit') _editService(u);
                          if (v == 'delete') _delete(u);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Uredi')),
                          PopupMenuItem(value: 'delete', child: Text('Obriši')),
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
                tooltip: 'Nova usluga',
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
        title: const Text('Otkazivanje rezervacije'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(r.uslugaNaziv ?? 'Usluga'),
            const SizedBox(height: 6),
            Text(
              r.datumRezervacije.toLocal().toString().split('.').first,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.70)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonCtrl,
              maxLength: 400,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Razlog otkaza (opcionalno)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Nazad'),
          ),
          FilledButton.icon(
            onPressed: r.isPlacena
                ? null
                : () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Otkaži'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final success = await _api.cancelRezervacija(
      r.id,
      razlogOtkaza: reasonCtrl.text,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Rezervacija otkazana.' : 'Neuspjelo otkazivanje.'),
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

    final therapists = await _api.getZaposlenici();
    final services = await _api.getUsluge();
    if (!mounted) return;

    therapistCtrl.value = r.zaposlenikId > 0
        ? r.zaposlenikId
        : _findTherapistIdFromName(therapists, r.zaposlenikIme);
    serviceCtrl.value = r.uslugaId > 0
        ? r.uslugaId
        : _findServiceIdFromName(services, r.uslugaNaziv);

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
        title: const Text('Uredi rezervaciju'),
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
                      labelText: 'Usluga',
                      border: OutlineInputBorder(),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        isExpanded: true,
                        value: serviceCtrl.value,
                        hint: const Text('Odaberite uslugu'),
                        items: services
                            .map(
                              (s) => DropdownMenuItem(
                                value: s.id,
                                child: Text(s.naziv),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setLocal(() => serviceCtrl.value = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Terapeut',
                      border: OutlineInputBorder(),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        isExpanded: true,
                        value: therapistCtrl.value,
                        hint: const Text('Odaberite terapeuta'),
                        items: therapists
                            .map(
                              (t) => DropdownMenuItem(
                                value: t.id,
                                child: Text('${t.ime} ${t.prezime}'),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setLocal(() => therapistCtrl.value = v),
                      ),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('VIP termin'),
                    value: vipCtrl.value,
                    onChanged: (v) => setLocal(() => vipCtrl.value = v),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Otkaži')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sačuvaj')),
        ],
      ),
    );

    if (ok != true || !mounted) return;
    if (therapistCtrl.value == null || serviceCtrl.value == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Terapeut i usluga su obavezni.')),
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
      SnackBar(content: Text(updated != null ? 'Sačuvano.' : 'Greška pri čuvanju.')),
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
                title: const Text('Prikaži otkazane'),
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
                            Expanded(child: Text(r.uslugaNaziv ?? 'Usluga')),
                            if (r.isOtkazana)
                              const Padding(
                                padding: EdgeInsets.only(left: 10),
                                child: Chip(label: Text('Otkazana')),
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
                                message: 'Uredi',
                                child: IconButton(
                                  onPressed: r.isPlacena ? null : () => _edit(r),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                              ),
                            if (!r.isOtkazana)
                              Tooltip(
                                message: 'Otkazivanje',
                                child: IconButton(
                                  onPressed: r.isPlacena ? null : () => _cancel(r),
                                  icon: const Icon(Icons.cancel_outlined),
                                ),
                              ),
                            Tooltip(
                              message: 'Potvrdi/odbij',
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
                                              content: Text('Nije moguće ažurirati rezervaciju.'),
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
                              title: const Text('Razlog otkaza'),
                              content: Text(reason),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Zatvori'),
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
            'Izvještaji',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Preuzmite PDF sa top uslugama (isti endpoint kao na backendu).',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.70)),
          ),
          const SizedBox(height: 24),
          Tooltip(
            message: 'Preuzmi PDF izvještaj (top usluge)',
            child: FilledButton.icon(
              onPressed: () async {
                await api.downloadReport();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Završeno preuzimanje.')),
                  );
                }
              },
              icon: const Icon(Icons.download),
              label: const Text('Preuzmi Top usluge (PDF)'),
            ),
          ),
        ],
      ),
    );
  }
}
