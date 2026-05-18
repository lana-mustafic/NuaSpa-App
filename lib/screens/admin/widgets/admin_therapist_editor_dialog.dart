import 'package:flutter/material.dart';

import '../../../core/api/services/api_service.dart';
import '../../../models/kategorija_usluga.dart';
import '../../../models/usluga.dart';
import '../../../models/zaposlenik.dart';

/// Add / edit therapist — shared by roster and profile screens.
Future<Zaposlenik?> showAdminTherapistEditorDialog(
  BuildContext context, {
  Zaposlenik? existing,
}) {
  return showDialog<Zaposlenik>(
    context: context,
    builder: (_) => AdminTherapistEditorDialog(existing: existing),
  );
}

class AdminTherapistEditorDialog extends StatefulWidget {
  const AdminTherapistEditorDialog({super.key, this.existing});

  final Zaposlenik? existing;

  @override
  State<AdminTherapistEditorDialog> createState() =>
      _AdminTherapistEditorDialogState();
}

class _AdminTherapistEditorDialogState extends State<AdminTherapistEditorDialog> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _ime = TextEditingController(
    text: widget.existing?.ime ?? '',
  );
  late final TextEditingController _prezime = TextEditingController(
    text: widget.existing?.prezime ?? '',
  );
  late final TextEditingController _telefon = TextEditingController(
    text: widget.existing?.telefon ?? '',
  );

  bool _loading = true;
  String? _loadError;
  List<KategorijaUsluga> _categories = [];
  List<Usluga> _services = [];

  int? _categoryId;
  final Set<int> _selectedServiceIds = {};
  String? _specializationError;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final results = await Future.wait([
        _api.getKategorijeUsluga(),
        _api.getUsluge(),
      ]);
      if (!mounted) return;

      final categories = results[0] as List<KategorijaUsluga>;
      final services = results[1] as List<Usluga>;
      final existingTags = _parseTags(widget.existing?.specijalizacija ?? '');

      int? categoryId = widget.existing?.kategorijaUslugaId;
      if (categoryId == null || categoryId <= 0) {
        categoryId = _inferCategoryId(services, existingTags);
      }
      if (categoryId == null && categories.isNotEmpty) {
        categoryId = categories.first.id;
      }

      final selectedIds = <int>{};
      if (categoryId != null) {
        for (final service in services.where(
          (u) => u.kategorijaUslugaId == categoryId,
        )) {
          final matchesTag = existingTags.any(
            (t) => t.toLowerCase() == service.naziv.trim().toLowerCase(),
          );
          if (matchesTag) selectedIds.add(service.id);
        }
      }

      setState(() {
        _categories = categories;
        _services = services;
        _categoryId = categoryId;
        _selectedServiceIds
          ..clear()
          ..addAll(selectedIds);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Failed to load categories and services.';
        _loading = false;
      });
    }
  }

  List<String> _parseTags(String raw) => raw
      .split(RegExp(r'[,;/]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  int? _inferCategoryId(List<Usluga> services, List<String> tags) {
    if (tags.isEmpty) return null;
    final counts = <int, int>{};
    for (final service in services) {
      final hit = tags.any(
        (t) => t.toLowerCase() == service.naziv.trim().toLowerCase(),
      );
      if (hit) {
        counts[service.kategorijaUslugaId] =
            (counts[service.kategorijaUslugaId] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return null;
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  List<Usluga> get _servicesInCategory {
    final catId = _categoryId;
    if (catId == null) return const [];
    final list =
        _services.where((u) => u.kategorijaUslugaId == catId).toList();
    list.sort((a, b) => a.naziv.compareTo(b.naziv));
    return list;
  }

  void _onCategoryChanged(int? id) {
    setState(() {
      _categoryId = id;
      _selectedServiceIds.clear();
    });
  }

  void _toggleService(int serviceId) {
    setState(() {
      if (_selectedServiceIds.contains(serviceId)) {
        _selectedServiceIds.remove(serviceId);
      } else {
        _selectedServiceIds.add(serviceId);
      }
      _specializationError = null;
    });
  }

  String _buildSpecijalizacija() {
    final names = _servicesInCategory
        .where((u) => _selectedServiceIds.contains(u.id))
        .map((u) => u.naziv.trim())
        .where((n) => n.isNotEmpty)
        .toList();
    return names.join(', ');
  }

  @override
  void dispose() {
    _ime.dispose();
    _prezime.dispose();
    _telefon.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null ? 'Add therapist' : 'Edit therapist',
      ),
      content: SizedBox(
        width: 560,
        child: _loading
            ? const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : _loadError != null
                ? Text(_loadError!)
                : Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _ime,
                            decoration: const InputDecoration(labelText: 'First name'),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                    ? 'First name is required.'
                                    : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _prezime,
                            decoration: const InputDecoration(labelText: 'Last name'),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                    ? 'Last name is required.'
                                    : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _telefon,
                            decoration: const InputDecoration(
                              labelText: 'Phone (optional)',
                            ),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<int>(
                            value: _categoryId,
                            decoration: const InputDecoration(
                              labelText: 'Service category',
                              helperText:
                                  'Therapist is assigned to this catalog category.',
                            ),
                            items: _categories
                                .map(
                                  (k) => DropdownMenuItem(
                                    value: k.id,
                                    child: Text(k.naziv),
                                  ),
                                )
                                .toList(),
                            onChanged: _categories.isEmpty ? null : _onCategoryChanged,
                            validator: (value) =>
                                value == null ? 'Category is required.' : null,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Specializations',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Select services from the chosen category.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.65),
                                ),
                          ),
                          const SizedBox(height: 10),
                          if (_servicesInCategory.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                _categoryId == null
                                    ? 'Choose a category first.'
                                    : 'No services in this category yet.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            )
                          else
                            Container(
                              constraints: const BoxConstraints(maxHeight: 220),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Theme.of(context).dividerColor,
                                ),
                              ),
                              child: SingleChildScrollView(
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final service in _servicesInCategory)
                                      FilterChip(
                                        label: Text(service.naziv),
                                        selected: _selectedServiceIds
                                            .contains(service.id),
                                        onSelected: (_) =>
                                            _toggleService(service.id),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          if (_selectedServiceIds.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              '${_selectedServiceIds.length} selected',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                          if (_specializationError != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _specializationError!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _loading || _loadError != null
              ? null
              : () {
                  if (!_formKey.currentState!.validate()) return;
                  if (_selectedServiceIds.isEmpty) {
                    setState(() {
                      _specializationError =
                          'Select at least one specialization.';
                    });
                    return;
                  }

                  Navigator.pop(
                    context,
                    Zaposlenik(
                      id: widget.existing?.id ?? 0,
                      ime: _ime.text.trim(),
                      prezime: _prezime.text.trim(),
                      specijalizacija: _buildSpecijalizacija(),
                      telefon: _telefon.text.trim().isEmpty
                          ? null
                          : _telefon.text.trim(),
                      kategorijaUslugaId: _categoryId,
                    ),
                  );
                },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
