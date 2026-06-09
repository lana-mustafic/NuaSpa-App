import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../core/api/services/api_service.dart';
import '../../core/config/app_config.dart';
import '../../core/jwt_roles.dart';
import '../../core/settings/settings_messages.dart';
import '../../models/account_profile.dart';
import '../../providers/auth_provider.dart';
import '../../screens/admin/admin_suite_route.dart';
import '../../ui/navigation/desktop_nav.dart';
import '../../ui/widgets/luxury/luxury_desktop_header.dart';

abstract final class _SetUi {
  static const bgTop = Color(0xFF07040F);
  static const bgBottom = Color(0xFF120A24);
  static const textPrimary = Color(0xFFF5F3FA);
  static const textSecondary = Color(0xA6FFFFFF);
  static const purple = Color(0xFF7B4DFF);
  static const lavender = Color(0xFF9D6BFF);
  static const green = Color(0xFF22C55E);
  static const orange = Color(0xFFF97316);
  static const pink = Color(0xFFEC4899);
  static const cardRadius = 18.0;
  static const gap = 24.0;
  static const sectionGap = 28.0;
}

class LuxurySettingsScreen extends StatefulWidget {
  const LuxurySettingsScreen({super.key});

  @override
  State<LuxurySettingsScreen> createState() => _LuxurySettingsScreenState();
}

