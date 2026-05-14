import 'package:flutter/material.dart';

import '../../core/api/services/api_service.dart';
import '../../models/usluga.dart';

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
      const SnackBar(content: Text('Prvo dodajte barem jednu kategoriju.')),
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
  final slikaCtrl = TextEditingController(
    text: existing != null && !existing.slikaUrl.contains('picsum.photos')
        ? existing.slikaUrl
        : '',
  );

  var katId = existing?.kategorijaUslugaId ?? katList.first.id;
  if (!katList.any((k) => k.id == katId)) {
    katId = katList.first.id;
  }

  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(existing == null ? 'Nova usluga' : 'Uredi uslugu'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              TextField(
                controller: slikaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Slika URL (opcionalno)',
                ),
              ),
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
                      setDialogState(() => katId = v);
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
    slikaCtrl.dispose();
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
  final slika = slikaCtrl.text.trim();

  disposeCtrls();

  if (naziv.isEmpty || cijena <= 0 || katId <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Provjerite naziv, cijenu i kategoriju.')),
    );
    return false;
  }

  final draft = Usluga(
    id: existing?.id ?? 0,
    naziv: naziv,
    cijena: cijena,
    trajanje: '$trajanje min',
    slikaUrl: slika.isNotEmpty
        ? slika
        : (existing?.slikaUrl ?? 'https://picsum.photos/seed/new/400/300'),
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
