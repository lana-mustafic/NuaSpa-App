import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/api/services/api_service.dart';
import '../../core/auth/app_permissions.dart';
import '../../models/zaposlenik.dart';
import '../../providers/auth_provider.dart';
import '../../ui/theme/nua_luxury_tokens.dart';
import '../../ui/widgets/luxury/luxury_glass_panel.dart';
import 'therapist_portal_scaffold.dart';

class TherapistServicesScreen extends StatefulWidget {
  const TherapistServicesScreen({super.key});

  @override
  State<TherapistServicesScreen> createState() =>
      _TherapistServicesScreenState();
}

class _TherapistServicesScreenState extends State<TherapistServicesScreen> {
  final _api = ApiService();
  Future<Zaposlenik?>? _future;

  @override
  void initState() {
    super.initState();
    _future = _api.getTherapistMe();
  }

  List<String> _tags(String raw) => raw
      .split(RegExp(r'[,;/]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!AppPermissions.of(auth).has(AppPermission.viewOwnTherapistData)) {
      return const TherapistPortalScaffold(
        title: 'My Services',
        subtitle: 'Access restricted.',
        child: TherapistEmptyState(message: 'Therapist login required.'),
      );
    }

    return TherapistPortalScaffold(
      title: 'My Services',
      subtitle: 'Treatments you are certified to perform at NuaSpa.',
      child: FutureBuilder<Zaposlenik?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }
          final me = snap.data;
          if (me == null) {
            return const TherapistEmptyState(
              message: 'Could not load your service list.',
            );
          }
          final tags = _tags(me.specijalizacija);
          if (tags.isEmpty) {
            return const TherapistEmptyState(
              message: 'No services assigned yet. Ask your administrator.',
              icon: Icons.spa_outlined,
            );
          }
          return ListView(
            children: [
              if (me.kategorijaUslugaNaziv != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Category: ${me.kategorijaUslugaNaziv}',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      color: NuaLuxuryTokens.lavenderWhisper.withValues(
                        alpha: 0.8,
                      ),
                    ),
                  ),
                ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final tag in tags)
                    LuxuryGlassPanel(
                      borderRadius: 999,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Text(
                        tag,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFF5F3FA),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
