import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api/services/api_service.dart';
import '../../models/rezervacija.dart';
import '../../providers/auth_provider.dart';

String _formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

String _formatTime(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String _formatDateTimeLocal(DateTime d) {
  final l = d.toLocal();
  return '${_formatDate(l)} ${_formatTime(l)}';
}

/// Raspored terapeuta: rezervacije za odabrani dan + slobodni slotovi.
class TherapistScheduleScreen extends StatefulWidget {
  const TherapistScheduleScreen({super.key});

  @override
  State<TherapistScheduleScreen> createState() =>
      _TherapistScheduleScreenState();
}

class _TherapistScheduleScreenState extends State<TherapistScheduleScreen> {
  final ApiService _api = ApiService();
  late DateTime _day;
  Future<_DayData>? _dayFuture;
  bool _autoLoadScheduled = false;
  String? _loadError;
  bool? _filterPotvrdjena; // null=all, false=pending, true=confirmed
  bool? _filterPlacena; // null=all, false=neplaćeno, true=plaćeno
  final TextEditingController _searchCtrl = TextEditingController();
  int? _selectedRezervacijaId;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _day = DateTime(n.year, n.month, n.day);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  DateTime _onlyDate(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _day = _onlyDate(picked));
      await _reload();
    }
  }

  Future<void> _reload() async {
    final auth = context.read<AuthProvider>();
    final zid = auth.zaposlenikId;
    if (!auth.isZaposlenik || zid == null) return;

    final f = _loadDay(zid, _day);
    setState(() {
      _dayFuture = f;
      _loadError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final zid = auth.zaposlenikId;

    if (!auth.isZaposlenik) {
      return const Center(
        child: Text('Vaš nalog nema ulogu terapeuta.'),
      );
    }

    if (zid == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'JWT nema ZaposlenikId. U bazi povežite korisnika sa zaposlenikom (Korisnik.ZaposlenikId).',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Ako je korisnik tek dobio token/claim nakon login-a, initState _reload može
    // završiti prije nego što zid postane dostupan. U tom slučaju pokreni auto reload.
    if (_dayFuture == null && !_autoLoadScheduled) {
      _autoLoadScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        _autoLoadScheduled = false;
        await _reload();
      });
    }

    final dayLabel = _formatDate(_day);

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 22, 26, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Raspored terapeuta',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Osvježi',
                onPressed: _reload,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Pregled rezervacija i slobodnih termina za odabrani dan.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.70)),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _reload,
              child: FutureBuilder<_DayData>(
                future: _dayFuture,
                builder: (context, snap) {
                  if (_dayFuture == null ||
                      snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snap.hasError) {
                    return ListView(
                      padding: const EdgeInsets.all(0),
                      children: [
                        Text(
                          'Greška pri učitavanju rasporeda.',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _loadError ?? snap.error.toString(),
                          style: TextStyle(color: Colors.red.shade300),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _reload,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Pokušaj ponovo'),
                        ),
                      ],
                    );
                  }

                  final data = snap.data ??
                      _DayData(rezervacije: [], slotovi: []);

                  return Scrollbar(
                    controller: _scrollController,
                    child: ListView(
                      controller: _scrollController,
                      primary: false,
                      padding: const EdgeInsets.all(0),
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () async {
                                setState(() {
                                  _day = _day.subtract(const Duration(days: 1));
                                });
                                await _reload();
                              },
                              icon: const Icon(Icons.chevron_left),
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: _pickDate,
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  child: Text(
                                    dayLabel,
                                    textAlign: TextAlign.center,
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () async {
                                setState(() {
                                  _day = _day.add(const Duration(days: 1));
                                });
                                await _reload();
                              },
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, c) {
                            final isWide = c.maxWidth >= 1100;
                            final q = _searchCtrl.text.trim().toLowerCase();

                            final filtered = data.rezervacije.where((r) {
                              if (_filterPlacena != null &&
                                  r.isPlacena != _filterPlacena) {
                                return false;
                              }
                              if (q.isEmpty) {
                                return true;
                              }
                              final s = [
                                r.uslugaNaziv,
                                r.korisnikIme,
                                r.zaposlenikIme,
                              ].whereType<String>().join(' ').toLowerCase();
                              return s.contains(q);
                            }).toList();

                            if (_selectedRezervacijaId != null &&
                                !filtered.any(
                                    (r) => r.id == _selectedRezervacijaId)) {
                              _selectedRezervacijaId = null;
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Rezervacije (${filtered.length})',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall,
                                      ),
                                    ),
                                    SizedBox(
                                      width: isWide ? 340 : 260,
                                      child: TextField(
                                        controller: _searchCtrl,
                                        onChanged: (_) => setState(() {}),
                                        decoration: const InputDecoration(
                                          hintText:
                                              'Pretraga (usluga/klijent)…',
                                          prefixIcon: Icon(Icons.search),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ChoiceChip(
                                      label: const Text('Sve'),
                                      selected: _filterPotvrdjena == null,
                                      onSelected: (_) async {
                                        setState(
                                            () => _filterPotvrdjena = null);
                                        await _reload();
                                      },
                                    ),
                                    ChoiceChip(
                                      label: const Text('Na čekanju'),
                                      selected: _filterPotvrdjena == false,
                                      onSelected: (_) async {
                                        setState(
                                            () => _filterPotvrdjena = false);
                                        await _reload();
                                      },
                                    ),
                                    ChoiceChip(
                                      label: const Text('Potvrđene'),
                                      selected: _filterPotvrdjena == true,
                                      onSelected: (_) async {
                                        setState(
                                            () => _filterPotvrdjena = true);
                                        await _reload();
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    FilterChip(
                                      label: const Text('Plaćeno'),
                                      selected: _filterPlacena == true,
                                      onSelected: (v) => setState(() {
                                        _filterPlacena = v ? true : null;
                                      }),
                                    ),
                                    FilterChip(
                                      label: const Text('Neplaćeno'),
                                      selected: _filterPlacena == false,
                                      onSelected: (v) => setState(() {
                                        _filterPlacena = v ? false : null;
                                      }),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (!isWide) ...[
                                  if (filtered.isEmpty)
                                    Text(
                                      'Nema rezervacija za ovaj dan.',
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.70),
                                      ),
                                    )
                                  else
                                    ...filtered.map(
                                      (r) => _ReservationTerapeutTile(
                                        rezervacija: r,
                                        onToggle: (v) async {
                                          final ok = await _api
                                              .updateRezervacijaPotvrdjena(
                                                  r.id, v);
                                          if (!context.mounted) return;
                                          if (!ok) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                    'Ažuriranje nije uspjelo.'),
                                              ),
                                            );
                                          }
                                          if (context.mounted) await _reload();
                                        },
                                      ),
                                    ),
                                  const SizedBox(height: 22),
                                  _SlotsSection(slotovi: data.slotovi),
                                  const SizedBox(height: 8),
                                ] else ...[
                                  SizedBox(
                                    height: 520,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 7,
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            child: SingleChildScrollView(
                                              child: DataTable(
                                                headingRowHeight: 44,
                                                dataRowMinHeight: 50,
                                                dataRowMaxHeight: 62,
                                                columns: const [
                                                  DataColumn(
                                                      label: Text('Vrijeme')),
                                                  DataColumn(
                                                      label: Text('Usluga')),
                                                  DataColumn(
                                                      label: Text('Klijent')),
                                                  DataColumn(
                                                      label: Text('Status')),
                                                  DataColumn(
                                                      label: Text('Plaćanje')),
                                                ],
                                                rows: [
                                                  for (final r in filtered)
                                                    DataRow(
                                                      selected: r.id ==
                                                          _selectedRezervacijaId,
                                                      onSelectChanged: (_) {
                                                        setState(() =>
                                                            _selectedRezervacijaId =
                                                                r.id);
                                                      },
                                                      cells: [
                                                        DataCell(Text(
                                                          _formatTime(r
                                                              .datumRezervacije
                                                              .toLocal()),
                                                        )),
                                                        DataCell(Text(
                                                            r.uslugaNaziv ??
                                                                'Usluga')),
                                                        DataCell(Text(
                                                            r.korisnikIme ??
                                                                '-')),
                                                        DataCell(Chip(
                                                          label: Text(
                                                            r.isPotvrdjena
                                                                ? 'Potvrđena'
                                                                : 'Na čekanju',
                                                          ),
                                                        )),
                                                        DataCell(Text(
                                                          r.isPlacena
                                                              ? 'Plaćeno'
                                                              : 'Neplaćeno',
                                                        )),
                                                      ],
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          flex: 5,
                                          child: _ReservationDetailsPanel(
                                            rezervacija: _selectedRezervacijaId ==
                                                    null
                                                ? null
                                                : filtered.firstWhere(
                                                    (r) =>
                                                        r.id ==
                                                        _selectedRezervacijaId,
                                                    orElse: () =>
                                                        filtered.first,
                                                  ),
                                            slotovi: data.slotovi,
                                            onToggle: (r, v) async {
                                              final ok = await _api
                                                  .updateRezervacijaPotvrdjena(
                                                r.id,
                                                v,
                                              );
                                              if (!context.mounted) return;
                                              if (!ok) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                        'Ažuriranje nije uspjelo.'),
                                                  ),
                                                );
                                              }
                                              if (context.mounted) {
                                                await _reload();
                                              }
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }

  Future<_DayData> _loadDay(int zaposlenikId, DateTime day) async {
    try {
      final results = await Future.wait([
        _api.getRezervacijeFiltered(datum: day, isPotvrdjena: _filterPotvrdjena),
        _api.getDostupniTermini(zaposlenikId: zaposlenikId, datum: day),
      ]).timeout(const Duration(seconds: 12));

      final rez = results[0] as List<Rezervacija>;
      final slotovi = results[1] as List<DateTime>;
      return _DayData(rezervacije: rez, slotovi: slotovi);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e.toString();
        });
      }
      rethrow;
    }
  }
}

class _DayData {
  final List<Rezervacija> rezervacije;
  final List<DateTime> slotovi;

  _DayData({required this.rezervacije, required this.slotovi});
}

class _SlotsSection extends StatelessWidget {
  const _SlotsSection({required this.slotovi});

  final List<DateTime> slotovi;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Slobodni slotovi (${slotovi.length})',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        if (slotovi.isEmpty)
          Text(
            'Nema slobodnih slotova (ili su svi zauzeti).',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.70)),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: slotovi
                .map((t) => Chip(label: Text(_formatTime(t.toLocal()))))
                .toList(),
          ),
      ],
    );
  }
}

