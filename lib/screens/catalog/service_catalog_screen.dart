import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/service_provider.dart';
import 'service_details_screen.dart';
import '../../ui/widgets/page_header.dart';
import '../../ui/widgets/hover_card.dart';

class ServiceCatalogScreen extends StatefulWidget {
  const ServiceCatalogScreen({super.key});

  @override
  State<ServiceCatalogScreen> createState() => _ServiceCatalogScreenState();
}

class _ServiceCatalogScreenState extends State<ServiceCatalogScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Učitavamo podatke čim se ekran otvori
    Future.microtask(() {
      // POPRAVLJENO: Provjera da li je widget još uvijek u stablu
      if (!mounted) return;
      Provider.of<ServiceProvider>(context, listen: false).fetchServices();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var serviceProvider = Provider.of<ServiceProvider>(context);

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 22, 26, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          const PageHeader(
            title: 'Katalog usluga',
            subtitle: 'Pretraži i upravljaj favoritima.',
            trailing: _BackIfPossible(),
          ),
          const SizedBox(height: 14),
          TextField(
            onChanged: (value) => serviceProvider.searchServices(value),
            decoration: const InputDecoration(
              hintText: 'Pretraži usluge…',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: serviceProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(
                    builder: (context, c) {
                      final w = c.maxWidth;
                      final crossAxisCount = w >= 1200
                          ? 4
                          : (w >= 900 ? 3 : (w >= 640 ? 2 : 1));

                      return Scrollbar(
                        controller: _scrollController,
                        child: GridView.builder(
                          controller: _scrollController,
                          primary: false,
                          padding: const EdgeInsets.all(0),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            childAspectRatio: 1.18,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: serviceProvider.services.length,
                          itemBuilder: (context, index) {
                            var usluga = serviceProvider.services[index];
                            final isFav =
                                serviceProvider.isFavorite(usluga.id);

                            return Stack(
                              children: [
                                Positioned.fill(
                                  child: HoverCard(
                                    padding: EdgeInsets.zero,
                                    tooltip:
                                        'Otvori detalje: ${usluga.naziv}',
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              ServiceDetailsScreen(
                                            serviceId: usluga.id,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius:
                                                const BorderRadius.vertical(
                                              top: Radius.circular(16),
                                            ),
                                            child: Image.network(
                                              usluga.slikaUrl,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error,
                                                      stackTrace) =>
                                                  const Center(
                                                child: Icon(
                                                  Icons.broken_image,
                                                  size: 44,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                              12, 10, 12, 12),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                usluga.naziv,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                '${usluga.cijena} KM • ${usluga.trajanje}',
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.72),
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 10,
                                  right: 10,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Colors.black
                                          .withValues(alpha: 0.35),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.14),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: IconButton(
                                      tooltip: isFav
                                          ? 'Ukloni iz favorita'
                                          : 'Dodaj u favorite',
                                      icon: Icon(
                                        isFav
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        color: isFav
                                            ? Colors.redAccent
                                            : Colors.white,
                                      ),
                                      onPressed: () {
                                        serviceProvider
                                            .toggleFavorite(usluga.id);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
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

class _BackIfPossible extends StatelessWidget {
  const _BackIfPossible();

  @override
  Widget build(BuildContext context) {
    if (!Navigator.canPop(context)) return const SizedBox.shrink();
    return IconButton(
      tooltip: 'Nazad',
      onPressed: () => Navigator.pop(context),
      icon: const Icon(Icons.arrow_back),
    );
  }
}