import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/services/api_service.dart';
import '../../core/format/km_format.dart';
import '../../models/admin/therapist_account_status.dart';
import '../../models/admin/therapist_admin_profile.dart';
import '../../models/admin/therapist_kpi.dart';
import '../../models/admin/therapist_top_service.dart';
import '../../models/admin/therapist_weekly_schedule_day.dart';
import '../../models/rezervacija.dart';
import '../../models/usluga.dart';
import '../../models/zaposlenik.dart';
import '../../models/zaposlenik_status.dart';
import '../catalog/service_details_screen.dart';
import 'widgets/admin_therapist_editor_dialog.dart';
import 'widgets/admin_therapist_portal_access_card.dart';

class _TherapistScreenBundle {
  const _TherapistScreenBundle({
    required this.profile,
    required this.accountStatus,
    this.profileError,
    this.accountError,
  });

  final TherapistAdminProfile? profile;
  final TherapistAccountStatus? accountStatus;
  final String? profileError;
  final String? accountError;

  bool get profileLoaded => profile != null;
}

/// Simplified luxury therapist profile — overview-focused layout.
class AdminTherapistProfileScreen extends StatefulWidget {
  const AdminTherapistProfileScreen({super.key, required this.therapist});

  final Zaposlenik therapist;

  @override
  State<AdminTherapistProfileScreen> createState() =>
      _AdminTherapistProfileScreenState();
}

enum _ProfileTab {
  overview,
  schedule,
  appointments,
  services,
  reviews,
  notes,
}

abstract final class _ProfileUi {
  static const Color bgDeep = Color(0xFF07040F);
  static const Color bgMid = Color(0xFF120A24);
  static const Color textPrimary = Color(0xFFF5F3FA);
  static const Color textSecondary = Color(0xA6FFFFFF);
  static const Color accentPurple = Color(0xFF7B4DFF);
  static const Color accentSecondary = Color(0xFF9D6BFF);
  static const Color success = Color(0xFF4ADE80);
  static const Color danger = Color(0xFFFF5E7A);

  static TextStyle title(BuildContext context) => GoogleFonts.inter(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: textPrimary,
      );

  static TextStyle cardTitle(BuildContext context) => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      );

  static TextStyle bodyMuted(BuildContext context) => GoogleFonts.inter(
        fontSize: 13.5,
        height: 1.45,
        color: textSecondary,
      );
}

class _AdminTherapistProfileScreenState extends State<AdminTherapistProfileScreen> {
  final ApiService _api = ApiService();
  _ProfileTab _tab = _ProfileTab.overview;
  late Zaposlenik _therapist = widget.therapist;
  int _kpiPeriodDays = 30;
  Future<_TherapistScreenBundle>? _bundleFuture;

  static DateTime _mondayOf(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    final diff = (day.weekday + 6) % 7;
    return day.subtract(Duration(days: diff));
  }

  @override
  void initState() {
    super.initState();
    _bundleFuture = _loadBundle();
  }

  void _reload() {
    setState(() {
      _bundleFuture = _loadBundle();
    });
  }

  Future<_TherapistScreenBundle> _loadBundle() async {
    final now = DateTime.now();
    final toD = DateTime(now.year, now.month, now.day);
    final fromD = toD.subtract(Duration(days: _kpiPeriodDays - 1));
    final weekStart = _mondayOf(toD);

    final results = await Future.wait([
      _api.getTherapistAdminProfile(
        zaposlenikId: _therapist.id,
        from: fromD,
        to: toD,
        weekStart: weekStart,
      ),
      _api.getTherapistAccountStatus(_therapist.id),
    ]);

    final profileResult = results[0] as ({TherapistAdminProfile? data, String? error});
    final accountResult =
        results[1] as ({TherapistAccountStatus? data, String? error});

    return _TherapistScreenBundle(
      profile: profileResult.data,
      profileError: profileResult.error,
      accountStatus: accountResult.data,
      accountError: accountResult.error,
    );
  }

  void _setKpiPeriod(int days) {
    if (_kpiPeriodDays == days) return;
    setState(() {
      _kpiPeriodDays = days;
      _bundleFuture = _loadBundle();
    });
  }

  Future<void> _editProfile() async {
    final editorResult = await showAdminTherapistEditorDialog(
      context,
      existing: _therapist,
    );
    if (!mounted || editorResult == null) return;
    final save = await _api.updateZaposlenik(editorResult.therapist);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          save.error ??
              (save.therapist == null
                  ? 'Failed to save profile.'
                  : 'Therapist profile updated.'),
        ),
      ),
    );
    if (save.therapist != null) {
      setState(() => _therapist = save.therapist!);
      _reload();
    }
  }

  String _shortDate(DateTime d) {
    final x = d.toLocal();
    return '${x.day.toString().padLeft(2, '0')}.'
        '${x.month.toString().padLeft(2, '0')}.'
        '${x.year}';
  }

  List<String> _tags(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return const [];
    return t
        .split(RegExp(r'[,;/]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(6)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_ProfileUi.bgDeep, _ProfileUi.bgMid],
          ),
        ),
        child: FutureBuilder<_TherapistScreenBundle>(
        future: _bundleFuture,
        builder: (context, snap) {
          final bundle = snap.data;
          final profile = bundle?.profile;
          final profileError = bundle?.profileError;
          final accountStatus = bundle?.accountStatus;
          final accountError = bundle?.accountError;
          final kpi = profile?.kpi;
          final schedule = profile?.sedmicniRaspored ?? const [];
          final topServices = profile?.topUsluge ?? const [];
          final t = profile?.terapeut ?? _therapist;
          final name = '${t.ime} ${t.prezime}'.trim();
          final tags = _tags(t.specijalizacija);
          final role = profile?.uloga ?? kpi?.uloga ?? 'Therapist';
          final location = profile?.lokacijaPrikaz?.trim();
          final loading = snap.connectionState == ConnectionState.waiting;
          final profileFailed = !loading && profile == null && profileError != null;

          final reviewCount = profile?.nedavneRecenzije.length;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _BackLink(onTap: () => Navigator.pop(context)),
                const SizedBox(height: 12),
                _PageTopBar(onEdit: _editProfile, onRefresh: _reload),
                const SizedBox(height: 14),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: _ProfileUi.accentPurple,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                else if (profileFailed)
                  _ProfileErrorState(
                    message: profileError,
                    therapistName: name,
                    onRetry: _reload,
                  )
                else ...[
                  if (profileError != null)
                    _InlineWarningBanner(message: profileError),
                  if (accountError != null) ...[
                    const SizedBox(height: 12),
                    _InlineWarningBanner(message: accountError),
                  ],
                  _HeroCard(
                    name: name,
                    role: role,
                    therapist: t,
                    linkedEmail: profile?.povezanEmail,
                    location: location,
                    tags: tags,
                    kpi: kpi,
                    schedule: schedule,
                  ),
                  const SizedBox(height: 14),
                  _TabRow(
                    selected: _tab,
                    reviewCount: reviewCount,
                    onSelect: (tab) => setState(() => _tab = tab),
                  ),
                  const SizedBox(height: 16),
                  if (_tab == _ProfileTab.overview)
                    _OverviewSection(
                      therapist: t,
                      profile: profile,
                      kpi: kpi,
                      kpiPeriodDays: _kpiPeriodDays,
                      onKpiPeriodChanged: _setKpiPeriod,
                      schedule: schedule,
                      topServices: topServices,
                      accountStatus: accountStatus,
                      accountError: accountError,
                      onPortalChanged: _reload,
                      onEdit: _editProfile,
                      onNavigateTab: (tab) => setState(() => _tab = tab),
                    )
                  else if (_tab == _ProfileTab.schedule)
                    _ScheduleTabPanel(schedule: schedule)
                  else if (_tab == _ProfileTab.appointments)
                    _TherapistAppointmentsPanel(
                      api: _api,
                      zaposlenikId: t.id,
                    )
                  else if (_tab == _ProfileTab.reviews)
                    _ReviewsPanel(
                      reviews: profile?.nedavneRecenzije ?? const [],
                      formatDate: _shortDate,
                    )
                  else if (_tab == _ProfileTab.notes)
                    _InternaNapomenaPanel(
                      api: _api,
                      zaposlenikId: t.id,
                      profile: profile,
                      onSaved: _reload,
                      onInvitePortal: () => setState(() => _tab = _ProfileTab.overview),
                    )
                  else if (_tab == _ProfileTab.services)
                    _TherapistServicesPanel(
                      api: _api,
                      therapist: t,
                    ),
                ],
              ],
            ),
          );
        },
        ),
      ),
    );
  }
}

