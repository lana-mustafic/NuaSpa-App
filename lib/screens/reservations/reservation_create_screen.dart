import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api/services/api_service.dart';
import '../../providers/service_provider.dart';

import '../../models/zaposlenik.dart';

class _ReservationBootstrap {
  _ReservationBootstrap(this.therapists);
  final List<Zaposlenik> therapists;
}

class ReservationCreateScreen extends StatefulWidget {
  const ReservationCreateScreen({super.key});

  @override
  State<ReservationCreateScreen> createState() =>
      _ReservationCreateScreenState();
}

class _ReservationCreateScreenState extends State<ReservationCreateScreen> {
  final ApiService _apiService = ApiService();

  DateTime _selectedDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  int? _selectedServiceId;
  int? _selectedTherapistId;
  DateTime? _selectedSlot;
  List<DateTime> _availableSlots = [];
  bool _loadingSlots = false;

  Future<_ReservationBootstrap>? _bootstrapFuture;
  bool _bootstrapStarted = false;
  bool _defaultsPostFramePending = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bootstrapStarted) return;
    _bootstrapStarted = true;
    final sp = context.read<ServiceProvider>();
    _bootstrapFuture = () async {
      await sp.fetchServices();
      final therapists = await _apiService.getZaposlenici();
      return _ReservationBootstrap(therapists);
    }();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );

    if (picked == null || !mounted) return;
    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
      _selectedSlot = null;
    });
    await _loadSlots();
  }

  Future<void> _loadSlots() async {
    final tid = _selectedTherapistId;
    if (tid == null || !mounted) return;

    final day = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

    setState(() {
      _loadingSlots = true;
      _selectedSlot = null;
    });

    final slots = await _apiService.getDostupniTermini(
      zaposlenikId: tid,
      datum: day,
    );

    if (!mounted) return;
    setState(() {
      _availableSlots = slots;
      _loadingSlots = false;
    });
  }

  String _formatSlot(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final serviceProvider = Provider.of<ServiceProvider>(context);
    final services = serviceProvider.services;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova rezervacija'),
      ),
      body: FutureBuilder<_ReservationBootstrap>(
        future: _bootstrapFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting ||
              snapshot.data == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final therapists = snapshot.data!.therapists;

          final needsDefaults = (services.isNotEmpty &&
                  _selectedServiceId == null) ||
              (therapists.isNotEmpty && _selectedTherapistId == null);
          if (needsDefaults && !_defaultsPostFramePending) {
            _defaultsPostFramePending = true;
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              _defaultsPostFramePending = false;
              if (!mounted) return;
              final freshServices =
                  context.read<ServiceProvider>().services;
              setState(() {
                if (freshServices.isNotEmpty && _selectedServiceId == null) {
                  _selectedServiceId = freshServices.first.id;
                }
                if (therapists.isNotEmpty && _selectedTherapistId == null) {
                  _selectedTherapistId = therapists.first.id;
                }
              });
              await _loadSlots();
            });
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Datum: ${_selectedDate.toLocal().toString().split(".").first}',
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
                    onChanged: services.isEmpty
                        ? null
                        : (value) {
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
                    onChanged: therapists.isEmpty
                        ? null
                        : (value) async {
                            setState(() {
                              _selectedTherapistId = value;
                              _selectedSlot = null;
                            });
                            await _loadSlots();
                          },
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Text(
                'Dostupni termini',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              if (_loadingSlots)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_selectedTherapistId == null)
                const Text('Odaberi terapeuta.')
              else if (_availableSlots.isEmpty)
                const Text('Nema slobodnih termina za ovaj datum.')
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableSlots.map((slot) {
                    final selected = _selectedSlot != null &&
                        _selectedSlot!.year == slot.year &&
                        _selectedSlot!.month == slot.month &&
                        _selectedSlot!.day == slot.day &&
                        _selectedSlot!.hour == slot.hour &&
                        _selectedSlot!.minute == slot.minute;
                    return FilterChip(
                      label: Text(_formatSlot(slot)),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => _selectedSlot = slot);
                      },
                    );
                  }).toList(),
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
                  if (_selectedSlot == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Odaberi jedan od dostupnih termina.'),
                      ),
                    );
                    return;
                  }

                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(context);

                  final created = await _apiService.createRezervacija(
                    datumRezervacije: _selectedSlot!,
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
