import 'package:flutter/material.dart';

import '../../core/api/services/api_service.dart';
import '../../models/kategorija_usluga.dart';

/// Lista kategorija usluga s dodavanjem, uređivanjem i brisanjem (Admin API).
class ServiceCategoryManagerPanel extends StatefulWidget {
  const ServiceCategoryManagerPanel({super.key});

  @override
  State<ServiceCategoryManagerPanel> createState() =>
      _ServiceCategoryManagerPanelState();
}

class _ServiceCategoryManagerPanelState extends State<ServiceCategoryManagerPanel> {
  final ApiService _api = ApiService();
  final ScrollController _scrollController = ScrollController();
  Future<List<KategorijaUsluga>>? _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = _api.getKategorijeUsluga();
    });
  }

  Future<void> _editCategory(KategorijaUsluga? existing) async {
    final ctrl = TextEditingController(text: existing?.naziv ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'New category' : 'Edit category'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    final naziv = ctrl.text.trim();
    ctrl.dispose();

    if (saved != true || !mounted) return;

    if (naziv.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required.')),
      );
      return;
    }

    final ok = existing == null
        ? await _api.createKategorijaUsluga(naziv) != null
        : await _api.updateKategorijaUsluga(
                KategorijaUsluga(id: existing.id, naziv: naziv),
              ) !=
              null;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Saved.' : 'Error saving.')),
    );
    if (ok) _reload();
  }

  Future<void> _delete(KategorijaUsluga k) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete category'),
        content: Text('Delete "${k.naziv}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;

    final err = await _api.deleteKategorijaUsluga(k.id);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category deleted.')),
      );
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<KategorijaUsluga>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snap.data ?? [];
        return Stack(
          children: [
            RefreshIndicator(
              onRefresh: () async => _reload(),
              child: Scrollbar(
                controller: _scrollController,
                child: ListView.builder(
                  controller: _scrollController,
                  primary: false,
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final k = list[i];
                    return ListTile(
                      leading: const Icon(Icons.folder_outlined),
                      title: Text(k.naziv),
                      trailing: PopupMenuButton<String>(
                        tooltip: 'Category actions',
                        onSelected: (v) {
                          if (v == 'edit') _editCategory(k);
                          if (v == 'delete') _delete(k);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                      onTap: () => _editCategory(k),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: FloatingActionButton(
                tooltip: 'New category',
                onPressed: () => _editCategory(null),
                child: const Icon(Icons.add),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Modalni prozor za upravljanje kategorijama (npr. s kataloga usluga).
Future<void> showServiceCategoryManagerDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                child: Row(
                  children: [
                    const Icon(Icons.category_outlined, size: 26),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Service categories',
                        style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  'Categories control how services are grouped in the catalog and when booking.',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: Theme.of(ctx)
                            .colorScheme
                            .onSurfaceVariant
                            .withValues(alpha: 0.95),
                      ),
                ),
              ),
              const Divider(height: 1),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: ServiceCategoryManagerPanel(),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
