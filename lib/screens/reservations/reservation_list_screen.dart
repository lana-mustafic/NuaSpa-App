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
      _futureReservations = _apiService.getRezervacije();
    });
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
                                    label: Text(r.isPotvrdjena
                                        ? 'Potvrđena'
                                        : 'Na čekanju'),
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

