import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/services/api_service.dart';
import '../../models/usluga.dart';
import '../../providers/auth_provider.dart';
import '../../providers/service_provider.dart';
import '../../ui/navigation/desktop_nav.dart';
import '../../ui/widgets/hover_card.dart';
import '../../ui/widgets/load_retry_panel.dart';
import '../../ui/widgets/page_header.dart';
import 'service_details_screen.dart';
import 'service_category_manager_panel.dart';
import 'service_editor_dialog.dart';

class ServiceCatalogScreen extends StatefulWidget {
  const ServiceCatalogScreen({super.key});

  @override
  State<ServiceCatalogScreen> createState() => _ServiceCatalogScreenState();
}

class _ServiceCatalogScreenState extends State<ServiceCatalogScreen> {
  final ScrollController _scrollController = ScrollController();
  late final TextEditingController _filterCtrl;

  @override
  void initState() {
    super.initState();
    _filterCtrl = TextEditingController();
    Future.microtask(() {
      if (!mounted) return;
      Provider.of<ServiceProvider>(context, listen: false).fetchServices();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final q = Provider.of<DesktopNav>(
          context,
          listen: false,
        ).takePendingCatalogSearch();
        if (q != null && q.isNotEmpty) {
          _filterCtrl.text = q;
          Provider.of<ServiceProvider>(
            context,
            listen: false,
          ).searchServices(q);
        }
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _filterCtrl.dispose();
    super.dispose();
  }

  Future<void> _openServiceEditor(Usluga? existing) async {
    final ok = await showServiceEditorDialog(context, existing: existing);
    if (!mounted) return;
    if (ok) {
      await context.read<ServiceProvider>().fetchServices();
    }
  }

  Future<void> _confirmDeleteService(Usluga u) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Brisanje usluge'),
        content: Text(
          'Obrisati „${u.naziv}“? Ako usluga ima rezervacije ili plaćanja, '
          'brisanje može biti odbijeno.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Otkaži'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Obriši'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;

    final err = await ApiService().deleteUsluga(u.id);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usluga obrisana.')),
      );
      await context.read<ServiceProvider>().fetchServices();
    }
  }

  @override
  Widget build(BuildContext context) {
    var serviceProvider = Provider.of<ServiceProvider>(context);
    final isAdmin = context.watch<AuthProvider>().isAdmin;

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Katalog usluga',
              subtitle: isAdmin
                  ? 'Pretraži i upravljaj favoritima; kao admin upravljaj kategorijama, dodaj, uredi ili obriši usluge.'
                  : 'Pretraži i upravljaj favoritima.',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isAdmin) ...[
                    IconButton(
                      tooltip: 'Kategorije usluga',
                      icon: const Icon(Icons.category_outlined),
                      onPressed: () =>
                          showServiceCategoryManagerDialog(context),
                    ),
                    IconButton(
                      tooltip: 'Nova usluga',
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => _openServiceEditor(null),
                    ),
                  ],
                  const _BackIfPossible(),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _filterCtrl,
              onChanged: (value) {
                serviceProvider.searchServices(value);
                setState(() {});
              },
              decoration: InputDecoration(
                hintText: 'Pretraži usluge…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _filterCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Očisti',
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _filterCtrl.clear();
                          serviceProvider.searchServices('');
                          setState(() {});
                        },
                      ),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: _buildCatalogBody(
                context,
                serviceProvider,
                isAdmin,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCatalogBody(
    BuildContext context,
    ServiceProvider serviceProvider,
    bool isAdmin,
  ) {
    if (serviceProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (serviceProvider.loadFailed) {
      return LoadRetryPanel(
        message: serviceProvider.loadError ?? 'Nepoznata greška.',
        onRetry: () => serviceProvider.fetchServices(),
      );
    }
    if (serviceProvider.services.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Nema dostupnih usluga u katalogu.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
              textAlign: TextAlign.center,
            ),
            if (isAdmin) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => _openServiceEditor(null),
                icon: const Icon(Icons.add),
                label: const Text('Dodaj uslugu'),
              ),
            ],
          ],
        ),
      );
    }

    return LayoutBuilder(
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
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 1.18,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: serviceProvider.services.length,
            itemBuilder: (context, index) {
              var usluga = serviceProvider.services[index];
              final isFav = serviceProvider.isFavorite(usluga.id);

              return Stack(
                children: [
                  Positioned.fill(
                    child: HoverCard(
                      padding: EdgeInsets.zero,
                      tooltip: 'Otvori detalje: ${usluga.naziv}',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ServiceDetailsScreen(serviceId: usluga.id),
                          ),
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                              child: Image.network(
                                usluga.slikaUrl,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Center(
                                      child: Icon(Icons.broken_image, size: 44),
                                    ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  usluga.naziv,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${usluga.cijena} KM • ${usluga.trajanje}',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.72),
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
                  if (isAdmin)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.14),
                            width: 0.8,
                          ),
                        ),
                        child: IconButton(
                          tooltip: 'Uredi uslugu',
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () => _openServiceEditor(usluga),
                        ),
                      ),
                    ),
                  if (isAdmin)
                    Positioned(
                      bottom: 10,
                      left: 10,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.14),
                            width: 0.8,
                          ),
                        ),
                        child: IconButton(
                          tooltip: 'Obriši uslugu',
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Color(0xFFFFAB91),
                            size: 20,
                          ),
                          onPressed: () => _confirmDeleteService(usluga),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14),
                          width: 0.8,
                        ),
                      ),
                      child: IconButton(
                        tooltip: isFav
                            ? 'Ukloni iz favorita'
                            : 'Dodaj u favorite',
                        icon: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          color: isFav ? Colors.redAccent : Colors.white,
                        ),
                        onPressed: () {
                          serviceProvider.toggleFavorite(usluga.id);
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
