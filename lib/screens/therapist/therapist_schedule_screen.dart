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

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _day = DateTime(n.year, n.month, n.day);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
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
    setState(() => _dayFuture = f);
    await f;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final zid = auth.zaposlenikId;

    if (!auth.isZaposlenik) {
      return Scaffold(
        appBar: AppBar(title: const Text('Terapeut')),
        body: const Center(
          child: Text('Vaš nalog nema ulogu terapeuta.'),
        ),
      );
    }

    if (zid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Terapeut')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'JWT nema ZaposlenikId. U bazi povežite korisnika sa zaposlenikom (Korisnik.ZaposlenikId).',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final dayLabel = _formatDate(_day);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Raspored terapeuta'),
        actions: [
          IconButton(
            tooltip: 'Osvježi',
            onPressed: () => _reload(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<_DayData>(
          future: _dayFuture,
          builder: (context, snap) {
            if (_dayFuture == null ||
                snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snap.data ??
                _DayData(rezervacije: [], slotovi: []);

            return ListView(
              padding: const EdgeInsets.all(16),
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
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            dayLabel,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium,
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
                Text(
                  'Termini (${data.rezervacije.length})',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                if (data.rezervacije.isEmpty)
                  Text(
                    'Nema rezervacija za ovaj dan.',
                    style: TextStyle(color: Colors.grey.shade700),
                  )
                else
                  ...data.rezervacije.map((r) => _ReservationTerapeutTile(
                        rezervacija: r,
                        onToggle: (v) async {
                          final ok =
                              await _api.updateRezervacijaPotvrdjena(r.id, v);
                          if (!context.mounted) return;
                          if (!ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Ažuriranje nije uspjelo.'),
                              ),
                            );
                          }
                          if (context.mounted) await _reload();
                        },
                      )),
                const SizedBox(height: 24),
                Text(
                  'Slobodni slotovi (${data.slotovi.length})',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                if (data.slotovi.isEmpty)
                  Text(
                    'Nema slobodnih slotova (ili su svi zauzeti).',
                    style: TextStyle(color: Colors.grey.shade700),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: data.slotovi
                        .map(
                          (t) => Chip(
                            label: Text(_formatTime(t.toLocal())),
                          ),
                        )
                        .toList(),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<_DayData> _loadDay(int zaposlenikId, DateTime day) async {
    final rez = await _api.getRezervacijeFiltered(datum: day);
    final slotovi =
        await _api.getDostupniTermini(zaposlenikId: zaposlenikId, datum: day);
    return _DayData(rezervacije: rez, slotovi: slotovi);
  }
}

class _DayData {
  final List<Rezervacija> rezervacije;
  final List<DateTime> slotovi;

  _DayData({required this.rezervacije, required this.slotovi});
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
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: SwitchListTile(
        secondary: Icon(
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
        value: rezervacija.isPotvrdjena,
        onChanged: (v) => onToggle(v),
      ),
    );
  }
}
