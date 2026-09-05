import 'package:flutter/material.dart';

import '../../core/api/api_error_messages.dart';
import '../../core/api/services/api_service.dart';
import '../../core/validation/nua_validators.dart';
import '../../models/account_profile.dart';
import '../../models/grad_lookup.dart';
import '../../ui/theme/mobile_spa_theme.dart';

Future<AccountProfile?> showEditAccountProfileSheet(
  BuildContext context, {
  required AccountProfile profile,
}) {
  return showModalBottomSheet<AccountProfile>(
    context: context,
    isScrollControlled: true,
    backgroundColor: MobileSpaColors.softWhite,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => EditAccountProfileForm(profile: profile),
  );
}

Future<AccountProfile?> showEditAccountProfileDialog(
  BuildContext context, {
  required AccountProfile profile,
}) {
  return showDialog<AccountProfile>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Edit profile'),
      content: SizedBox(
        width: 440,
        child: EditAccountProfileForm(
          profile: profile,
          embeddedInDialog: true,
        ),
      ),
    ),
  );
}

class EditAccountProfileForm extends StatefulWidget {
  const EditAccountProfileForm({
    super.key,
    required this.profile,
    this.embeddedInDialog = false,
  });

  final AccountProfile profile;
  final bool embeddedInDialog;

  @override
  State<EditAccountProfileForm> createState() => _EditAccountProfileFormState();
}

class _EditAccountProfileFormState extends State<EditAccountProfileForm> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  List<GradLookup> _cities = const [];
  int? _gradId;
  bool _loadingCities = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _firstName = TextEditingController(text: p.firstName);
    _lastName = TextEditingController(text: p.lastName);
    _email = TextEditingController(text: p.email ?? '');
    _phone = TextEditingController(text: p.phone ?? '');
    _gradId = p.gradId;
    if (p.isClient) {
      _loadCities();
    }
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _loadCities() async {
    setState(() => _loadingCities = true);
    final cities = await _api.getGradovi();
    if (!mounted) return;
    setState(() {
      _cities = cities;
      _loadingCities = false;
      if (_gradId != null && !cities.any((c) => c.id == _gradId)) {
        _gradId = null;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final phone = _phone.text.trim();
      final updated = await _api.updateAccountProfile(
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        email: _email.text.trim(),
        phone: phone.isEmpty ? null : phone,
        gradId: widget.profile.isClient ? _gradId : null,
      );
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = ApiErrorMessages.fromObject(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final fields = [
      TextFormField(
        controller: _firstName,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'First name'),
        validator: (v) => NuaValidators.personName(v, fieldLabel: 'First name'),
      ),
      TextFormField(
        controller: _lastName,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Last name'),
        validator: (v) => NuaValidators.personName(v, fieldLabel: 'Last name'),
      ),
      TextFormField(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        decoration: const InputDecoration(labelText: 'Email'),
        validator: NuaValidators.email,
      ),
      TextFormField(
        controller: _phone,
        keyboardType: TextInputType.phone,
        autofillHints: const [AutofillHints.telephoneNumber],
        decoration: const InputDecoration(labelText: 'Phone'),
        validator: NuaValidators.phoneOptional,
      ),
      if (widget.profile.isClient)
        _loadingCities
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : DropdownButtonFormField<int>(
                // ignore: deprecated_member_use — controlled selection
                value: _gradId,
                decoration: const InputDecoration(labelText: 'City'),
                items: [
                  for (final city in _cities)
                    DropdownMenuItem(
                      value: city.id,
                      child: Text(city.label),
                    ),
                ],
                onChanged: (v) => setState(() => _gradId = v),
              ),
    ];

    final form = Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.embeddedInDialog) ...[
            Text('Edit profile', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
          ],
          for (var i = 0; i < fields.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            fields[i],
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              if (widget.embeddedInDialog)
                TextButton(
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              if (widget.embeddedInDialog) const Spacer(),
              Expanded(
                flex: widget.embeddedInDialog ? 0 : 1,
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  style: widget.embeddedInDialog
                      ? null
                      : FilledButton.styleFrom(
                          backgroundColor: MobileSpaColors.royalPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save changes'),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (widget.embeddedInDialog) {
      return SingleChildScrollView(child: form);
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottom),
      child: SingleChildScrollView(child: form),
    );
  }
}