class _LuxurySettingsScreenState extends State<LuxurySettingsScreen>
    with SingleTickerProviderStateMixin {
  static const _storage = FlutterSecureStorage();
  static const _tabs = ['Account', 'Security', 'Workspace', 'Application'];

  final _api = ApiService();
  AccountProfile? _profile;
  DateTime? _tokenExpiresAt;
  bool _loading = true;
  String? _profileError;
  String? _appVersion;
  bool _refreshingSession = false;
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this)
      ..addListener(() {
        if (!_tabCtrl.indexIsChanging) setState(() {});
      });
    _loadAll();
    _loadAppVersion();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _appVersion = info.version);
    } catch (_) {
      if (!mounted) return;
      setState(() => _appVersion = '—');
    }
  }

  Future<void> _loadTokenExpiry() async {
    final token = await _storage.read(key: 'jwt_token');
    _tokenExpiresAt = parseJwtExpiry(token);
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _profileError = null;
    });
    await _loadTokenExpiry();
    final profile = await _api.getAccountProfile();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _profileError = profile == null
          ? 'Could not load account details. Check your connection and try again.'
          : null;
      _loading = false;
    });
  }

  String _roleLabel(AccountProfile? profile, AuthProvider auth) {
    if (profile != null) {
      if (profile.roles.contains('Admin')) return 'Administrator';
      if (profile.roles.contains('Zaposlenik')) return 'Therapist';
      if (profile.roles.contains('Klijent')) return 'Client';
    }
    if (auth.isAdmin) return 'Administrator';
    if (auth.isZaposlenik) return 'Therapist';
    return 'Client';
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

  bool get _sessionExpiringSoon {
    final exp = _tokenExpiresAt;
    if (exp == null) return false;
    return exp.difference(DateTime.now()) <= const Duration(minutes: 15);
  }

  Future<void> _refreshSession(BuildContext context) async {
    if (_refreshingSession) return;
    setState(() => _refreshingSession = true);
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await auth.reloadLocalSession();
    await _loadAll();
    if (!mounted) return;
    setState(() => _refreshingSession = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Session details reloaded.'
              : 'Your session has expired. Please sign in again.',
        ),
        behavior: SnackBarBehavior.floating,
        width: 420,
      ),
    );
  }

  void _onEditProfile(AuthProvider auth, DesktopNav nav, AccountProfile? profile) {
    if (auth.isZaposlenik && auth.zaposlenikId != null) {
      nav.goTo(DesktopRouteKey.therapistProfile);
      return;
    }
    if (auth.isZaposlenik) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your therapist profile is not linked to this account yet. Contact your spa administrator.',
          ),
          behavior: SnackBarBehavior.floating,
          width: 420,
        ),
      );
      return;
    }
    if (auth.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Administrator account details are managed by your system operator.',
          ),
          behavior: SnackBarBehavior.floating,
          width: 420,
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          profile?.email != null
              ? 'Contact NuaSpa to update your client profile details.'
              : 'Profile editing is not available for your account yet.',
        ),
        behavior: SnackBarBehavior.floating,
        width: 420,
      ),
    );
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
      final serverOk = await context.read<AuthProvider>().logout();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            SettingsMessages.en(
              serverOk
                  ? 'Signed out successfully.'
                  : 'Server sign-out failed. Your local session was cleared.',
            ),
          ),
          behavior: SnackBarBehavior.floating,
          width: 420,
        ),
      );
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
          subtitle: 'Client profiles, notes, and CRM',
          onTap: () => nav.goToAdminSuite(AdminSuiteRoute.clients),
        ),
        _WorkspaceLink(
          icon: Icons.payments_outlined,
          label: 'Payments',
          subtitle: 'Payments, revenue and transactions',
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
        onTap: () => nav.goToCatalogFavorites(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final nav = context.watch<DesktopNav>();
    final profile = _profile;

    final displayName = profile != null && profile.fullName.isNotEmpty
        ? profile.fullName
        : (profile?.userName ?? auth.displayName ?? 'Signed in');
    final accountActive = profile?.isActive ?? auth.status == AuthStatus.authenticated;
    final sessionActive =
        auth.status == AuthStatus.authenticated && accountActive;
    final workspaceLinks = _workspaceLinks(auth, nav);
    final expiresLabel =
        _loading ? 'Loading…' : _formatExpiry(_tokenExpiresAt);
    final role = _roleLabel(profile, auth);

    final accountRows = <_SettingsRowData>[
      if (profile != null && profile.fullName.isNotEmpty)
        _SettingsRowData(label: 'Full name', value: profile.fullName),
      _SettingsRowData(
        label: 'Username',
        value: profile?.userName ?? auth.displayName ?? '—',
      ),
      if (profile?.email != null && profile!.email!.isNotEmpty)
        _SettingsRowData(label: 'Email', value: profile.email!),
      _SettingsRowData(label: 'Role', value: role),
      if ((profile?.roles ?? auth.roles).isNotEmpty)
        _SettingsRowData(
          label: 'Roles',
          value: (profile?.roles ?? auth.roles).join(', '),
        ),
    ];

    return _SettingsShell(
      child: SingleChildScrollView(
        padding: LuxuryPageChrome.bodyPadding.copyWith(top: 8, bottom: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AccountSummaryStrip(
              displayName: displayName,
              role: role,
              initials: auth.userInitials ?? 'NS',
              isActive: sessionActive,
              expiresLabel: expiresLabel,
            ),
            if (_sessionExpiringSoon && !_loading) ...[
              const SizedBox(height: 12),
              _SessionExpiryBanner(expiresLabel: expiresLabel),
            ],
            if (_profileError != null) ...[
              const SizedBox(height: 12),
              _SettingsNotice(
                message: _profileError!,
                actionLabel: 'Retry',
                onAction: _loadAll,
              ),
            ],
            const SizedBox(height: 20),
            _SettingsTabBar(
              tabs: _tabs,
              activeIndex: _tabCtrl.index,
              onTab: (i) => _tabCtrl.animateTo(i),
            ),
            const SizedBox(height: _SetUi.sectionGap),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              switch (_tabCtrl.index) {
                0 => _AccountTab(
                    rows: accountRows,
                    onEditProfile: () => _onEditProfile(auth, nav, profile),
                  ),
                1 => _SecurityTab(
                    isActive: sessionActive,
                    statusLabel: sessionActive
                        ? 'Active'
                        : (accountActive
                            ? auth.status.name
                            : 'Account inactive'),
                    role: role,
                    expiresLabel: expiresLabel,
                    hasPassword: profile?.hasPassword ?? true,
                    refreshing: _refreshingSession,
                    onRefresh: () => _refreshSession(context),
                    onSignOut: () => _confirmSignOut(context),
                    onPasswordChanged: _loadAll,
                  ),
                2 => _WorkspaceTab(
                    auth: auth,
                    links: workspaceLinks,
                  ),
                _ => _ApplicationTab(
                    appVersion: _appVersion ?? '—',
                    onCopyApiUrl: () => _copyApiUrl(context),
                  ),
              },
          ],
        ),
      ),
    );
  }
}

