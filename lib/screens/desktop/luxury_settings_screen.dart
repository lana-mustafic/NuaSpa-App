import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/jwt_roles.dart';
import '../../providers/auth_provider.dart';
import '../../screens/admin/admin_suite_route.dart';
import '../../ui/navigation/desktop_nav.dart';
import '../../ui/theme/nua_luxury_tokens.dart';
import '../../ui/widgets/luxury/luxury_glass_panel.dart';

/// Keep in sync with [pubspec.yaml] version.
const _kAppVersion = '1.0.0';

class _SessionSnapshot {
  const _SessionSnapshot({
    this.email,
    this.firstName,
    this.lastName,
    this.expiresAt,
  });

  final String? email;
  final String? firstName;
  final String? lastName;
  final DateTime? expiresAt;
}

class LuxurySettingsScreen extends StatefulWidget {
  const LuxurySettingsScreen({super.key});

  @override
  State<LuxurySettingsScreen> createState() => _LuxurySettingsScreenState();
}

class _LuxurySettingsScreenState extends State<LuxurySettingsScreen> {
  static const _storage = FlutterSecureStorage();
  _SessionSnapshot? _session;
  bool _loadingSession = true;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final token = await _storage.read(key: 'jwt_token');
    if (!mounted) return;
    setState(() {
      _session = _SessionSnapshot(
        email: parseJwtStringClaim(token, 'email'),
        firstName: parseJwtStringClaim(token, 'Ime'),
        lastName: parseJwtStringClaim(token, 'Prezime'),
        expiresAt: parseJwtExpiry(token),
      );
      _loadingSession = false;
    });
  }

  String _roleLabel(AuthProvider auth) {
    if (auth.isAdmin) return 'Administrator';
    if (auth.isZaposlenik) return 'Therapist / Staff';
    return 'Client';
  }

  String _fullName(_SessionSnapshot? s) {
    if (s == null) return '';
    final parts = [s.firstName, s.lastName]
        .whereType<String>()
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return parts.join(' ');
  }

  String _formatExpiry(DateTime? dt) {
    if (dt == null) return 'Unknown';
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
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '${months[local.month - 1]} ${local.day}, ${local.year} · $h:$m';
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NuaLuxuryTokens.voidViolet,
        title: const Text(
          'Sign out?',
          style: TextStyle(color: Color(0xFFF5F3FA), fontWeight: FontWeight.w800),
        ),
        content: Text(
          'You will need to sign in again to access appointments, clients, and reports.',
          style: TextStyle(
            color: NuaLuxuryTokens.lavenderWhisper.withValues(alpha: 0.75),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEC4899),
            ),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<AuthProvider>().logout();
    }
  }

  void _copyApiUrl(BuildContext context) {
    final url = AppConfig.apiBaseUrl;
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('API URL copied: $url'),
        behavior: SnackBarBehavior.floating,
        width: 420,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final nav = context.read<DesktopNav>();
    final t = Theme.of(context);
    final fullName = _fullName(_session);
    final display = fullName.isNotEmpty
        ? fullName
        : (auth.displayName ?? 'Signed in');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 8, 32, 40),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: LayoutBuilder(
            builder: (context, c) {
              final twoCol = c.maxWidth >= 720;
              final accountCol = _SettingsSection(
                title: 'Account',
                icon: Icons.person_outline_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _DetailRow(
                      label: 'Username',
                      value: auth.displayName ?? '—',
                    ),
                    if (fullName.isNotEmpty)
                      _DetailRow(label: 'Full name', value: fullName),
                    if (_session?.email != null)
                      _DetailRow(label: 'Email', value: _session!.email!),
                    _DetailRow(label: 'Role', value: _roleLabel(auth)),
                    if (auth.zaposlenikId != null)
                      _DetailRow(
                        label: 'Staff profile ID',
                        value: '#${auth.zaposlenikId}',
                      ),
                    if (auth.roles.isNotEmpty)
                      _DetailRow(
                        label: 'Permissions',
                        value: auth.roles.join(', '),
                      ),
                  ],
                ),
              );

              final sessionCol = _SettingsSection(
                title: 'Session',
                icon: Icons.shield_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _DetailRow(
                      label: 'Status',
                      value: auth.status == AuthStatus.authenticated
                          ? 'Active'
                          : auth.status.name,
                      valueColor: const Color(0xFF34D399),
                    ),
                    _DetailRow(
                      label: 'Expires',
                      value: _loadingSession
                          ? 'Loading…'
                          : _formatExpiry(_session?.expiresAt),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _loadingSession
                          ? null
                          : () async {
                              await context.read<AuthProvider>().checkAuthState();
                              await _loadSession();
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Session refreshed.'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Refresh session'),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: () => _confirmSignOut(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFEC4899),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Sign out'),
                    ),
                  ],
                ),
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LuxuryGlassPanel(
                    blurSigma: 26,
                    opacity: 0.44,
                    borderRadius: NuaLuxuryTokens.radiusXl,
                    padding: const EdgeInsets.all(28),
                    child: Row(
                      children: [
                        _AvatarBadge(initials: auth.userInitials ?? 'NS'),
                        const SizedBox(width: 22),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                display,
                                style: t.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFFF5F3FA),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _roleLabel(auth),
                                style: t.textTheme.bodyMedium?.copyWith(
                                  color: NuaLuxuryTokens.champagneGold,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                auth.isAdmin
                                    ? 'Manage NuaSpa operations from this workspace — appointments, staff, clients, and revenue.'
                                    : auth.isZaposlenik
                                        ? 'View your schedule and day-to-day spa tasks.'
                                        : 'Book treatments, manage reservations, and save your favorites.',
                                style: t.textTheme.bodySmall?.copyWith(
                                  color: NuaLuxuryTokens.lavenderWhisper
                                      .withValues(alpha: 0.65),
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _RolePill(label: _roleLabel(auth)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (twoCol)
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: accountCol),
                          const SizedBox(width: 20),
                          Expanded(child: sessionCol),
                        ],
                      ),
                    )
                  else ...[
                    accountCol,
                    const SizedBox(height: 16),
                    sessionCol,
                  ],
                  if (auth.isAdmin) ...[
                    const SizedBox(height: 24),
                    _SettingsSection(
                      title: 'Workspace',
                      icon: Icons.dashboard_customize_outlined,
                      subtitle:
                          'Jump to the modules you use most in the admin console.',
                      child: _ShortcutGrid(
                        items: [
                          _Shortcut(
                            icon: Icons.hub_outlined,
                            label: 'Command Center',
                            onTap: () =>
                                nav.goTo(DesktopRouteKey.commandCenter),
                          ),
                          _Shortcut(
                            icon: Icons.event_note_outlined,
                            label: 'Appointments',
                            onTap: () => nav.goTo(DesktopRouteKey.reservations),
                          ),
                          _Shortcut(
                            icon: Icons.calendar_month_outlined,
                            label: 'Calendar',
                            onTap: () =>
                                nav.goTo(DesktopRouteKey.adminCalendar),
                          ),
                          _Shortcut(
                            icon: Icons.grid_view_rounded,
                            label: 'Services',
                            onTap: () => nav.goTo(DesktopRouteKey.catalog),
                          ),
                          _Shortcut(
                            icon: Icons.groups_outlined,
                            label: 'Therapists',
                            onTap: () => nav.goTo(DesktopRouteKey.therapists),
                          ),
                          _Shortcut(
                            icon: Icons.people_outline,
                            label: 'Clients',
                            onTap: () => nav.goToAdminSuite(
                              AdminSuiteRoute.clients,
                            ),
                          ),
                          _Shortcut(
                            icon: Icons.payments_outlined,
                            label: 'Payments',
                            onTap: () => nav.goToAdminSuite(
                              AdminSuiteRoute.finance,
                            ),
                          ),
                          _Shortcut(
                            icon: Icons.area_chart_rounded,
                            label: 'Reports',
                            onTap: () =>
                                nav.goTo(DesktopRouteKey.revenueAnalytics),
                          ),
                          _Shortcut(
                            icon: Icons.reviews_outlined,
                            label: 'Reviews',
                            onTap: () => nav.goTo(DesktopRouteKey.reviews),
                          ),
                        ],
                      ),
                    ),
                  ] else if (auth.isZaposlenik) ...[
                    const SizedBox(height: 24),
                    _SettingsSection(
                      title: 'Workspace',
                      icon: Icons.view_timeline_rounded,
                      subtitle: 'Your therapist tools in NuaSpa.',
                      child: _ShortcutGrid(
                        items: [
                          _Shortcut(
                            icon: Icons.home_outlined,
                            label: 'Pulse',
                            onTap: () => nav.goTo(DesktopRouteKey.home),
                          ),
                          _Shortcut(
                            icon: Icons.view_timeline_rounded,
                            label: 'Schedule',
                            onTap: () => nav.goTo(DesktopRouteKey.schedule),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 24),
                    _SettingsSection(
                      title: 'Workspace',
                      icon: Icons.spa_outlined,
                      subtitle: 'Your booking experience.',
                      child: _ShortcutGrid(
                        items: [
                          _Shortcut(
                            icon: Icons.grid_view_rounded,
                            label: 'Services',
                            onTap: () => nav.goTo(DesktopRouteKey.catalog),
                          ),
                          _Shortcut(
                            icon: Icons.event_available_outlined,
                            label: 'Bookings',
                            onTap: () => nav.goTo(DesktopRouteKey.reservations),
                          ),
                          _Shortcut(
                            icon: Icons.favorite_border,
                            label: 'Favorites',
                            onTap: () => nav.goTo(DesktopRouteKey.favorites),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  _SettingsSection(
                    title: 'Application',
                    icon: Icons.info_outline_rounded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _DetailRow(label: 'App', value: 'NuaSpa Desktop'),
                        _DetailRow(label: 'Version', value: _kAppVersion),
                        _DetailRow(
                          label: 'Platform',
                          value: defaultTargetPlatform.name,
                        ),
                        _DetailRow(
                          label: 'API endpoint',
                          value: AppConfig.apiBaseUrl,
                          monospace: true,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _copyApiUrl(context),
                              icon: const Icon(Icons.copy_rounded, size: 18),
                              label: const Text('Copy API URL'),
                            ),
                            if (kDebugMode)
                              Text(
                                'Override at build time: --dart-define=NUASPA_API_BASE_URL=…',
                                style: t.textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.4),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AvatarBadge extends StatelessWidget {
  const _AvatarBadge({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF7B4DFF), Color(0xFF9D6BFF)],
        ),
        boxShadow: NuaLuxuryTokens.cardGlow(opacity: 0.22),
      ),
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  const _RolePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFFF5F3FA),
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.child,
    this.subtitle,
  });

  final String title;
  final IconData icon;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return LuxuryGlassPanel(
      blurSigma: 22,
      opacity: 0.4,
      borderRadius: NuaLuxuryTokens.radiusLg,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: NuaLuxuryTokens.champagneGold),
              const SizedBox(width: 10),
              Text(
                title,
                style: t.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFF5F3FA),
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: t.textTheme.bodySmall?.copyWith(
                color: NuaLuxuryTokens.lavenderWhisper.withValues(alpha: 0.58),
              ),
            ),
          ],
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.monospace = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: NuaLuxuryTokens.lavenderWhisper.withValues(alpha: 0.55),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: monospace ? 'monospace' : null,
                color: valueColor ?? const Color(0xFFF5F3FA),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Shortcut {
  const _Shortcut({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _ShortcutGrid extends StatelessWidget {
  const _ShortcutGrid({required this.items});

  final List<_Shortcut> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 520 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.4,
          ),
          itemBuilder: (context, i) {
            final s = items[i];
            return _ShortcutTile(
              icon: s.icon,
              label: s.label,
              onTap: s.onTap,
            );
          },
        );
      },
    );
  }
}

class _ShortcutTile extends StatefulWidget {
  const _ShortcutTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_ShortcutTile> createState() => _ShortcutTileState();
}

class _ShortcutTileState extends State<_ShortcutTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: Colors.white.withValues(alpha: _hover ? 0.08 : 0.04),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  widget.icon,
                  size: 18,
                  color: NuaLuxuryTokens.softPurpleGlow,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFF5F3FA),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
