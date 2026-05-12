import 'package:flutter/material.dart';

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
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _ime = TextEditingController(
    text: widget.existing?.ime ?? '',
  );
  late final TextEditingController _prezime = TextEditingController(
    text: widget.existing?.prezime ?? '',
  );
  late final TextEditingController _specijalizacija = TextEditingController(
    text: widget.existing?.specijalizacija ?? '',
  );
  late final TextEditingController _telefon = TextEditingController(
    text: widget.existing?.telefon ?? '',
  );

  @override
  void dispose() {
    _ime.dispose();
    _prezime.dispose();
    _specijalizacija.dispose();
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
        width: 520,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _ime,
                decoration: const InputDecoration(labelText: 'Ime'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Ime je obavezno.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _prezime,
                decoration: const InputDecoration(labelText: 'Prezime'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Prezime je obavezno.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _specijalizacija,
                decoration: const InputDecoration(
                  labelText: 'Specijalizacije',
                  helperText: 'Odvojite tagove zarezom, npr. Swedish, Facial',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Specijalizacija je obavezna.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _telefon,
                decoration: const InputDecoration(
                  labelText: 'Telefon (opcionalno)',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Otkaži'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              Zaposlenik(
                id: widget.existing?.id ?? 0,
                ime: _ime.text.trim(),
                prezime: _prezime.text.trim(),
                specijalizacija: _specijalizacija.text.trim(),
                telefon: _telefon.text.trim().isEmpty
                    ? null
                    : _telefon.text.trim(),
              ),
            );
          },
          child: const Text('Sačuvaj'),
        ),
      ],
    );
  }
}
