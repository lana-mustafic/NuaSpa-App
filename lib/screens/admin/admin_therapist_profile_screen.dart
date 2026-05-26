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
import '../catalog/service_details_screen.dart';
import 'widgets/admin_therapist_editor_dialog.dart';
import 'widgets/admin_therapist_portal_access_card.dart';

class _TherapistScreenBundle {
  const _TherapistScreenBundle({
    required this.profile,
    required this.accountStatus,
  });

  final TherapistAdminProfile? profile;
  final TherapistAccountStatus? accountStatus;
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
  Future<_TherapistScreenBundle>? _bundleFuture;

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
    final fromD = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 30));
    final toD = DateTime(now.year, now.month, now.day);

    final results = await Future.wait([
      _api.getTherapistAdminProfile(
        zaposlenikId: _therapist.id,
        from: fromD,
        to: toD,
      ),
      _api.getTherapistAccountStatus(_therapist.id),
    ]);

    return _TherapistScreenBundle(
      profile: results[0] as TherapistAdminProfile?,
      accountStatus: results[1] as TherapistAccountStatus?,
    );
  }

  Future<void> _editProfile() async {
    final editorResult = await showAdminTherapistEditorDialog(
      context,
      existing: _therapist,
    );
    if (!mounted || editorResult == null) return;
    final result = await _api.updateZaposlenik(editorResult.therapist);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == null
              ? 'Failed to save profile.'
              : 'Therapist profile updated.',
        ),
      ),
    );
    if (result != null) {
      setState(() => _therapist = result);
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
          final profile = snap.data?.profile;
          final accountStatus = snap.data?.accountStatus;
          final kpi = profile?.kpi;
          final schedule = profile?.sedmicniRaspored ?? const [];
          final topServices = profile?.topUsluge ?? const [];
          final t = profile?.terapeut ?? _therapist;
          final name = '${t.ime} ${t.prezime}'.trim();
          final tags = _tags(t.specijalizacija);
          final role = profile?.uloga ?? kpi?.uloga ?? 'Therapist';
          final location = profile?.lokacijaPrikaz?.trim();
          final loading = snap.connectionState == ConnectionState.waiting;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _BackLink(onTap: () => Navigator.pop(context)),
                const SizedBox(height: 12),
                _PageTopBar(onEdit: _editProfile, onRefresh: _reload),
                const SizedBox(height: 20),
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
                else ...[
                  _HeroCard(
                    name: name,
                    role: role,
                    therapist: t,
                    linkedEmail: profile?.povezanEmail,
                    location: location,
                    tags: tags,
                  ),
                  const SizedBox(height: 18),
                  AdminTherapistPortalAccessCard(
                    therapist: t,
                    accountStatus: accountStatus,
                    onChanged: _reload,
                  ),
                  const SizedBox(height: 22),
                  _TabRow(
                    selected: _tab,
                    onSelect: (tab) => setState(() => _tab = tab),
                  ),
                  const SizedBox(height: 22),
                  if (_tab == _ProfileTab.overview)
                    _OverviewSection(
                      therapist: t,
                      profile: profile,
                      kpi: kpi,
                      schedule: schedule,
                      topServices: topServices,
                    )
                  else if (_tab == _ProfileTab.schedule)
                    _WeekScheduleListCard(schedule: schedule)
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
                    )
                  else if (_tab == _ProfileTab.services)
                    _TherapistServicesPanel(
                      api: _api,
                      therapist: t,
                      topServices: topServices,
                    )
                  else
                    const _PlaceholderTab(label: 'Section'),
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
  });

  final String name;
  final String role;
  final Zaposlenik therapist;
  final List<String> tags;
  final String? linkedEmail;
  final String? location;

  @override
  Widget build(BuildContext context) {
    final phone = therapist.telefon?.trim().isNotEmpty == true
        ? therapist.telefon!
        : '—';
    final contactEmail = _contactEmail(therapist, linkedEmail);
    final initials =
        '${therapist.ime.isNotEmpty ? therapist.ime[0] : ''}'
        '${therapist.prezime.isNotEmpty ? therapist.prezime[0] : ''}'
        .toUpperCase();

    return _GlassCard(
      padding: const EdgeInsets.all(32),
      child: LayoutBuilder(
        builder: (context, c) {
          final stack = c.maxWidth < 720;
          final avatar = _Avatar(initials: initials.isEmpty ? '?' : initials);
          final info = Column(
            crossAxisAlignment:
                stack ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: [
              Text(
                name,
                textAlign: stack ? TextAlign.center : TextAlign.start,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: _ProfileUi.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                role,
                style: _ProfileUi.bodyMuted(context),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 18,
                runSpacing: 8,
                alignment: stack ? WrapAlignment.center : WrapAlignment.start,
                children: [
                  _ContactItem(icon: Icons.phone_outlined, text: phone),
                  _ContactItem(
                    icon: Icons.mail_outline_rounded,
                    text: contactEmail,
                  ),
                  _ContactItem(
                    icon: Icons.location_on_outlined,
                    text: location?.isNotEmpty == true
                        ? location!
                        : '—',
                  ),
                ],
              ),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: stack ? WrapAlignment.center : WrapAlignment.start,
                  children: [
                    for (final tag in tags) _SpecPill(label: tag),
                  ],
                ),
              ],
            ],
          );

          if (stack) {
            return Column(
              children: [avatar, const SizedBox(height: 20), info],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              avatar,
              const SizedBox(width: 24),
              Expanded(child: info),
            ],
          );
        },
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 88,
          height: 88,
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
                color: _ProfileUi.accentPurple.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            initials,
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        Positioned(
          right: 4,
          bottom: 4,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: _ProfileUi.success,
              shape: BoxShape.circle,
              border: Border.all(color: _ProfileUi.bgDeep, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _ContactItem extends StatelessWidget {
  const _ContactItem({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: _ProfileUi.textSecondary),
        const SizedBox(width: 6),
        Text(text, style: _ProfileUi.bodyMuted(context).copyWith(fontSize: 13)),
      ],
    );
  }
}

class _SpecPill extends StatelessWidget {
  const _SpecPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: _ProfileUi.accentPurple.withValues(alpha: 0.18),
        border: Border.all(
          color: _ProfileUi.accentPurple.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: _ProfileUi.textPrimary,
        ),
      ),
    );
  }
}

