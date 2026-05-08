import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/api/services/api_service.dart';
import '../../models/rezervacija.dart';
import 'reservation_create_screen.dart';
import '../../core/payments/stripe_payment_service.dart';
import '../../ui/widgets/page_header.dart';
import '../../ui/widgets/primary_button.dart';

class ReservationListScreen extends StatefulWidget {
  const ReservationListScreen({super.key});

  @override
  State<ReservationListScreen> createState() => _ReservationListScreenState();
}

class _ReservationListScreenState extends State<ReservationListScreen> {
  final ApiService _apiService = ApiService();
  final StripePaymentService _stripe = StripePaymentService();

  late Future<List<Rezervacija>> _futureReservations;
  final ScrollController _scrollController = ScrollController();
  bool _includeOtkazane = false;

  @override
  void initState() {
    super.initState();
    _futureReservations = _apiService.getRezervacije();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _futureReservations =
          _apiService.getRezervacijeFiltered(includeOtkazane: _includeOtkazane);
    });
  }

  Future<void> _cancelReservation(Rezervacija r) async {
    final reasonCtrl = TextEditingController();
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Otkazati rezervaciju?'),
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
                labelText: 'Razlog (opcionalno)',
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
            onPressed: r.isPlacena ? null : () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Otkaži'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    final ok = await _apiService.cancelRezervacija(
      r.id,
      razlogOtkaza: reasonCtrl.text,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Rezervacija otkazana.' : 'Neuspjelo otkazivanje.'),
      ),
    );
    if (ok) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final hideFab = context.watch<AuthProvider>().isZaposlenik;

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 22, 26, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          PageHeader(
            title: 'Moje rezervacije',
            subtitle: 'Pregled vaših rezervacija, statusa i plaćanja.',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Osvježi',
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                ),
                const SizedBox(width: 6),
                Tooltip(
                  message: 'Prikaži otkazane',
                  child: FilterChip(
                    label: const Text('Otkazane'),
                    selected: _includeOtkazane,
                    onSelected: (v) {
                      setState(() => _includeOtkazane = v);
                      _refresh();
                    },
                  ),
                ),
                if (!hideFab) ...[
                  const SizedBox(width: 8),
                  PrimaryButton(
                    label: 'Nova rezervacija',
                    icon: Icons.add,
                    tooltip: 'Kreiraj novu rezervaciju',
                    onPressed: () async {
                      final created = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ReservationCreateScreen(),
                        ),
                      );
                      if (created == true && mounted) _refresh();
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: FutureBuilder<List<Rezervacija>>(
              future: _futureReservations,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.data ?? [];
                if (data.isEmpty) {
                  return Center(
                    child: Text(
                      'Trenutno nema rezervacija.',
                      style:
                          TextStyle(color: Colors.white.withValues(alpha: 0.75)),
                    ),
                  );
                }

                return Scrollbar(
                  controller: _scrollController,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    primary: false,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: DataTable(
                        headingRowHeight: 44,
                        dataRowMinHeight: 54,
                        dataRowMaxHeight: 66,
                        columns: const [
                          DataColumn(label: Text('Usluga')),
                          DataColumn(label: Text('Datum & vrijeme')),
                          DataColumn(label: Text('Terapeut')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Plaćanje')),
                          DataColumn(label: Text('Akcije')),
                        ],
                        rows: [
                          for (final r in data)
                            DataRow(
                              onSelectChanged: (_) {},
                              cells: [
                                DataCell(Text(r.uslugaNaziv ?? 'Usluga')),
                                DataCell(Text(
                                  r.datumRezervacije
                                      .toLocal()
                                      .toString()
                                      .split('.')
                                      .first,
                                )),
                                DataCell(Text(r.zaposlenikIme ?? '-')),
                                DataCell(
                                  Chip(
                                    label: Text(
                                      r.isOtkazana
                                          ? 'Otkazana'
                                          : (r.isPotvrdjena
                                              ? 'Potvrđena'
                                              : 'Na čekanju'),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (r.isPlacena)
                                        const Text(
                                          'Plaćeno',
                                          style: TextStyle(color: Colors.green),
                                        )
                                      else if (r.isOtkazana)
                                        const Text(
                                          '—',
                                          style: TextStyle(color: Colors.white70),
                                        )
                                      else
                                        SizedBox(
                                          height: 34,
                                          child: Tooltip(
                                            message:
                                                'Plati Online (Stripe, Android/iOS)',
                                            child: FilledButton(
                                            onPressed: () async {
                                              final messenger =
                                                  ScaffoldMessenger.of(context);
                                              if (!StripePaymentService
                                                  .paymentSheetSupported) {
                                                messenger.showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Online plaćanje (Stripe) dostupno je samo na Android i iOS uređajima.',
                                                    ),
                                                  ),
                                                );
                                                return;
                                              }
                                              final ok = await _stripe
                                                  .payForReservation(r.id);
                                              if (!mounted) return;
                                              messenger.showSnackBar(
                                                SnackBar(
                                                  content: Text(ok
                                                      ? 'Plaćanje uspješno. (Webhook može kasniti par sekundi)'
                                                      : 'Plaćanje nije završeno.'),
                                                ),
                                              );
                                              if (ok) _refresh();
                                            },
                                            child: const Text('Plati'),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Tooltip(
                                        message: r.isPlacena
                                            ? 'Plaćene rezervacije se ne otkazuju (MVP)'
                                            : (r.isOtkazana
                                                ? 'Već otkazana'
                                                : 'Otkaži rezervaciju'),
                                        child: IconButton(
                                          onPressed: (r.isPlacena || r.isOtkazana)
                                              ? null
                                              : () => _cancelReservation(r),
                                          icon: const Icon(Icons.cancel_outlined),
                                        ),
                                      ),
                                    ],
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
          ),
          ],
        ),
      ),
    );
  }
}

