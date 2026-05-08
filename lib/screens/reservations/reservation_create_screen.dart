import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api/services/api_service.dart';
import '../../providers/service_provider.dart';

import '../../models/zaposlenik.dart';
import '../../models/usluga.dart';
import '../../ui/widgets/page_header.dart';
import '../../ui/widgets/glass_panel.dart';

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

  static const double _kSplitBreakpoint = 960;

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

  final ScrollController _mainScrollController = ScrollController();
  final ScrollController _slotsScrollController = ScrollController();

  @override
  void dispose() {
    _mainScrollController.dispose();
    _slotsScrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bootstrapStarted) return;
    _bootstrapStarted = true;
    // Ne pozivati fetchServices (notifyListeners) iz didChangeDependencies —
    // Provider bi se označio tijekom build faze. Odgodi do post-frame + Future.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final sp = context.read<ServiceProvider>();
      setState(() {
        _bootstrapFuture = Future(() async {
          await sp.fetchServices();
          final therapists = await _apiService.getZaposlenici();
          return _ReservationBootstrap(therapists);
        });
      });
    });
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

  Future<void> _submit() async {
    if (_selectedServiceId == null || _selectedTherapistId == null) {
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
  }

  int? _effectiveDropdownValue(int? selected, List<int> validIds) {
    if (selected == null || validIds.isEmpty) return null;
    return validIds.contains(selected) ? selected : null;
  }

  Widget _buildServiceTherapistPickers(
    BuildContext context,
    List<Usluga> services,
    List<Zaposlenik> therapists,
  ) {
    final serviceIds = services.map((s) => s.id).toList();
    final therapistIds = therapists.map((t) => t.id).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Usluga',
            border: OutlineInputBorder(),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              isExpanded: true,
              hint: services.isEmpty
                  ? const Text('Nema učitanih usluga')
                  : const Text('Odaberite uslugu'),
              value: _effectiveDropdownValue(_selectedServiceId, serviceIds),
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
              hint: therapists.isEmpty
                  ? const Text('Nema terapeuta')
                  : const Text('Odaberite terapeuta'),
              value: _effectiveDropdownValue(_selectedTherapistId, therapistIds),
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
      ],
    );
  }

  Widget _buildDateRow(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Datum: ${_selectedDate.toLocal().toString().split(".").first}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Tooltip(
          message: 'Odaberi datum rezervacije',
          child: OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today),
            label: const Text('Odaberi datum'),
          ),
        ),
      ],
    );
  }

  Widget _buildSlotsSection({bool forWidePanel = false}) {
    final title = Text(
      'Dostupni termini',
      style: Theme.of(context).textTheme.titleSmall,
    );

    Widget slotBody() {
      if (_loadingSlots) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: CircularProgressIndicator(),
          ),
        );
      }
      if (_selectedTherapistId == null) {
        return Align(
          alignment: Alignment.topLeft,
          child: Text(
            'Odaberi terapeuta.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
          ),
        );
      }
      if (_availableSlots.isEmpty) {
        return Align(
          alignment: Alignment.topLeft,
          child: Text(
            'Nema slobodnih termina za ovaj datum.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
          ),
        );
      }
      if (forWidePanel) {
        return Scrollbar(
          controller: _slotsScrollController,
          child: SingleChildScrollView(
            controller: _slotsScrollController,
            primary: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildSlotChips(),
            ),
          ),
        );
      }
      return _buildSlotChips();
    }

    if (!forWidePanel) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: 8),
          slotBody(),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title,
        const SizedBox(height: 8),
        Expanded(child: slotBody()),
      ],
    );
  }

  Widget _buildSlotChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _availableSlots.map((slot) {
        final selected = _selectedSlot != null &&
            _selectedSlot!.year == slot.year &&
            _selectedSlot!.month == slot.month &&
            _selectedSlot!.day == slot.day &&
            _selectedSlot!.hour == slot.hour &&
            _selectedSlot!.minute == slot.minute;
        final label = _formatSlot(slot);
        return Tooltip(
          message: 'Termin $label',
          child: FilterChip(
            label: Text(label),
            selected: selected,
            onSelected: (_) {
              setState(() => _selectedSlot = slot);
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSubmitButton() {
    return Tooltip(
      message: 'Potvrdi rezervaciju',
      child: FilledButton.icon(
        onPressed: _submit,
        icon: const Icon(Icons.check_circle_outline),
        label: const Text('Rezerviši'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final serviceProvider = Provider.of<ServiceProvider>(context);
    // Pun katalog — ne oslanjati se na filtriranu listu iz pretrage kataloga.
    final services = serviceProvider.allServices;

    Widget? leading;
    if (Navigator.canPop(context)) {
      leading = Tooltip(
        message: 'Nazad',
        child: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
      );
    }

    return Scaffold(
      body: Material(
        color: Theme.of(context).colorScheme.surface,
        child: FutureBuilder<_ReservationBootstrap>(
          future: _bootstrapFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting ||
                snapshot.data == null) {
              return const Center(child: CircularProgressIndicator());
            }

            final therapists = snapshot.data!.therapists;

            // Ako je ID izvan liste (npr. nakon promjene podataka), vrati na prvu valjanu stavku.
            final serviceIds = services.map((s) => s.id).toSet();
            final therapistIds = therapists.map((t) => t.id).toSet();
            final needsSanitize = (_selectedServiceId != null &&
                    !serviceIds.contains(_selectedServiceId)) ||
                (_selectedTherapistId != null &&
                    !therapistIds.contains(_selectedTherapistId));

            final needsDefaults = (services.isNotEmpty &&
                    _selectedServiceId == null) ||
                (therapists.isNotEmpty && _selectedTherapistId == null) ||
                needsSanitize;
            if (needsDefaults && !_defaultsPostFramePending) {
              _defaultsPostFramePending = true;
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                _defaultsPostFramePending = false;
                if (!mounted) return;
                final freshAll =
                    context.read<ServiceProvider>().allServices;
                setState(() {
                  if (freshAll.isEmpty) {
                    _selectedServiceId = null;
                  } else if (_selectedServiceId == null ||
                      !freshAll.any((u) => u.id == _selectedServiceId)) {
                    _selectedServiceId = freshAll.first.id;
                  }
                  if (therapists.isEmpty) {
                    _selectedTherapistId = null;
                  } else if (_selectedTherapistId == null ||
                      !therapists.any((t) => t.id == _selectedTherapistId)) {
                    _selectedTherapistId = therapists.first.id;
                  }
                });
                await _loadSlots();
              });
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(26, 22, 26, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PageHeader(
                    title: 'Nova rezervacija',
                    subtitle:
                        'Odaberite uslugu, terapeuta i jedan od slobodnih termina.',
                    trailing: leading,
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final wide =
                            constraints.maxWidth >= _kSplitBreakpoint;
                        if (wide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                flex: 5,
                                child: Scrollbar(
                                  controller: _mainScrollController,
                                  child: SingleChildScrollView(
                                    controller: _mainScrollController,
                                    primary: false,
                                    padding: const EdgeInsets.only(
                                      right: 16,
                                      bottom: 8,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        _buildDateRow(context),
                                        const SizedBox(height: 20),
                                        _buildServiceTherapistPickers(
                                          context,
                                          services,
                                          therapists,
                                        ),
                                        const SizedBox(height: 28),
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: _buildSubmitButton(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              VerticalDivider(
                                width: 1,
                                thickness: 1,
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                              Expanded(
                                flex: 4,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 16),
                                  child: GlassPanel(
                                    child: _buildSlotsSection(
                                      forWidePanel: true,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }

                        return Scrollbar(
                          controller: _mainScrollController,
                          child: SingleChildScrollView(
                            controller: _mainScrollController,
                            primary: false,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildDateRow(context),
                                const SizedBox(height: 16),
                                _buildServiceTherapistPickers(
                                  context,
                                  services,
                                  therapists,
                                ),
                                const SizedBox(height: 20),
                                _buildSlotsSection(forWidePanel: false),
                                const SizedBox(height: 24),
                                _buildSubmitButton(),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
