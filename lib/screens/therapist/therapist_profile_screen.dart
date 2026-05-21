import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/api/services/api_service.dart';
import '../../core/auth/app_permissions.dart';
import '../../models/zaposlenik.dart';
import '../../providers/auth_provider.dart';
import '../../ui/theme/luxury_modal_style.dart';
import '../../ui/theme/nua_luxury_tokens.dart';
import '../../ui/widgets/luxury/luxury_glass_panel.dart';
import 'therapist_portal_scaffold.dart';

class TherapistProfileScreen extends StatefulWidget {
  const TherapistProfileScreen({super.key});

  @override
  State<TherapistProfileScreen> createState() => _TherapistProfileScreenState();
}

class _TherapistProfileScreenState extends State<TherapistProfileScreen> {
  final _api = ApiService();
  final _telefon = TextEditingController();
  final _jezici = TextEditingController();
  Future<Zaposlenik?>? _future;
  bool _saving = false;

  @override
  void dispose() {
    _telefon.dispose();
    _jezici.dispose();
    super.dispose();
  }

  void _bind(Zaposlenik z) {
    _telefon.text = z.telefon ?? '';
    _jezici.text = z.jezici ?? '';
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final updated = await _api.patchTherapistMe(
      telefon: _telefon.text.trim().isEmpty ? '' : _telefon.text.trim(),
      jezici: _jezici.text.trim().isEmpty ? '' : _jezici.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (updated != null) {
      _bind(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save profile.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!AppPermissions.of(auth).has(AppPermission.updateOwnTherapistProfile)) {
      return const TherapistPortalScaffold(
        title: 'Profile',
        subtitle: 'Access restricted.',
        child: TherapistEmptyState(message: 'Therapist login required.'),
      );
    }

    _future ??= _api.getTherapistMe().then((z) {
      if (z != null) _bind(z);
      return z;
    });

    return TherapistPortalScaffold(
      title: 'Profile',
      subtitle: 'Update contact details. Role and services are managed by admin.',
      child: FutureBuilder<Zaposlenik?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }
          final z = snap.data;
          if (z == null) {
            return const TherapistEmptyState(message: 'Profile not found.');
          }
          return ListView(
            children: [
              LuxuryGlassPanel(
                borderRadius: 22,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      z.fullName,
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFF5F3FA),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Status: ${z.status.label}',
                      style: GoogleFonts.inter(
                        color: NuaLuxuryTokens.lavenderWhisper.withValues(
                          alpha: 0.75,
                        ),
                      ),
                    ),
                    if (z.email != null && z.email!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        z.email!,
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    TextField(
                      controller: _telefon,
                      style: const TextStyle(color: Colors.white),
                      decoration: LuxuryModalStyle.fieldDecoration(
                        hint: 'Phone',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _jezici,
                      style: const TextStyle(color: Colors.white),
                      decoration: LuxuryModalStyle.fieldDecoration(
                        hint: 'Languages',
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: NuaLuxuryTokens.softPurpleGlow,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Save changes',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
