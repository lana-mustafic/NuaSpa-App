import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/api/services/api_service.dart';
import '../../core/auth/app_permissions.dart';
import '../../models/rezervacija.dart';
import '../../providers/auth_provider.dart';
import '../../ui/theme/nua_luxury_tokens.dart';
import '../../ui/widgets/luxury/luxury_glass_panel.dart';
import 'therapist_portal_scaffold.dart';

class TherapistAppointmentsScreen extends StatefulWidget {
  const TherapistAppointmentsScreen({super.key});

  @override
  State<TherapistAppointmentsScreen> createState() =>
      _TherapistAppointmentsScreenState();
}

class _TherapistAppointmentsScreenState extends State<TherapistAppointmentsScreen> {
  final _api = ApiService();
  Future<List<Rezervacija>>? _future;
  String _filter = 'Upcoming';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() => _future = _api.getRezervacije());
  }

  List<Rezervacija> _applyFilter(List<Rezervacija> all) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_filter) {
      case 'Today':
        return all
            .where((r) {
              final d = r.datumRezervacije.toLocal();
              final day = DateTime(d.year, d.month, d.day);
              return day == today && !r.isOtkazana;
            })
            .toList()
          ..sort((a, b) => a.datumRezervacije.compareTo(b.datumRezervacije));
      case 'Past':
        return all
            .where((r) => r.datumRezervacije.isBefore(now) || r.isOtkazana)
            .toList()
          ..sort((a, b) => b.datumRezervacije.compareTo(a.datumRezervacije));
      default:
        return all
            .where((r) => r.datumRezervacije.isAfter(now) && !r.isOtkazana)
            .toList()
          ..sort((a, b) => a.datumRezervacije.compareTo(b.datumRezervacije));
    }
  }

  String _formatDt(DateTime d) {
    final l = d.toLocal();
    return '${l.day.toString().padLeft(2, '0')}.${l.month.toString().padLeft(2, '0')}.${l.year} '
        '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!AppPermissions.of(auth).has(AppPermission.manageOwnAppointments)) {
      return const TherapistPortalScaffold(
        title: 'My Appointments',
        subtitle: 'Access restricted.',
        child: TherapistEmptyState(message: 'Therapist login required.'),
      );
    }

    return TherapistPortalScaffold(
      title: 'My Appointments',
      subtitle: 'View and manage your assigned bookings.',
      actions: [
        LuxuryGlassPanel(
          borderRadius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _filter,
              dropdownColor: NuaLuxuryTokens.voidViolet,
              items: const [
                DropdownMenuItem(value: 'Today', child: Text('Today')),
                DropdownMenuItem(value: 'Upcoming', child: Text('Upcoming')),
                DropdownMenuItem(value: 'Past', child: Text('Past')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _filter = v);
              },
            ),
          ),
        ),
        IconButton(
          onPressed: _reload,
          icon: const Icon(Icons.refresh_rounded),
          color: Colors.white70,
        ),
      ],
      child: FutureBuilder<List<Rezervacija>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }
          final list = _applyFilter(snap.data ?? []);
          if (list.isEmpty) {
            return TherapistEmptyState(
              message: _filter == 'Today'
                  ? 'No appointments scheduled for today.'
                  : 'No appointments in this view.',
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
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.uslugaNaziv ?? 'Service',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: const Color(0xFFF5F3FA),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _formatDt(r.datumRezervacije),
                            style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _StatusChip(
                      label: r.isOtkazana
                          ? 'Cancelled'
                          : r.isPotvrdjena
                              ? 'Confirmed'
                              : 'Pending',
                      color: r.isOtkazana
                          ? const Color(0xFFF87171)
                          : r.isPotvrdjena
                              ? const Color(0xFF6EE7B7)
                              : NuaLuxuryTokens.softPurpleGlow,
                    ),
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
