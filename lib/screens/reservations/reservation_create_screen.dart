import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api/services/api_service.dart';
import '../../providers/service_provider.dart';

import '../../models/zaposlenik.dart';

class ReservationCreateScreen extends StatefulWidget {
  const ReservationCreateScreen({super.key});

  @override
  State<ReservationCreateScreen> createState() =>
      _ReservationCreateScreenState();
}

class _ReservationCreateScreenState extends State<ReservationCreateScreen> {
  final ApiService _apiService = ApiService();

  DateTime _selectedDate = DateTime.now();
  int? _selectedServiceId;
  int? _selectedTherapistId;

  late Future<List<Zaposlenik>> _futureTherapists;

  @override
  void initState() {
    super.initState();

    _futureTherapists = _apiService.getZaposlenici();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );

    if (picked == null) return;
    setState(() {
      _selectedDate = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _selectedDate.hour,
        _selectedDate.minute,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final serviceProvider = Provider.of<ServiceProvider>(context);
    final services = serviceProvider.services;

    // Init odabira prvih vrijednosti (ako korisnik nije ništa odabrao).
    if (_selectedServiceId == null && services.isNotEmpty) {
      _selectedServiceId = services.first.id;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova rezervacija'),
      ),
      body: FutureBuilder<List<Zaposlenik>>(
        future: _futureTherapists,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final therapists = snapshot.data ?? [];

          if (therapists.isNotEmpty && _selectedTherapistId == null) {
            _selectedTherapistId = therapists.first.id;
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Datum rezervacije: ${_selectedDate.toLocal().toString().split(".").first}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today),
                label: const Text('Odaberi datum'),
              ),

              const SizedBox(height: 16),

              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Usluga',
                  border: OutlineInputBorder(),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: _selectedServiceId,
                    items: services
                        .map(
                          (s) => DropdownMenuItem<int>(
                            value: s.id,
                            child: Text(s.naziv),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedServiceId = value;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Terapeut',
                  border: OutlineInputBorder(),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: _selectedTherapistId,
                    items: therapists
                        .map(
                          (t) => DropdownMenuItem<int>(
                            value: t.id,
                            child: Text('${t.ime} ${t.prezime}'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedTherapistId = value;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 24),

              FilledButton.icon(
                onPressed: () async {
                  if (_selectedServiceId == null ||
                      _selectedTherapistId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Odaberi uslugu i terapeuta.'),
                      ),
                    );
                    return;
                  }

                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(context);

                  final created = await _apiService.createRezervacija(
                    datumRezervacije: _selectedDate,
                    uslugaId: _selectedServiceId!,
                    zaposlenikId: _selectedTherapistId!,
                  );

                  if (!mounted) return;

                  if (created == null) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Neuspjela kreacija rezervacije.'),
                      ),
                    );
                    return;
                  }

                  navigator.pop(true);
                },
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Rezerviši'),
              ),
            ],
          );
        },
      ),
    );
  }
}