class _TabRow extends StatelessWidget {
  const _TabRow({required this.selected, required this.onSelect});

  final _ProfileTab selected;
  final ValueChanged<_ProfileTab> onSelect;

  static const _tabs = _ProfileTab.values;

  static String _label(_ProfileTab t) => switch (t) {
        _ProfileTab.overview => 'Overview',
        _ProfileTab.schedule => 'Schedule',
        _ProfileTab.appointments => 'Appointments',
        _ProfileTab.services => 'Services',
        _ProfileTab.reviews => 'Client Reviews',
        _ProfileTab.notes => 'Notes',
      };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final tab in _tabs) ...[
            _TabItem(
              label: _label(tab),
              selected: selected == tab,
              onTap: () => onSelect(tab),
            ),
            const SizedBox(width: 24),
          ],
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected
                    ? _ProfileUi.textPrimary
                    : _ProfileUi.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 2,
              decoration: BoxDecoration(
                color: selected ? _ProfileUi.accentPurple : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: _ProfileUi.accentPurple.withValues(alpha: 0.5),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
            ),
          ],
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
    required this.schedule,
    required this.topServices,
  });

  final Zaposlenik therapist;
  final TherapistAdminProfile? profile;
  final TherapistKpi? kpi;
  final List<TherapistWeeklyScheduleDay> schedule;
  final List<TherapistTopService> topServices;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final stacked = c.maxWidth < 1100;
        final grid = stacked
            ? Column(
                children: [
                  _AboutCard(
                    therapist: therapist,
                    profile: profile,
                  ),
                  const SizedBox(height: 16),
                  _WeekScheduleListCard(schedule: schedule),
                  const SizedBox(height: 16),
                  _PerformanceSummaryCard(kpi: kpi),
                ],
              )
            : IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _AboutCard(
                        therapist: therapist,
                        profile: profile,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _WeekScheduleListCard(schedule: schedule),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: _PerformanceSummaryCard(kpi: kpi)),
                  ],
                ),
              );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            grid,
            const SizedBox(height: 16),
            _TopServicesCard(
              topServices: topServices,
              fallbackTags: therapist.specijalizacija,
            ),
          ],
        );
      },
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

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('About ${therapist.ime}', style: _ProfileUi.cardTitle(context)),
          const SizedBox(height: 16),
          _InfoRow(label: 'Phone', value: phone),
          _InfoRow(label: 'Email', value: email),
          if (therapist.kategorijaUslugaNaziv?.trim().isNotEmpty == true)
            _InfoRow(
              label: 'Category',
              value: therapist.kategorijaUslugaNaziv!,
            ),
          const SizedBox(height: 12),
          _InfoRow(
            label: 'Languages',
            value: therapist.jezici?.trim().isNotEmpty == true
                ? therapist.jezici!
                : '—',
          ),
          const SizedBox(height: 8),
          Text('Education', style: _ProfileUi.bodyMuted(context)),
          const SizedBox(height: 6),
          Text(
            therapist.obrazovanje?.trim().isNotEmpty == true
                ? therapist.obrazovanje!
                : '—',
            style: _ProfileUi.bodyMuted(context).copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: _ProfileUi.bodyMuted(context)),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("This Week's Schedule", style: _ProfileUi.cardTitle(context)),
          const SizedBox(height: 16),
          if (schedule.isEmpty)
            Text('No schedule data.', style: _ProfileUi.bodyMuted(context))
          else
            for (var i = 0; i < schedule.length; i++) ...[
              _ScheduleRow(
                label: schedule[i].label,
                hours: schedule[i].hoursText,
              ),
              if (i < schedule.length - 1) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({required this.label, required this.hours});

  final String label;
  final String hours;

  bool get _isOff => hours == 'Day off';

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (!_isOff) ...[
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: _ProfileUi.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
        ] else
          const SizedBox(width: 18),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: _ProfileUi.textPrimary,
            ),
          ),
        ),
        Text(
          hours,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: _isOff ? _ProfileUi.textSecondary : _ProfileUi.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _PerformanceSummaryCard extends StatelessWidget {
  const _PerformanceSummaryCard({required this.kpi});

  final TherapistKpi? kpi;

  @override
  Widget build(BuildContext context) {
    final total = kpi?.ukupnoRezervacija ?? 0;
    final completed = kpi?.placeneRezervacije ?? kpi?.potvrdjeneRezervacije ?? 0;
    final cancelPct = kpi?.stopaOtkazivanjaPostotak ?? 0;
    final rating = (kpi?.prosjecnaOcjena ?? 0) > 0 ? kpi!.prosjecnaOcjena : 0;
    final satisfaction = kpi?.zadovoljstvoKlijenataPostotak;
    final revenue = kpi?.prihod ?? 0;

    final cancelTrend = kpi?.trendOtkazanePostotak;
    final cancelTrendBadge = TherapistKpi.badgePercent(cancelTrend);
    final cancelTrendPositive = cancelTrend == null || cancelTrend <= 0;

    final rows = <_PerfRow>[
      _PerfRow(
        'Total Appointments',
        '$total',
        badge: TherapistKpi.badgePercent(kpi?.trendUkupnoRezervacijaPostotak),
        positive: (kpi?.trendUkupnoRezervacijaPostotak ?? 0) >= 0,
      ),
      _PerfRow(
        'Completed Appointments',
        '$completed',
        badge: TherapistKpi.badgePercent(kpi?.trendPotvrdjenePostotak),
        positive: (kpi?.trendPotvrdjenePostotak ?? 0) >= 0,
      ),
      _PerfRow(
        'Cancellation Rate',
        '${cancelPct.toStringAsFixed(0)}%',
        badge: cancelTrendBadge,
        positive: cancelTrendPositive,
      ),
      _PerfRow(
        'Average Rating',
        rating > 0 ? '${rating.toStringAsFixed(1)} / 5' : '—',
        badge: TherapistKpi.badgeRatingDelta(kpi?.trendProsjecnaOcjenaDelta),
        positive: (kpi?.trendProsjecnaOcjenaDelta ?? 0) >= 0,
      ),
      _PerfRow(
        'Client Satisfaction',
        satisfaction != null ? '$satisfaction%' : '—',
        badge: TherapistKpi.badgePercent(kpi?.trendZadovoljstvoPostotak),
        positive: (kpi?.trendZadovoljstvoPostotak ?? 0) >= 0,
      ),
      _PerfRow(
        'Revenue Generated',
        revenue > 0 ? formatKm(revenue) : '—',
        badge: TherapistKpi.badgePercent(kpi?.trendPrihodPostotak),
        positive: (kpi?.trendPrihodPostotak ?? 0) >= 0,
      ),
    ];

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Performance Summary', style: _ProfileUi.cardTitle(context)),
          const SizedBox(height: 14),
          for (final row in rows) ...[
            _PerformanceRow(row: row),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _PerfRow {
  const _PerfRow(this.label, this.value, {this.badge, this.positive = true});

  final String label;
  final String value;
  final String? badge;
  final bool positive;
}

class _PerformanceRow extends StatelessWidget {
  const _PerformanceRow({required this.row});

  final _PerfRow row;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(row.label, style: _ProfileUi.bodyMuted(context)),
        ),
        Text(
          row.value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _ProfileUi.textPrimary,
          ),
        ),
        if (row.badge != null) ...[
          const SizedBox(width: 8),
          _TrendBadge(text: row.badge!, positive: row.positive),
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
              ),
              if (i < rows.length - 1) const SizedBox(height: 14),
            ],
        ],
      ),
    );
  }
}

