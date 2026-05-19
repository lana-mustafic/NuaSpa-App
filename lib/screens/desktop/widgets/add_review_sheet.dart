import 'package:flutter/material.dart';

import '../../../core/api/services/api_service.dart';
import '../../../models/usluga.dart';
import '../../../models/zaposlenik.dart';
import '../../../ui/theme/nua_luxury_tokens.dart';

/// Admin / dashboard flow: pick therapist first, then a service from their category.
class AddReviewSheet extends StatefulWidget {
  const AddReviewSheet({
    super.key,
    required this.therapists,
    required this.usluge,
    required this.api,
  });

  final List<Zaposlenik> therapists;
  final List<Usluga> usluge;
  final ApiService api;

  @override
  State<AddReviewSheet> createState() => _AddReviewSheetState();
}

class _AddReviewSheetState extends State<AddReviewSheet> {
  int? _zaposlenikId;
  int? _uslugaId;
  int _ocjena = 5;
  bool _busy = false;
  final _komentar = TextEditingController();

  @override
  void dispose() {
    _komentar.dispose();
    super.dispose();
  }

  List<Zaposlenik> get _eligibleTherapists => widget.therapists
      .where((z) => (z.kategorijaUslugaId ?? 0) > 0)
      .toList();

  Zaposlenik? _therapistById(int id) {
    for (final z in widget.therapists) {
      if (z.id == id) return z;
    }
    return null;
  }

  List<Usluga> _servicesFor(int? zaposlenikId) {
    if (zaposlenikId == null) return [];
    final z = _therapistById(zaposlenikId);
    final kat = z?.kategorijaUslugaId;
    if (kat == null || kat <= 0) return [];
    return widget.usluge.where((u) => u.kategorijaUslugaId == kat).toList();
  }

  String _therapistLabel(Zaposlenik z) {
    final cat = z.kategorijaUslugaNaziv;
    final base = '${z.ime} ${z.prezime}';
    if (cat != null && cat.trim().isNotEmpty) return '$base · $cat';
    return base;
  }

  Future<void> _submit() async {
    final zId = _zaposlenikId;
    final uId = _uslugaId;
    final komentar = _komentar.text.trim();

    if (zId == null) {
      _snack('Odaberite terapeuta.');
      return;
    }
    if (uId == null) {
      _snack('Odaberite uslugu.');
      return;
    }
    if (komentar.isEmpty) {
      _snack('Unesite komentar.');
      return;
    }

    setState(() => _busy = true);
    final (_, error) = await widget.api.createRecenzija(
      uslugaId: uId,
      zaposlenikId: zId,
      ocjena: _ocjena,
      komentar: komentar,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (error != null) {
      _snack(error);
      return;
    }
    Navigator.pop(context, true);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating, width: 380),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context).bottom;
    final ik = MediaQuery.viewInsetsOf(context).bottom;
    final services = _servicesFor(_zaposlenikId);
    final therapists = _eligibleTherapists;

    return Padding(
      padding: EdgeInsets.only(bottom: ik),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Material(
              color: NuaLuxuryTokens.voidViolet,
              elevation: 12,
              borderRadius: BorderRadius.circular(22),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + pad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Nova recenzija',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                          ),
                        ),
                        IconButton(
                          onPressed: _busy ? null : () => Navigator.pop(context, false),
                          icon: const Icon(Icons.close_rounded),
                          color: Colors.white70,
                        ),
                      ],
                    ),
                    Text(
                      'Odaberite terapeuta, zatim uslugu iz njegove kategorije.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white60,
                          ),
                    ),
                    const SizedBox(height: 18),
                    if (therapists.isEmpty)
                      Text(
                        'Nema terapeuta s dodijeljenom kategorijom usluga.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white70,
                            ),
                      )
                    else ...[
                      _fieldLabel('Terapeut *'),
                      const SizedBox(height: 8),
                      _darkDropdown<int>(
                        value: _zaposlenikId,
                        hint: 'Odaberite terapeuta',
                        items: therapists
                            .map(
                              (z) => DropdownMenuItem(
                                value: z.id,
                                child: Text(_therapistLabel(z)),
                              ),
                            )
                            .toList(),
                        onChanged: _busy
                            ? null
                            : (v) => setState(() {
                                  _zaposlenikId = v;
                                  _uslugaId = null;
                                }),
                      ),
                      const SizedBox(height: 16),
                      _fieldLabel('Usluga *'),
                      const SizedBox(height: 8),
                      _darkDropdown<int>(
                        value: _uslugaId,
                        hint: _zaposlenikId == null
                            ? 'Prvo odaberite terapeuta'
                            : services.isEmpty
                                ? 'Nema usluga u kategoriji'
                                : 'Odaberite uslugu',
                        items: services
                            .map(
                              (u) => DropdownMenuItem(
                                value: u.id,
                                child: Text(u.naziv),
                              ),
                            )
                            .toList(),
                        onChanged: _busy || _zaposlenikId == null || services.isEmpty
                            ? null
                            : (v) => setState(() => _uslugaId = v),
                      ),
                      const SizedBox(height: 16),
                      _fieldLabel('Ocjena'),
                      const SizedBox(height: 8),
                      Row(
                        children: List.generate(5, (i) {
                          final star = i + 1;
                          return IconButton(
                            onPressed: _busy ? null : () => setState(() => _ocjena = star),
                            icon: Icon(
                              star <= _ocjena
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: const Color(0xFFF5B942),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 8),
                      _fieldLabel('Komentar *'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _komentar,
                        maxLines: 4,
                        maxLength: 500,
                        enabled: !_busy,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.06),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          hintText: 'Iskustvo gosta…',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _busy || therapists.isEmpty ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: NuaLuxuryTokens.softPurpleGlow,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _busy
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Spremi recenziju'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) => Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white54,
              fontWeight: FontWeight.w700,
            ),
      );

  Widget _darkDropdown<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            isExpanded: true,
            value: value,
            hint: Text(hint, style: TextStyle(color: Colors.white.withValues(alpha: 0.45))),
            dropdownColor: NuaLuxuryTokens.voidViolet,
            style: const TextStyle(color: Colors.white),
            items: items,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}
