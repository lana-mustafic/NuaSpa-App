import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/services/api_service.dart';
import '../../core/settings/settings_messages.dart';
import '../../models/account_profile.dart';
import '../../providers/auth_provider.dart';
import '../admin/admin_dashboard_screen.dart';
import '../therapist/therapist_schedule_screen.dart';
import '../../providers/mobile_nav_provider.dart';
import '../../providers/service_provider.dart';
import '../../ui/theme/mobile_spa_theme.dart';

class MobileProfileScreen extends StatefulWidget {
  const MobileProfileScreen({super.key});

  @override
  State<MobileProfileScreen> createState() => _MobileProfileScreenState();
}

class _MobileProfileScreenState extends State<MobileProfileScreen> {
  final ApiService _api = ApiService();

  AccountProfile? _profile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final profile = await _api.getAccountProfile();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _loading = false;
      _error = profile == null
          ? 'Could not load your account details. Pull to refresh.'
          : null;
    });
  }

  Future<void> _openChangePassword() async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MobileSpaColors.softWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _ChangePasswordSheet(),
    );
    if (changed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully.')),
      );
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    final local = dt.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[local.month - 1]} ${local.day}, ${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final tt = Theme.of(context).textTheme;
    final profile = _profile;

    return RefreshIndicator(
      onRefresh: _loadProfile,
      color: MobileSpaColors.royalPurple,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
        children: [
          Text('Profile', style: tt.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Your account details and shortcuts',
            style: tt.bodySmall?.copyWith(
              color: MobileSpaColors.royalPurple.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_error != null)
            _GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_error!, style: tt.bodyMedium),
                  const SizedBox(height: 12),
                  TextButton(onPressed: _loadProfile, child: const Text('Retry')),
                ],
              ),
            )
          else if (profile != null) ...[
            _ProfileHeaderCard(profile: profile),
            const SizedBox(height: 16),
            _SectionTitle(title: 'Account'),
            _GlassPanel(
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.alternate_email_rounded,
                    label: 'Username',
                    value: profile.userName,
                  ),
                  _divider(),
                  _InfoRow(
                    icon: Icons.mail_outline_rounded,
                    label: 'Email',
                    value: profile.email?.trim().isNotEmpty == true
                        ? profile.email!
                        : 'Not set',
                  ),
                  _divider(),
                  _InfoRow(
                    icon: Icons.phone_outlined,
                    label: 'Phone',
                    value: profile.phone?.trim().isNotEmpty == true
                        ? profile.phone!
                        : 'Not set',
                  ),
                  if (profile.isClient) ...[
                    _divider(),
                    _InfoRow(
                      icon: Icons.location_city_outlined,
                      label: 'City',
                      value: profile.cityName?.trim().isNotEmpty == true
                          ? profile.cityName!
                          : 'Not set',
                    ),
                  ],
                  _divider(),
                  _InfoRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Member since',
                    value: _formatDate(profile.memberSince),
                  ),
                  _divider(),
                  _InfoRow(
                    icon: Icons.verified_user_outlined,
                    label: 'Account status',
                    value: profile.isActive ? 'Active' : 'Inactive',
                  ),
                ],
              ),
            ),
            if (profile.isClient &&
                (profile.totalVisits != null || profile.totalSpent != null)) ...[
              const SizedBox(height: 20),
              _SectionTitle(title: 'Your activity'),
              _GlassPanel(
                child: Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        label: 'Visits',
                        value: '${profile.totalVisits ?? 0}',
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 44,
                      color: MobileSpaColors.lavender.withValues(alpha: 0.45),
                    ),
                    Expanded(
                      child: _StatTile(
                        label: 'Total spent',
                        value:
                            '${(profile.totalSpent ?? 0).toStringAsFixed(2)} KM',
                      ),
                    ),
                  ],
                ),
              ),
              if (profile.lastVisit != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Last visit: ${_formatDate(profile.lastVisit)}',
                  style: tt.bodySmall?.copyWith(
                    color: MobileSpaColors.royalPurple.withValues(alpha: 0.62),
                  ),
                ),
              ],
            ],
          ],
          const SizedBox(height: 28),
          _SectionTitle(title: 'Shortcuts'),
          _GlassTile(
            icon: Icons.event_available_outlined,
            label: 'My reservations',
            onTap: () => context.read<MobileNavProvider>().setTab(2),
            visible: !auth.isZaposlenik,
          ),
          _GlassTile(
            icon: Icons.favorite_outline,
            label: 'Favorites',
            onTap: () {
              context
                  .read<ServiceProvider>()
                  .setCatalogTab(ServiceCatalogTab.favorites);
              context.read<MobileNavProvider>().setTab(1);
            },
            visible: !auth.isZaposlenik,
          ),
          _GlassTile(
            icon: Icons.calendar_month_outlined,
            label: 'My schedule',
            onTap: () {
              final n = DateTime.now();
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => TherapistScheduleScreen(
                    filterDay: DateTime(n.year, n.month, n.day),
                  ),
                ),
              );
            },
            visible: auth.isZaposlenik,
          ),
          _GlassTile(
            icon: Icons.admin_panel_settings_outlined,
            label: 'Admin',
            onTap: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const AdminDashboardScreen(),
                ),
              );
            },
            visible: auth.isAdmin,
          ),
          if (profile?.hasPassword ?? true) ...[
            const SizedBox(height: 8),
            _GlassTile(
              icon: Icons.lock_outline_rounded,
              label: 'Change password',
              onTap: _openChangePassword,
            ),
          ],
          const SizedBox(height: 32),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: MobileSpaColors.royalPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            onPressed: () => context.read<AuthProvider>().logout(),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Divider(
        height: 1,
        color: MobileSpaColors.lavender.withValues(alpha: 0.35),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: MobileSpaColors.royalPurple.withValues(alpha: 0.85),
            ),
      ),
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({required this.profile});

  final AccountProfile profile;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                MobileSpaColors.lavender.withValues(alpha: 0.55),
                Colors.white.withValues(alpha: 0.72),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: MobileSpaColors.lavender.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: MobileSpaColors.royalPurple,
                foregroundColor: Colors.white,
                child: Text(
                  profile.initials,
                  style: tt.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.fullName,
                      style: tt.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.roleLabel,
                      style: tt.bodyMedium?.copyWith(
                        color: MobileSpaColors.royalPurple.withValues(alpha: 0.65),
                      ),
                    ),
                    if (profile.isClient && profile.isVip == true) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: MobileSpaColors.gold.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: MobileSpaColors.gold.withValues(alpha: 0.55),
                          ),
                        ),
                        child: Text(
                          'VIP client',
                          style: tt.labelMedium?.copyWith(
                            color: MobileSpaColors.royalPurple,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.55),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: MobileSpaColors.lavender.withValues(alpha: 0.35),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        child: child,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: MobileSpaColors.royalPurple),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: tt.labelMedium?.copyWith(
                    color: MobileSpaColors.royalPurple.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Column(
        children: [
          Text(
            value,
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: tt.labelMedium?.copyWith(
              color: MobileSpaColors.royalPurple.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _GlassTile extends StatelessWidget {
  const _GlassTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.visible = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white.withValues(alpha: 0.55),
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: MobileSpaColors.lavender.withValues(alpha: 0.35),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                Icon(icon, color: MobileSpaColors.royalPurple),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: MobileSpaColors.royalPurple.withValues(alpha: 0.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _api = ApiService();
  bool _submitting = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final result = await _api.changePassword(
      staraLozinka: _currentCtrl.text,
      novaLozinka: _newCtrl.text,
      potvrdaNoveLozinke: _confirmCtrl.text,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (result.success) {
      Navigator.pop(context, true);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(SettingsMessages.en(result.message))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Change password', style: tt.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _currentCtrl,
              obscureText: _obscureCurrent,
              decoration: InputDecoration(
                labelText: 'Current password',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureCurrent
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscureCurrent = !_obscureCurrent),
                ),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Enter your current password.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _newCtrl,
              obscureText: _obscureNew,
              decoration: InputDecoration(
                labelText: 'New password',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureNew
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                ),
              ),
              validator: (v) {
                if (v == null || v.length < 8) {
                  return 'Password must be at least 8 characters.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmCtrl,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                labelText: 'Confirm new password',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              validator: (v) {
                if (v != _newCtrl.text) return 'Passwords do not match.';
                return null;
              },
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
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
                  : const Text('Update password'),
            ),
          ],
        ),
      ),
    );
  }
}