class _SettingsRowData {
  const _SettingsRowData({required this.label, required this.value});

  final String label;
  final String value;
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
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_SetUi.bgTop, _SetUi.bgBottom],
        ),
      ),
      child: child,
    );
  }
}

class _SetGlass extends StatelessWidget {
  const _SetGlass({
    required this.child,
    this.padding,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(_SetUi.cardRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: child,
    );
  }
}

class _AccountSummaryStrip extends StatelessWidget {
  const _AccountSummaryStrip({
    required this.displayName,
    required this.role,
    required this.initials,
    required this.isActive,
    required this.expiresLabel,
  });

  final String displayName;
  final String role;
  final String initials;
  final bool isActive;
  final String expiresLabel;

  @override
  Widget build(BuildContext context) {
    return _SetGlass(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: LayoutBuilder(
        builder: (context, c) {
          final compact = c.maxWidth < 720;
          return SizedBox(
            height: compact ? 96 : 88,
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _identityRow()),
                      const SizedBox(height: 8),
                      _expiryText(),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: _identityRow()),
                      const SizedBox(width: 16),
                      _expiryText(),
                    ],
                  ),
          );
        },
      ),
    );
  }

  Widget _identityRow() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [_SetUi.purple, _SetUi.lavender],
            ),
          ),
          child: Text(
            initials,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _SetUi.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$role • ${isActive ? 'Active session' : 'Inactive session'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: _SetUi.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _expiryText() {
    return Text(
      'Token expires: $expiresLabel',
      maxLines: 2,
      textAlign: TextAlign.right,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.white.withValues(alpha: 0.5),
        height: 1.35,
      ),
    );
  }
}

class _SettingsTabBar extends StatelessWidget {
  const _SettingsTabBar({
    required this.tabs,
    required this.activeIndex,
    required this.onTab,
  });

  final List<String> tabs;
  final int activeIndex;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < tabs.length; i++)
          _SettingsTab(
            label: tabs[i],
            active: activeIndex == i,
            onTap: () => onTab(i),
          ),
      ],
    );
  }
}

class _SettingsTab extends StatefulWidget {
  const _SettingsTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
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
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: widget.active
                  ? _SetUi.purple.withValues(alpha: 0.28)
                  : Colors.white.withValues(alpha: _hover ? 0.06 : 0.03),
              border: Border.all(
                color: widget.active
                    ? _SetUi.lavender.withValues(alpha: 0.45)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Text(
              widget.label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: widget.active
                    ? _SetUi.textPrimary
                    : Colors.white.withValues(alpha: 0.62),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({
    required this.title,
    this.subtitle,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _SetGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _SetUi.textPrimary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: _SetUi.textSecondary,
                height: 1.4,
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

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.monospace = false,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool monospace;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 148,
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.52),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: monospace
                      ? const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                          color: _SetUi.textPrimary,
                        )
                      : GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: valueColor ?? _SetUi.textPrimary,
                        ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
      ],
    );
  }
}

class _AccountTab extends StatelessWidget {
  const _AccountTab({
    required this.rows,
    required this.onEditProfile,
  });

