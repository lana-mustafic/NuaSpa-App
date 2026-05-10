import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/services/api_service.dart';
import '../../models/rezervacija.dart';
import '../../models/rezervacija_povijest_item.dart';
import '../../providers/auth_provider.dart';
import 'therapist_schedule_timeline.dart';

String _formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

String _formatTime(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String _formatDateTimeLocal(DateTime d) {
  final l = d.toLocal();
  return '${_formatDate(l)} ${_formatTime(l)}';
}

/// Raspored terapeuta — calendar timeline + desni Drawer s kontekstom klijenta.
class TherapistScheduleScreen extends StatefulWidget {
  const TherapistScheduleScreen({super.key});

  @override
  State<TherapistScheduleScreen> createState() =>
      _TherapistScheduleScreenState();
}

class _TherapistScheduleScreenState extends State<TherapistScheduleScreen> {
  final ApiService _api = ApiService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late DateTime _day;
  Future<_DayData>? _dayFuture;
  bool _autoLoadScheduled = false;
  String? _loadError;
  bool? _filterPotvrdjena;
  bool? _filterPlacena;

  final TextEditingController _searchCtrl = TextEditingController();
  Rezervacija? _detailBooking;

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

  void _openBookingDetail(Rezervacija r) {
    setState(() => _detailBooking = r);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scaffoldKey.currentState?.openEndDrawer();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final zid = auth.zaposlenikId;

    if (!auth.isZaposlenik) {
      return const Center(child: Text('Vaš nalog nema ulogu terapeuta.'));
    }

    if (zid == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'JWT nema ZaposlenikId. U bazi povežite korisnika sa zaposlenikom.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_dayFuture == null && !_autoLoadScheduled) {
      _autoLoadScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        _autoLoadScheduled = false;
        await _reload();
      });
    }

    final theme = Theme.of(context);
    final dayLabel = _formatDate(_day);

    final mq = MediaQuery.sizeOf(context);
    final drawerW = mq.width >= 600 ? 420.0 : mq.width * .92;

    return Theme(
      data: theme.copyWith(
        drawerTheme: DrawerThemeData(
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          width: drawerW,
        ),
      ),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.transparent,
        onEndDrawerChanged: (opened) {
          if (!opened && mounted) setState(() => _detailBooking = null);
        },
        endDrawer: _detailBooking == null
            ? null
            : Drawer(
                child: _TherapistClientDrawerContent(
                  api: _api,
                  rezervacija: _detailBooking!,
                  onClose: () => Navigator.maybePop(context),
                  slotoviFuture: () async {
                    final data = await _dayFuture;
                    return data?.slotovi ?? [];
                  },
                  onPotvrdiToggled: _togglePotvrdaAndReload,
                ),
              ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Raspored terapeuta',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Osvježi',
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Calendar timeline pregled rezervacija (blokovi) i brzi kontekst klijenta.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.70)),
              ),
              const SizedBox(height: 20),
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
                          padding: const EdgeInsets.all(24),
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

                      final data =
                          snap.data ?? _DayData(rezervacije: [], slotovi: []);

                      return Scrollbar(
                        controller: _scrollController,
                        child: ListView(
                          controller: _scrollController,
                          primary: false,
                          padding: EdgeInsets.zero,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  tooltip: 'Prethodni dan',
                                  onPressed: () async {
                                    setState(() {
                                      _day = _day.subtract(
                                        const Duration(days: 1),
                                      );
                                    });
                                    await _reload();
                                  },
                                  icon: const Icon(Icons.chevron_left),
                                ),
                                Expanded(
                                  child: Tooltip(
                                    message: 'Odaberi datum iz kalendara',
                                    child: InkWell(
                                      onTap: _pickDate,
                                      borderRadius: BorderRadius.circular(12),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        child: Text(
                                          dayLabel,
                                          textAlign: TextAlign.center,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Sljedeći dan',
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
                            const SizedBox(height: 20),
                            LayoutBuilder(
                              builder: (context, c) {
                                final q = _searchCtrl.text.trim().toLowerCase();

                                List<Rezervacija>
                                filtered = data.rezervacije.where((r) {
                                  if (_filterPlacena != null &&
                                      r.isPlacena != _filterPlacena) {
                                    return false;
                                  }
                                  if (q.isEmpty) return true;
                                  final s = [
                                    r.uslugaNaziv,
                                    r.korisnikIme,
                                    r.zaposlenikIme,
                                  ].whereType<String>().join(' ').toLowerCase();
                                  return s.contains(q);
                                }).toList();

                                if (_detailBooking != null &&
                                    !filtered.any(
                                      (r) => r.id == _detailBooking!.id,
                                    )) {
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (!mounted) return;
                                    setState(() => _detailBooking = null);
                                    Navigator.maybePop(context);
                                  });
                                }

                                final isWide = c.maxWidth >= 1020;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _searchCtrl,
                                            onChanged: (_) => setState(() {}),
                                            decoration: const InputDecoration(
                                              hintText:
                                                  'Pretraga klijenata i usluga…',
                                              prefixIcon: Icon(Icons.search),
                                            ),
                                          ),
                                        ),
                                        if (!isWide) ...[
                                          const SizedBox(width: 10),
                                          Text(
                                            '${filtered.length}',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleSmall,
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        ChoiceChip(
                                          label: const Text('Sve'),
                                          selected: _filterPotvrdjena == null,
                                          onSelected: (_) async {
                                            setState(
                                              () => _filterPotvrdjena = null,
                                            );
                                            await _reload();
                                          },
                                        ),
                                        ChoiceChip(
                                          label: const Text('Na čekanju'),
                                          selected: _filterPotvrdjena == false,
                                          onSelected: (_) async {
                                            setState(
                                              () => _filterPotvrdjena = false,
                                            );
                                            await _reload();
                                          },
                                        ),
                                        ChoiceChip(
                                          label: const Text('Potvrđene'),
                                          selected: _filterPotvrdjena == true,
                                          onSelected: (_) async {
                                            setState(
                                              () => _filterPotvrdjena = true,
                                            );
                                            await _reload();
                                          },
                                        ),
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
                                    const SizedBox(height: 14),
                                    _LegendRow(),
                                    const SizedBox(height: 16),
                                    if (filtered.isEmpty)
                                      _TimelineEmpty(dayLabel)
                                    else ...[
                                      if (isWide)
                                        Text(
                                          'Termini (${filtered.length})',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      if (isWide) const SizedBox(height: 12),
                                      SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        physics: filtered.isEmpty
                                            ? const NeverScrollableScrollPhysics()
                                            : null,
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                            minWidth: isWide ? c.maxWidth : 520,
                                          ),
                                          child: TherapistDayTimeline(
                                            rezervacije: filtered,
                                            selectedId: _detailBooking?.id,
                                            onSelect: _openBookingDetail,
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 28),
                                    _SlotsSection(slotovi: data.slotovi),
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
      ),
    );
  }

  Future<void> _togglePotvrdaAndReload(Rezervacija r, bool v) async {
    final ok = await _api.updateRezervacijaPotvrdjena(r.id, v);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ažuriranje nije uspjelo.')));
    }
    await _reload();
  }

  Future<_DayData> _loadDay(int zaposlenikId, DateTime day) async {
    try {
      final results = await Future.wait([
        _api.getRezervacijeFiltered(
          datum: day,
          isPotvrdjena: _filterPotvrdjena,
        ),
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

class _LegendRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Widget dot(Color c, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.75),
          ),
        ),
      ],
    );

    return Wrap(
      spacing: 14,
      runSpacing: 8,
      children: [
        dot(TherapistSchedulePalette.pendingStroke, 'Na čekanju'),
        dot(TherapistSchedulePalette.confirmedStroke, 'Potvrđeno'),
        dot(TherapistSchedulePalette.premiumStroke, 'Premium (VIP ili plać.+potvr.)'),
        dot(TherapistSchedulePalette.cancelled(context), 'Otkazano / prošlost'),
      ],
    );
  }
}