class _ProfileErrorState extends StatelessWidget {
  const _ProfileErrorState({
    required this.message,
    required this.therapistName,
    required this.onRetry,
  });

  final String message;
  final String therapistName;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Could not load profile',
            style: _ProfileUi.cardTitle(context),
          ),
          const SizedBox(height: 8),
          Text(
            therapistName,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _ProfileUi.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(message, style: _ProfileUi.bodyMuted(context)),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: _PurpleButton(label: 'Retry', onPressed: onRetry),
          ),
        ],
      ),
    );
  }
}

class _InlineWarningBanner extends StatelessWidget {
  const _InlineWarningBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF5B942).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFF5B942).withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 20,
              color: Color(0xFFF5B942),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.4,
                  color: _ProfileUi.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackLink extends StatelessWidget {
  const _BackLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: _ProfileUi.textSecondary,
          padding: EdgeInsets.zero,
        ),
        icon: const Icon(Icons.chevron_left_rounded, size: 22),
        label: Text(
          'Back to Therapists',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _PageTopBar extends StatelessWidget {
  const _PageTopBar({required this.onEdit, required this.onRefresh});

  final VoidCallback onEdit;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Therapist Profile',
            style: _ProfileUi.title(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        _PurpleButton(label: 'Edit Profile', onPressed: onEdit),
        const SizedBox(width: 10),
        _IconSquareButton(
          icon: Icons.more_horiz_rounded,
          onPressed: () {},
          menuItems: const [
            ('refresh', 'Refresh data'),
          ],
          onMenu: (v) {
            if (v == 'refresh') onRefresh();
          },
        ),
      ],
    );
  }
}

class _PurpleButton extends StatefulWidget {
  const _PurpleButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  State<_PurpleButton> createState() => _PurpleButtonState();
}

class _PurpleButtonState extends State<_PurpleButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: _hover
                  ? [_ProfileUi.accentSecondary, _ProfileUi.accentPurple]
                  : [_ProfileUi.accentPurple, _ProfileUi.accentSecondary],
            ),
            boxShadow: [
              BoxShadow(
                color: _ProfileUi.accentPurple.withValues(alpha: _hover ? 0.4 : 0.28),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Text(
            widget.label,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _IconSquareButton extends StatelessWidget {
  const _IconSquareButton({
    required this.icon,
    required this.onPressed,
    this.menuItems,
    this.onMenu,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final List<(String, String)>? menuItems;
  final void Function(String)? onMenu;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 22),
    );

    if (menuItems != null && onMenu != null) {
      return Material(
        color: Colors.transparent,
        child: PopupMenuButton<String>(
          tooltip: 'More',
          offset: const Offset(0, 44),
          color: _ProfileUi.bgMid,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          onSelected: onMenu,
          itemBuilder: (_) => [
            for (final item in menuItems!)
              PopupMenuItem(
                value: item.$1,
                child: Text(
                  item.$2,
                  style: GoogleFonts.inter(color: _ProfileUi.textPrimary),
                ),
              ),
          ],
          child: child,
        ),
      );
    }

    return GestureDetector(onTap: onPressed, child: child);
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.name,
    required this.role,
    required this.therapist,
    required this.tags,
    this.linkedEmail,
    this.location,
    this.kpi,
    this.schedule = const [],
  });

  final String name;
  final String role;
  final Zaposlenik therapist;
  final List<String> tags;
  final String? linkedEmail;
  final String? location;
  final TherapistKpi? kpi;
  final List<TherapistWeeklyScheduleDay> schedule;

  @override
  Widget build(BuildContext context) {
    final contactEmail = _contactEmail(therapist, linkedEmail);
    final initials =
        '${therapist.ime.isNotEmpty ? therapist.ime[0] : ''}'
        '${therapist.prezime.isNotEmpty ? therapist.prezime[0] : ''}'
        .toUpperCase();
    final rating = (kpi?.prosjecnaOcjena ?? 0) > 0 ? kpi!.prosjecnaOcjena : 0.0;
    final weekDays = schedule.where((d) => d.isWorking).length;
    final loc = location?.trim().isNotEmpty == true ? location!.trim() : null;

    final metaParts = <String>[
      if (contactEmail != '—') contactEmail,
      if (loc != null) loc,
    ];
    final metaLine = metaParts.isEmpty ? '—' : metaParts.join(' · ');

    return _GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      borderRadius: 18,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 120, maxHeight: 180),
        child: LayoutBuilder(
          builder: (context, c) {
            final narrow = c.maxWidth < 860;
            final avatar = _Avatar(
              initials: initials.isEmpty ? '?' : initials,
              status: therapist.status,
              size: 56,
            );

            final center = Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _ProfileUi.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '$role · ${therapist.status.label}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _ProfileUi.bodyMuted(context).copyWith(
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    metaLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: _ProfileUi.textSecondary,
                    ),
                  ),
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final tag in tags.take(4))
                          _SpecPill(label: tag, compact: true),
                        if (tags.length > 4)
                          _SpecPill(label: '+${tags.length - 4}', compact: true),
                      ],
                    ),
                  ],
                ],
              ),
            );

            final stats = Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _EmploymentStatusBadge(status: therapist.status),
                if (rating > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...List.generate(
                        5,
                        (i) => Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: i < rating.round()
                              ? const Color(0xFFF5B942)
                              : Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        rating.toStringAsFixed(1),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _ProfileUi.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
                if (schedule.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    weekDays > 0
                        ? '$weekDays days scheduled this week'
                        : 'No days scheduled this week',
                    style: _ProfileUi.bodyMuted(context).copyWith(fontSize: 11),
                    textAlign: TextAlign.end,
                  ),
                ],
              ],
            );

            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [avatar, const SizedBox(width: 14), center],
                  ),
                  const SizedBox(height: 10),
                  Align(alignment: Alignment.centerLeft, child: stats),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                avatar,
                const SizedBox(width: 16),
                center,
                const SizedBox(width: 12),
                stats,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EmploymentStatusBadge extends StatelessWidget {
  const _EmploymentStatusBadge({required this.status});

  final ZaposlenikStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (status) {
      ZaposlenikStatus.active => (
          const Color(0xFF6EE7B7).withValues(alpha: 0.14),
          const Color(0xFF6EE7B7),
          const Color(0xFF6EE7B7).withValues(alpha: 0.35),
        ),
      ZaposlenikStatus.onLeave => (
          const Color(0xFFE8C872).withValues(alpha: 0.14),
          const Color(0xFFE8C872),
          const Color(0xFFE8C872).withValues(alpha: 0.35),
        ),
      ZaposlenikStatus.inactive => (
          const Color(0xFFF87171).withValues(alpha: 0.12),
          const Color(0xFFF87171),
          const Color(0xFFF87171).withValues(alpha: 0.32),
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        status.label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.initials,
    required this.status,
    this.size = 56,
  });

  final String initials;
  final ZaposlenikStatus status;
  final double size;

  Color get _dotColor => switch (status) {
        ZaposlenikStatus.active => _ProfileUi.success,
        ZaposlenikStatus.onLeave => const Color(0xFFF5B942),
        ZaposlenikStatus.inactive => _ProfileUi.danger,
      };

  @override
  Widget build(BuildContext context) {
    final fontSize = size * 0.38;
    final dot = size * 0.16;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF7B4DFF),
                Color(0xFF9D6BFF),
                Color(0xFFC8B6E8),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: _ProfileUi.accentPurple.withValues(alpha: 0.28),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            initials,
            style: GoogleFonts.inter(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        Positioned(
          right: 2,
          bottom: 2,
          child: Container(
            width: dot,
            height: dot,
            decoration: BoxDecoration(
              color: _dotColor,
              shape: BoxShape.circle,
              border: Border.all(color: _ProfileUi.bgDeep, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _SpecPill extends StatelessWidget {
  const _SpecPill({required this.label, this.compact = false});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 3 : 6,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: _ProfileUi.accentPurple.withValues(alpha: 0.16),
        border: Border.all(
          color: _ProfileUi.accentPurple.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: compact ? 11 : 12.5,
          fontWeight: FontWeight.w600,
          color: _ProfileUi.textPrimary,
        ),
      ),
    );
  }
}

class _TabRow extends StatelessWidget {
  const _TabRow({
    required this.selected,
    required this.onSelect,
    this.reviewCount,
  });

  final _ProfileTab selected;
  final ValueChanged<_ProfileTab> onSelect;
  final int? reviewCount;

  static const _tabs = _ProfileTab.values;

  String _label(_ProfileTab t) {
    final base = switch (t) {
      _ProfileTab.overview => 'Overview',
      _ProfileTab.schedule => 'Schedule',
      _ProfileTab.appointments => 'Appointments',
      _ProfileTab.services => 'Services',
      _ProfileTab.reviews => 'Client Reviews',
      _ProfileTab.notes => 'Notes',
    };
    if (t == _ProfileTab.reviews && reviewCount != null) {
      return '$base ($reviewCount)';
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final tab in _tabs) ...[
              _TabItem(
                label: _label(tab),
                selected: selected == tab,
                onTap: () => onSelect(tab),
              ),
              const SizedBox(width: 20),
            ],
          ],
        ),
      ),
    );
  }
}

