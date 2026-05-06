import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/usluga.dart';
import '../../providers/service_provider.dart';
import '../catalog/service_details_screen.dart';
import '../../ui/widgets/page_header.dart';
import '../../ui/widgets/hover_card.dart';
import '../../ui/widgets/load_retry_panel.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!mounted) return;
      // Učitaj katalog i ID-eve favorita; favoriteServices filtrira po _allServices.
      await context.read<ServiceProvider>().fetchServices();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<ServiceProvider>();
    final favorites = sp.favoriteServices;

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 22, 26, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          const PageHeader(
            title: 'Favoriti',
            subtitle: 'Vaše omiljene usluge na jednom mjestu.',
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _buildFavoritesBody(context, sp, favorites),
          ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoritesBody(
    BuildContext context,
    ServiceProvider sp,
    List<Usluga> favorites,
  ) {
    if (sp.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (sp.loadFailed) {
      return LoadRetryPanel(
        message: sp.loadError ?? 'Nepoznata greška.',
        title: 'Ne možemo učitati favorita',
        onRetry: () => sp.fetchServices(),
      );
    }
    if (favorites.isEmpty) {
      return Center(
        child: Text(
          'Još nemaš favorita.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final crossAxisCount = w >= 1100 ? 3 : (w >= 760 ? 2 : 1);

        return Scrollbar(
          controller: _scrollController,
          child: GridView.builder(
            controller: _scrollController,
            primary: false,
            padding: const EdgeInsets.all(0),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 2.6,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: favorites.length,
            itemBuilder: (context, index) {
              final u = favorites[index];
              return HoverCard(
                padding: const EdgeInsets.all(14),
                tooltip: 'Otvori detalje: ${u.naziv}',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ServiceDetailsScreen(serviceId: u.id),
                    ),
                  );
                },
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        u.slikaUrl,
                        width: 92,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox(
                          width: 92,
                          height: 64,
                          child: Center(
                            child: Icon(Icons.broken_image),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            u.naziv,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${u.cijena} KM • ${u.trajanje}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.72),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Ukloni iz favorita',
                      icon: const Icon(
                        Icons.favorite,
                        color: Colors.redAccent,
                      ),
                      onPressed: () => sp.toggleFavorite(u.id),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