class _TimelineEmpty extends StatelessWidget {
  const _TimelineEmpty(this.dayLabel);
  final String dayLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedScale(
      scale: 1,
      duration: const Duration(milliseconds: 300),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: 1,
        child: Material(
          color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(40, 48, 40, 48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary.withValues(alpha: 0.35),
                        theme.colorScheme.tertiary.withValues(alpha: 0.2),
                      ],
                    ),
                  ),
                  child: Icon(
                    Icons.self_improvement_rounded,
                    size: 64,
                    color: theme.colorScheme.onPrimary.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(height: 26),
                Text(
                  'Sve je spremno za danas!',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Trenutno nema zakazanih termina za $dayLabel u ovom filtru.\nProvjerite drugi datum ili stanje filtara.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.45,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
            'Nema slobodnih slotova.',
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

class _TherapistClientDrawerContent extends StatefulWidget {
  const _TherapistClientDrawerContent({
    required this.api,
    required this.rezervacija,
    required this.onClose,
    required this.slotoviFuture,
    required this.onPotvrdiToggled,
  });

  final ApiService api;
  final Rezervacija rezervacija;
  final VoidCallback onClose;
  final Future<List<DateTime>> Function() slotoviFuture;
  final Future<void> Function(Rezervacija r, bool potvrdi) onPotvrdiToggled;

  @override
  State<_TherapistClientDrawerContent> createState() =>
      _TherapistClientDrawerContentState();
}

class _TherapistClientDrawerContentState
    extends State<_TherapistClientDrawerContent> {
  late Future<List<DateTime>> _slots;
  late Future<List<RezervacijaPovijestItem>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _slots = widget.slotoviFuture();
    final kid = widget.rezervacija.korisnikId;
    _historyFuture = kid > 0
        ? widget.api.getRezervacijaPovijestZaKlijenta(
            korisnikId: kid,
            excludeRezervacijaId: widget.rezervacija.id,
            take: 20,
          )
        : Future.value(const <RezervacijaPovijestItem>[]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = widget.rezervacija;
    final dt = r.datumRezervacije.toLocal();
    final isPast = dt.isBefore(DateTime.now());

    final premiumSegment = r.premiumKlijent || (r.isPotvrdjena && r.isPlacena);
    final napomena = r.napomenaZaTerapeuta?.trim();

    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          transitionBuilder: (child, anim) =>
                              FadeTransition(opacity: anim, child: child),
                          child: Align(
                            key: ValueKey(r.id),
                            alignment: Alignment.centerLeft,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Klijent — kontekst',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    letterSpacing: 0.15,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.65),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  r.korisnikIme ?? 'Nepoznat klijent',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (r.korisnikTelefon?.trim().isNotEmpty ??
                                    false) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    r.korisnikTelefon!.trim(),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                                if (premiumSegment) ...[
                                  const SizedBox(height: 8),
                                  Chip(
                                    avatar: Icon(
                                      Icons.workspace_premium_outlined,
                                      size: 18,
                                      color: TherapistSchedulePalette
                                          .premiumStroke,
                                    ),
                                    label: Text(
                                      r.premiumKlijent
                                          ? 'Premium klijent (VIP)'
                                          : 'Potvrđeno i plaćeno',
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Zatvori panel',
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                color: Colors.amber.shade900.withValues(alpha: 0.22),
                child: ListTile(
                  leading: const Icon(Icons.health_and_safety_outlined),
                  title: const Text('Napomena za tretman'),
                  subtitle: Text(
                    napomena == null || napomena.isEmpty
                        ? 'Nema unesene napomene (alergije, kontraindikacije…).'
                        : napomena,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _formatDateTimeLocal(dt),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${r.uslugaNaziv ?? 'Usluga'}\n'
                'Terapeut vidi samo vlastite termine.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.onClose,
                      icon: const Icon(Icons.keyboard_return),
                      label: const Text('Sakrij panel'),
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              Text(
                'Povijest tretmana',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              FutureBuilder<List<RezervacijaPovijestItem>>(
                future: _historyFuture,
                builder: (context, histSnap) {
                  if (histSnap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }
                  final items = histSnap.data ?? const [];
                  if (items.isEmpty) {
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.history_rounded),
                      title: Text(
                        r.korisnikId <= 0
                            ? 'Nije dostupan ID klijenta'
                            : 'Nema dodatnih termina',
                      ),
                      subtitle: Text(
                        r.korisnikId <= 0
                            ? 'Kontaktirajte administratora (API).'
                            : 'Prikazuju se samo zajednički termini s vama.',
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final h in items)
                        ListTile(
                          dense: true,
                          leading: Icon(
                            h.isOtkazana
                                ? Icons.event_busy_rounded
                                : Icons.event_rounded,
                          ),
                          title: Text(h.uslugaNaziv ?? 'Usluga'),
                          subtitle: Text(
                            '${_formatDateTimeLocal(h.datumRezervacije)} · '
                            '${h.isPotvrdjena ? 'potvr.' : 'čekanje'} · '
                            '${h.isPlacena ? 'plać.' : 'neplać.'}'
                            '${h.isOtkazana ? ' · otkazano' : ''}',
                          ),
                        ),
                    ],
                  );
                },
              ),
              const Divider(height: 24),
              Text(
                'Rezervacija',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Chip(
                    label: Text(r.isPotvrdjena ? 'Potvrđena' : 'Na čekanju'),
                  ),
                  Chip(label: Text(r.isPlacena ? 'Plaćeno' : 'Neplaćeno')),
                ],
              ),
              const SizedBox(height: 12),
              if (isPast)
                Text(
                  'Termin je u prošlosti.',
                  style: TextStyle(color: Colors.grey.shade500),
                )
              else if (!r.isPotvrdjena)
                FilledButton.icon(
                  onPressed: () => widget.onPotvrdiToggled(r, true),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Potvrdi rezervaciju'),
                )
              else
                OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Vrati na čekanje?'),
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
                    if (ok == true && context.mounted) {
                      await widget.onPotvrdiToggled(r, false);
                    }
                  },
                  icon: const Icon(Icons.schedule),
                  label: const Text('Vrati na čekanje'),
                ),
              const SizedBox(height: 18),
              FutureBuilder<List<DateTime>>(
                future: _slots,
                builder: (context, s) => _SlotsSection(slotovi: s.data ?? []),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
