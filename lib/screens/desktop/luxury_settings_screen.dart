import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/jwt_roles.dart';
import '../../providers/auth_provider.dart';
import '../../screens/admin/admin_suite_route.dart';
import '../../ui/navigation/desktop_nav.dart';
import '../../ui/theme/nua_luxury_tokens.dart';

/// Keep in sync with [pubspec.yaml] version.
const _kAppVersion = '1.0.0';

abstract final class _SetUi {
  static const bgTop = Color(0xFF07040F);
  static const bgBottom = Color(0xFF120A24);
  static const textPrimary = Color(0xFFF5F3FA);
  static const textSecondary = Color(0xA6FFFFFF);
  static const purple = Color(0xFF7B4DFF);
  static const lavender = Color(0xFF9D6BFF);
  static const gold = Color(0xFFF5B942);
  static const green = Color(0xFF22C55E);
  static const orange = Color(0xFFF97316);
  static const pink = Color(0xFFEC4899);
  static const cardRadius = 24.0;
  static const heroRadius = 30.0;
  static const gap = 24.0;
  static const sidebarWidth = 340.0;
  static const contentPadding = 32.0;
}

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

class _LuxurySettingsScreenState extends State<LuxurySettingsScreen>
    with SingleTickerProviderStateMixin {
  static const _storage = FlutterSecureStorage();
  _SessionSnapshot? _session;
  bool _loadingSession = true;
  int _lastFiltersPulse = 0;
  String _activeSection = 'Account';
  final _searchCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _accountKey = GlobalKey();
  final GlobalKey _sessionKey = GlobalKey();
  final GlobalKey _workspaceKey = GlobalKey();
  final GlobalKey _appKey = GlobalKey();
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic);
    _loadSession();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _scrollToSection(String label, GlobalKey key) {
    setState(() => _activeSection = label);
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      alignment: 0.06,
    );
    _fadeCtrl.forward(from: 0);
  }

  Future<void> _showSectionPicker() async {
    const sections = ['Account', 'Session', 'Workspace', 'Application'];
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _SetUi.bgBottom,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Jump to section',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _SetUi.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              for (final s in sections)
                ListTile(
                  leading: Icon(
                    _sectionIcon(s),
                    color: _SetUi.lavender,
                  ),
                  title: Text(
                    s,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: _SetUi.textPrimary,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _jumpSection(s);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _sectionIcon(String s) {
    switch (s) {
      case 'Session':
        return Icons.shield_outlined;
      case 'Workspace':
        return Icons.dashboard_customize_outlined;
      case 'Application':
        return Icons.info_outline_rounded;
      default:
        return Icons.person_outline_rounded;
    }
  }

  void _jumpSection(String s) {
    switch (s) {
      case 'Session':
        _scrollToSection(s, _sessionKey);
      case 'Workspace':
        _scrollToSection(s, _workspaceKey);
      case 'Application':
        _scrollToSection(s, _appKey);
      default:
        _scrollToSection('Account', _accountKey);
    }
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
    if (auth.isZaposlenik) return 'Therapist';
    return 'Client';
  }

  String _heroSubtitle(AuthProvider auth) {
    if (auth.isAdmin) {
      return 'Manage your NuaSpa admin account, session security, and workspace shortcuts.';
    }
    if (auth.isZaposlenik) {
      return 'Your therapist account, active session, and portal navigation in one place.';
    }
    return 'Your booking account, session details, and spa experience shortcuts.';
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

  double? _sessionHealthProgress(DateTime? expiresAt) {
    if (expiresAt == null) return null;
    final now = DateTime.now();
    if (!expiresAt.isAfter(now)) return 0;
    const window = Duration(hours: 8);
    final remaining = expiresAt.difference(now);
    return (remaining.inMilliseconds / window.inMilliseconds).clamp(0.0, 1.0);
  }

  bool _matchesSearch(String query, List<String> fields) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return fields.any((f) => f.toLowerCase().contains(q));
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _SetUi.bgBottom,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          'Sign out?',
          style: GoogleFonts.inter(
            color: _SetUi.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          'You will need to sign in again to access appointments, clients, and reports.',
          style: GoogleFonts.inter(
            color: _SetUi.textSecondary,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: _SetUi.pink),
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

  List<_WorkspaceLink> _workspaceLinks(AuthProvider auth, DesktopNav nav) {
    if (auth.isAdmin) {
      return [
        _WorkspaceLink(
          icon: Icons.hub_outlined,
          label: 'Command Center',
          subtitle: 'Live KPIs and today\'s overview',
          onTap: () => nav.goTo(DesktopRouteKey.commandCenter),
        ),
        _WorkspaceLink(
          icon: Icons.event_note_outlined,
          label: 'Appointments',
          subtitle: 'Manage all spa bookings',
          onTap: () => nav.goTo(DesktopRouteKey.reservations),
        ),
        _WorkspaceLink(
          icon: Icons.calendar_month_outlined,
          label: 'Calendar',
          subtitle: 'Schedule and availability',
          onTap: () => nav.goTo(DesktopRouteKey.adminCalendar),
        ),
        _WorkspaceLink(
          icon: Icons.grid_view_rounded,
          label: 'Services',
          subtitle: 'Treatment catalog',
          onTap: () => nav.goTo(DesktopRouteKey.catalog),
        ),
        _WorkspaceLink(
          icon: Icons.groups_outlined,
          label: 'Therapists',
          subtitle: 'Staff roster and specialties',
          onTap: () => nav.goTo(DesktopRouteKey.therapists),
        ),
        _WorkspaceLink(
          icon: Icons.people_outline,
          label: 'Clients',
          subtitle: 'Client profiles and history',
          onTap: () => nav.goToAdminSuite(AdminSuiteRoute.clients),
        ),
        _WorkspaceLink(
          icon: Icons.payments_outlined,
          label: 'Payments',
          subtitle: 'Invoices and transactions',
          onTap: () => nav.goToAdminSuite(AdminSuiteRoute.finance),
        ),
        _WorkspaceLink(
          icon: Icons.area_chart_rounded,
          label: 'Reports',
          subtitle: 'Revenue and analytics',
          onTap: () => nav.goTo(DesktopRouteKey.revenueAnalytics),
        ),
        _WorkspaceLink(
          icon: Icons.reviews_outlined,
          label: 'Reviews',
          subtitle: 'Client feedback hub',
          onTap: () => nav.goTo(DesktopRouteKey.reviews),
        ),
      ];
    }
    if (auth.isZaposlenik) {
      return [
        _WorkspaceLink(
          icon: Icons.space_dashboard_outlined,
          label: 'My Dashboard',
          subtitle: 'Today\'s overview and KPIs',
          onTap: () => nav.goTo(DesktopRouteKey.therapistDashboard),
        ),
        _WorkspaceLink(
          icon: Icons.event_note_outlined,
          label: 'My Appointments',
          subtitle: 'Assigned bookings',
          onTap: () => nav.goTo(DesktopRouteKey.therapistAppointments),
        ),
        _WorkspaceLink(
          icon: Icons.view_timeline_rounded,
          label: 'My Schedule',
          subtitle: 'Daily timeline and slots',
          onTap: () => nav.goTo(DesktopRouteKey.schedule),
        ),
        _WorkspaceLink(
          icon: Icons.spa_outlined,
          label: 'My Services',
          subtitle: 'Certified treatments',
          onTap: () => nav.goTo(DesktopRouteKey.therapistServices),
        ),
        _WorkspaceLink(
          icon: Icons.reviews_outlined,
          label: 'My Reviews',
          subtitle: 'Client feedback and ratings',
          onTap: () => nav.goTo(DesktopRouteKey.therapistReviews),
        ),
        _WorkspaceLink(
          icon: Icons.person_outline_rounded,
          label: 'Profile',
          subtitle: 'Contact and profile details',
          onTap: () => nav.goTo(DesktopRouteKey.therapistProfile),
        ),
      ];
    }
    return [
      _WorkspaceLink(
        icon: Icons.grid_view_rounded,
        label: 'Services',
        subtitle: 'Browse treatments',
        onTap: () => nav.goTo(DesktopRouteKey.catalog),
      ),
      _WorkspaceLink(
        icon: Icons.event_available_outlined,
        label: 'Bookings',
        subtitle: 'Your reservations',
        onTap: () => nav.goTo(DesktopRouteKey.reservations),
      ),
      _WorkspaceLink(
        icon: Icons.favorite_border,
        label: 'Favorites',
        subtitle: 'Saved services',
        onTap: () => nav.goTo(DesktopRouteKey.favorites),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final nav = context.watch<DesktopNav>();
    if (nav.headerFiltersPulse != _lastFiltersPulse) {
      _lastFiltersPulse = nav.headerFiltersPulse;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showSectionPicker();
      });
    }

    final fullName = _fullName(_session);
    final display = fullName.isNotEmpty
        ? fullName
        : (auth.displayName ?? 'Signed in');
    final query = _searchCtrl.text.trim();
    final sessionProgress = _sessionHealthProgress(_session?.expiresAt);
    final isActive = auth.status == AuthStatus.authenticated;
    final workspaceLinks = _workspaceLinks(auth, nav);

    final accountFields = [
      ('Username', auth.displayName ?? '—'),
      if (fullName.isNotEmpty) ('Full name', fullName),
      if (_session?.email != null) ('Email', _session!.email!),
      ('Role', _roleLabel(auth)),
      if (auth.zaposlenikId != null) ('Staff ID', '#${auth.zaposlenikId}'),
      if (auth.roles.isNotEmpty) ('Permissions', auth.roles.join(', ')),
    ];

    final showAccount = _matchesSearch(
      query,
      accountFields.map((e) => '${e.$1} ${e.$2}').toList(),
    );
    final showSession = _matchesSearch(
      query,
      ['Session', 'Active', 'Expires', _formatExpiry(_session?.expiresAt)],
    );
    final showWorkspace = _matchesSearch(
      query,
      workspaceLinks.map((l) => '${l.label} ${l.subtitle}').toList(),
    );
    final showApp = _matchesSearch(
      query,
      ['Application', 'NuaSpa', _kAppVersion, AppConfig.apiBaseUrl],
    );

    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeroAccountCard(
          displayName: display,
          role: _roleLabel(auth),
          subtitle: _heroSubtitle(auth),
          initials: auth.userInitials ?? 'NS',
          isActive: isActive,
        ),
        const SizedBox(height: _SetUi.gap),
        _SectionJumpBar(
          active: _activeSection,
          searchCtrl: _searchCtrl,
          onSearchChanged: () => setState(() {}),
          onSection: (s) {
            switch (s) {
              case 'Session':
                _scrollToSection(s, _sessionKey);
              case 'Workspace':
                _scrollToSection(s, _workspaceKey);
              case 'Application':
                _scrollToSection(s, _appKey);
              default:
                _scrollToSection('Account', _accountKey);
            }
          },
        ),
        const SizedBox(height: _SetUi.gap),
        if (showAccount) ...[
          _SettingsBlock(
            key: _accountKey,
            title: 'Account',
            subtitle: 'Your signed-in identity and access level.',
            icon: Icons.person_outline_rounded,
            child: Column(
              children: [
                for (var i = 0; i < accountFields.length; i++) ...[
                  _DetailGlassRow(
                    label: accountFields[i].$1,
                    value: accountFields[i].$2,
                  ),
                  if (i < accountFields.length - 1) const SizedBox(height: 10),
                ],
              ],
            ),
          ),
          const SizedBox(height: _SetUi.gap),
        ],
        if (showSession) ...[
          _SettingsBlock(
            key: _sessionKey,
            title: 'Session & Security',
            subtitle: 'Authentication status and sign-out controls.',
            icon: Icons.shield_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DetailGlassRow(
                  label: 'Status',
                  value: isActive ? 'Active' : auth.status.name,
                  valueColor: isActive ? _SetUi.green : _SetUi.orange,
                  leadingIcon: isActive
                      ? Icons.verified_user_rounded
                      : Icons.warning_amber_rounded,
                ),
                const SizedBox(height: 10),
                _DetailGlassRow(
                  label: 'Expires',
                  value: _loadingSession
                      ? 'Loading…'
                      : _formatExpiry(_session?.expiresAt),
                  leadingIcon: Icons.schedule_rounded,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _OutlinedAction(
                        icon: Icons.refresh_rounded,
                        label: 'Refresh session',
                        onPressed: _loadingSession
                            ? null
                            : () async {
                                await context
                                    .read<AuthProvider>()
                                    .checkAuthState();
                                await _loadSession();
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Session refreshed.'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _FilledDangerAction(
                        icon: Icons.logout_rounded,
                        label: 'Sign out',
                        onPressed: () => _confirmSignOut(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: _SetUi.gap),
        ],
        if (showWorkspace) ...[
          _SettingsBlock(
            key: _workspaceKey,
            title: 'Workspace',
            subtitle: auth.isAdmin
                ? 'Jump to the modules you use most in the admin console.'
                : auth.isZaposlenik
                    ? 'Your therapist portal — dashboard, schedule, and more.'
                    : 'Your booking experience shortcuts.',
            icon: Icons.dashboard_customize_outlined,
            child: Column(
              children: [
                for (var i = 0; i < workspaceLinks.length; i++) ...[
                  _WorkspaceRow(link: workspaceLinks[i]),
                  if (i < workspaceLinks.length - 1)
                    const SizedBox(height: 10),
                ],
              ],
            ),
          ),
          const SizedBox(height: _SetUi.gap),
        ],
        if (showApp)
          _SettingsBlock(
            key: _appKey,
            title: 'Application',
            subtitle: 'Build info and API connection for support.',
            icon: Icons.info_outline_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _DetailGlassRow(
                  label: 'App',
                  value: 'NuaSpa Desktop',
                  leadingIcon: Icons.desktop_windows_rounded,
                ),
                const SizedBox(height: 10),
                _DetailGlassRow(
                  label: 'Version',
                  value: _kAppVersion,
                  leadingIcon: Icons.tag_rounded,
                ),
                const SizedBox(height: 10),
                _DetailGlassRow(
                  label: 'Platform',
                  value: defaultTargetPlatform.name,
                  leadingIcon: Icons.devices_rounded,
                ),
                const SizedBox(height: 10),
                _DetailGlassRow(
                  label: 'API endpoint',
                  value: AppConfig.apiBaseUrl,
                  monospace: true,
                  leadingIcon: Icons.link_rounded,
                ),
                const SizedBox(height: 16),
                _OutlinedAction(
                  icon: Icons.copy_rounded,
                  label: 'Copy API URL',
                  onPressed: () => _copyApiUrl(context),
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Override at build: --dart-define=NUASPA_API_BASE_URL=…',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: _SetUi.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        if (!showAccount && !showSession && !showWorkspace && !showApp)
          _SetGlass(
            radius: _SetUi.heroRadius,
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 28),
            child: Column(
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 48,
                  color: _SetUi.lavender.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 16),
                Text(
                  'No settings match your search',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _SetUi.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Try another keyword or clear the search field.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: _SetUi.textSecondary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    final sidebar = _SettingsSidebar(
      isActive: isActive,
      role: _roleLabel(auth),
      expiresLabel: _loadingSession
          ? 'Loading…'
          : _formatExpiry(_session?.expiresAt),
      sessionProgress: sessionProgress,
      workspaceLinks: workspaceLinks.take(4).toList(),
      onSignOut: () => _confirmSignOut(context),
      onRefreshSession: _loadingSession
          ? null
          : () async {
              await context.read<AuthProvider>().checkAuthState();
              await _loadSession();
            },
    );

    return _SettingsShell(
      child: FadeTransition(
        opacity: _fadeAnim,
        child: LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 1100;
            return SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(
                _SetUi.contentPadding,
                8,
                _SetUi.contentPadding,
                40,
              ),
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: main),
                        const SizedBox(width: _SetUi.gap),
                        SizedBox(width: _SetUi.sidebarWidth, child: sidebar),
                      ],
                    )
                  : Column(
                      children: [
                        main,
                        const SizedBox(height: _SetUi.gap),
                        sidebar,
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }
}

class _WorkspaceLink {
  const _WorkspaceLink({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
}

class _SettingsShell extends StatelessWidget {
  const _SettingsShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_SetUi.bgTop, _SetUi.bgBottom],
            ),
          ),
        ),
        Positioned(
          top: -80,
          left: -40,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _SetUi.purple.withValues(alpha: 0.2),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 60,
          right: 20,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _SetUi.lavender.withValues(alpha: 0.14),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _SetGlass extends StatelessWidget {
  const _SetGlass({
    required this.child,
    this.padding,
    this.radius = _SetUi.cardRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: _SetUi.purple.withValues(alpha: 0.1),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _HeroAccountCard extends StatelessWidget {
  const _HeroAccountCard({
    required this.displayName,
    required this.role,
    required this.subtitle,
    required this.initials,
    required this.isActive,
  });

  final String displayName;
  final String role;
  final String subtitle;
  final String initials;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return _SetGlass(
      radius: _SetUi.heroRadius,
      padding: const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 200),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: const LinearGradient(
                  colors: [_SetUi.purple, _SetUi.lavender],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _SetUi.purple.withValues(alpha: 0.45),
                    blurRadius: 28,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.settings_suggest_rounded,
                    size: 52,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                  Text(
                    initials,
                    style: GoogleFonts.inter(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: GoogleFonts.inter(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: _SetUi.textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _StatusChip(
                        label: role,
                        color: NuaLuxuryTokens.champagneGold,
                      ),
                      const SizedBox(width: 8),
                      _StatusChip(
                        label: isActive ? 'Session active' : 'Session inactive',
                        color: isActive ? _SetUi.green : _SetUi.orange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.5,
                      color: _SetUi.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _SetUi.textPrimary,
        ),
      ),
    );
  }
}

class _SectionJumpBar extends StatelessWidget {
  const _SectionJumpBar({
    required this.active,
    required this.searchCtrl,
    required this.onSearchChanged,
    required this.onSection,
  });

  final String active;
  final TextEditingController searchCtrl;
  final VoidCallback onSearchChanged;
  final ValueChanged<String> onSection;

  static const _sections = [
    'Account',
    'Session',
    'Workspace',
    'Application',
  ];

  @override
  Widget build(BuildContext context) {
    return _SetGlass(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: searchCtrl,
            onChanged: (_) => onSearchChanged(),
            style: GoogleFonts.inter(
              color: _SetUi.textPrimary,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: 'Search settings…',
              hintStyle: GoogleFonts.inter(
                color: _SetUi.textSecondary,
                fontSize: 14,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: _SetUi.lavender.withValues(alpha: 0.85),
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: _SetUi.purple.withValues(alpha: 0.55),
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in _sections)
                _FilterPill(
                  label: s,
                  active: active == s,
                  onTap: () => onSection(s),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatefulWidget {
  const _FilterPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_FilterPill> createState() => _FilterPillState();
}

class _FilterPillState extends State<_FilterPill> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: widget.active
                  ? const LinearGradient(
                      colors: [_SetUi.purple, _SetUi.lavender],
                    )
                  : null,
              color: widget.active
                  ? null
                  : Colors.white.withValues(alpha: _hover ? 0.08 : 0.04),
              border: Border.all(
                color: widget.active
                    ? _SetUi.lavender.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.1),
              ),
              boxShadow: widget.active
                  ? [
                      BoxShadow(
                        color: _SetUi.purple.withValues(alpha: 0.35),
                        blurRadius: 14,
                      ),
                    ]
                  : null,
            ),
            child: Text(
              widget.label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: widget.active
                    ? Colors.white
                    : NuaLuxuryTokens.lavenderWhisper.withValues(alpha: 0.75),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsBlock extends StatelessWidget {
  const _SettingsBlock({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _SetGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    colors: [
                      _SetUi.purple.withValues(alpha: 0.35),
                      _SetUi.lavender.withValues(alpha: 0.2),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Icon(icon, color: _SetUi.lavender, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _SetUi.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: _SetUi.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _DetailGlassRow extends StatelessWidget {
  const _DetailGlassRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.monospace = false,
    this.leadingIcon,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool monospace;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leadingIcon != null) ...[
            Icon(leadingIcon, size: 18, color: _SetUi.lavender),
            const SizedBox(width: 12),
          ],
          SizedBox(
            width: leadingIcon != null ? 108 : 120,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _SetUi.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: monospace
                  ? const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                      color: _SetUi.textPrimary,
                    )
                  : GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: valueColor ?? _SetUi.textPrimary,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceRow extends StatefulWidget {
  const _WorkspaceRow({required this.link});

  final _WorkspaceLink link;

  @override
  State<_WorkspaceRow> createState() => _WorkspaceRowState();
}

class _WorkspaceRowState extends State<_WorkspaceRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.link.onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Colors.white.withValues(alpha: _hover ? 0.07 : 0.035),
              border: Border.all(
                color: _SetUi.purple.withValues(alpha: _hover ? 0.38 : 0.16),
              ),
              boxShadow: _hover
                  ? [
                      BoxShadow(
                        color: _SetUi.purple.withValues(alpha: 0.2),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: _SetUi.purple.withValues(alpha: 0.2),
                  ),
                  child: Icon(widget.link.icon, color: _SetUi.lavender),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.link.label,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _SetUi.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.link.subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _SetUi.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlinedAction extends StatefulWidget {
  const _OutlinedAction({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  State<_OutlinedAction> createState() => _OutlinedActionState();
}

class _OutlinedActionState extends State<_OutlinedAction> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: OutlinedButton.icon(
        onPressed: widget.onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: _SetUi.textPrimary,
          side: BorderSide(
            color: _SetUi.purple.withValues(alpha: _hover ? 0.65 : 0.35),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        icon: Icon(widget.icon, size: 18),
        label: Text(
          widget.label,
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _FilledDangerAction extends StatelessWidget {
  const _FilledDangerAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: _SetUi.pink,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SettingsSidebar extends StatelessWidget {
  const _SettingsSidebar({
    required this.isActive,
    required this.role,
    required this.expiresLabel,
    required this.sessionProgress,
    required this.workspaceLinks,
    required this.onSignOut,
    this.onRefreshSession,
  });

  final bool isActive;
  final String role;
  final String expiresLabel;
  final double? sessionProgress;
  final List<_WorkspaceLink> workspaceLinks;
  final VoidCallback onSignOut;
  final Future<void> Function()? onRefreshSession;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SetGlass(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Session Overview',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _SetUi.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              _SidebarMetric(
                label: 'Status',
                value: isActive ? 'Active' : 'Inactive',
                progress: isActive ? 1.0 : 0.25,
                accent: isActive ? _SetUi.green : _SetUi.orange,
              ),
              const SizedBox(height: 14),
              _SidebarMetric(
                label: 'Role',
                value: role,
                progress: 1.0,
                accent: _SetUi.gold,
              ),
              const SizedBox(height: 14),
              _SidebarMetric(
                label: 'Token expires',
                value: expiresLabel,
                progress: sessionProgress ?? 0.5,
                accent: _SetUi.lavender,
              ),
              if (onRefreshSession != null) ...[
                const SizedBox(height: 16),
                _SidebarQuickRow(
                  icon: Icons.refresh_rounded,
                  label: 'Refresh session',
                  onTap: () async {
                    await onRefreshSession!();
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SetGlass(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Quick Navigation',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _SetUi.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < workspaceLinks.length; i++) ...[
                _SidebarQuickRow(
                  icon: workspaceLinks[i].icon,
                  label: workspaceLinks[i].label,
                  onTap: workspaceLinks[i].onTap,
                ),
                if (i < workspaceLinks.length - 1) const SizedBox(height: 10),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SetGlass(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'App Info',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _SetUi.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'NuaSpa Desktop · v$_kAppVersion',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _SetUi.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                defaultTargetPlatform.name,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: _SetUi.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              _SidebarQuickRow(
                icon: Icons.logout_rounded,
                label: 'Sign out',
                onTap: onSignOut,
                danger: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SidebarMetric extends StatelessWidget {
  const _SidebarMetric({
    required this.label,
    required this.value,
    required this.progress,
    required this.accent,
  });

  final String label;
  final String value;
  final double progress;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: _SetUi.textSecondary,
                ),
              ),
            ),
            Flexible(
              child: Text(
                value,
                maxLines: 2,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _SetUi.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 8,
            child: Stack(
              children: [
                Container(color: Colors.white.withValues(alpha: 0.08)),
                FractionallySizedBox(
                  widthFactor: progress.clamp(0.0, 1.0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accent, accent.withValues(alpha: 0.55)],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SidebarQuickRow extends StatefulWidget {
  const _SidebarQuickRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  State<_SidebarQuickRow> createState() => _SidebarQuickRowState();
}

class _SidebarQuickRowState extends State<_SidebarQuickRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.danger ? _SetUi.pink : _SetUi.lavender;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Colors.white.withValues(alpha: _hover ? 0.08 : 0.04),
              border: Border.all(
                color: accent.withValues(alpha: _hover ? 0.45 : 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(widget.icon, color: accent, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.label,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      color: _SetUi.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
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