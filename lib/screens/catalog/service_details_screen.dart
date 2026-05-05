import 'package:flutter/material.dart';
import '../../models/usluga.dart';
import '../../core/api/services/api_service.dart';
import '../../models/recenzija.dart';

class ServiceDetailsScreen extends StatefulWidget {
  final int serviceId;

  const ServiceDetailsScreen({super.key, required this.serviceId});

  @override
  State<ServiceDetailsScreen> createState() => _ServiceDetailsScreenState();
}

class _ServiceDetailsScreenState extends State<ServiceDetailsScreen> {
  final ApiService _apiService = ApiService();

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalji usluge'),
      ),
      body: FutureBuilder<Usluga?>(
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

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  service.slikaUrl,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox(
                      height: 220,
                      child: Center(child: Icon(Icons.broken_image, size: 60)),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              Text(
                service.naziv,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '${service.cijena} KM',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                service.trajanje,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[700],
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Kategorija: ${service.kategorija}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),

              // Opis trenutno nije modeliran na Flutteru (nema polje u `Usluga` modelu),
              // pa ga za sada preskačemo. (Možemo dodati sljedeće u fazama.)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Opis uskoro (potrebno je dodati polje u Flutter model).',
                ),
              ),

              const SizedBox(height: 24),
              _buildReviewsSection(),
            ],
          );
        },
      ),
    );
  }
}

