import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/api/services/api_service.dart';
import '../../core/auth/app_permissions.dart';
import '../../models/admin/therapist_admin_profile.dart';
import '../../providers/auth_provider.dart';
import '../../ui/theme/nua_luxury_tokens.dart';
import '../../ui/widgets/luxury/luxury_glass_panel.dart';
import 'therapist_portal_scaffold.dart';

class TherapistReviewsScreen extends StatefulWidget {
  const TherapistReviewsScreen({super.key});

  @override
  State<TherapistReviewsScreen> createState() => _TherapistReviewsScreenState();
}

class _TherapistReviewsScreenState extends State<TherapistReviewsScreen> {
  final _api = ApiService();
  late final Future<List<TherapistReviewRow>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.getTherapistMyReviews();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!AppPermissions.of(auth).has(AppPermission.viewOwnTherapistData)) {
      return const TherapistPortalScaffold(
        title: 'My Reviews',
        subtitle: 'Access restricted.',
        child: TherapistEmptyState(message: 'Therapist login required.'),
      );
    }

    return TherapistPortalScaffold(
      title: 'My Reviews',
      subtitle: 'Client feedback from appointments you performed.',
      child: FutureBuilder<List<TherapistReviewRow>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return const TherapistEmptyState(
              message: 'No reviews yet.',
              icon: Icons.reviews_outlined,
            );
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final r = list[i];
              return LuxuryGlassPanel(
                borderRadius: 18,
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ...List.generate(
                          5,
                          (idx) => Icon(
                            idx < r.ocjena
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 18,
                            color: const Color(0xFFE8C872),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          r.uslugaNaziv,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      r.korisnikIme,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFF5F3FA),
                      ),
                    ),
                    if (r.komentar.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        r.komentar,
                        style: GoogleFonts.inter(
                          color: NuaLuxuryTokens.lavenderWhisper.withValues(
                            alpha: 0.85,
                          ),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