class _ServiceProgressRow extends StatelessWidget {
  const _ServiceProgressRow({required this.label, required this.percent});

  final String label;
  final int percent;

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
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: _ProfileUi.accentPurple.withValues(alpha: 0.12),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            '${label[0].toUpperCase()}${label.substring(1)} — coming soon.',
            style: _ProfileUi.bodyMuted(context),
          ),
        ),
      ),
    );
  }
}

class _TherapistServicesPanel extends StatefulWidget {
  const _TherapistServicesPanel({
    required this.api,
    required this.therapist,
    required this.topServices,
  });

  final ApiService api;
  final Zaposlenik therapist;
  final List<TherapistTopService> topServices;

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

  Map<String, TherapistTopService> get _topByName {
    final map = <String, TherapistTopService>{};
    for (final s in widget.topServices) {
      final key = s.naziv.trim().toLowerCase();
      if (key.isNotEmpty) map[key] = s;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final katName = widget.therapist.kategorijaUslugaNaziv?.trim();
    final hasCategory =
        (widget.therapist.kategorijaUslugaId ?? 0) > 0 &&
        katName != null &&
        katName.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasCategory)
          _GlassCard(
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      colors: [
                        _ProfileUi.accentPurple,
                        _ProfileUi.accentSecondary,
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.spa_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Service category',
                        style: _ProfileUi.bodyMuted(context),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        katName,
                        style: _ProfileUi.cardTitle(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          _GlassCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: _ProfileUi.accentSecondary.withValues(alpha: 0.9),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No service category is assigned. Edit the therapist profile '
                    'and link a category to show eligible services here.',
                    style: _ProfileUi.bodyMuted(context),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        _TopServicesCard(
          topServices: widget.topServices,
          fallbackTags: widget.therapist.specijalizacija,
        ),
        const SizedBox(height: 16),
        _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Linked services',
                      style: _ProfileUi.cardTitle(context),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                hasCategory
                    ? 'Services in this therapist\'s category from the catalog.'
                    : 'Assign a category to list services.',
                style: _ProfileUi.bodyMuted(context),
              ),
              const SizedBox(height: 16),
              FutureBuilder<List<Usluga>>(
                future: _servicesFuture,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(28),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: _ProfileUi.accentPurple,
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  }
                  final services = snap.data ?? const <Usluga>[];
                  if (!hasCategory) {
                    return Text(
                      '—',
                      style: _ProfileUi.bodyMuted(context),
                    );
                  }
                  if (services.isEmpty) {
                    return Text(
                      'No services found for this category.',
                      style: _ProfileUi.bodyMuted(context),
                    );
                  }
                  return Column(
                    children: [
                      for (var i = 0; i < services.length; i++) ...[
                        _TherapistServiceTile(
                          service: services[i],
                          top: _topByName[services[i].naziv.trim().toLowerCase()],
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ServiceDetailsScreen(
                                  serviceId: services[i].id,
                                ),
                              ),
                            );
                          },
                        ),
                        if (i < services.length - 1)
                          Divider(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TherapistServiceTile extends StatelessWidget {
  const _TherapistServiceTile({
    required this.service,
    required this.onTap,
    this.top,
  });

  final Usluga service;
  final TherapistTopService? top;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _ProfileUi.accentPurple.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.design_services_outlined,
                  color: _ProfileUi.accentSecondary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.naziv,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _ProfileUi.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${service.cijenaKm} · ${service.trajanje}',
                      style: _ProfileUi.bodyMuted(context),
                    ),
                    if (top != null && top!.broj > 0) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${top!.broj} completed · ${top!.postotak.round()}% of volume',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _ProfileUi.accentSecondary.withValues(
                            alpha: 0.95,
                          ),
                        ),
                      ),
                    ],
                  ],
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
          const SizedBox(height: 16),
          if (reviews.isEmpty)
            Text(
              'No reviews yet for confirmed sessions with this therapist.',
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

class _TherapistAppointmentsPanelState extends State<_TherapistAppointmentsPanel> {
  late Future<List<Rezervacija>> _future = widget.api.getRezervacijeFiltered(
    includeOtkazane: true,
    zaposlenikId: widget.zaposlenikId,
  );

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Appointments', style: _ProfileUi.cardTitle(context)),
              ),
              TextButton.icon(
                onPressed: () => setState(() {
                  _future = widget.api.getRezervacijeFiltered(
                    includeOtkazane: true,
                    zaposlenikId: widget.zaposlenikId,
                  );
                }),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<Rezervacija>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: _ProfileUi.accentPurple,
                      strokeWidth: 2,
                    ),
                  ),
                );
              }
              final list = snap.data ?? const <Rezervacija>[];
              if (list.isEmpty) {
                return Text(
                  'No appointments for this therapist.',
                  style: _ProfileUi.bodyMuted(context),
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < list.length; i++) ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        list[i].korisnikIme ??
                            (list[i].korisnikEmail?.trim().isNotEmpty == true
                                ? list[i].korisnikEmail!
                                : 'Nepoznat klijent'),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: _ProfileUi.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        '${list[i].uslugaNaziv ?? 'Service'} · '
                        '${_fmt(list[i].datumRezervacije)}',
                        style: _ProfileUi.bodyMuted(context),
                      ),
                      trailing: Text(
                        list[i].isOtkazana
                            ? 'Cancelled'
                            : (list[i].isPotvrdjena ? 'Confirmed' : 'Pending'),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: list[i].isOtkazana
                              ? _ProfileUi.danger
                              : _ProfileUi.textSecondary,
                        ),
                      ),
                    ),
                    if (i < list.length - 1)
                      Divider(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) {
    final l = d.toLocal();
    return '${l.day.toString().padLeft(2, '0')}.'
        '${l.month.toString().padLeft(2, '0')}.'
        '${l.year} '
        '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }
}

class _InternaNapomenaPanel extends StatefulWidget {
  const _InternaNapomenaPanel({
    required this.api,
    required this.zaposlenikId,
    required this.profile,
    required this.onSaved,
  });

  final ApiService api;
  final int zaposlenikId;
  final TherapistAdminProfile? profile;
  final VoidCallback onSaved;

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
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not save note.')),
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
          if (!canEdit)
            Text(
              'This therapist has no linked user account.',
              style: _ProfileUi.bodyMuted(context),
            )
          else ...[
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
