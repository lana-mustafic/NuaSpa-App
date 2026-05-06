import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/service_provider.dart';
import '../catalog/service_details_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
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
  Widget build(BuildContext context) {
    final sp = context.watch<ServiceProvider>();
    final favorites = sp.favoriteServices;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favoriti'),
      ),
      body: favorites.isEmpty
          ? const Center(child: Text('Još nemaš favorita.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final u = favorites[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        u.slikaUrl,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.broken_image),
                      ),
                    ),
                    title: Text(u.naziv),
                    subtitle: Text('${u.cijena} KM • ${u.trajanje}'),
                    trailing: IconButton(
                      tooltip: 'Ukloni iz favorita',
                      icon: const Icon(Icons.favorite, color: Colors.red),
                      onPressed: () => sp.toggleFavorite(u.id),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ServiceDetailsScreen(serviceId: u.id),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