class _TabItem extends StatefulWidget {
  const _TabItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_TabItem> createState() => _TabItemState();
}

class _TabItemState extends State<_TabItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.selected
        ? _ProfileUi.textPrimary
        : (_hover
            ? _ProfileUi.accentSecondary.withValues(alpha: 0.95)
            : _ProfileUi.textSecondary);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  widget.label,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 2,
                decoration: BoxDecoration(
                  color: widget.selected
                      ? _ProfileUi.accentPurple
                      : (_hover
                          ? _ProfileUi.accentPurple.withValues(alpha: 0.35)
                          : Colors.transparent),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: widget.selected
                      ? [
                          BoxShadow(
                            color:
                                _ProfileUi.accentPurple.withValues(alpha: 0.45),
                            blurRadius: 6,
                          ),
                        ]
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _contactEmail(Zaposlenik therapist, String? linkedEmail) {
  final stored = therapist.email?.trim();
  if (stored != null && stored.isNotEmpty) return stored;
  final linked = linkedEmail?.trim();
  if (linked != null && linked.isNotEmpty) return linked;
  return '—';
}

class _OverviewSection extends StatelessWidget {
  const _OverviewSection({
    required this.therapist,
    required this.profile,
    required this.kpi,
    required this.kpiPeriodDays,
    required this.onKpiPeriodChanged,
    required this.schedule,
    required this.topServices,
    required this.accountStatus,
    this.accountError,
    required this.onPortalChanged,
    required this.onEdit,
    required this.onNavigateTab,
  });

  final Zaposlenik therapist;
  final TherapistAdminProfile? profile;
  final TherapistKpi? kpi;
  final int kpiPeriodDays;
  final ValueChanged<int> onKpiPeriodChanged;
  final List<TherapistWeeklyScheduleDay> schedule;
  final List<TherapistTopService> topServices;
  final TherapistAccountStatus? accountStatus;
  final String? accountError;
  final VoidCallback onPortalChanged;
  final VoidCallback onEdit;
  final ValueChanged<_ProfileTab> onNavigateTab;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final cols = w >= 1100 ? 3 : (w >= 720 ? 2 : 1);
        final gap = 14.0;

        Widget gridRow(List<Widget> children) {
          if (cols == 1) {
            return Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) SizedBox(height: gap),
                  children[i],
                ],
              ],
            );
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) SizedBox(width: gap),
                  Expanded(child: children[i]),
                ],
              ],
            ),
          );
        }

        final mainCards = [
          _AboutCard(therapist: therapist, profile: profile),
          _WeekScheduleListCard(schedule: schedule),
          _PerformanceSummaryCard(
            kpi: kpi,
            periodDays: kpiPeriodDays,
            onPeriodChanged: onKpiPeriodChanged,
          ),
        ];

        final secondaryCards = [
          AdminTherapistPortalAccessCard(
            therapist: therapist,
            accountStatus: accountStatus,
            accountError: accountError,
            onChanged: onPortalChanged,
            compact: true,
          ),
          _QuickActionsCard(
            onEdit: onEdit,
            onNavigateTab: onNavigateTab,
          ),
          _LastActivityCard(
            schedule: schedule,
            reviews: profile?.nedavneRecenzije ?? const [],
          ),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _OverviewKpiStrip(
              kpi: kpi,
              schedule: schedule,
              periodDays: kpiPeriodDays,
            ),
            SizedBox(height: gap),
            if (cols >= 3)
              gridRow(mainCards)
            else ...[
              gridRow(mainCards.take(2).toList()),
              SizedBox(height: gap),
              mainCards[2],
            ],
            SizedBox(height: gap),
            if (cols >= 3)
              gridRow(secondaryCards)
            else ...[
              gridRow(secondaryCards.take(2).toList()),
              SizedBox(height: gap),
              secondaryCards[2],
            ],
            if (topServices.isNotEmpty ||
                therapist.specijalizacija.trim().isNotEmpty) ...[
              SizedBox(height: gap),
              _TopServicesCard(
                topServices: topServices,
                fallbackTags: therapist.specijalizacija,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _OverviewKpiStrip extends StatelessWidget {
  const _OverviewKpiStrip({
    required this.kpi,
    required this.schedule,
    required this.periodDays,
  });

  final TherapistKpi? kpi;
  final List<TherapistWeeklyScheduleDay> schedule;
  final int periodDays;

  @override
  Widget build(BuildContext context) {
    final weekDays = schedule.where((d) => d.isWorking).length;
    final weekValue = schedule.isEmpty ? '—' : '$weekDays';
    final completed = kpi != null ? '${kpi!.potvrdjeneRezervacije}' : '—';
    final rating = (kpi?.prosjecnaOcjena ?? 0) > 0
        ? kpi!.prosjecnaOcjena.toStringAsFixed(1)
        : '—';
    final revenue = (kpi?.prihod ?? 0) > 0 ? formatKm(kpi!.prihod) : '—';

    return LayoutBuilder(
      builder: (context, c) {
        final narrow = c.maxWidth < 720;
        final cards = [
          _MetricKpiCard(
            label: 'This week',
            value: weekValue,
            subtitle: 'scheduled days',
            accent: const Color(0xFF5EEAD4),
            icon: Icons.calendar_today_outlined,
          ),
          _MetricKpiCard(
            label: 'Completed',
            value: completed,
            subtitle: 'last $periodDays days',
            accent: _ProfileUi.accentPurple,
            icon: Icons.check_circle_outline_rounded,
          ),
          _MetricKpiCard(
            label: 'Average rating',
            value: rating,
            subtitle: rating != '—' ? 'out of 5' : null,
            accent: const Color(0xFFF5B942),
            icon: Icons.star_outline_rounded,
          ),
          _MetricKpiCard(
            label: 'Revenue',
            value: revenue,
            subtitle: 'in KPI period',
            accent: const Color(0xFF9D6BFF),
            icon: Icons.payments_outlined,
          ),
        ];

        if (narrow) {
          return Column(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                cards[i],
              ],
            ],
          );
        }

        return Row(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: cards[i]),
            ],
          ],
        );
      },
    );
  }
}

