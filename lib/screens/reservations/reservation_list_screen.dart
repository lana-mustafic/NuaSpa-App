import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/api/services/api_service.dart';
import '../../models/rezervacija.dart';
import 'reservation_create_screen.dart';
import '../../core/payments/stripe_payment_service.dart';

class ReservationListScreen extends StatefulWidget {
  const ReservationListScreen({super.key});

  @override
  State<ReservationListScreen> createState() => _ReservationListScreenState();
}

class _ReservationListScreenState extends State<ReservationListScreen> {
  final ApiService _apiService = ApiService();
  final StripePaymentService _stripe = StripePaymentService();

  late Future<List<Rezervacija>> _futureReservations;

  @override
  void initState() {
    super.initState();
    _futureReservations = _apiService.getRezervacije();
  }

  Future<void> _refresh() async {
    setState(() {
      _futureReservations = _apiService.getRezervacije();
    });
  }

  @override
  Widget build(BuildContext context) {
    final hideFab = context.watch<AuthProvider>().isZaposlenik;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Moje rezervacije'),
      ),
      floatingActionButton: hideFab
          ? null
          : FloatingActionButton(
              onPressed: () async {
                final created = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ReservationCreateScreen(),
                  ),
                );
                if (created == true && mounted) {
                  _refresh();
                }
              },
              child: const Icon(Icons.add),
            ),
      body: FutureBuilder<List<Rezervacija>>(
        future: _futureReservations,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data ?? [];
          if (data.isEmpty) {
            return const Center(child: Text('Trenutno nema rezervacija.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: data.length,
            itemBuilder: (context, index) {
              final r = data[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(r.uslugaNaziv ?? 'Usluga'),
                  subtitle: Text(
                    '${r.datumRezervacije.toLocal().toString().split(".").first}\n'
                    'Terapeut: ${r.zaposlenikIme ?? '-'}',
                  ),
                  trailing: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Chip(
                        label: Text(r.isPotvrdjena ? 'Potvrđena' : 'Na čekanju'),
                      ),
                      const SizedBox(height: 6),
                      if (!r.isPlacena)
                        SizedBox(
                          height: 32,
                          child: FilledButton(
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              if (!StripePaymentService.paymentSheetSupported) {
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Online plaćanje (Stripe) dostupno je samo na Android i iOS uređajima.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              final ok = await _stripe.payForReservation(r.id);
                              if (!mounted) return;
                              if (ok) {
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Plaćanje uspješno. (Webhook može kasniti par sekundi)'),
                                  ),
                                );
                                _refresh();
                              } else {
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Plaćanje nije završeno.'),
                                  ),
                                );
                              }
                            },
                            child: const Text('Plati'),
                          ),
                        )
                      else
                        const Text(
                          'Plaćeno',
                          style: TextStyle(color: Colors.green),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

