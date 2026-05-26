import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/api/services/api_service.dart';
import '../../core/auth/app_permissions.dart';
import '../../models/usluga.dart';
import '../../models/zaposlenik.dart';
import '../../models/zaposlenik_status.dart';
import '../../providers/auth_provider.dart';
import '../../ui/navigation/desktop_nav.dart';
import '../../ui/theme/luxury_modal_style.dart';
import '../../ui/theme/nua_luxury_tokens.dart';
import 'therapist_portal_scaffold.dart';

abstract final class _ProfUi {
  static const bgTop = Color(0xFF07040F);
  static const bgBottom = Color(0xFF120A24);
  static const textPrimary = Color(0xFFF5F3FA);
  static const textSecondary = Color(0xA6FFFFFF);
  static const purple = Color(0xFF7B4DFF);
  static const lavender = Color(0xFF9D6BFF);
  static const gold = Color(0xFFF5B942);
  static const green = Color(0xFF22C55E);
  static const orange = Color(0xFFF97316);
  static const cardRadius = 24.0;
  static const heroRadius = 30.0;
  static const gap = 24.0;
  static const sidebarWidth = 340.0;
  static const contentPadding = 32.0;
}

class _ProfileData {
  const _ProfileData({
    required this.profile,
    required this.certifiedCount,
  });

  final Zaposlenik profile;
  final int certifiedCount;
}

List<Usluga> _linkedServices(Zaposlenik me, List<Usluga> all) {
  final katId = me.kategorijaUslugaId;
  if (katId != null && katId > 0) {
    return all.where((u) => u.kategorijaUslugaId == katId).toList();
  }
  final tags = me.specijalizacija
      .split(RegExp(r'[,;/]'))
      .map((e) => e.trim().toLowerCase())
      .where((e) => e.isNotEmpty)
      .toSet();
  if (tags.isEmpty) return const [];
  return all
      .where((u) => tags.contains(u.naziv.trim().toLowerCase()))
      .toList();
}

String _initials(Zaposlenik z) {
  final a = z.ime.trim().isNotEmpty ? z.ime.trim()[0] : '';
  final b = z.prezime.trim().isNotEmpty ? z.prezime.trim()[0] : '';
  final s = '$a$b'.toUpperCase();
  return s.isEmpty ? 'TH' : s;
}

String _formatDate(DateTime? d) {
  if (d == null) return '—';
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final loc = d.toLocal();
  return '${months[loc.month - 1]} ${loc.day}, ${loc.year}';
}

int _profileCompleteness(Zaposlenik z) {
  var score = 0;
  if ((z.telefon ?? '').trim().isNotEmpty) score += 25;
  if ((z.jezici ?? '').trim().isNotEmpty) score += 25;
  if ((z.email ?? '').trim().isNotEmpty) score += 25;
  if (z.specijalizacija.trim().isNotEmpty) score += 25;
  return score;
}

Color _statusColor(ZaposlenikStatus s) {
  switch (s) {
    case ZaposlenikStatus.active:
      return _ProfUi.green;
    case ZaposlenikStatus.onLeave:
      return _ProfUi.gold;
    case ZaposlenikStatus.inactive:
      return _ProfUi.orange;
  }
}

class TherapistProfileScreen extends StatefulWidget {
  const TherapistProfileScreen({super.key});

  @override
  State<TherapistProfileScreen> createState() => _TherapistProfileScreenState();
}