class _MetricKpiCard extends StatelessWidget {
  const _MetricKpiCard({
    required this.label,
    required this.value,
    required this.accent,
    required this.icon,
    this.subtitle,
  });

  final String label;
  final String value;
  final String? subtitle;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 18,
      child: SizedBox(
        height: 118,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: accent.withValues(alpha: 0.28)),
                  ),
                  child: Icon(icon, size: 16, color: accent),
                ),
                const Spacer(),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: _ProfileUi.textPrimary,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: _ProfileUi.bodyMuted(context).copyWith(fontSize: 12),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: _ProfileUi.bodyMuted(context).copyWith(fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard({
    required this.onEdit,
    required this.onNavigateTab,
  });

  final VoidCallback onEdit;
  final ValueChanged<_ProfileTab> onNavigateTab;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick Actions', style: _ProfileUi.cardTitle(context)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickActionChip(
                icon: Icons.calendar_month_outlined,
                label: 'View Schedule',
                onTap: () => onNavigateTab(_ProfileTab.schedule),
              ),
              _QuickActionChip(
                icon: Icons.event_note_outlined,
                label: 'View Appointments',
                onTap: () => onNavigateTab(_ProfileTab.appointments),
              ),
              _QuickActionChip(
                icon: Icons.edit_outlined,
                label: 'Edit Therapist',
                onTap: onEdit,
              ),
              _QuickActionChip(
                icon: Icons.rate_review_outlined,
                label: 'View Reviews',
                onTap: () => onNavigateTab(_ProfileTab.reviews),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionChip extends StatefulWidget {
  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_QuickActionChip> createState() => _QuickActionChipState();
}

class _QuickActionChipState extends State<_QuickActionChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: _hover
                ? _ProfileUi.accentPurple.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.04),
            border: Border.all(
              color: _hover
                  ? _ProfileUi.accentPurple.withValues(alpha: 0.45)
                  : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 16, color: _ProfileUi.accentSecondary),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _ProfileUi.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LastActivityCard extends StatelessWidget {
  const _LastActivityCard({
    required this.schedule,
    required this.reviews,
  });

  final List<TherapistWeeklyScheduleDay> schedule;
  final List<TherapistReviewRow> reviews;

  List<String> _lines() {
    final lines = <String>[];
    final latestReview = reviews.isEmpty
        ? null
        : reviews.reduce(
            (a, b) => a.createdAt.isAfter(b.createdAt) ? a : b,
          );
    if (latestReview != null) {
      final d = latestReview.createdAt.toLocal();
      lines.add(
        '${d.day.toString().padLeft(2, '0')}.'
        '${d.month.toString().padLeft(2, '0')}. — '
        'Client review (${latestReview.ocjena}/5)',
      );
    }
    final working = schedule.where((d) => d.isWorking).toList();
    if (working.isNotEmpty) {
      final d = working.last;
      lines.add('${d.label} — Scheduled ${d.hoursText}');
    }
    return lines.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final lines = _lines();
    return _GlassCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Last Activity', style: _ProfileUi.cardTitle(context)),
          const SizedBox(height: 12),
          if (lines.isEmpty)
            Text('No recent activity.', style: _ProfileUi.bodyMuted(context))
          else
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(top: 6, right: 10),
                      decoration: BoxDecoration(
                        color: _ProfileUi.accentPurple.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        line,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          height: 1.4,
                          color: _ProfileUi.textPrimary,
                        ),
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

class _AboutCard extends StatelessWidget {
  const _AboutCard({
    required this.therapist,
    required this.profile,
  });

  final Zaposlenik therapist;
  final TherapistAdminProfile? profile;

  @override
  Widget build(BuildContext context) {
    final phone = therapist.telefon?.trim().isNotEmpty == true
        ? therapist.telefon!
        : '—';
    final email = _contactEmail(therapist, profile?.povezanEmail);
    final education = therapist.obrazovanje?.trim().isNotEmpty == true
        ? therapist.obrazovanje!
        : '—';

    return _GlassCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Personal Information', style: _ProfileUi.cardTitle(context)),
          const SizedBox(height: 14),
          _InfoRow(
            icon: Icons.phone_outlined,
            label: 'Phone',
            value: phone,
          ),
          _InfoRow(
            icon: Icons.mail_outline_rounded,
            label: 'Email',
            value: email,
          ),
          if (therapist.kategorijaUslugaNaziv?.trim().isNotEmpty == true)
            _InfoRow(
              icon: Icons.category_outlined,
              label: 'Category',
              value: therapist.kategorijaUslugaNaziv!,
            ),
          _InfoRow(
            icon: Icons.translate_rounded,
            label: 'Languages',
            value: therapist.jezici?.trim().isNotEmpty == true
                ? therapist.jezici!
                : '—',
          ),
          _InfoRow(
            icon: Icons.school_outlined,
            label: 'Education',
            value: education,
          ),
        ],
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: _ProfileUi.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: _ProfileUi.bodyMuted(context).copyWith(fontSize: 12.5),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _ProfileUi.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekScheduleListCard extends StatelessWidget {
  const _WeekScheduleListCard({required this.schedule});

  final List<TherapistWeeklyScheduleDay> schedule;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("This Week's Schedule", style: _ProfileUi.cardTitle(context)),
          const SizedBox(height: 12),
          if (schedule.isEmpty)
            Text('No schedule data.', style: _ProfileUi.bodyMuted(context))
          else
            for (var i = 0; i < schedule.length; i++) ...[
              _ScheduleRow(
                label: schedule[i].label,
                hours: schedule[i].hoursText,
                isWorking: schedule[i].isWorking,
              ),
              if (i < schedule.length - 1) const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    required this.label,
    required this.hours,
    required this.isWorking,
  });

  final String label;
  final String hours;
  final bool isWorking;

  bool get _isOff => hours == 'Day off' || !isWorking;

  @override
  Widget build(BuildContext context) {
    final (badgeLabel, badgeColor) = _isOff
        ? ('Day off', Colors.white.withValues(alpha: 0.35))
        : ('Scheduled', const Color(0xFF5EEAD4));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _ProfileUi.textPrimary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: badgeColor.withValues(alpha: 0.35)),
            ),
            child: Text(
              badgeLabel,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: badgeColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 88,
            child: Text(
              hours,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _isOff ? _ProfileUi.textSecondary : _ProfileUi.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PerformanceSummaryCard extends StatelessWidget {
  const _PerformanceSummaryCard({
    required this.kpi,
    required this.periodDays,
    required this.onPeriodChanged,
  });

  final TherapistKpi? kpi;
  final int periodDays;
  final ValueChanged<int> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    final total = kpi?.ukupnoRezervacija ?? 0;
    final confirmed = kpi?.potvrdjeneRezervacije ?? 0;
    final paid = kpi?.placeneRezervacije ?? 0;
    final reviewCount = kpi?.brojRecenzija ?? 0;
    final cancelPct = kpi?.stopaOtkazivanjaPostotak ?? 0;
    final rating = (kpi?.prosjecnaOcjena ?? 0) > 0 ? kpi!.prosjecnaOcjena : 0;
    final satisfaction = kpi?.zadovoljstvoKlijenataPostotak;
    final revenue = kpi?.prihod ?? 0;

    final cancelTrend = kpi?.trendOtkazanePostotak;
    final cancelTrendBadge = TherapistKpi.badgePercent(cancelTrend);
    final cancelTrendPositive = cancelTrend == null || cancelTrend <= 0;
    final maxRevenue = revenue > 0 ? revenue : 1.0;

    return _GlassCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Performance Summary',
                  style: _ProfileUi.cardTitle(context),
                ),
              ),
              _KpiPeriodChips(
                selectedDays: periodDays,
                onChanged: onPeriodChanged,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Last $periodDays days',
            style: _ProfileUi.bodyMuted(context).copyWith(fontSize: 11),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _PerfHighlight(
                  label: 'Total Appointments',
                  value: '$total',
                  badge: TherapistKpi.badgePercent(
                    kpi?.trendUkupnoRezervacijaPostotak,
                  ),
                  positive: (kpi?.trendUkupnoRezervacijaPostotak ?? 0) >= 0,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PerfHighlight(
                  label: 'Revenue',
                  value: revenue > 0 ? formatKm(revenue) : '—',
                  badge: TherapistKpi.badgePercent(kpi?.trendPrihodPostotak),
                  positive: (kpi?.trendPrihodPostotak ?? 0) >= 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _PerfMetricBar(
            label: 'Average Rating',
            valueLabel: rating > 0 ? '${rating.toStringAsFixed(1)} / 5' : '—',
            progress: rating > 0 ? rating / 5.0 : 0,
            color: const Color(0xFFF5B942),
            trailing: rating > 0
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      5,
                      (i) => Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: i < rating.round()
                            ? const Color(0xFFF5B942)
                            : Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 12),
          _PerfMetricBar(
            label: 'Cancellation Rate',
            valueLabel: '${cancelPct.toStringAsFixed(0)}%',
            progress: (cancelPct / 100).clamp(0.0, 1.0),
            color: cancelPct > 20 ? _ProfileUi.danger : _ProfileUi.success,
            badge: cancelTrendBadge,
            badgePositive: cancelTrendPositive,
          ),
          const SizedBox(height: 12),
          _PerfMetricBar(
            label: 'Client Satisfaction',
            valueLabel: satisfaction != null ? '$satisfaction%' : '—',
            progress: satisfaction != null ? satisfaction / 100.0 : 0,
            color: _ProfileUi.accentSecondary,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Confirmed · Paid',
                  style: _ProfileUi.bodyMuted(context).copyWith(fontSize: 12),
                ),
              ),
              Text(
                '$confirmed · $paid',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _ProfileUi.textPrimary,
                ),
              ),
            ],
          ),
          if (reviewCount > 0) ...[
            const SizedBox(height: 6),
            Text(
              '$reviewCount reviews in period',
              style: _ProfileUi.bodyMuted(context).copyWith(fontSize: 11),
            ),
          ],
          if (revenue > 0) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: (revenue / maxRevenue).clamp(0.05, 1.0),
                minHeight: 4,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                color: _ProfileUi.accentPurple,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PerfHighlight extends StatelessWidget {
  const _PerfHighlight({
    required this.label,
    required this.value,
    this.badge,
    this.positive = true,
  });

  final String label;
  final String value;
  final String? badge;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _ProfileUi.bodyMuted(context).copyWith(fontSize: 11)),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _ProfileUi.textPrimary,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 6),
                _TrendBadge(text: badge!, positive: positive),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PerfMetricBar extends StatelessWidget {
  const _PerfMetricBar({
    required this.label,
    required this.valueLabel,
    required this.progress,
    required this.color,
    this.trailing,
    this.badge,
    this.badgePositive = true,
  });

  final String label;
  final String valueLabel;
  final double progress;
  final Color color;
  final Widget? trailing;
  final String? badge;
  final bool badgePositive;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: _ProfileUi.bodyMuted(context).copyWith(fontSize: 12),
              ),
            ),
            if (trailing != null) trailing!,
            if (badge != null) ...[
              const SizedBox(width: 6),
              _TrendBadge(text: badge!, positive: badgePositive),
            ],
            const SizedBox(width: 8),
            Text(
              valueLabel,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _ProfileUi.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress > 0 ? progress.clamp(0.0, 1.0) : null,
            minHeight: 6,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            color: color,
          ),
        ),
      ],
    );
  }
}

