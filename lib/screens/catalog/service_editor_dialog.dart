import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/api/services/api_service.dart';
import '../../models/usluga.dart';

String _fileNameFromPath(String path) {
  final normalized = path.replaceAll(r'\', '/');
  final i = normalized.lastIndexOf('/');
  return i >= 0 ? normalized.substring(i + 1) : normalized;
}

/// Opens a dialog to create or edit a service (Admin API).
/// Returns `true` if the record was saved successfully.
Future<bool> showServiceEditorDialog(
  BuildContext context, {
  Usluga? existing,
}) async {
  final api = ApiService();
  final katList = await api.getKategorijeUsluga();
  if (!context.mounted) return false;

  if (katList.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'No categories yet. In Service catalog (admin) open the category icon and add at least one.',
        ),
      ),
    );
    return false;
  }

  final nazivCtrl = TextEditingController(text: existing?.naziv ?? '');
  final cijenaCtrl = TextEditingController(
    text: existing != null ? existing.cijena.toStringAsFixed(2) : '',
  );
  final trajanjeCtrl = TextEditingController(
    text: '${existing?.trajanjeMinuta ?? 60}',
  );
  final opisCtrl = TextEditingController(text: existing?.opis ?? '');

  var katId = existing?.kategorijaUslugaId ?? katList.first.id;
  if (!katList.any((k) => k.id == katId)) {
    katId = katList.first.id;
  }

  String? pickedImagePath;

  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(existing == null ? 'New service' : 'Edit service'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: nazivCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: cijenaCtrl,
                decoration: const InputDecoration(labelText: 'Price (KM)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: trajanjeCtrl,
                decoration:
                    const InputDecoration(labelText: 'Duration (minutes)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: opisCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              Text(
                'Image',
                style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 6),
              if (kIsWeb)
                Text(
                  'Image upload from files is not supported in the browser; '
                  'use Windows, macOS or the mobile app.',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      ),
                )
              else ...[
                OutlinedButton.icon(
                  onPressed: () async {
                    final r = await FilePicker.platform.pickFiles(
                      type: FileType.image,
                      allowMultiple: false,
                      withData: false,
                    );
                    if (r != null &&
                        r.files.isNotEmpty &&
                        r.files.single.path != null) {
                      pickedImagePath = r.files.single.path;
                      setDialogState(() {});
                    }
                  },
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(
                    pickedImagePath == null
                        ? 'Choose image from files…'
                        : 'Change image…',
                  ),
                ),
                if (pickedImagePath != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _fileNameFromPath(pickedImagePath!),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(ctx).textTheme.bodySmall,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          pickedImagePath = null;
                          setDialogState(() {});
                        },
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
                ],
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: DropdownButton<int>(
                  value: katId,
                  hint: const Text('Category'),
                  isExpanded: true,
                  items: katList
                      .map(
                        (k) => DropdownMenuItem(
                          value: k.id,
                          child: Text(k.naziv),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() {
                        katId = v;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
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
    ),
  );

  void disposeCtrls() {
    nazivCtrl.dispose();
    cijenaCtrl.dispose();
    trajanjeCtrl.dispose();
    opisCtrl.dispose();
  }

  if (saved != true || !context.mounted) {
    disposeCtrls();
    return false;
  }

  final naziv = nazivCtrl.text.trim();
  final cijena = double.tryParse(
        cijenaCtrl.text.replaceAll(',', '.'),
      ) ??
      0;
  final trajanje = int.tryParse(trajanjeCtrl.text.trim()) ?? 60;
  final opis = opisCtrl.text.trim();

  disposeCtrls();

  if (naziv.isEmpty || cijena <= 0 || katId <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Check name, price and category.')),
    );
    return false;
  }

  String slikaUrl;
  if (pickedImagePath != null) {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Image upload is not available in the web browser.'),
        ),
      );
      return false;
    }
    final uploaded = await api.uploadUslugaImage(pickedImagePath!);
    if (!context.mounted) return false;
    if (uploaded == null || uploaded.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Image upload failed. Check your connection and permissions.',
          ),
        ),
      );
      return false;
    }
    slikaUrl = uploaded;
  } else if (existing != null &&
      !existing.slikaUrl.contains('picsum.photos')) {
    slikaUrl = existing.slikaUrl;
  } else {
    slikaUrl = 'https://picsum.photos/seed/new/400/300';
  }

  final draft = Usluga(
    id: existing?.id ?? 0,
    naziv: naziv,
    cijena: cijena,
    trajanje: '$trajanje min',
    slikaUrl: slikaUrl,
    kategorija: katList.firstWhere((k) => k.id == katId).naziv,
    trajanjeMinuta: trajanje,
    opis: opis,
    kategorijaUslugaId: katId,
  );

  final ok = existing == null
      ? await api.createUsluga(draft) != null
      : await api.updateUsluga(draft) != null;

  if (!context.mounted) return false;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(ok ? 'Saved.' : 'Error saving.')),
  );
  return ok;
}