class _TherapistProfileScreenState extends State<TherapistProfileScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  final _telefon = TextEditingController();
  final _jezici = TextEditingController();
  final _scrollCtrl = ScrollController();
  Future<_ProfileData?>? _future;
  bool _saving = false;
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
    _reload();
  }

  @override
  void dispose() {
    _telefon.dispose();
    _jezici.dispose();
    _scrollCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _bind(Zaposlenik z) {
    _telefon.text = z.telefon ?? '';
    _jezici.text = z.jezici ?? '';
  }

  Future<void> _reload() async {
    setState(() {
      _future = () async {
        final results = await Future.wait([
          _api.getTherapistMe(),
          _api.getUsluge(),
        ]);
        final me = results[0] as Zaposlenik?;
        final all = results[1] as List<Usluga>;
        if (me == null) return null;
        _bind(me);
        return _ProfileData(
          profile: me,
          certifiedCount: _linkedServices(me, all).length,
        );
      }();
    });
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
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _fadeCtrl.forward(from: 0);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save profile.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!AppPermissions.of(auth).has(AppPermission.updateOwnTherapistProfile)) {
      return const _ProfileShell(
        child: TherapistEmptyState(message: 'Therapist login required.'),
      );
    }

    return _ProfileShell(
      child: FutureBuilder<_ProfileData?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          final data = snap.data;
          if (data == null) {
            return _ProfileEmptyCard(
              onRetry: _reload,
            );
          }

          final z = data.profile;
          final completeness = _profileCompleteness(z);
          final tags = z.specijalizacija
              .split(RegExp(r'[,;/]'))
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();

          final main = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeroProfileCard(
                initials: _initials(z),
                name: z.fullName,
                specialization: z.specijalizacija.trim().isEmpty
                    ? 'Therapist'
                    : z.specijalizacija,
                status: z.status,
                certifiedCount: data.certifiedCount,
              ),
              const SizedBox(height: _ProfUi.gap),
              _ProfGlass(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SectionHeader(
                      icon: Icons.edit_note_rounded,
                      title: 'Editable details',
                      subtitle:
                          'Update contact info you can change yourself. Name, role, and services are managed by admin.',
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Phone',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _ProfUi.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _telefon,
                      style: LuxuryModalStyle.fieldStyle(context),
                      decoration: LuxuryModalStyle.fieldDecoration(
                        hint: 'e.g. +385 91 234 5678',
                        prefixIcon: Icon(
                          Icons.phone_outlined,
                          color: _ProfUi.lavender.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Languages',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _ProfUi.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _jezici,
                      style: LuxuryModalStyle.fieldStyle(context),
                      decoration: LuxuryModalStyle.fieldDecoration(
                        hint: 'e.g. English, Croatian',
                        prefixIcon: Icon(
                          Icons.translate_rounded,
                          color: _ProfUi.lavender.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    _SaveButton(
                      saving: _saving,
                      onPressed: _save,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: _ProfUi.gap),
              _ProfGlass(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SectionHeader(
                      icon: Icons.badge_outlined,
                      title: 'Professional profile',
                      subtitle:
                          'Read-only details from your NuaSpa staff record.',
                    ),
                    const SizedBox(height: 18),
                    _ReadOnlyRow(
                      label: 'Full name',
                      value: z.fullName,
                      icon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 10),
                    _ReadOnlyRow(
                      label: 'Email',
                      value: (z.email ?? '').trim().isEmpty ? '—' : z.email!,
                      icon: Icons.mail_outline_rounded,
                    ),
                    const SizedBox(height: 10),
                    _ReadOnlyRow(
                      label: 'Specialization',
                      value: z.specijalizacija.trim().isEmpty
                          ? '—'
                          : z.specijalizacija,
                      icon: Icons.spa_outlined,
                    ),
                    const SizedBox(height: 10),
                    _ReadOnlyRow(
                      label: 'Service category',
                      value: (z.kategorijaUslugaNaziv ?? '').trim().isEmpty
                          ? '—'
                          : z.kategorijaUslugaNaziv!,
                      icon: Icons.category_outlined,
                    ),
                    const SizedBox(height: 10),
                    _ReadOnlyRow(
                      label: 'Education',
                      value: (z.obrazovanje ?? '').trim().isEmpty
                          ? '—'
                          : z.obrazovanje!,
                      icon: Icons.school_outlined,
                    ),
                    const SizedBox(height: 10),
                    _ReadOnlyRow(
                      label: 'Location',
                      value: (z.lokacija ?? '').trim().isEmpty
                          ? '—'
                          : z.lokacija!,
                      icon: Icons.location_on_outlined,
                    ),
                    const SizedBox(height: 10),
                    _ReadOnlyRow(
                      label: 'Employed since',
                      value: _formatDate(z.datumZaposlenja),
                      icon: Icons.calendar_month_outlined,
                    ),
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Text(
                        'Specialties',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _ProfUi.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final t in tags)
                            _SpecialtyChip(label: t),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );

          final sidebar = _ProfileSidebar(
            completeness: completeness,
            status: z.status,
            certifiedCount: data.certifiedCount,
            category: z.kategorijaUslugaNaziv,
            onRefresh: _reload,
          );

          return FadeTransition(
            opacity: _fadeAnim,
            child: LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 1100;
                return SingleChildScrollView(
                  controller: _scrollCtrl,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    _ProfUi.contentPadding,
                    8,
                    _ProfUi.contentPadding,
                    40,
                  ),
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: main),
                            const SizedBox(width: _ProfUi.gap),
                            SizedBox(
                              width: _ProfUi.sidebarWidth,
                              child: sidebar,
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            main,
                            const SizedBox(height: _ProfUi.gap),
                            sidebar,
                          ],
                        ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ProfileShell extends StatelessWidget {
  const _ProfileShell({required this.child});

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
              colors: [_ProfUi.bgTop, _ProfUi.bgBottom],
            ),
          ),
        ),
        Positioned(
          top: -70,
          right: 60,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _ProfUi.purple.withValues(alpha: 0.22),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 40,
          left: -20,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _ProfUi.lavender.withValues(alpha: 0.12),
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

class _ProfGlass extends StatelessWidget {
  const _ProfGlass({
    required this.child,
    this.padding,
    this.radius = _ProfUi.cardRadius,
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
            color: _ProfUi.purple.withValues(alpha: 0.1),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: [
                _ProfUi.purple.withValues(alpha: 0.35),
                _ProfUi.lavender.withValues(alpha: 0.2),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Icon(icon, color: _ProfUi.lavender, size: 20),
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
                  color: _ProfUi.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.45,
                  color: _ProfUi.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroProfileCard extends StatelessWidget {
  const _HeroProfileCard({
    required this.initials,
    required this.name,
    required this.specialization,
    required this.status,
    required this.certifiedCount,
  });

  final String initials;
  final String name;
  final String specialization;
  final ZaposlenikStatus status;
  final int certifiedCount;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(status);
    return _ProfGlass(
      radius: _ProfUi.heroRadius,
      padding: const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 220),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  colors: [_ProfUi.purple, _ProfUi.lavender],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _ProfUi.purple.withValues(alpha: 0.5),
                    blurRadius: 32,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Text(
                initials,
                style: GoogleFonts.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.inter(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: _ProfUi.textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    specialization,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: NuaLuxuryTokens.champagneGold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _HeroChip(
                        label: status.label,
                        color: statusColor,
                      ),
                      _HeroChip(
                        label: '$certifiedCount certified services',
                        color: _ProfUi.lavender,
                      ),
                      const _HeroChip(
                        label: 'Therapist',
                        color: _ProfUi.purple,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.verified_user_rounded,
              size: 56,
              color: _ProfUi.purple.withValues(alpha: 0.25),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.label, required this.color});

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
          color: _ProfUi.textPrimary,
        ),
      ),
    );
  }
}

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

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
          Icon(icon, size: 18, color: _ProfUi.lavender),
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _ProfUi.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _ProfUi.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpecialtyChip extends StatelessWidget {
  const _SpecialtyChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _ProfUi.purple.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _ProfUi.lavender.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: _ProfUi.textPrimary,
        ),
      ),
    );
  }
}

class _SaveButton extends StatefulWidget {
  const _SaveButton({required this.saving, required this.onPressed});

  final bool saving;
  final VoidCallback onPressed;

  @override
  State<_SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<_SaveButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [_ProfUi.purple, _ProfUi.lavender],
          ),
          boxShadow: _hover
              ? [
                  BoxShadow(
                    color: _ProfUi.purple.withValues(alpha: 0.45),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.saving ? null : widget.onPressed,
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: Center(
                child: widget.saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.save_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Save changes',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileSidebar extends StatelessWidget {
  const _ProfileSidebar({
    required this.completeness,
    required this.status,
    required this.certifiedCount,
    required this.category,
    required this.onRefresh,
  });

  final int completeness;
  final ZaposlenikStatus status;
  final int certifiedCount;
  final String? category;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final nav = context.read<DesktopNav>();
    final statusColor = _statusColor(status);
    final catLabel =
        (category ?? '').trim().isEmpty ? 'Not assigned' : category!;

    return Column(
      children: [
        _ProfGlass(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Profile Overview',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _ProfUi.textPrimary,
                ),
              ),
              const SizedBox(height: 18),
              _SidebarMetric(
                label: 'Profile completeness',
                value: '$completeness%',
                progress: completeness / 100,
                accent: _ProfUi.lavender,
              ),
              const SizedBox(height: 14),
              _SidebarMetric(
                label: 'Account status',
                value: status.label,
                progress: status.isBookable ? 1.0 : 0.4,
                accent: statusColor,
              ),
              const SizedBox(height: 14),
              _SidebarMetric(
                label: 'Certified services',
                value: '$certifiedCount',
                progress: certifiedCount > 0
                    ? (certifiedCount.clamp(0, 12) / 12)
                    : 0.05,
                accent: _ProfUi.gold,
              ),
              const SizedBox(height: 14),
              _SidebarMetric(
                label: 'Service category',
                value: catLabel,
                progress: catLabel == 'Not assigned' ? 0.05 : 1.0,
                accent: _ProfUi.purple,
              ),
              const SizedBox(height: 6),
              Text(
                'Category: $catLabel',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: _ProfUi.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _ProfGlass(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Quick Actions',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _ProfUi.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              _QuickRow(
                icon: Icons.spa_outlined,
                label: 'My Services',
                onTap: () => nav.goTo(DesktopRouteKey.therapistServices),
              ),
              const SizedBox(height: 10),
              _QuickRow(
                icon: Icons.reviews_outlined,
                label: 'My Reviews',
                onTap: () => nav.goTo(DesktopRouteKey.therapistReviews),
              ),
              const SizedBox(height: 10),
              _QuickRow(
                icon: Icons.view_timeline_rounded,
                label: 'My Schedule',
                onTap: () => nav.goTo(DesktopRouteKey.schedule),
              ),
              const SizedBox(height: 10),
              _QuickRow(
                icon: Icons.tune_rounded,
                label: 'Settings',
                onTap: () => nav.goTo(DesktopRouteKey.settings),
              ),
              const SizedBox(height: 10),
              _QuickRow(
                icon: Icons.refresh_rounded,
                label: 'Refresh profile',
                onTap: onRefresh,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _ProfGlass(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: _ProfUi.lavender.withValues(alpha: 0.85),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Admin-managed fields',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _ProfUi.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Name, specialization, service category, and certifications are updated by your spa administrator.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  height: 1.5,
                  color: _ProfUi.textSecondary,
                ),
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
                  color: _ProfUi.textSecondary,
                ),
              ),
            ),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _ProfUi.textPrimary,
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

class _QuickRow extends StatefulWidget {
  const _QuickRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_QuickRow> createState() => _QuickRowState();
}

class _QuickRowState extends State<_QuickRow> {
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
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Colors.white.withValues(alpha: _hover ? 0.08 : 0.04),
              border: Border.all(
                color: _ProfUi.purple.withValues(alpha: _hover ? 0.4 : 0.18),
              ),
            ),
            child: Row(
              children: [
                Icon(widget.icon, color: _ProfUi.lavender, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.label,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      color: _ProfUi.textPrimary,
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

class _ProfileEmptyCard extends StatelessWidget {
  const _ProfileEmptyCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _ProfGlass(
        radius: _ProfUi.heroRadius,
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_off_outlined,
              size: 56,
              color: _ProfUi.lavender.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 18),
            Text(
              'Profile not found',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _ProfUi.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We could not load your therapist record. Try refreshing or contact your administrator.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: _ProfUi.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),
            OutlinedButton.icon(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: _ProfUi.textPrimary,
                side: BorderSide(color: _ProfUi.purple.withValues(alpha: 0.45)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                'Retry',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