class _KpiPeriodChips extends StatelessWidget {
  const _KpiPeriodChips({
    required this.selectedDays,
    required this.onChanged,
  });

  final int selectedDays;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final days in const [30, 90]) ...[
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: GestureDetector(
              onTap: () => onChanged(days),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: selectedDays == days
                      ? _ProfileUi.accentPurple.withValues(alpha: 0.35)
                      : Colors.white.withValues(alpha: 0.06),
                  border: Border.all(
                    color: selectedDays == days
                        ? _ProfileUi.accentPurple.withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Text(
                  '${days}d',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _ProfileUi.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TrendBadge extends StatelessWidget {
  const _TrendBadge({required this.text, required this.positive});

  final String text;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final color = positive ? _ProfileUi.success : _ProfileUi.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: color.withValues(alpha: 0.12),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _TopServicesCard extends StatelessWidget {
  const _TopServicesCard({
    required this.topServices,
    required this.fallbackTags,
  });

  final List<TherapistTopService> topServices;
  final String fallbackTags;

  List<(String, int)> _fallbackRows() {
    final tags = fallbackTags
        .split(RegExp(r'[,;/]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(4)
        .toList();
    if (tags.isEmpty) return const [];
    final weights = [40, 30, 20, 10];
    final result = <(String, int)>[];
    for (var i = 0; i < tags.length && i < 4; i++) {
      result.add((tags[i], weights[i]));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final fromApi = topServices
        .where((s) => s.naziv.trim().isNotEmpty)
        .map((s) => (s.naziv, s.postotak.round()))
        .toList();

    final fallback = _fallbackRows();
    final useApi = fromApi.isNotEmpty;
    final rows = useApi
        ? fromApi
        : fallback
            .map((e) => (e.$1, e.$2))
            .toList();

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Top Services Performed', style: _ProfileUi.cardTitle(context)),
          if (!useApi && rows.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'No booking history yet — bars show specialties only (not real volume).',
              style: _ProfileUi.bodyMuted(context).copyWith(fontSize: 12),
            ),
          ] else if (useApi) ...[
            const SizedBox(height: 6),
            Text(
              'Based on completed appointments in the last 90 days.',
              style: _ProfileUi.bodyMuted(context).copyWith(fontSize: 12),
            ),
          ],
          const SizedBox(height: 18),
          if (rows.isEmpty)
            Text(
              'No service history yet.',
              style: _ProfileUi.bodyMuted(context),
            )
          else
            for (var i = 0; i < rows.length; i++) ...[
              _ServiceProgressRow(
                label: rows[i].$1,
                percent: rows[i].$2,
                showPercent: useApi,
              ),
              if (i < rows.length - 1) const SizedBox(height: 14),
            ],
        ],
      ),
    );
  }
}

class _ServiceProgressRow extends StatelessWidget {
  const _ServiceProgressRow({
    required this.label,
    required this.percent,
    this.showPercent = true,
  });

  final String label;
  final int percent;
  final bool showPercent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: _ProfileUi.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 8,
              child: Stack(
                children: [
                  Container(color: Colors.white.withValues(alpha: 0.08)),
                  FractionallySizedBox(
                    widthFactor: percent / 100,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF7B4DFF),
                            Color(0xFF9D6BFF),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showPercent) ...[
          const SizedBox(width: 12),
          SizedBox(
            width: 40,
            child: Text(
              '$percent%',
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _ProfileUi.textSecondary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    this.padding,
    this.borderRadius = 20,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: _ProfileUi.accentPurple.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Shared tab shell: title → summary metrics → content.
class _ProfileTabHeader extends StatelessWidget {
  const _ProfileTabHeader({
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: _ProfileUi.title(context).copyWith(fontSize: 20)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: _ProfileUi.bodyMuted(context)),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _ProfileSummaryStrip extends StatelessWidget {
  const _ProfileSummaryStrip({required this.metrics});

  final List<_ProfileSummaryMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final narrow = c.maxWidth < 560;
        if (narrow) {
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: metrics.map((m) => _SummaryMetricChip(metric: m)).toList(),
          );
        }
        return Row(
          children: [
            for (var i = 0; i < metrics.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: _SummaryMetricChip(metric: metrics[i])),
            ],
          ],
        );
      },
    );
  }
}

class _ProfileSummaryMetric {
  const _ProfileSummaryMetric({
    required this.label,
    required this.value,
    this.accent,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final String value;
  final Color? accent;
  final bool selected;
  final VoidCallback? onTap;
}

class _SummaryMetricChip extends StatefulWidget {
  const _SummaryMetricChip({required this.metric});

  final _ProfileSummaryMetric metric;

  @override
  State<_SummaryMetricChip> createState() => _SummaryMetricChipState();
}

class _SummaryMetricChipState extends State<_SummaryMetricChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.metric;
    final accent = m.accent ?? _ProfileUi.accentPurple;
    final interactive = m.onTap != null;
    final selected = m.selected;

    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: selected
            ? accent.withValues(alpha: 0.14)
            : (_hover && interactive
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.03)),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected
              ? accent.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            m.value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: selected ? accent : _ProfileUi.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            m.label,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: _ProfileUi.textSecondary,
            ),
          ),
        ],
      ),
    );

    if (!interactive) return child;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: m.onTap,
        behavior: HitTestBehavior.opaque,
        child: child,
      ),
    );
  }
}