  final List<_SettingsRowData> rows;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    return _SettingsPanel(
      title: 'Account Information',
      subtitle: 'Your signed-in identity and access level.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++)
            _SettingsRow(
              label: rows[i].label,
              value: rows[i].value,
              showDivider: i < rows.length - 1,
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onEditProfile,
              icon: const Icon(Icons.edit_outlined, size: 17),
              label: const Text('Edit Profile'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white.withValues(alpha: 0.82),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionExpiryBanner extends StatelessWidget {
  const _SessionExpiryBanner({required this.expiresLabel});

  final String expiresLabel;

  @override
  Widget build(BuildContext context) {
    return _SetGlass(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            Icons.schedule_rounded,
            size: 18,
            color: _SetUi.orange.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your session expires soon ($expiresLabel). Reload session details or sign in again after expiry.',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                height: 1.4,
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsNotice extends StatelessWidget {
  const _SettingsNotice({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return _SetGlass(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
          ),
          TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _SecurityTab extends StatelessWidget {
  const _SecurityTab({
    required this.isActive,
    required this.statusLabel,
    required this.role,
    required this.expiresLabel,
    required this.hasPassword,
    required this.refreshing,
    required this.onRefresh,
    required this.onSignOut,
    required this.onPasswordChanged,
  });

  final bool isActive;
  final String statusLabel;
  final String role;
  final String expiresLabel;
  final bool hasPassword;
  final bool refreshing;
  final VoidCallback onRefresh;
  final VoidCallback onSignOut;
  final VoidCallback onPasswordChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettingsPanel(
          title: 'Session',
          subtitle: 'Authentication status and session controls.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SettingsRow(
                label: 'Status',
                value: statusLabel,
                valueColor: isActive ? _SetUi.green : _SetUi.orange,
              ),
              _SettingsRow(label: 'Role', value: role),
              _SettingsRow(
                label: 'Token expires',
                value: expiresLabel,
                showDivider: false,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: refreshing ? null : onRefresh,
                    icon: refreshing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded, size: 17),
                    label: Text(refreshing ? 'Reloading…' : 'Reload session'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white.withValues(alpha: 0.82),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: onSignOut,
                    icon: const Icon(Icons.logout_rounded, size: 17),
                    label: const Text('Sign out'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _SetUi.pink,
                      side: BorderSide(
                        color: _SetUi.pink.withValues(alpha: 0.45),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (hasPassword) ...[
          const SizedBox(height: _SetUi.gap),
          _SettingsPanel(
            title: 'Password',
            subtitle: 'Update your account password.',
            child: _ChangePasswordPanel(onChanged: onPasswordChanged),
          ),
        ] else ...[
          const SizedBox(height: _SetUi.gap),
          _SettingsPanel(
            title: 'Password',
            subtitle: 'Portal access activation.',
            child: Text(
              'Password is not set yet. Use your invitation link to activate access.',
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.45,
                color: _SetUi.textSecondary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _WorkspaceTab extends StatelessWidget {
  const _WorkspaceTab({
    required this.auth,
    required this.links,
  });

  final AuthProvider auth;
  final List<_WorkspaceLink> links;

  @override
  Widget build(BuildContext context) {
    final subtitle = auth.isAdmin
        ? 'Shortcuts to modules you use most in the admin console.'
        : auth.isZaposlenik
            ? 'Your therapist portal modules.'
            : 'Your booking experience shortcuts.';

    return _SettingsPanel(
      title: 'Workspace',
      subtitle: subtitle,
      child: Column(
        children: [
          for (var i = 0; i < links.length; i++) ...[
            _WorkspaceRow(link: links[i]),
            if (i < links.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _ApplicationTab extends StatelessWidget {
  const _ApplicationTab({
    required this.appVersion,
    required this.onCopyApiUrl,
  });

  final String appVersion;
  final VoidCallback onCopyApiUrl;

  @override
  Widget build(BuildContext context) {
    return _SettingsPanel(
      title: 'Application',
      subtitle: 'Build info and API connection for support.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SettingsRow(label: 'App', value: 'NuaSpa Desktop'),
          _SettingsRow(label: 'Version', value: appVersion),
          _SettingsRow(
            label: 'Platform',
            value: defaultTargetPlatform.name,
          ),
          _SettingsRow(
            label: 'API endpoint',
            value: AppConfig.apiBaseUrl,
            monospace: true,
            showDivider: false,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onCopyApiUrl,
            icon: const Icon(Icons.copy_rounded, size: 17),
            label: const Text('Copy API URL'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white.withValues(alpha: 0.82),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 12),
            Text(
              'Override: --dart-define=API_BASE_URL=… or --dart-define-from-file=.env',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: _SetUi.textSecondary,
              ),
            ),
          ],
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
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white.withValues(alpha: _hover ? 0.05 : 0.025),
              border: Border.all(
                color: Colors.white.withValues(alpha: _hover ? 0.1 : 0.06),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  widget.link.icon,
                  size: 18,
                  color: _SetUi.lavender.withValues(alpha: 0.85),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.link.label,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _SetUi.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.link.subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: _SetUi.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.32),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChangePasswordPanel extends StatefulWidget {
  const _ChangePasswordPanel({required this.onChanged});

  final VoidCallback onChanged;

  @override
  State<_ChangePasswordPanel> createState() => _ChangePasswordPanelState();
}

class _ChangePasswordPanelState extends State<_ChangePasswordPanel> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _oldC = TextEditingController();
  final _newC = TextEditingController();
  final _confirmC = TextEditingController();
  var _obscureOld = true;
  var _obscureNew = true;
  var _obscureConfirm = true;
  var _saving = false;
  var _attemptedSubmit = false;

  @override
  void dispose() {
    _oldC.dispose();
    _newC.dispose();
    _confirmC.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _attemptedSubmit = true);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final result = await _api.changePassword(
      staraLozinka: _oldC.text,
      novaLozinka: _newC.text,
      potvrdaNoveLozinke: _confirmC.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(SettingsMessages.en(result.message)),
        behavior: SnackBarBehavior.floating,
      ),
    );
    if (result.success) {
      if (result.token != null && result.token!.isNotEmpty) {
        await context.read<AuthProvider>().applySessionToken(
              result.token!,
              refreshToken: result.refreshToken,
            );
      }
      _oldC.clear();
      _newC.clear();
      _confirmC.clear();
      setState(() => _attemptedSubmit = false);
      widget.onChanged();
    }
  }

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required.';
    }
    return null;
  }

  String? _newPassword(String? value) {
    final err = _required(value, 'New password');
    if (err != null) return err;
    if (value!.length < 6) {
      return 'New password must be at least 6 characters.';
    }
    if (value == _oldC.text) {
      return 'New password must be different from your current password.';
    }
    return null;
  }

  String? _confirmPassword(String? value) {
    final err = _required(value, 'Password confirmation');
    if (err != null) return err;
    if (value != _newC.text) {
      return 'New password and confirmation do not match.';
    }
    return null;
  }

  InputDecoration _decoration(String label, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(
        color: Colors.white.withValues(alpha: 0.55),
        fontSize: 13,
      ),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.04),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _SetUi.lavender, width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.red.shade300),
      ),
      suffixIcon: suffix,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Form(
          key: _formKey,
          autovalidateMode: _attemptedSubmit
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child: Column(
            children: [
              TextFormField(
                controller: _oldC,
                obscureText: _obscureOld,
                style: GoogleFonts.inter(color: _SetUi.textPrimary),
                decoration: _decoration(
                  'Current password',
                  suffix: IconButton(
                    icon: Icon(
                      _obscureOld
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: Colors.white54,
                    ),
                    onPressed: () =>
                        setState(() => _obscureOld = !_obscureOld),
                  ),
                ),
                validator: (v) => _required(v, 'Current password'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _newC,
                obscureText: _obscureNew,
                style: GoogleFonts.inter(color: _SetUi.textPrimary),
                decoration: _decoration(
                  'New password',
                  suffix: IconButton(
                    icon: Icon(
                      _obscureNew
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: Colors.white54,
                    ),
                    onPressed: () =>
                        setState(() => _obscureNew = !_obscureNew),
                  ),
                ),
                validator: _newPassword,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmC,
                obscureText: _obscureConfirm,
                style: GoogleFonts.inter(color: _SetUi.textPrimary),
                decoration: _decoration(
                  'Confirm new password',
                  suffix: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: Colors.white54,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                validator: _confirmPassword,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.lock_reset_rounded, size: 20),
            label: Text(_saving ? 'Saving…' : 'Save new password'),
            style: FilledButton.styleFrom(
              backgroundColor: _SetUi.purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}