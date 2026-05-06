import 'package:flutter/material.dart';
import '../../models/usluga.dart';
import '../../core/api/services/api_service.dart';
import '../../models/recenzija.dart';
import '../../ui/widgets/page_header.dart';
import '../../ui/widgets/hover_card.dart';

class ServiceDetailsScreen extends StatefulWidget {
  final int serviceId;

  const ServiceDetailsScreen({super.key, required this.serviceId});

  @override
  State<ServiceDetailsScreen> createState() => _ServiceDetailsScreenState();
}

class _ServiceDetailsScreenState extends State<ServiceDetailsScreen> {
  final ApiService _apiService = ApiService();
  final ScrollController _leftScrollController = ScrollController();
  final ScrollController _rightScrollController = ScrollController();

  Future<Usluga?> get _serviceFuture => _apiService.getUslugaById(widget.serviceId);
  late Future<List<Recenzija>> _recenzijeFuture;

  final TextEditingController _komentarController = TextEditingController();
  int _ocjena = 5;

  @override
  void initState() {
    super.initState();
    _recenzijeFuture = _apiService.getRecenzijeByUsluga(widget.serviceId);
  }

  @override
  void dispose() {
    _komentarController.dispose();
    _leftScrollController.dispose();
    _rightScrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshRecenzije() async {
    setState(() {
      _recenzijeFuture = _apiService.getRecenzijeByUsluga(widget.serviceId);
    });
  }

  Widget _buildStars(int value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(
          i < value ? Icons.star : Icons.star_border,
          size: 18,
          color: Colors.amber[700],
        ),
      ),
    );
  }

  Widget _buildRatingPicker() {
    return Row(
      children: List.generate(5, (i) {
        final v = i + 1;
        return IconButton(
          tooltip: '$v',
          onPressed: () => setState(() => _ocjena = v),
          icon: Icon(
            v <= _ocjena ? Icons.star : Icons.star_border,
            color: Colors.amber[700],
          ),
        );
      }),
    );
  }

  Widget _buildReviewsSection() {
    return FutureBuilder<List<Recenzija>>(
      future: _recenzijeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final reviews = snapshot.data ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recenzije',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  tooltip: 'Osvježi',
                  onPressed: _refreshRecenzije,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (reviews.isEmpty)
              const Text('Još nema recenzija za ovu uslugu.')
            else
              ...reviews.map((r) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              r.korisnikIme.isEmpty ? 'Korisnik' : r.korisnikIme,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            _buildStars(r.ocjena),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(r.komentar),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 16),
            Text(
              'Dodaj recenziju',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            _buildRatingPicker(),
            const SizedBox(height: 8),
            TextField(
              controller: _komentarController,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Komentar',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () async {
                final komentar = _komentarController.text.trim();
                if (komentar.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Unesi komentar.')),
                  );
                  return;
                }

                final messenger = ScaffoldMessenger.of(context);

                final created = await _apiService.createRecenzija(
                  uslugaId: widget.serviceId,
                  ocjena: _ocjena,
                  komentar: komentar,
                );

                if (!mounted) return;

                if (created == null) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Neuspjelo slanje recenzije.')),
                  );
                  return;
                }

                _komentarController.clear();
                await _refreshRecenzije();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Recenzija je dodana.')),
                );
              },
              icon: const Icon(Icons.send),
              label: const Text('Pošalji'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: FutureBuilder<Usluga?>(
        future: _serviceFuture,
        builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Greška pri učitavanju: ${snapshot.error}'),
          );
        }

        final service = snapshot.data;
        if (service == null) {
          return const Center(child: Text('Usluga nije pronađena.'));
        }

        return LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 980;

            final hero = HoverCard(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: Image.network(
                      service.slikaUrl,
                      height: wide ? 420 : 240,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return SizedBox(
                          height: wide ? 420 : 240,
                          child: const Center(
                            child: Icon(Icons.broken_image, size: 60),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service.naziv,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              '${service.cijena} KM',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '• ${service.trajanje}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.72),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Kategorija: ${service.kategorija}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );

            final detailsPanel = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PageHeader(
                  title: 'Detalji usluge',
                  subtitle: 'Pregled usluge i recenzija.',
                  trailing: IconButton(
                    tooltip: 'Nazad',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surface
                        .withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                      width: 0.8,
                    ),
                  ),
                  child: const Text(
                    'Opis uskoro (potrebno je dodati polje u Flutter model).',
                  ),
                ),
                const SizedBox(height: 18),
                _buildReviewsSection(),
              ],
            );

            if (!wide) {
              return Scrollbar(
                controller: _leftScrollController,
                child: ListView(
                  controller: _leftScrollController,
                  primary: false,
                  padding: const EdgeInsets.fromLTRB(26, 22, 26, 26),
                  children: [
                    detailsPanel,
                    const SizedBox(height: 14),
                    hero,
                  ],
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(26, 22, 26, 26),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: hero),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 6,
                    child: Scrollbar(
                      controller: _rightScrollController,
                      child: SingleChildScrollView(
                        controller: _rightScrollController,
                        primary: false,
                        child: detailsPanel,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      ),
    );
  }
}