class _ProfileStatusBadge extends StatelessWidget {
  const _ProfileStatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

int _scheduleWorkingDays(List<TherapistWeeklyScheduleDay> schedule) =>
    schedule.where((d) => d.isWorking).length;

String? _scheduleNextAppointment(List<TherapistWeeklyScheduleDay> schedule) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  for (final d in schedule) {
    if (!d.isWorking || d.hoursText == 'Day off') continue;
    final parts = d.label.split(' ');
    if (parts.length < 3) continue;
    final monthName = parts[1];
    final dayNum = int.tryParse(parts[2]);
    if (dayNum == null) continue;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final monthIndex = months.indexOf(monthName);
    if (monthIndex < 0) continue;
    final dayDate = DateTime(now.year, monthIndex + 1, dayNum);
    if (dayDate.isBefore(today)) continue;
    final shortDay = parts.first;
    final time = d.hoursText.contains('–')
        ? d.hoursText.split('–').first.trim()
        : d.hoursText;
    return '$shortDay $time';
  }
  return null;
}

_ScheduleDayStatus _scheduleDayStatus(TherapistWeeklyScheduleDay day) {
  if (!day.isWorking || day.hoursText == 'Day off') {
    return _ScheduleDayStatus.dayOff;
  }
  final span = day.hoursText;
  if (span.contains('–')) {
    final parts = span.split('–');
    if (parts.length == 2) {
      final start = _parseHm(parts[0].trim());
      final end = _parseHm(parts[1].trim());
      if (start != null && end != null && end - start >= 480) {
        return _ScheduleDayStatus.fullyBooked;
      }
    }
  }
  return _ScheduleDayStatus.scheduled;
}

int? _parseHm(String raw) {
  final p = raw.split(':');
  if (p.length != 2) return null;
  final h = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  if (h == null || m == null) return null;
  return h * 60 + m;
}

enum _ScheduleDayStatus { scheduled, dayOff, fullyBooked }

class _ScheduleTabPanel extends StatelessWidget {
  const _ScheduleTabPanel({required this.schedule});

  final List<TherapistWeeklyScheduleDay> schedule;

  @override
  Widget build(BuildContext context) {
    final scheduledDays = _scheduleWorkingDays(schedule);
    final next = _scheduleNextAppointment(schedule);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ProfileTabHeader(title: 'Schedule'),
        const SizedBox(height: 16),
        _ProfileSummaryStrip(
          metrics: [
            _ProfileSummaryMetric(
              label: 'Scheduled days',
              value: schedule.isEmpty ? '—' : '$scheduledDays',
              accent: const Color(0xFF5EEAD4),
            ),
            _ProfileSummaryMetric(
              label: 'Appointments',
              value: schedule.isEmpty ? '—' : '$scheduledDays',
              accent: _ProfileUi.accentSecondary,
            ),
            _ProfileSummaryMetric(
              label: 'Next',
              value: next ?? '—',
              accent: const Color(0xFFF5B942),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _GlassCard(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          borderRadius: 18,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Weekly availability',
                style: _ProfileUi.cardTitle(context),
              ),
              const SizedBox(height: 4),
              Text(
                'Non-cancelled appointments this week',
                style: _ProfileUi.bodyMuted(context).copyWith(fontSize: 11.5),
              ),
              const SizedBox(height: 12),
              if (schedule.isEmpty)
                Text(
                  'No schedule data.',
                  style: _ProfileUi.bodyMuted(context),
                )
              else
                for (var i = 0; i < schedule.length; i++)
                  _CompactScheduleDayRow(day: schedule[i]),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompactScheduleDayRow extends StatelessWidget {
  const _CompactScheduleDayRow({required this.day});

  final TherapistWeeklyScheduleDay day;

  @override
  Widget build(BuildContext context) {
    final status = _scheduleDayStatus(day);
    final (badgeLabel, badgeColor) = switch (status) {
      _ScheduleDayStatus.dayOff => (
          'Day off',
          Colors.white.withValues(alpha: 0.38),
        ),
      _ScheduleDayStatus.fullyBooked => (
          'Fully booked',
          const Color(0xFFF59E0B),
        ),
      _ScheduleDayStatus.scheduled => (
          'Scheduled',
          const Color(0xFF5EEAD4),
        ),
    };

    final dayShort = day.label.split(' ').first;
    final detail = status == _ScheduleDayStatus.dayOff
        ? 'Day off'
        : day.hoursText;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              dayShort,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _ProfileUi.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              detail,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: status == _ScheduleDayStatus.dayOff
                    ? _ProfileUi.textSecondary
                    : _ProfileUi.textPrimary,
              ),
            ),
          ),
          _ProfileStatusBadge(label: badgeLabel, color: badgeColor),
        ],
      ),
    );
  }
}

