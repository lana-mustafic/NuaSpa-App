import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/api/media_url_resolver.dart';
import '../../core/api/services/api_service.dart';
import '../../core/auth/app_permissions.dart';
import '../../core/therapist/therapist_appointment_utils.dart';
import '../../core/therapist/therapist_service_eligibility.dart';
import '../../models/therapist/therapist_my_profile.dart';
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
  static const contentPadding = 32.0;
  static const teal = Color(0xFF2DD4BF);
}

class _ProfileInsights {
  const _ProfileInsights({
    required this.eligibleServices,
    required this.averageRating,
    required this.reviewCount,
    required this.allTimeCompletedSessions,
    required this.completedSessionsThisMonth,
    required this.memberSince,
    this.accountLinkedAt,
    this.nextAppointment,
  });

  final int eligibleServices;
  final double averageRating;
  final int reviewCount;
  final int allTimeCompletedSessions;
  final int completedSessionsThisMonth;
  final DateTime? memberSince;
  final DateTime? accountLinkedAt;
  final TherapistProfileNextAppointment? nextAppointment;
}

class _ProfileData {
  const _ProfileData({
    required this.profile,
    required this.insights,
    this.loginEmail,
    this.loadError,
  });

  final Zaposlenik profile;
  final _ProfileInsights insights;
  final String? loginEmail;
  final String? loadError;
}

final _phonePattern = RegExp(r'^\+?[0-9][0-9\s\-]{7,18}$');

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

