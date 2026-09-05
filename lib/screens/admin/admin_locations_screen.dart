import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/api_error_messages.dart';
import '../../core/api/services/api_service.dart';
import '../../models/drzava_lookup.dart';
import '../../models/grad_lookup.dart';
import '../../ui/theme/nua_luxury_tokens.dart';
import '../../ui/widgets/luxury/luxury_confirm_dialog.dart';

class AdminLocationsScreen extends StatefulWidget {
  const AdminLocationsScreen({super.key});

  @override
  State<AdminLocationsScreen> createState() => _AdminLocationsScreenState();
}

enum _LocTab { countries, cities }

class _AdminLocationsScreenState extends State<AdminLocationsScreen> {
  final _api = ApiService();
  _LocTab _tab = _LocTab.countries;
  bool _loading = true;
  String? _error;
  List<DrzavaLookup> _countries = const [];
  List<GradLookup> _cities = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final countries = await _api.getDrzave();
      final cities = await _api.getGradovi();
      if (!mounted) return;
      setState(() {
        _countries = countries;
        _cities = cities;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ApiErrorMessages.fromObject(e);
      });
    }
  }

  Future<void> _editCountry([DrzavaLookup? existing]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => _CountryDialog(api: _api, existing: existing),
    );
    if (saved == true) await _reload();
  }

  Future<void> _editCity([GradLookup? existing]) async {
    if (_countries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a country before adding cities.')),
      );
      return;
    }
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => _CityDialog(
        api: _api,
        countries: _countries,
        existing: existing,
      ),
    );
    if (saved == true) await _reload();
  }

  Future<void> _deleteCountry(DrzavaLookup row) async {
    final ok = await showLuxuryConfirmDialog(
      context,
      title: 'Delete country',
      message:
          'Delete ${row.naziv}? This is blocked if the country still has cities or user profiles.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await _api.deleteDrzava(row.id);
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiErrorMessages.fromObject(e))),
      );
    }
  }

  Future<void> _deleteCity(GradLookup row) async {
    final ok = await showLuxuryConfirmDialog(
      context,
      title: 'Delete city',
      message:
          'Delete ${row.naziv}? This is blocked if clients or staff still use this city.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await _api.deleteGrad(row.id);
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiErrorMessages.fromObject(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Locations',
              style: GoogleFonts.manrope(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFF5F3FA),
              ),
            ),
            const Spacer(),
            SegmentedButton<_LocTab>(
              segments: const [
                ButtonSegment(
                  value: _LocTab.countries,
                  label: Text('Countries'),
                  icon: Icon(Icons.public_outlined),
                ),
                ButtonSegment(
                  value: _LocTab.cities,
                  label: Text('Cities'),
                  icon: Icon(Icons.location_city_outlined),
                ),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() => _tab = s.first),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: _tab == _LocTab.countries
                  ? () => _editCountry()
                  : () => _editCity(),
              icon: const Icon(Icons.add),
              label: Text(_tab == _LocTab.countries ? 'Add country' : 'Add city'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Maintain country and city catalogs used on user profiles.',
          style: GoogleFonts.manrope(
            fontSize: 13,
            color: NuaLuxuryTokens.lavenderWhisper.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }

    if (_tab == _LocTab.countries) {
      if (_countries.isEmpty) {
        return const Center(child: Text('No countries yet.'));
      }
      return _CatalogTable(
        columns: const ['Name', 'Calling code', ''],
        rows: [
          for (final row in _countries)
            [
              Text(row.naziv),
              Text(row.pozivniBroj.isEmpty ? '—' : row.pozivniBroj),
              _RowActions(
                onEdit: () => _editCountry(row),
                onDelete: () => _deleteCountry(row),
              ),
            ],
        ],
      );
    }

    if (_cities.isEmpty) {
      return const Center(child: Text('No cities yet.'));
    }
    return _CatalogTable(
      columns: const ['City', 'Postal code', 'Country', ''],
      rows: [
        for (final row in _cities)
          [
            Text(row.naziv),
            Text(row.postanskiBroj),
            Text(row.drzavaNaziv ?? '—'),
            _RowActions(
              onEdit: () => _editCity(row),
              onDelete: () => _deleteCity(row),
            ),
          ],
      ],
    );
  }
}

class _CatalogTable extends StatelessWidget {
  const _CatalogTable({required this.columns, required this.rows});

  final List<String> columns;
  final List<List<Widget>> rows;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF161022),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SingleChildScrollView(
          child: Table(
            columnWidths: {
              for (var i = 0; i < columns.length - 1; i++)
                i: const FlexColumnWidth(),
              columns.length - 1: const FixedColumnWidth(120),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                ),
                children: [
                  for (final c in columns)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Text(
                        c,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: NuaLuxuryTokens.lavenderWhisper,
                        ),
                      ),
                    ),
                ],
              ),
              for (final row in rows)
                TableRow(
                  children: [
                    for (final cell in row)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                        child: DefaultTextStyle(
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            color: const Color(0xFFF5F3FA),
                          ),
                          child: cell,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RowActions extends StatelessWidget {
  const _RowActions({required this.onEdit, required this.onDelete});

  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          tooltip: 'Edit',
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined, size: 20),
        ),
        IconButton(
          tooltip: 'Delete',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline, size: 20),
        ),
      ],
    );
  }
}

