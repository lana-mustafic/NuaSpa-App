import 'package:flutter/material.dart';

import '../../core/api/services/api_service.dart';
import '../../models/admin/therapist_kpi.dart';
import '../../models/admin/rezervacija_calendar_item.dart';
import '../../models/zaposlenik.dart';
import '../../ui/widgets/page_header.dart';

class AdminTherapistProfileScreen extends StatefulWidget {
  const AdminTherapistProfileScreen({
    super.key,
    required this.therapist,
  });

  final Zaposlenik therapist;

  @override
  State<AdminTherapistProfileScreen> createState() =>
      _AdminTherapistProfileScreenState();
}

enum _Tab { overview, appointments }

class _AdminTherapistProfileScreenState extends State<AdminTherapistProfileScreen> {
  final ApiService _api = ApiService();
  _Tab _tab = _Tab.overview;

  DateTimeRange _range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );

  Future<TherapistKpi?>? _kpiFuture;
  Future<List<RezervacijaCalendarItem>>? _appointmentsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final from = DateTime(_range.start.year, _range.start.month, _range.start.day);
    final to = DateTime(_range.end.year, _range.end.month, _range.end.day);
    setState(() {
      _kpiFuture = _api.getTherapistKpis(
        zaposlenikId: widget.therapist.id,
        from: from,
        to: to,
      );
      _appointmentsFuture = _api.getRezervacijeCalendar(
        from: from,
        to: to,
        zaposlenikId: widget.therapist.id,
        includeOtkazane: true,
      );
    });
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _range,
    );
    if (picked == null || !mounted) return;
    setState(() => _range = picked);
    _reload();
  }

  List<String> _tags(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return const [];
    return t
        .split(RegExp(r'[,;/]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(8)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.therapist;
    final name = '${t.ime} ${t.prezime}'.trim();
    final tags = _tags(t.specijalizacija);

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 22, 26, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: name,
              subtitle: 'Profil terapeuta · KPI · termini',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickRange,
                    icon: const Icon(Icons.date_range_outlined),
                    label: Text(
                      '${_range.start.toLocal().toString().split(' ').first} – '
                      '${_range.end.toLocal().toString().split(' ').first}',
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Osvježi'),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    tooltip: 'Nazad',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in tags)
                  Chip(
                    label: Text(tag),
                  ),
                if (tags.isEmpty)
                  Text(
                    'Specijalizacija nije postavljena.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SegmentedButton<_Tab>(
              segments: const [
                ButtonSegment(
                  value: _Tab.overview,
                  label: Text('Pregled'),
                  icon: Icon(Icons.insights_outlined),
                ),
                ButtonSegment(
                  value: _Tab.appointments,
                  label: Text('Termini'),
                  icon: Icon(Icons.event_note_outlined),
                ),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() => _tab = s.first),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: IndexedStack(
                index: _tab.index,
                children: [
                  _OverviewTab(kpiFuture: _kpiFuture),
                  _AppointmentsTab(future: _appointmentsFuture),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.kpiFuture});
  final Future<TherapistKpi?>? kpiFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TherapistKpi?>(
      future: kpiFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final kpi = snap.data;
        if (kpi == null) {
          return const Center(child: Text('Nema KPI podataka.'));
        }

        final tiles = [
          _KpiTile(label: 'Ukupno', value: '${kpi.ukupnoRezervacija}', icon: Icons.event_note_outlined),
          _KpiTile(label: 'Potvrđene', value: '${kpi.potvrdjeneRezervacije}', icon: Icons.check_circle_outline),
          _KpiTile(label: 'Otkazane', value: '${kpi.otkazaneRezervacije}', icon: Icons.cancel_outlined),
          _KpiTile(label: 'Plaćene', value: '${kpi.placeneRezervacije}', icon: Icons.payments_outlined),
          _KpiTile(label: 'Prihod', value: '${kpi.prihod.toStringAsFixed(0)} KM', icon: Icons.show_chart_rounded),
          _KpiTile(label: 'Ocjena', value: kpi.prosjecnaOcjena == 0 ? '—' : kpi.prosjecnaOcjena.toStringAsFixed(2), icon: Icons.star_border_rounded),
        ];

        return LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final cols = w >= 1200 ? 3 : 2;
            const gap = 12.0;
            final tileW = (w - gap * (cols - 1)) / cols;
            return SingleChildScrollView(
              primary: false,
              child: Wrap(
                spacing: gap,
                runSpacing: gap,
                children: tiles.map((t) => SizedBox(width: tileW, child: t)).toList(),
              ),
            );
          },
        );
      },
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.70),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppointmentsTab extends StatelessWidget {
  const _AppointmentsTab({required this.future});
  final Future<List<RezervacijaCalendarItem>>? future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RezervacijaCalendarItem>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snap.data ?? const [];
        if (list.isEmpty) {
          return const Center(child: Text('Nema termina za period.'));
        }

        return Card(
          child: SingleChildScrollView(
            primary: false,
            child: DataTable(
              showCheckboxColumn: false,
              columns: const [
                DataColumn(label: Text('Datum')),
                DataColumn(label: Text('Vrijeme')),
                DataColumn(label: Text('Usluga')),
                DataColumn(label: Text('Klijent')),
                DataColumn(label: Text('Status')),
              ],
              rows: [
                for (final r in list)
                  DataRow(
                    cells: [
                      DataCell(Text(r.datumRezervacije.toLocal().toString().split(' ').first)),
                      DataCell(Text(r.datumRezervacije.toLocal().toString().split(' ').last.substring(0, 5))),
                      DataCell(Text(r.uslugaNaziv ?? 'Usluga')),
                      DataCell(Text(r.korisnikIme ?? '')),
                      DataCell(Chip(
                        label: Text(
                          r.isOtkazana
                              ? 'Otkazana'
                              : (r.isPotvrdjena ? 'Potvrđena' : 'Na čekanju'),
                        ),
                      )),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

