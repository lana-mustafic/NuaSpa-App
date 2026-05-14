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

/// Otvara dijalog za kreiranje ili uređivanje usluge (Admin API).
/// Vraća `true` ako je zapis uspješno snimljen.
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
          'Nema kategorija. U Katalogu usluga (admin) otvori ikonu kategorije i dodaj barem jednu.',
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
        title: Text(existing == null ? 'Nova usluga' : 'Uredi uslugu'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: nazivCtrl,
                decoration: const InputDecoration(labelText: 'Naziv'),
              ),
              TextField(
                controller: cijenaCtrl,
                decoration: const InputDecoration(labelText: 'Cijena (KM)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: trajanjeCtrl,
                decoration:
                    const InputDecoration(labelText: 'Trajanje (minute)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: opisCtrl,
                decoration: const InputDecoration(labelText: 'Opis'),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              Text(
                'Slika',
                style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 6),
              if (kIsWeb)
                Text(
                  'Upload slike iz datoteka na ovoj platformi nije podržan u pregledniku; '
                  'koristi Windows, macOS ili mobilnu aplikaciju.',
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
                        ? 'Odaberi sliku iz dokumenata…'
                        : 'Promijeni sliku…',
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
                        child: const Text('Ukloni'),
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
                  hint: const Text('Kategorija'),
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
            child: const Text('Otkaži'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sačuvaj'),
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
      const SnackBar(content: Text('Provjerite naziv, cijenu i kategoriju.')),
    );
    return false;
  }

  String slikaUrl;
  if (pickedImagePath != null) {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload slike nije dostupan u web pregledniku.')),
      );
      return false;
    }
    final uploaded = await api.uploadUslugaImage(pickedImagePath!);
    if (!context.mounted) return false;
    if (uploaded == null || uploaded.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upload slike nije uspio. Provjeri vezu i dozvole.'),
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
    SnackBar(content: Text(ok ? 'Sačuvano.' : 'Greška pri čuvanju.')),
  );
  return ok;
}