class _CountryDialog extends StatefulWidget {
  const _CountryDialog({required this.api, this.existing});

  final ApiService api;
  final DrzavaLookup? existing;

  @override
  State<_CountryDialog> createState() => _CountryDialogState();
}

class _CountryDialogState extends State<_CountryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _naziv;
  late final TextEditingController _pozivni;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _naziv = TextEditingController(text: widget.existing?.naziv ?? '');
    _pozivni = TextEditingController(text: widget.existing?.pozivniBroj ?? '');
  }

  @override
  void dispose() {
    _naziv.dispose();
    _pozivni.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      if (widget.existing == null) {
        await widget.api.createDrzava(
          naziv: _naziv.text.trim(),
          pozivniBroj: _pozivni.text.trim(),
        );
      } else {
        await widget.api.updateDrzava(
          id: widget.existing!.id,
          naziv: _naziv.text.trim(),
          pozivniBroj: _pozivni.text.trim(),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiErrorMessages.fromObject(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add country' : 'Edit country'),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _naziv,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pozivni,
                decoration: const InputDecoration(labelText: 'Calling code'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }
}

class _CityDialog extends StatefulWidget {
  const _CityDialog({
    required this.api,
    required this.countries,
    this.existing,
  });

  final ApiService api;
  final List<DrzavaLookup> countries;
  final GradLookup? existing;

  @override
  State<_CityDialog> createState() => _CityDialogState();
}

class _CityDialogState extends State<_CityDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _naziv;
  late final TextEditingController _postanski;
  late int _drzavaId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _naziv = TextEditingController(text: widget.existing?.naziv ?? '');
    _postanski =
        TextEditingController(text: widget.existing?.postanskiBroj ?? '');
    _drzavaId = widget.existing?.drzavaId ?? widget.countries.first.id;
  }

  @override
  void dispose() {
    _naziv.dispose();
    _postanski.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      if (widget.existing == null) {
        await widget.api.createGrad(
          naziv: _naziv.text.trim(),
          postanskiBroj: _postanski.text.trim(),
          drzavaId: _drzavaId,
        );
      } else {
        await widget.api.updateGrad(
          id: widget.existing!.id,
          naziv: _naziv.text.trim(),
          postanskiBroj: _postanski.text.trim(),
          drzavaId: _drzavaId,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiErrorMessages.fromObject(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add city' : 'Edit city'),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                // ignore: deprecated_member_use — controlled selection
                value: _drzavaId,
                decoration: const InputDecoration(labelText: 'Country'),
                items: [
                  for (final c in widget.countries)
                    DropdownMenuItem(value: c.id, child: Text(c.naziv)),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _drzavaId = v);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _naziv,
                decoration: const InputDecoration(labelText: 'City'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _postanski,
                decoration: const InputDecoration(labelText: 'Postal code'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }
}
