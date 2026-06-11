import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/api/services/api_service.dart';
import '../../core/auth/app_permissions.dart';
import '../../core/therapist/therapist_appointment_utils.dart';
import '../../core/therapist/therapist_service_eligibility.dart';
import '../../models/therapist/therapist_appointments_list.dart';
import '../../models/zaposlenik.dart';
import '../../models/zaposlenik_status.dart';
import '../../providers/auth_provider.dart';
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
  static const contentPadding = 32.0;
  static const teal = Color(0xFF2DD4BF);
}

class _ProfileInsights {
  const _ProfileInsights({
    required this.certifiedServices,
    required this.averageRating,
    required this.completedSessions,
    required this.memberSince,
    this.nextAppointment,
  });

  final int certifiedServices;
  final double averageRating;
  final int completedSessions;
  final DateTime? memberSince;
  final TherapistAppointmentRow? nextAppointment;
}

class _ProfileData {
  const _ProfileData({
    required this.profile,
    required this.insights,
  });

  final Zaposlenik profile;
  final _ProfileInsights insights;
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

String _formatMemberSince(DateTime? d) {
  if (d == null) return '—';
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
  final loc = d.toLocal();
  return '${months[loc.month - 1]} ${loc.year}';
}

String _formatRating(double rating) {
  if (rating <= 0) return '—';
  return rating.toStringAsFixed(1);
}

String _therapistBio(Zaposlenik z) {
  final parts = <String>[];
  final spec = z.specijalizacija.trim();
  if (spec.isNotEmpty) {
    parts.add(
      'Licensed therapist specializing in $spec, dedicated to personalized wellness experiences.',
    );
  }
  final edu = (z.obrazovanje ?? '').trim();
  if (edu.isNotEmpty) parts.add(edu);
  final langs = (z.jezici ?? '').trim();
  if (langs.isNotEmpty) {
    parts.add('Sessions available in $langs.');
  }
  final loc = (z.lokacija ?? '').trim();
  if (loc.isNotEmpty) parts.add('Based at $loc.');
  if (parts.isEmpty) {
    return 'Welcome to your NuaSpa therapist profile. Add your contact details and languages so clients can get to know you better.';
  }
  return parts.join(' ');
}

List<String> _completionTips(Zaposlenik z) {
  final tips = <String>[];
  if ((z.telefon ?? '').trim().isEmpty) {
    tips.add('Add a phone number for client follow-ups.');
  }
  if ((z.jezici ?? '').trim().isEmpty) {
    tips.add('List the languages you offer sessions in.');
  }
  if ((z.email ?? '').trim().isEmpty) {
    tips.add('Ask your administrator to link an email to your account.');
  }
  if (z.specijalizacija.trim().isEmpty) {
    tips.add('Your specialization is set by your spa administrator.');
  }
  if (tips.isEmpty) {
    tips.add('Your profile is complete — keep your schedule up to date.');
  }
  return tips;
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
  Zaposlenik? _loadedProfile;
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
        final result = await _api.getTherapistMyServices();
        final me = result.therapist;
        if (me == null) return null;

        final reviewsResult = await _api.getTherapistMyReviewsSummary();
        final (completedList, _) = await _api.getTherapistAppointments(
          tab: 'completed',
          page: 1,
          pageSize: 1,
        );
        final (upcomingList, _) = await _api.getTherapistAppointments(
          tab: 'upcoming',
          page: 1,
          pageSize: 1,
        );

        final insights = _ProfileInsights(
          certifiedServices: result.services.length,
          averageRating: reviewsResult.summary?.averageRating ?? 0,
          completedSessions: completedList?.completedCount ?? 0,
          memberSince: me.datumZaposlenja,
          nextAppointment: upcomingList?.nextAppointment,
        );

        _bind(me);
        _loadedProfile = me;
        return _ProfileData(profile: me, insights: insights);
      }();
    });
  }

  void _cancelEdits() {
    final original = _loadedProfile;
    if (original == null) return;
    _bind(original);
    setState(() {});
  }

  void _showAvatarHint() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile photo upload will be available soon.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
          final insights = data.insights;
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
                initials: therapistInitials(z),
                name: z.fullName,
                specialization: z.specijalizacija.trim().isEmpty
                    ? 'Therapist'
                    : z.specijalizacija,
                status: z.status,
                insights: insights,
                onAvatarTap: _showAvatarHint,
              ),
              const SizedBox(height: 16),
              _AboutMeCard(bio: _therapistBio(z)),
              const SizedBox(height: _ProfUi.gap),
              _ProfGlass(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SectionHeader(
                      icon: Icons.edit_note_rounded,
                      title: 'Contact details',
                      subtitle:
                          'Update the information clients and your spa can reach you with.',
                    ),
                    const SizedBox(height: 22),
                    LayoutBuilder(
                      builder: (context, c) {
                        final twoCol = c.maxWidth >= 520;
                        final phoneField = _EditableField(
                          label: 'Phone',
                          child: TextField(
                            controller: _telefon,
                            style: LuxuryModalStyle.fieldStyle(context),
                            decoration: LuxuryModalStyle.fieldDecoration(
                              hint: 'e.g. +385 91 234 5678',
                              prefixIcon: Icon(
                                Icons.phone_outlined,
                                color:
                                    _ProfUi.lavender.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                        );
                        final languagesField = _EditableField(
                          label: 'Languages',
                          child: TextField(
                            controller: _jezici,
                            style: LuxuryModalStyle.fieldStyle(context),
                            decoration: LuxuryModalStyle.fieldDecoration(
                              hint: 'e.g. English, Croatian',
                              prefixIcon: Icon(
                                Icons.translate_rounded,
                                color:
                                    _ProfUi.lavender.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                        );
                        if (twoCol) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: phoneField),
                              const SizedBox(width: 16),
                              Expanded(child: languagesField),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            phoneField,
                            const SizedBox(height: 18),
                            languagesField,
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    _EditableField(
                      label: 'Email',
                      hint: 'Managed by your spa administrator',
                      child: _ReadOnlyInputShell(
                        icon: Icons.mail_outline_rounded,
                        value: (z.email ?? '').trim().isEmpty
                            ? '—'
                            : z.email!,
                        locked: true,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _ProfileActionBar(
                      saving: _saving,
                      onCancel: _cancelEdits,
                      onSave: _save,
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
            insights: insights,
            category: z.kategorijaUslugaNaziv,
            tips: _completionTips(z),
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
                            Expanded(flex: 3, child: main),
                            const SizedBox(width: _ProfUi.gap),
                            Expanded(flex: 1, child: sidebar),
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
    required this.insights,
    required this.onAvatarTap,
  });

  final String initials;
  final String name;
  final String specialization;
  final ZaposlenikStatus status;
  final _ProfileInsights insights;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(status);
    return _ProfGlass(
      radius: _ProfUi.heroRadius,
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AvatarWithEdit(
                initials: initials,
                onTap: onAvatarTap,
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: _ProfUi.textPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
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
                        _HeroChip(label: status.label, color: statusColor),
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
                size: 48,
                color: _ProfUi.purple.withValues(alpha: 0.22),
              ),
            ],
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, c) {
              final compact = c.maxWidth < 640;
              final stats = [
                _HeroStatCard(
                  icon: Icons.spa_outlined,
                  value: '${insights.certifiedServices}',
                  label: 'Certified Services',
                  accent: _ProfUi.lavender,
                ),
                _HeroStatCard(
                  icon: Icons.star_rounded,
                  value: _formatRating(insights.averageRating),
                  label: 'Average Rating',
                  accent: _ProfUi.gold,
                ),
                _HeroStatCard(
                  icon: Icons.check_circle_outline_rounded,
                  value: '${insights.completedSessions}',
                  label: 'Completed Sessions',
                  accent: _ProfUi.teal,
                ),
                _HeroStatCard(
                  icon: Icons.calendar_month_outlined,
                  value: _formatMemberSince(insights.memberSince),
                  label: 'Member Since',
                  accent: _ProfUi.purple,
                ),
              ];
              if (compact) {
                return Column(
                  children: [
                    for (var i = 0; i < stats.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      stats[i],
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  for (var i = 0; i < stats.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(child: stats[i]),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AvatarWithEdit extends StatefulWidget {
  const _AvatarWithEdit({
    required this.initials,
    required this.onTap,
  });

  final String initials;
  final VoidCallback onTap;

  @override
  State<_AvatarWithEdit> createState() => _AvatarWithEditState();
}

class _AvatarWithEditState extends State<_AvatarWithEdit> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
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
                    color: _ProfUi.purple.withValues(alpha: _hover ? 0.6 : 0.45),
                    blurRadius: _hover ? 36 : 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Text(
                widget.initials,
                style: GoogleFonts.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [_ProfUi.purple, _ProfUi.lavender],
                  ),
                  border: Border.all(
                    color: const Color(0xFF120A24),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroStatCard extends StatelessWidget {
  const _HeroStatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: accent.withValues(alpha: 0.16),
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: _ProfUi.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _ProfUi.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutMeCard extends StatelessWidget {
  const _AboutMeCard({required this.bio});

  final String bio;

  @override
  Widget build(BuildContext context) {
    return _ProfGlass(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                colors: [
                  _ProfUi.purple.withValues(alpha: 0.3),
                  _ProfUi.lavender.withValues(alpha: 0.15),
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: const Icon(
              Icons.person_pin_rounded,
              color: _ProfUi.lavender,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About Me',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _ProfUi.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  bio,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.55,
                    color: _ProfUi.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
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

class _EditableField extends StatelessWidget {
  const _EditableField({
    required this.label,
    required this.child,
    this.hint,
  });

  final String label;
  final Widget child;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _ProfUi.textPrimary,
                letterSpacing: 0.2,
              ),
            ),
            if (hint != null) ...[
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hint!,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: _ProfUi.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _ReadOnlyInputShell extends StatelessWidget {
  const _ReadOnlyInputShell({
    required this.icon,
    required this.value,
    this.locked = false,
  });

  final IconData icon;
  final String value;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: _ProfUi.lavender.withValues(alpha: 0.55)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: _ProfUi.textSecondary,
              ),
            ),
          ),
          if (locked)
            Icon(
              Icons.lock_outline_rounded,
              size: 16,
              color: Colors.white.withValues(alpha: 0.3),
            ),
        ],
      ),
    );
  }
}

class _ProfileActionBar extends StatelessWidget {
  const _ProfileActionBar({
    required this.saving,
    required this.onCancel,
    required this.onSave,
  });

  final bool saving;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        alignment: WrapAlignment.end,
        children: [
          _ActionButton(
            label: 'Cancel',
            outlined: true,
            onPressed: saving ? null : onCancel,
          ),
          _ActionButton(
            label: 'Save Changes',
            saving: saving,
            onPressed: saving ? null : onSave,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.label,
    required this.onPressed,
    this.outlined = false,
    this.saving = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool outlined;
  final bool saving;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: widget.outlined
                  ? null
                  : const LinearGradient(
                      colors: [_ProfUi.purple, _ProfUi.lavender],
                    ),
              color: widget.outlined
                  ? Colors.white.withValues(alpha: _hover ? 0.08 : 0.04)
                  : null,
              border: widget.outlined
                  ? Border.all(
                      color: _ProfUi.purple.withValues(alpha: _hover ? 0.5 : 0.3),
                    )
                  : null,
              boxShadow: !widget.outlined && _hover && enabled
                  ? [
                      BoxShadow(
                        color: _ProfUi.purple.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: widget.saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      widget.label,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: widget.outlined
                            ? _ProfUi.textPrimary
                            : Colors.white,
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
    required this.insights,
    required this.category,
    required this.tips,
    required this.onRefresh,
  });

  final int completeness;
  final ZaposlenikStatus status;
  final _ProfileInsights insights;
  final String? category;
  final List<String> tips;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(status);
    final catLabel =
        (category ?? '').trim().isEmpty ? 'Not assigned' : category!;
    final nextLabel = insights.nextAppointment == null
        ? 'None scheduled'
        : TherapistAppointmentUtils.formatUpcomingDateTime(
            insights.nextAppointment!.datumRezervacije,
          );

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
              const SizedBox(height: 20),
              _ProfileProgressWidget(percent: completeness),
              const SizedBox(height: 20),
              _HighlightedStatusRow(
                label: 'Account status',
                value: status.label,
                color: statusColor,
              ),
              const SizedBox(height: 12),
              _HighlightedStatusRow(
                label: 'Service category',
                value: catLabel,
                color: catLabel == 'Not assigned'
                    ? _ProfUi.orange
                    : _ProfUi.lavender,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _ProfGlass(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Quick Insights',
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _ProfUi.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onRefresh,
                    tooltip: 'Refresh',
                    icon: Icon(
                      Icons.refresh_rounded,
                      size: 20,
                      color: _ProfUi.lavender.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _InsightRow(
                icon: Icons.check_circle_outline_rounded,
                label: 'Completed Sessions',
                value: '${insights.completedSessions}',
                accent: _ProfUi.teal,
              ),
              const SizedBox(height: 10),
              _InsightRow(
                icon: Icons.star_rounded,
                label: 'Average Rating',
                value: _formatRating(insights.averageRating),
                accent: _ProfUi.gold,
              ),
              const SizedBox(height: 10),
              _InsightRow(
                icon: Icons.spa_outlined,
                label: 'Certified Services',
                value: '${insights.certifiedServices}',
                accent: _ProfUi.lavender,
              ),
              const SizedBox(height: 10),
              _InsightRow(
                icon: Icons.event_available_rounded,
                label: 'Next Appointment',
                value: nextLabel,
                accent: _ProfUi.purple,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _ProfGlass(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profile Completion Tips',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _ProfUi.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              for (final tip in tips) ...[
                _TipRow(text: tip),
                if (tip != tips.last) const SizedBox(height: 10),
              ],
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

class _ProfileProgressWidget extends StatelessWidget {
  const _ProfileProgressWidget({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    final progress = (percent / 100).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _ProfUi.purple.withValues(alpha: 0.14),
            _ProfUi.lavender.withValues(alpha: 0.06),
          ],
        ),
        border: Border.all(color: _ProfUi.purple.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$percent%',
                style: GoogleFonts.inter(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: _ProfUi.textPrimary,
                  height: 1,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Profile Complete',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _ProfUi.lavender,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 10,
              child: Stack(
                children: [
                  Container(color: Colors.white.withValues(alpha: 0.08)),
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_ProfUi.purple, _ProfUi.lavender],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HighlightedStatusRow extends StatelessWidget {
  const _HighlightedStatusRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: _ProfUi.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              color: accent.withValues(alpha: 0.14),
            ),
            child: Icon(icon, size: 17, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: _ProfUi.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _ProfUi.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  const _TipRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.lightbulb_outline_rounded,
          size: 16,
          color: _ProfUi.gold.withValues(alpha: 0.85),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              height: 1.45,
              color: _ProfUi.textSecondary,
            ),
          ),
        ),
      ],
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