int _profileCompleteness(Zaposlenik z, {String? loginEmail}) {
  var score = 0;
  if ((z.telefon ?? '').trim().isNotEmpty) score += 25;
  if ((z.jezici ?? '').trim().isNotEmpty) score += 25;
  if ((z.bio ?? '').trim().isNotEmpty) score += 25;
  final hasEmail = (z.email ?? '').trim().isNotEmpty ||
      (loginEmail ?? '').trim().isNotEmpty;
  if (hasEmail) score += 25;
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

String _nextAppointmentLabel(TherapistProfileNextAppointment? apt) {
  if (apt == null) return 'None scheduled';
  final when = TherapistAppointmentUtils.formatUpcomingDateTime(
    apt.datumRezervacije,
  );
  final service = (apt.uslugaNaziv ?? '').trim();
  if (service.isEmpty) return when;
  return '$when · $service';
}

List<String> _completionTips(Zaposlenik z, {String? loginEmail}) {
  final tips = <String>[];
  if ((z.telefon ?? '').trim().isEmpty) {
    tips.add('Add a phone number for client follow-ups.');
  }
  if ((z.jezici ?? '').trim().isEmpty) {
    tips.add('List the languages you offer sessions in.');
  }
  if ((z.bio ?? '').trim().isEmpty) {
    tips.add('Write a short About Me so clients can get to know you.');
  }
  if ((z.email ?? '').trim().isEmpty && (loginEmail ?? '').trim().isEmpty) {
    tips.add('Ask your administrator to link an email to your account.');
  }
  if (tips.isEmpty) {
    tips.add('Your profile looks great — keep your schedule up to date.');
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
  final _bio = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _sectionOverviewKey = GlobalKey();
  final _sectionAboutKey = GlobalKey();
  final _sectionContactKey = GlobalKey();
  final _sectionStaffKey = GlobalKey();
  Future<_ProfileData?>? _future;
  Zaposlenik? _loadedProfile;
  String? _loadedLoginEmail;
  String _originalTelefon = '';
  String _originalJezici = '';
  String _originalBio = '';
  int _lastRefreshToken = -1;
  int _lastSectionPulse = -1;
  String? _loadError;
  bool _saving = false;
  bool _uploadingAvatar = false;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  bool get _isDirty =>
      _telefon.text.trim() != _originalTelefon ||
      _jezici.text.trim() != _originalJezici ||
      _bio.text.trim() != _originalBio;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic);
    _telefon.addListener(_onFieldChanged);
    _jezici.addListener(_onFieldChanged);
    _bio.addListener(_onFieldChanged);
    _reload();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nav = context.read<DesktopNav>();
    final token = nav.therapistProfileRefresh;
    if (token != _lastRefreshToken) {
      _lastRefreshToken = token;
      if (token > 0) _reload();
    }

    final sectionPulse = nav.therapistProfileSectionPulse;
    if (sectionPulse != _lastSectionPulse) {
      _lastSectionPulse = sectionPulse;
      final section = nav.takeTherapistProfileSectionRequest();
      if (section != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scrollToSection(section);
        });
      }
    }
  }

  void _scrollToSection(TherapistProfileSection section) {
    final key = switch (section) {
      TherapistProfileSection.overview => _sectionOverviewKey,
      TherapistProfileSection.about => _sectionAboutKey,
      TherapistProfileSection.contact => _sectionContactKey,
      TherapistProfileSection.staffRecord => _sectionStaffKey,
    };
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      alignment: 0.04,
    );
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _telefon.removeListener(_onFieldChanged);
    _jezici.removeListener(_onFieldChanged);
    _bio.removeListener(_onFieldChanged);
    _telefon.dispose();
    _jezici.dispose();
    _bio.dispose();
    _scrollCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _bind(Zaposlenik z, {String? loginEmail}) {
    _telefon.text = z.telefon ?? '';
    _jezici.text = z.jezici ?? '';
    _bio.text = z.bio ?? '';
    _originalTelefon = _telefon.text.trim();
    _originalJezici = _jezici.text.trim();
    _originalBio = _bio.text.trim();
    _loadedProfile = z;
    _loadedLoginEmail = loginEmail;
  }

  void _updateHeader(Zaposlenik z, int completeness) {
    if (!mounted) return;
    context.read<DesktopNav>().setTherapistProfileHeader(
      title: 'My Profile',
      subtitle:
          '${z.fullName} · $completeness% complete · Manage your professional identity',
    );
  }

  Future<void> _reload() async {
    final auth = context.read<AuthProvider>();
    if (!AppPermissions.of(auth).has(AppPermission.viewOwnTherapistData)) {
      setState(() {
        _loadError = 'You do not have permission to view this profile.';
        _future = Future.value(null);
      });
      return;
    }
    setState(() {
      _loadError = null;
      _future = _loadProfile();
    });
  }

  Future<_ProfileData?> _loadProfile() async {
    final result = await _api.getTherapistMyProfile();
    if (!mounted) return null;

    if (result.accountNotLinked) {
      _loadError = result.error;
      return null;
    }
    final bundle = result.profile;
    if (bundle == null) {
      _loadError = result.error ?? 'Could not load your therapist profile.';
      return null;
    }

    final me = bundle.profile;
    final insights = _ProfileInsights(
      eligibleServices: bundle.eligibleServicesCount,
      averageRating: bundle.averageRating,
      reviewCount: bundle.reviewCount,
      allTimeCompletedSessions: bundle.allTimeCompletedSessions,
      completedSessionsThisMonth: bundle.completedSessionsThisMonth,
      memberSince: me.datumZaposlenja,
      accountLinkedAt: bundle.accountLinkedAt,
      nextAppointment: bundle.nextAppointment,
    );

    _bind(me, loginEmail: bundle.loginEmail);
    final completeness = _profileCompleteness(me, loginEmail: bundle.loginEmail);
    _updateHeader(me, completeness);

    return _ProfileData(
      profile: me,
      insights: insights,
      loginEmail: bundle.loginEmail,
      loadError: result.error,
    );
  }

  void _cancelEdits() {
    final original = _loadedProfile;
    if (original == null) return;
    _bind(original, loginEmail: _loadedLoginEmail);
    setState(() {});
  }

  Future<void> _pickAndUploadAvatar() async {
    if (_uploadingAvatar) return;
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: false,
    );
    final path = picked?.files.single.path;
    if (path == null || path.trim().isEmpty) return;

    setState(() => _uploadingAvatar = true);
    final updated = await _api.uploadTherapistAvatar(path);
    if (!mounted) return;
    setState(() => _uploadingAvatar = false);

    if (updated != null) {
      _bind(updated, loginEmail: _loadedLoginEmail);
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile photo updated.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not upload profile photo.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _save() async {
    final phone = _telefon.text.trim();
    final langs = _jezici.text.trim();
    final bio = _bio.text.trim();

    if (phone.isNotEmpty && !_phonePattern.hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid phone number.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (langs.length > 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Languages must be 200 characters or fewer.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (bio.length > 2000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('About Me must be 2000 characters or fewer.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final result = await _api.patchTherapistMe(
      telefon: phone.isEmpty ? '' : phone,
      jezici: langs.isEmpty ? '' : langs,
      bio: bio.isEmpty ? '' : bio,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (result.profile != null) {
      _bind(result.profile!, loginEmail: _loadedLoginEmail);
      _updateHeader(
        result.profile!,
        _profileCompleteness(
          result.profile!,
          loginEmail: _loadedLoginEmail,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _fadeCtrl.forward(from: 0);
      setState(() {});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Could not save profile.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!AppPermissions.of(auth).has(AppPermission.viewOwnTherapistData)) {
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
          if (snap.hasError) {
            return _ProfileEmptyCard(
              message: 'Something went wrong while loading your profile.',
              onRetry: _reload,
            );
          }
          final data = snap.data;
          if (data == null) {
            return _ProfileEmptyCard(
              message: _loadError ?? 'Profile not found.',
              onRetry: _reload,
            );
          }

          final z = data.profile;
          final insights = data.insights;
          final loginEmail = data.loginEmail;
          final completeness = _profileCompleteness(z, loginEmail: loginEmail);
          final tags = z.specijalizacija
              .split(RegExp(r'[,;/]'))
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();

          final main = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KeyedSubtree(
                key: _sectionOverviewKey,
                child: _HeroProfileCard(
                initials: therapistInitials(z),
                imageUrl: z.slikaUrl,
                uploadingAvatar: _uploadingAvatar,
                name: z.fullName,
                specialization: z.specijalizacija.trim().isEmpty
                    ? 'Therapist'
                    : z.specijalizacija,
                status: z.status,
                insights: insights,
                onAvatarTap: _pickAndUploadAvatar,
                ),
              ),
              const SizedBox(height: 16),
              KeyedSubtree(
                key: _sectionAboutKey,
                child: _AboutMeCard(controller: _bio),
              ),
              const SizedBox(height: _ProfUi.gap),
              KeyedSubtree(
                key: _sectionContactKey,
                child: _ProfGlass(
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
                      label: 'Staff email',
                      hint: 'On your spa record',
                      child: _ReadOnlyInputShell(
                        icon: Icons.mail_outline_rounded,
                        value: (z.email ?? '').trim().isEmpty
                            ? '—'
                            : z.email!,
                        locked: true,
                      ),
                    ),
                    if ((loginEmail ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _EditableField(
                        label: 'Login email',
                        hint: 'Used to sign in to NuaSpa',
                        child: _ReadOnlyInputShell(
                          icon: Icons.alternate_email_rounded,
                          value: loginEmail!,
                          locked: true,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    _ProfileActionBar(
                      saving: _saving,
                      canSave: _isDirty,
                      onCancel: _cancelEdits,
                      onSave: _save,
                    ),
                  ],
                ),
              ),
              ),
              const SizedBox(height: _ProfUi.gap),
              KeyedSubtree(
                key: _sectionStaffKey,
                child: _ProfGlass(
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
              ),
            ],
          );

          final sidebar = _ProfileSidebar(
            completeness: completeness,
            status: z.status,
            insights: insights,
            category: z.kategorijaUslugaNaziv,
            tips: _completionTips(z, loginEmail: loginEmail),
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
    this.imageUrl,
    this.uploadingAvatar = false,
  });

  final String initials;
  final String? imageUrl;
  final bool uploadingAvatar;
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
                imageUrl: imageUrl,
                uploading: uploadingAvatar,
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
                  value: '${insights.eligibleServices}',
                  label: 'Eligible Services',
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
                  value: '${insights.allTimeCompletedSessions}',
                  label: 'All-time Completed',
                  accent: _ProfUi.teal,
                ),
                _HeroStatCard(
                  icon: Icons.calendar_month_outlined,
                  value: _formatMemberSince(insights.memberSince),
                  label: 'Employed Since',
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
    this.imageUrl,
    this.uploading = false,
  });

  final String initials;
  final String? imageUrl;
  final bool uploading;
  final VoidCallback onTap;

  @override
  State<_AvatarWithEdit> createState() => _AvatarWithEditState();
}

class _AvatarWithEditState extends State<_AvatarWithEdit> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final resolved = resolveMediaUrl(widget.imageUrl);
    final hasImage = resolved.isNotEmpty;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.uploading ? null : widget.onTap,
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
                gradient: hasImage
                    ? null
                    : const LinearGradient(
                        colors: [_ProfUi.purple, _ProfUi.lavender],
                      ),
                image: hasImage
                    ? DecorationImage(
                        image: NetworkImage(resolved),
                        fit: BoxFit.cover,
                      )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: _ProfUi.purple.withValues(alpha: _hover ? 0.6 : 0.45),
                    blurRadius: _hover ? 36 : 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: widget.uploading
                  ? const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : hasImage
                  ? null
                  : Text(
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
  const _AboutMeCard({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return _ProfGlass(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
              Text(
                'About Me',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _ProfUi.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            minLines: 3,
            maxLines: 6,
            maxLength: 2000,
            style: LuxuryModalStyle.fieldStyle(context),
            decoration: LuxuryModalStyle.fieldDecoration(
              hint:
                  'Introduce yourself to clients — your approach, experience, and what makes your sessions special.',
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
    required this.canSave,
    required this.onCancel,
    required this.onSave,
  });

  final bool saving;
  final bool canSave;
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
            onPressed: saving || !canSave ? null : onCancel,
          ),
          _ActionButton(
            label: 'Save Changes',
            saving: saving,
            onPressed: saving || !canSave ? null : onSave,
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
    final nextLabel = _nextAppointmentLabel(insights.nextAppointment);

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
                icon: Icons.calendar_today_rounded,
                label: 'Completed This Month',
                value: '${insights.completedSessionsThisMonth}',
                accent: _ProfUi.teal,
              ),
              const SizedBox(height: 10),
              _InsightRow(
                icon: Icons.reviews_outlined,
                label: 'Client Reviews',
                value: insights.reviewCount == 0
                    ? 'No reviews yet'
                    : '${insights.reviewCount} · ${_formatRating(insights.averageRating)} avg',
                accent: _ProfUi.gold,
              ),
              const SizedBox(height: 10),
              _InsightRow(
                icon: Icons.event_available_rounded,
                label: 'Next Appointment',
                value: nextLabel,
                accent: _ProfUi.purple,
              ),
              if (insights.accountLinkedAt != null) ...[
                const SizedBox(height: 10),
                _InsightRow(
                  icon: Icons.verified_user_outlined,
                  label: 'Account Since',
                  value: _formatMemberSince(insights.accountLinkedAt),
                  accent: _ProfUi.lavender,
                ),
              ],
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
  const _ProfileEmptyCard({
    required this.onRetry,
    this.message = 'Profile not found',
  });

  final VoidCallback onRetry;
  final String message;

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
              message,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _ProfUi.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try refreshing or contact your spa administrator if the problem continues.',
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
