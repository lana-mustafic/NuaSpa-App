import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/services/api_service.dart';
import '../../core/auth/app_permissions.dart';
import '../../models/therapist/therapist_dashboard.dart';
import '../../providers/auth_provider.dart';
import 'therapist_portal_scaffold.dart';

class TherapistDashboardScreen extends StatefulWidget {
  const TherapistDashboardScreen({super.key});

  @override
  State<TherapistDashboardScreen> createState() =>
      _TherapistDashboardScreenState();
}

class _TherapistDashboardScreenState extends State<TherapistDashboardScreen> {
  final _api = ApiService();
  Future<TherapistDashboard?>? _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final auth = context.read<AuthProvider>();
    if (!AppPermissions.of(auth).has(AppPermission.viewOwnTherapistData)) {
      return;
    }
    setState(() {
      _future = _api.getTherapistDashboard(day: DateTime.now());
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isZaposlenik || auth.zaposlenikId == null) {
      return const TherapistPortalScaffold(
        title: 'My Dashboard',
        subtitle: 'Therapist account is not linked to an employee record.',
        child: TherapistEmptyState(
          message: 'Contact your spa administrator to link your login.',
        ),
      );
    }

    return TherapistPortalScaffold(
      title: 'My Dashboard',
      subtitle: 'Today at a glance — appointments, ratings, and your month.',
      child: FutureBuilder<TherapistDashboard?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }
          final d = snap.data;
          if (d == null) {
            return const TherapistEmptyState(
              message: 'Could not load dashboard. Pull to refresh later.',
            );
          }
          return ListView(
            children: [
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  SizedBox(
                    width: 240,
                    child: TherapistStatCard(
                      label: 'Today',
                      value: '${d.todayAppointments}',
                      icon: Icons.today_rounded,
                    ),
                  ),
                  SizedBox(
                    width: 240,
                    child: TherapistStatCard(
                      label: 'Upcoming',
                      value: '${d.upcomingAppointments}',
                      icon: Icons.upcoming_rounded,
                    ),
                  ),
                  SizedBox(
                    width: 240,
                    child: TherapistStatCard(
                      label: 'Completed (month)',
                      value: '${d.completedThisMonth}',
                      icon: Icons.check_circle_outline_rounded,
                      accent: const Color(0xFF6EE7B7),
                    ),
                  ),
                  SizedBox(
                    width: 240,
                    child: TherapistStatCard(
                      label: 'Average rating',
                      value: d.prosjecnaOcjena > 0
                          ? d.prosjecnaOcjena.toStringAsFixed(1)
                          : '—',
                      icon: Icons.star_rounded,
                      accent: const Color(0xFFE8C872),
                    ),
                  ),
                  SizedBox(
                    width: 240,
                    child: TherapistStatCard(
                      label: 'Reviews',
                      value: '${d.reviewCount}',
                      icon: Icons.reviews_outlined,
                    ),
                  ),
                  SizedBox(
                    width: 240,
                    child: TherapistStatCard(
                      label: 'My revenue (month)',
                      value: '€${d.revenueThisMonth.toStringAsFixed(0)}',
                      icon: Icons.payments_outlined,
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