List<String> _specializationTags(Zaposlenik therapist) {
  return therapist.specijalizacija
      .split(RegExp(r'[,;/]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

class _TherapistServicesPanel extends StatefulWidget {
  const _TherapistServicesPanel({
    required this.api,
    required this.therapist,
  });

  final ApiService api;
  final Zaposlenik therapist;

  @override
  State<_TherapistServicesPanel> createState() => _TherapistServicesPanelState();
}

class _TherapistServicesPanelState extends State<_TherapistServicesPanel> {
  late Future<List<Usluga>> _servicesFuture = _loadServices();

  Future<List<Usluga>> _loadServices() async {
    final all = await widget.api.getUsluge();
    final katId = widget.therapist.kategorijaUslugaId;
    if (katId == null || katId <= 0) return const [];
    return all.where((u) => u.kategorijaUslugaId == katId).toList()
      ..sort((a, b) => a.naziv.compareTo(b.naziv));
  }

  void _refresh() {
    setState(() => _servicesFuture = _loadServices());
  }

  @override
  Widget build(BuildContext context) {
    final tags = _specializationTags(widget.therapist);
    final katName = widget.therapist.kategorijaUslugaNaziv?.trim();
    final hasCategory =
        (widget.therapist.kategorijaUslugaId ?? 0) > 0 &&
        katName != null &&
        katName.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProfileTabHeader(
          title: 'Services',
          subtitle: hasCategory
              ? 'Qualified treatments · $katName'
              : 'Assign a service category in profile settings',
          trailing: IconButton(
            onPressed: _refresh,
            tooltip: 'Refresh',
            icon: Icon(
              Icons.refresh_rounded,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Specializations',
          style: _ProfileUi.cardTitle(context),
        ),
        const SizedBox(height: 10),
        if (tags.isEmpty)
          Text(
            'No specializations listed yet.',
            style: _ProfileUi.bodyMuted(context),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final tag in tags)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _ProfileUi.accentPurple.withValues(alpha: 0.22),
                        _ProfileUi.accentSecondary.withValues(alpha: 0.12),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: _ProfileUi.accentPurple.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    tag,
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: _ProfileUi.textPrimary,
                    ),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 20),
        Text(
          'Available services',
          style: _ProfileUi.cardTitle(context),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<Usluga>>(
          future: _servicesFuture,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(
                    color: _ProfileUi.accentPurple,
                    strokeWidth: 2,
                  ),
                ),
              );
            }
            if (!hasCategory) {
              return _GlassCard(
                padding: const EdgeInsets.all(16),
                borderRadius: 18,
                child: Text(
                  'Link a service category to show treatments this therapist can perform.',
                  style: _ProfileUi.bodyMuted(context),
                ),
              );
            }
            final services = snap.data ?? const <Usluga>[];
            if (services.isEmpty) {
              return _GlassCard(
                padding: const EdgeInsets.all(16),
                borderRadius: 18,
                child: Text(
                  'No services in this category.',
                  style: _ProfileUi.bodyMuted(context),
                ),
              );
            }
            return LayoutBuilder(
              builder: (context, c) {
                final cols = c.maxWidth >= 900
                    ? 3
                    : (c.maxWidth >= 560 ? 2 : 1);
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: cols == 1 ? 2.8 : 1.35,
                  ),
                  itemCount: services.length,
                  itemBuilder: (context, i) {
                    return _TherapistServiceGridCard(
                      service: services[i],
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ServiceDetailsScreen(
                              serviceId: services[i].id,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _TherapistServiceGridCard extends StatefulWidget {
  const _TherapistServiceGridCard({
    required this.service,
    required this.onTap,
  });

  final Usluga service;
  final VoidCallback onTap;

  @override
  State<_TherapistServiceGridCard> createState() =>
      _TherapistServiceGridCardState();
}

class _TherapistServiceGridCardState extends State<_TherapistServiceGridCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final duration = widget.service.trajanjeMinuta > 0
        ? '${widget.service.trajanjeMinuta} min'
        : widget.service.trajanje;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _hover
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _hover
                    ? _ProfileUi.accentPurple.withValues(alpha: 0.35)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    widget.service.naziv,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _ProfileUi.textPrimary,
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  duration,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _ProfileUi.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.service.cijenaKm,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFD4AF7A),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewsPanel extends StatelessWidget {
  const _ReviewsPanel({
    required this.reviews,
    required this.formatDate,
  });

  final List<TherapistReviewRow> reviews;
  final String Function(DateTime) formatDate;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Client Reviews', style: _ProfileUi.cardTitle(context)),
          const SizedBox(height: 6),
          Text(
            'Reviews linked to this therapist (by therapist ID or matching non-cancelled appointment).',
            style: _ProfileUi.bodyMuted(context).copyWith(fontSize: 12),
          ),
          const SizedBox(height: 16),
          if (reviews.isEmpty)
            Text(
              'No reviews yet for this therapist.',
              style: _ProfileUi.bodyMuted(context),
            )
          else
            for (var i = 0; i < reviews.length; i++) ...[
              _ReviewTile(review: reviews[i], formatDate: formatDate),
              if (i < reviews.length - 1)
                Divider(
                  height: 24,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
            ],
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review, required this.formatDate});

  final TherapistReviewRow review;
  final String Function(DateTime) formatDate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                review.korisnikIme,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: _ProfileUi.textPrimary,
                ),
              ),
            ),
            Text(formatDate(review.createdAt), style: _ProfileUi.bodyMuted(context)),
          ],
        ),
        if (review.uslugaNaziv.trim().isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(review.uslugaNaziv, style: _ProfileUi.bodyMuted(context)),
        ],
        const SizedBox(height: 6),
        Row(
          children: List.generate(
            5,
            (i) => Icon(
              Icons.star_rounded,
              size: 16,
              color: i < review.ocjena
                  ? const Color(0xFFF5B942)
                  : Colors.white.withValues(alpha: 0.12),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          review.komentar.trim().isEmpty ? '—' : review.komentar,
          style: _ProfileUi.bodyMuted(context),
        ),
      ],
    );
  }
}

class _TherapistAppointmentsPanel extends StatefulWidget {
  const _TherapistAppointmentsPanel({
    required this.api,
    required this.zaposlenikId,
  });

  final ApiService api;
  final int zaposlenikId;

  @override
  State<_TherapistAppointmentsPanel> createState() =>
      _TherapistAppointmentsPanelState();
}

enum _AppointmentFilter { upcoming, past, cancelled }

class _TherapistAppointmentsPanelState extends State<_TherapistAppointmentsPanel> {
  late Future<({List<Rezervacija> items, String? error})> _future =
      _loadAppointments();
  _AppointmentFilter _filter = _AppointmentFilter.upcoming;

  Future<({List<Rezervacija> items, String? error})> _loadAppointments() {
    return widget.api.getRezervacijeFilteredAllResult(
      includeOtkazane: true,
      zaposlenikId: widget.zaposlenikId,
    );
  }

  void _refresh() => setState(() => _future = _loadAppointments());

  List<Rezervacija> _filtered(List<Rezervacija> all) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    bool isUpcoming(Rezervacija r) {
      final d = r.datumRezervacije.toLocal();
      final day = DateTime(d.year, d.month, d.day);
      return !r.isOtkazana && !day.isBefore(today);
    }

    final sorted = List<Rezervacija>.from(all)
      ..sort((a, b) => b.datumRezervacije.compareTo(a.datumRezervacije));