class _ReservationDetailsPanel extends StatelessWidget {
  const _ReservationDetailsPanel({
    required this.rezervacija,
    required this.slotovi,
    required this.onToggle,
  });

  final Rezervacija? rezervacija;
  final List<DateTime> slotovi;
  final Future<void> Function(Rezervacija r, bool v) onToggle;

  @override
  Widget build(BuildContext context) {
    if (rezervacija == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Detalji', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Odaberi rezervaciju iz tabele.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
              ),
              const SizedBox(height: 18),
              _SlotsSection(slotovi: slotovi),
            ],
          ),
        ),
      );
    }

    final dt = rezervacija!.datumRezervacije.toLocal();
    final isPast = dt.isBefore(DateTime.now());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Detalji', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Text(
              rezervacija!.uslugaNaziv ?? 'Usluga',
              style: Theme.of(context).textTheme.titleLarge,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              '${_formatDateTimeLocal(dt)}\n'
              'Klijent: ${rezervacija!.korisnikIme ?? '-'}\n'
              'Plaćanje: ${rezervacija!.isPlacena ? 'Plaćeno' : 'Neplaćeno'}',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Chip(
                  label: Text(
                    rezervacija!.isPotvrdjena ? 'Potvrđena' : 'Na čekanju',
                  ),
                ),
                const Spacer(),
                if (isPast)
                  const Text('Prošlo', style: TextStyle(color: Colors.grey))
                else if (!rezervacija!.isPotvrdjena)
                  FilledButton(
                    onPressed: () => onToggle(rezervacija!, true),
                    child: const Text('Potvrdi'),
                  )
                else
                  OutlinedButton(
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Vrati na čekanje?'),
                          content: const Text(
                            'Ovo će označiti rezervaciju kao nepotvrđenu.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Odustani'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Potvrdi'),
                            ),
                          ],
                        ),
                      );
                      if (ok != true) return;
                      await onToggle(rezervacija!, false);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Rezervacija vraćena na čekanje.'),
                        ),
                      );
                    },
                    child: const Text('Vrati'),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Expanded(
              child: SingleChildScrollView(
                child: _SlotsSection(slotovi: slotovi),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReservationTerapeutTile extends StatelessWidget {
  final Rezervacija rezervacija;
  final Future<void> Function(bool) onToggle;

  const _ReservationTerapeutTile({
    required this.rezervacija,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final dt = rezervacija.datumRezervacije.toLocal();
    final isPast = dt.isBefore(DateTime.now());
    final messenger = ScaffoldMessenger.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          rezervacija.isPotvrdjena ? Icons.check_circle : Icons.schedule,
          color: rezervacija.isPotvrdjena ? Colors.green : Colors.orange,
        ),
        title: Text(rezervacija.uslugaNaziv ?? 'Usluga'),
        subtitle: Text(
          '${_formatDateTimeLocal(dt)}\n'
          'Klijent: ${rezervacija.korisnikIme ?? '-'}\n'
          '${rezervacija.isPlacena ? 'Plaćeno' : 'Nije plaćeno'}',
          style: const TextStyle(fontSize: 12),
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (isPast)
              const Text(
                'Prošlo',
                style: TextStyle(color: Colors.grey),
              )
            else if (!rezervacija.isPotvrdjena)
              FilledButton(
                onPressed: () async {
                  await onToggle(true);
                },
                child: const Text('Potvrdi'),
              )
            else
              OutlinedButton(
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Vrati na čekanje?'),
                      content: const Text(
                        'Ovo će označiti rezervaciju kao nepotvrđenu.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Odustani'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Potvrdi'),
                        ),
                      ],
                    ),
                  );
                  if (ok != true) return;
                  await onToggle(false);
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Rezervacija vraćena na čekanje.')),
                  );
                },
                child: const Text('Vrati'),
              ),
          ],
        ),
      ),
    );
  }
}