    return switch (_filter) {
      _AppointmentFilter.upcoming => sorted.where(isUpcoming).toList(),
      _AppointmentFilter.past => sorted.where((r) {
          final d = r.datumRezervacije.toLocal();
          final day = DateTime(d.year, d.month, d.day);
          return !r.isOtkazana && day.isBefore(today);
        }).toList(),
      _AppointmentFilter.cancelled =>
        sorted.where((r) => r.isOtkazana).toList(),
    };
  }

  ({int upcoming, int completed, int cancelled}) _counts(
    List<Rezervacija> all,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var upcoming = 0;
    var completed = 0;
    var cancelled = 0;
    for (final r in all) {
      if (r.isOtkazana) {
        cancelled++;
        continue;
      }
      final d = r.datumRezervacije.toLocal();
      final day = DateTime(d.year, d.month, d.day);
      if (day.isBefore(today)) {
        completed++;
      } else {
        upcoming++;
      }
    }
    return (upcoming: upcoming, completed: completed, cancelled: cancelled);
  }

  static String _appointmentDateLabel(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final l = d.toLocal();
    return '${months[l.month - 1]} ${l.day}, ${l.year}';
  }

  static String _appointmentTimeLabel(DateTime d) {
    final l = d.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }

  static (String label, Color color) _statusStyle(Rezervacija r) {
    if (r.isOtkazana) {
      return ('Cancelled', _ProfileUi.danger);
    }
    if (r.isPlacena) return ('Paid', const Color(0xFF5EEAD4));
    if (r.isPotvrdjena) return ('Confirmed', _ProfileUi.success);
    return ('Pending', const Color(0xFFF5B942));
  }

  void _showDetails(BuildContext context, Rezervacija r) {
    final client = r.korisnikIme?.trim().isNotEmpty == true
        ? r.korisnikIme!
        : (r.korisnikEmail?.trim().isNotEmpty == true
            ? r.korisnikEmail!
            : 'Unknown client');
    final status = r.isOtkazana
        ? 'Cancelled'
        : (r.isPlacena
            ? 'Paid'
            : (r.isPotvrdjena ? 'Confirmed' : 'Pending'));

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _ProfileUi.bgMid,
        title: Text(
          'Appointment',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: _ProfileUi.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailLine('Client', client),
            _DetailLine('Service', r.uslugaNaziv ?? '—'),
            _DetailLine(
              'When',
              '${_appointmentDateLabel(r.datumRezervacije)} '
              '${_appointmentTimeLabel(r.datumRezervacije)}',
            ),
            _DetailLine('Status', status),
            if (r.isVip) const _DetailLine('VIP', 'Yes'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({List<Rezervacija> items, String? error})>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: CircularProgressIndicator(
                color: _ProfileUi.accentPurple,
                strokeWidth: 2,
              ),
            ),
          );
        }

        final error = snap.data?.error;
        final all = snap.data?.items ?? const <Rezervacija>[];
        final counts = _counts(all);
        final list = _filtered(all);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ProfileTabHeader(
              title: 'Appointments',
              trailing: IconButton(
                onPressed: _refresh,
                tooltip: 'Refresh',
                icon: Icon(
                  Icons.refresh_rounded,
                  color: Colors.white.withValues(alpha: 0.65),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _ProfileSummaryStrip(
              metrics: [
                _ProfileSummaryMetric(
                  label: 'Upcoming',
                  value: '${counts.upcoming}',
                  accent: const Color(0xFF5EEAD4),
                  selected: _filter == _AppointmentFilter.upcoming,
                  onTap: () =>
                      setState(() => _filter = _AppointmentFilter.upcoming),
                ),
                _ProfileSummaryMetric(
                  label: 'Completed',
                  value: '${counts.completed}',
                  accent: _ProfileUi.accentSecondary,
                  selected: _filter == _AppointmentFilter.past,
                  onTap: () => setState(() => _filter = _AppointmentFilter.past),
                ),
                _ProfileSummaryMetric(
                  label: 'Cancelled',
                  value: '${counts.cancelled}',
                  accent: _ProfileUi.danger,
                  selected: _filter == _AppointmentFilter.cancelled,
                  onTap: () =>
                      setState(() => _filter = _AppointmentFilter.cancelled),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (error != null) ...[
              _GlassCard(
                padding: const EdgeInsets.all(16),
                borderRadius: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(error, style: _ProfileUi.bodyMuted(context)),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Retry'),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (list.isEmpty)
              _GlassCard(
                padding: const EdgeInsets.all(16),
                borderRadius: 18,
                child: Text(
                  switch (_filter) {
                    _AppointmentFilter.upcoming => 'No upcoming appointments.',
                    _AppointmentFilter.past => 'No completed appointments yet.',
                    _AppointmentFilter.cancelled =>
                      'No cancelled appointments.',
                  },
                  style: _ProfileUi.bodyMuted(context),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, c) {
                  final twoCol = c.maxWidth >= 640;
                  if (!twoCol) {
                    return Column(
                      children: [
                        for (final r in list)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _AppointmentGridCard(
                              rezervacija: r,
                              onTap: () => _showDetails(context, r),
                            ),
                          ),
                      ],
                    );
                  }
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.55,
                    ),
                    itemCount: list.length,
                    itemBuilder: (context, i) => _AppointmentGridCard(
                      rezervacija: list[i],
                      onTap: () => _showDetails(context, list[i]),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class _AppointmentGridCard extends StatefulWidget {
  const _AppointmentGridCard({
    required this.rezervacija,
    required this.onTap,
  });

  final Rezervacija rezervacija;
  final VoidCallback onTap;

  @override
  State<_AppointmentGridCard> createState() => _AppointmentGridCardState();
}

class _AppointmentGridCardState extends State<_AppointmentGridCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.rezervacija;
    final client = r.korisnikIme?.trim().isNotEmpty == true
        ? r.korisnikIme!
        : (r.korisnikEmail?.trim().isNotEmpty == true
            ? r.korisnikEmail!
            : 'Unknown client');
    final (statusLabel, statusColor) =
        _TherapistAppointmentsPanelState._statusStyle(r);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _hover
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _hover
                    ? _ProfileUi.accentPurple.withValues(alpha: 0.32)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        client,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _ProfileUi.textPrimary,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_outward_rounded,
                      size: 16,
                      color: Colors.white.withValues(
                        alpha: _hover ? 0.55 : 0.28,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  r.uslugaNaziv ?? 'Service',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: _ProfileUi.textSecondary,
                    height: 1.35,
                  ),
                ),
                const Spacer(),
                Text(
                  _TherapistAppointmentsPanelState._appointmentDateLabel(
                    r.datumRezervacije,
                  ),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _ProfileUi.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _TherapistAppointmentsPanelState._appointmentTimeLabel(
                    r.datumRezervacije,
                  ),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _ProfileUi.accentSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                _ProfileStatusBadge(label: statusLabel, color: statusColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: _ProfileUi.bodyMuted(context),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(color: _ProfileUi.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class _InternaNapomenaPanel extends StatefulWidget {
  const _InternaNapomenaPanel({
    required this.api,
    required this.zaposlenikId,
    required this.profile,
    required this.onSaved,
    this.onInvitePortal,
  });

  final ApiService api;
  final int zaposlenikId;
  final TherapistAdminProfile? profile;
  final VoidCallback onSaved;
  final VoidCallback? onInvitePortal;

  @override
  State<_InternaNapomenaPanel> createState() => _InternaNapomenaPanelState();
}

class _InternaNapomenaPanelState extends State<_InternaNapomenaPanel> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.profile?.internaNapomena ?? '',
  );
  bool _saving = false;

  @override
  void didUpdateWidget(covariant _InternaNapomenaPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile?.internaNapomena != widget.profile?.internaNapomena) {
      _controller.text = widget.profile?.internaNapomena ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(widget.profile?.imaKorisnickiNalog ?? false)) return;
    setState(() => _saving = true);
    final ok = await widget.api.patchTherapistInternaNapomena(
      zaposlenikId: widget.zaposlenikId,
      napomena: _controller.text.trim().isEmpty ? null : _controller.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    final messenger = ScaffoldMessenger.of(context);
    if (ok == true) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Note saved.')),
      );
      widget.onSaved();
    } else if (ok == false) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'No linked portal account. Send a portal invite first, then save the note.',
          ),
        ),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Network error. Check your connection and try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = widget.profile?.imaKorisnickiNalog ?? false;

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Notes', style: _ProfileUi.cardTitle(context)),
          const SizedBox(height: 8),
          Text(
            'Internal note linked to the therapist account.',
            style: _ProfileUi.bodyMuted(context),
          ),
          const SizedBox(height: 16),
          if (!canEdit) ...[
            Text(
              'Internal notes are stored on the portal user account. '
              'Invite this therapist to the portal first.',
              style: _ProfileUi.bodyMuted(context),
            ),
            if (widget.onInvitePortal != null) ...[
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: widget.onInvitePortal,
                  icon: const Icon(Icons.vpn_key_outlined, size: 18),
                  label: const Text('Go to Portal access'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _ProfileUi.accentSecondary,
                    side: BorderSide(
                      color: _ProfileUi.accentPurple.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              ),
            ],
          ] else ...[
            TextField(
              controller: _controller,
              minLines: 5,
              maxLines: 10,
              style: GoogleFonts.inter(color: _ProfileUi.textPrimary),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: _ProfileUi.accentPurple.withValues(alpha: 0.65),
                  ),
                ),
                hintText: 'Allergies, preferences, contraindications…',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: _PurpleButton(
                label: _saving ? 'Saving…' : 'Save note',
                onPressed: _saving ? () {} : _save,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
