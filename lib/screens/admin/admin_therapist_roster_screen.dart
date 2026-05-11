import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/services/api_service.dart';
import '../../models/admin/rezervacija_calendar_item.dart';
import '../../models/admin/therapist_kpi.dart';
import '../../models/zaposlenik.dart';
import '../../ui/navigation/desktop_nav.dart';
import '../../ui/theme/nua_luxury_tokens.dart';
import '../../ui/widgets/luxury/luxury_glass_panel.dart';
import 'admin_therapist_profile_screen.dart';

class AdminTherapistRosterScreen extends StatefulWidget {
  const AdminTherapistRosterScreen({super.key});

  @override
  State<AdminTherapistRosterScreen> createState() =>
      _AdminTherapistRosterScreenState();
}

class _AdminTherapistRosterScreenState
    extends State<AdminTherapistRosterScreen> {
  static const _pageSize = 5;

  final ApiService _api = ApiService();
  final TextEditingController _specialty = TextEditingController();
  late Future<_TherapistRosterData> _future;
  String _status = 'All Status';
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _future = _loadRoster();
  }

  @override
  void dispose() {
    _specialty.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final navQuery = context.watch<DesktopNav>().therapistSearchQuery;
    return FutureBuilder<_TherapistRosterData>(
      future: _future,
      builder: (context, snap) {
        final data = snap.data ?? _TherapistRosterData.empty();
        final therapists = data.therapists;
        final filtered = therapists.where((t) {
          final q = navQuery.trim().toLowerCase();
          final s = _specialty.text.trim().toLowerCase();
          final matchesSearch =
              q.isEmpty ||
              t.name.toLowerCase().contains(q) ||
              t.specializations.any((x) => x.toLowerCase().contains(q));
          final matchesSpecialty =
              s.isEmpty ||
              t.specializations.any((x) => x.toLowerCase().contains(s));
          final matchesStatus =
              _status == 'All Status' || t.rosterStatus == _status;
          return matchesSearch && matchesSpecialty && matchesStatus;
        }).toList();
        final maxPage = filtered.isEmpty
            ? 0
            : ((filtered.length - 1) / _pageSize).floor();
        final page = _page.clamp(0, maxPage);
        if (page != _page) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _page = page);
          });
        }
        final visible = filtered
            .skip(page * _pageSize)
            .take(_pageSize)
            .toList();

        return Stack(
          children: [
            Positioned(
              top: 20,
              right: 44,
              child: _AmbientOrb(
                size: 260,
                color: NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.16),
              ),
            ),
            Positioned(
              left: 120,
              bottom: 26,
              child: _AmbientOrb(
                size: 220,
                color: NuaLuxuryTokens.champagneGold.withValues(alpha: 0.08),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TherapistActionBar(
                    status: _status,
                    specialty: _specialty,
                    onStatusChanged: (value) => setState(() {
                      _status = value;
                      _page = 0;
                    }),
                    onChanged: () => setState(() => _page = 0),
                    onAdd: () => _editTherapist(null),
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: snap.connectionState == ConnectionState.waiting
                        ? const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : _TherapistRosterList(
                            therapists: visible,
                            totalCount: filtered.length,
                            page: page,
                            pageSize: _pageSize,
                            onPageChanged: (next) =>
                                setState(() => _page = next.clamp(0, maxPage)),
                            onEdit: _editTherapist,
                            onDelete: _deleteTherapist,
                            onOpenProfile: _openProfile,
                            onOpenDay: _openDaySlots,
                          ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<_TherapistRosterData> _loadRoster() async {
    final weekStart = _startOfWeek(DateTime.now());
    final weekDays = List.generate(7, (i) => weekStart.add(Duration(days: i)));
    final therapists = await _api.getZaposlenici();
    final from30 = DateTime.now().subtract(const Duration(days: 30));
    final kpis = await Future.wait(
      therapists.map(
        (t) => _api.getTherapistKpis(
          zaposlenikId: t.id,
          from: from30,
          to: DateTime.now(),
        ),
      ),
    );
    final calendar = await _api.getRezervacijeCalendar(
      from: weekStart,
      to: weekStart.add(const Duration(days: 6)),
      includeOtkazane: false,
    );

    final kpiById = <int, TherapistKpi?>{};
    for (var i = 0; i < therapists.length; i++) {
      kpiById[therapists[i].id] = kpis[i];
    }

    return _TherapistRosterData(
      weekDays: weekDays,
      therapists: [
        for (final therapist in therapists)
          _buildRosterTherapist(
            therapist,
            kpiById[therapist.id],
            weekDays,
            calendar,
          ),
      ],
    );
  }

  _RosterTherapist _buildRosterTherapist(
    Zaposlenik therapist,
    TherapistKpi? kpi,
    List<DateTime> weekDays,
    List<RezervacijaCalendarItem> calendar,
  ) {
    final statuses = [
      for (final day in weekDays)
        _statusFromBookings(
          calendar
              .where(
                (r) =>
                    r.zaposlenikId == therapist.id &&
                    _sameDay(r.datumRezervacije, day),
              )
              .length,
        ),
    ];
    final rating = (kpi?.prosjecnaOcjena ?? 0) <= 0
        ? null
        : kpi!.prosjecnaOcjena;
    final appointmentCount = kpi?.ukupnoRezervacija ?? 0;
    return _RosterTherapist(
      zaposlenik: therapist,
      name: '${therapist.ime} ${therapist.prezime}'.trim(),
      role: appointmentCount >= 20 ? 'Senior Therapist' : 'Therapist',
      rating: rating,
      reviews: appointmentCount,
      specializations: _tags(therapist.specijalizacija),
      weekDays: weekDays,
      weekStatuses: statuses,
      paidAppointments: kpi?.placeneRezervacije ?? 0,
      revenue: kpi?.prihod ?? 0,
    );
  }

  List<String> _tags(String raw) {
    final tags = raw
        .split(RegExp(r'[,;/]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(4)
        .toList();
    return tags;
  }

  _AvailabilityStatus _statusFromBookings(int count) {
    if (count >= 5) return _AvailabilityStatus.unavailable;
    if (count > 0) return _AvailabilityStatus.partial;
    return _AvailabilityStatus.available;
  }

  String _hm(DateTime d) {
    final loc = d.toLocal();
    return '${loc.hour.toString().padLeft(2, '0')}:${loc.minute.toString().padLeft(2, '0')}';
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _startOfWeek(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  void _reload() {
    setState(() {
      _future = _loadRoster();
    });
  }

  void _openProfile(_RosterTherapist therapist) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            AdminTherapistProfileScreen(therapist: therapist.zaposlenik),
      ),
    );
  }

  Future<void> _openDaySlots(_RosterTherapist therapist, DateTime day) async {
    final slots = await _api.getDostupniTermini(
      zaposlenikId: therapist.zaposlenik.id,
      datum: day,
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '${therapist.name} · ${day.toLocal().toString().split(' ').first}',
        ),
        content: SizedBox(
          width: 520,
          child: slots.isEmpty
              ? const Text('Nema slobodnih termina za ovaj dan.')
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final slot in slots) Chip(label: Text(_hm(slot))),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Zatvori'),
          ),
        ],
      ),
    );
  }

  Future<void> _editTherapist(_RosterTherapist? existing) async {
    final saved = await showDialog<Zaposlenik>(
      context: context,
      builder: (_) => _TherapistEditorDialog(existing: existing?.zaposlenik),
    );
    if (saved == null || !mounted) return;

    final result = existing == null
        ? await _api.createZaposlenik(saved)
        : await _api.updateZaposlenik(saved);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == null
              ? 'Greška pri čuvanju terapeuta.'
              : 'Terapeut sačuvan.',
        ),
      ),
    );
    if (result != null) _reload();
  }

  Future<void> _deleteTherapist(_RosterTherapist therapist) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Obrisati terapeuta?'),
        content: Text(
          'Ova akcija će pokušati obrisati ${therapist.name}. Terapeuti s postojećim rezervacijama neće biti obrisani.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Obriši'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final error = await _api.deleteZaposlenik(therapist.zaposlenik.id);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error ?? 'Terapeut obrisan.')));
    if (error == null) _reload();
  }
}

class _TherapistActionBar extends StatelessWidget {
  const _TherapistActionBar({
    required this.status,
    required this.specialty,
    required this.onStatusChanged,
    required this.onChanged,
    required this.onAdd,
  });

  final String status;
  final TextEditingController specialty;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onChanged;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _GlassDropdown(
          value: status,
          values: const [
            'All Status',
            'Available',
            'Partially Booked',
            'Offline',
          ],
          onChanged: onStatusChanged,
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 320,
          child: _GlassField(
            controller: specialty,
            hint: 'Filter by specialty…',
            icon: Icons.manage_search_rounded,
            onChanged: onChanged,
          ),
        ),
        const Spacer(),
        _AddTherapistButton(onPressed: onAdd),
      ],
    );
  }
}

class _GlassDropdown extends StatelessWidget {
  const _GlassDropdown({
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return LuxuryGlassPanel(
      borderRadius: 18,
      blurSigma: 18,
      opacity: 0.28,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: NuaLuxuryTokens.voidViolet,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          items: [
            for (final item in values)
              DropdownMenuItem(value: item, child: Text(item)),
          ],
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ),
    );
  }
}

class _GlassField extends StatelessWidget {
  const _GlassField({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return LuxuryGlassPanel(
      borderRadius: 18,
      blurSigma: 18,
      opacity: 0.24,
      padding: EdgeInsets.zero,
      child: TextField(
        controller: controller,
        onChanged: (_) => onChanged(),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: NuaLuxuryTokens.lavenderWhisper),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
        ),
      ),
    );
  }
}

class _AddTherapistButton extends StatefulWidget {
  const _AddTherapistButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_AddTherapistButton> createState() => _AddTherapistButtonState();
}

class _AddTherapistButtonState extends State<_AddTherapistButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedScale(
        scale: _hover ? 1.018 : 1,
        duration: const Duration(milliseconds: 180),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Color(0xFF7B4DFF), Color(0xFF9B6DFF)],
            ),
            boxShadow: [
              BoxShadow(
                color: NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.32),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: widget.onPressed,
            icon: const Icon(Icons.add_rounded),
            label: const Text(
              'Add New Therapist',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ),
    );
  }
}

class _TherapistRosterList extends StatelessWidget {
  const _TherapistRosterList({
    required this.therapists,
    required this.totalCount,
    required this.page,
    required this.pageSize,
    required this.onPageChanged,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenProfile,
    required this.onOpenDay,
  });

  final List<_RosterTherapist> therapists;
  final int totalCount;
  final int page;
  final int pageSize;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<_RosterTherapist> onEdit;
  final ValueChanged<_RosterTherapist> onDelete;
  final ValueChanged<_RosterTherapist> onOpenProfile;
  final void Function(_RosterTherapist therapist, DateTime day) onOpenDay;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 18),
            itemCount: therapists.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, i) => _TherapistRosterCard(
              therapist: therapists[i],
              onEdit: onEdit,
              onDelete: onDelete,
              onOpenProfile: onOpenProfile,
              onOpenDay: onOpenDay,
            ),
          ),
        ),
        _RosterPagination(
          totalCount: totalCount,
          page: page,
          pageSize: pageSize,
          onPageChanged: onPageChanged,
        ),
      ],
    );
  }
}

class _TherapistRosterCard extends StatefulWidget {
  const _TherapistRosterCard({
    required this.therapist,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenProfile,
    required this.onOpenDay,
  });

  final _RosterTherapist therapist;
  final ValueChanged<_RosterTherapist> onEdit;
  final ValueChanged<_RosterTherapist> onDelete;
  final ValueChanged<_RosterTherapist> onOpenProfile;
  final void Function(_RosterTherapist therapist, DateTime day) onOpenDay;

  @override
  State<_TherapistRosterCard> createState() => _TherapistRosterCardState();
}

class _TherapistRosterCardState extends State<_TherapistRosterCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.therapist;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: _hover ? 1.006 : 1,
        duration: const Duration(milliseconds: 180),
        child: LuxuryGlassPanel(
          borderRadius: 24,
          blurSigma: _hover ? 30 : 22,
          opacity: _hover ? 0.46 : 0.36,
          borderOpacity: _hover ? 0.2 : 0.1,
          padding: const EdgeInsets.fromLTRB(22, 20, 18, 20),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 1030),
              child: Row(
                children: [
                  SizedBox(width: 250, child: _TherapistProfile(t: t)),
                  const SizedBox(width: 24),
                  SizedBox(
                    width: 300,
                    child: _Specializations(tags: t.specializations),
                  ),
                  const SizedBox(width: 30),
                  SizedBox(
                    width: 360,
                    child: _WeeklyAvailability(
                      weekDays: t.weekDays,
                      statuses: t.weekStatuses,
                      onOpenDay: (day) => widget.onOpenDay(t, day),
                    ),
                  ),
                  const SizedBox(width: 18),
                  _RosterActions(
                    onEdit: () => widget.onEdit(t),
                    onDelete: () => widget.onDelete(t),
                    onOpenProfile: () => widget.onOpenProfile(t),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TherapistProfile extends StatelessWidget {
  const _TherapistProfile({required this.t});

  final _RosterTherapist t;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Stack(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.72),
                    NuaLuxuryTokens.champagneGold.withValues(alpha: 0.42),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: NuaLuxuryTokens.softPurpleGlow.withValues(
                      alpha: 0.28,
                    ),
                    blurRadius: 22,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  _initials(t.name),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFF5F3FA),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                width: 15,
                height: 15,
                decoration: BoxDecoration(
                  color: const Color(0xFF6EE7B7),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: NuaLuxuryTokens.deepIndigo,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6EE7B7).withValues(alpha: 0.48),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFF5F3FA),
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${t.role} · ${t.paidAppointments} paid · ${t.revenue.toStringAsFixed(0)} KM',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: NuaLuxuryTokens.lavenderWhisper.withValues(
                    alpha: 0.62,
                  ),
                ),
              ),
              const SizedBox(height: 11),
              Row(
                children: [
                  const Icon(
                    Icons.star_rounded,
                    color: NuaLuxuryTokens.champagneGold,
                    size: 18,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    t.rating == null ? '—' : t.rating!.toStringAsFixed(1),
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '(${t.reviews} appointments)',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'NS';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class _Specializations extends StatelessWidget {
  const _Specializations({required this.tags});

  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Specializations',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w900,
            color: Colors.white.withValues(alpha: 0.78),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in tags)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: NuaLuxuryTokens.softPurpleGlow.withValues(
                      alpha: 0.22,
                    ),
                  ),
                ),
                child: Text(
                  tag,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: NuaLuxuryTokens.lavenderWhisper.withValues(
                      alpha: 0.86,
                    ),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _WeeklyAvailability extends StatelessWidget {
  const _WeeklyAvailability({
    required this.weekDays,
    required this.statuses,
    required this.onOpenDay,
  });

  final List<DateTime> weekDays;
  final List<_AvailabilityStatus> statuses;
  final ValueChanged<DateTime> onOpenDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Weekly Availability',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Colors.white.withValues(alpha: 0.78),
                ),
              ),
            ),
            Text(
              '${_dateLabel(weekDays.first)} – ${_dateLabel(weekDays.last)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: NuaLuxuryTokens.lavenderWhisper.withValues(alpha: 0.55),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            for (var i = 0; i < weekDays.length; i++)
              Expanded(
                child: _DayStatus(
                  day: weekDays[i],
                  status: statuses[i],
                  onTap: () => onOpenDay(weekDays[i]),
                ),
              ),
          ],
        ),
      ],
    );
  }

  String _dateLabel(DateTime day) {
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
    return '${months[day.month - 1]} ${day.day}';
  }
}

class _DayStatus extends StatelessWidget {
  const _DayStatus({
    required this.day,
    required this.status,
    required this.onTap,
  });

  final DateTime day;
  final _AvailabilityStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final color = switch (status) {
      _AvailabilityStatus.available => const Color(0xFF6EE7B7),
      _AvailabilityStatus.partial => NuaLuxuryTokens.champagneGold,
      _AvailabilityStatus.unavailable => NuaLuxuryTokens.softPurpleGlow,
    };
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Column(
        children: [
          Text(
            names[day.weekday - 1],
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.56),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${day.day}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 11),
          Container(
            width: 15,
            height: 15,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RosterActions extends StatelessWidget {
  const _RosterActions({
    required this.onEdit,
    required this.onDelete,
    required this.onOpenProfile,
  });

  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _RosterActionButton(icon: Icons.edit_outlined, onTap: onEdit),
        const SizedBox(height: 10),
        PopupMenuButton<String>(
          tooltip: 'Akcije',
          color: NuaLuxuryTokens.voidViolet,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          onSelected: (value) {
            if (value == 'profile') onOpenProfile();
            if (value == 'delete') onDelete();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'profile', child: Text('View profile')),
            PopupMenuItem(value: 'delete', child: Text('Delete therapist')),
          ],
          child: const _RosterActionButton(icon: Icons.more_horiz_rounded),
        ),
      ],
    );
  }
}

class _RosterActionButton extends StatefulWidget {
  const _RosterActionButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  State<_RosterActionButton> createState() => _RosterActionButtonState();
}

class _RosterActionButtonState extends State<_RosterActionButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: _hover ? 0.09 : 0.045),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: NuaLuxuryTokens.lavenderWhisper.withValues(
                alpha: _hover ? 0.3 : 0.12,
              ),
            ),
            boxShadow: _hover
                ? [
                    BoxShadow(
                      color: NuaLuxuryTokens.softPurpleGlow.withValues(
                        alpha: 0.18,
                      ),
                      blurRadius: 16,
                    ),
                  ]
                : null,
          ),
          child: Icon(widget.icon, size: 20),
        ),
      ),
    );
  }
}

class _RosterPagination extends StatelessWidget {
  const _RosterPagination({
    required this.totalCount,
    required this.page,
    required this.pageSize,
    required this.onPageChanged,
  });

  final int totalCount;
  final int page;
  final int pageSize;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final from = totalCount == 0 ? 0 : page * pageSize + 1;
    final to = (from + pageSize - 1).clamp(0, totalCount);
    final pages = totalCount == 0
        ? 1
        : ((totalCount - 1) / pageSize).floor() + 1;
    return Row(
      children: [
        Text(
          'Showing $from to $to of $totalCount therapists',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: NuaLuxuryTokens.lavenderWhisper.withValues(alpha: 0.58),
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        _PageButton(label: '<', onTap: () => onPageChanged(page - 1)),
        const SizedBox(width: 8),
        for (var i = 0; i < pages; i++) ...[
          _PageButton(
            label: '${i + 1}',
            active: i == page,
            onTap: () => onPageChanged(i),
          ),
          const SizedBox(width: 8),
        ],
        _PageButton(label: '>', onTap: () => onPageChanged(page + 1)),
      ],
    );
  }
}

class _PageButton extends StatelessWidget {
  const _PageButton({
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: active
              ? NuaLuxuryTokens.softPurpleGlow
              : Colors.white.withValues(alpha: 0.045),
          border: Border.all(
            color: active
                ? NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.88)
                : Colors.white.withValues(alpha: 0.1),
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: NuaLuxuryTokens.softPurpleGlow.withValues(
                      alpha: 0.28,
                    ),
                    blurRadius: 16,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w900,
            color: const Color(0xFFF5F3FA),
          ),
        ),
      ),
    );
  }
}

class _AmbientOrb extends StatelessWidget {
  const _AmbientOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [BoxShadow(color: color, blurRadius: size * 0.42)],
        ),
      ),
    );
  }
}

class _TherapistEditorDialog extends StatefulWidget {
  const _TherapistEditorDialog({this.existing});

  final Zaposlenik? existing;

  @override
  State<_TherapistEditorDialog> createState() => _TherapistEditorDialogState();
}

class _TherapistEditorDialogState extends State<_TherapistEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _ime = TextEditingController(
    text: widget.existing?.ime ?? '',
  );
  late final TextEditingController _prezime = TextEditingController(
    text: widget.existing?.prezime ?? '',
  );
  late final TextEditingController _specijalizacija = TextEditingController(
    text: widget.existing?.specijalizacija ?? '',
  );
  late final TextEditingController _telefon = TextEditingController(
    text: widget.existing?.telefon ?? '',
  );

  @override
  void dispose() {
    _ime.dispose();
    _prezime.dispose();
    _specijalizacija.dispose();
    _telefon.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add therapist' : 'Edit therapist'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _ime,
                decoration: const InputDecoration(labelText: 'Ime'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Ime je obavezno.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _prezime,
                decoration: const InputDecoration(labelText: 'Prezime'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Prezime je obavezno.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _specijalizacija,
                decoration: const InputDecoration(
                  labelText: 'Specijalizacije',
                  helperText: 'Odvojite tagove zarezom, npr. Swedish, Facial',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Specijalizacija je obavezna.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _telefon,
                decoration: const InputDecoration(
                  labelText: 'Telefon (opcionalno)',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Otkaži'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              Zaposlenik(
                id: widget.existing?.id ?? 0,
                ime: _ime.text.trim(),
                prezime: _prezime.text.trim(),
                specijalizacija: _specijalizacija.text.trim(),
                telefon: _telefon.text.trim().isEmpty
                    ? null
                    : _telefon.text.trim(),
              ),
            );
          },
          child: const Text('Sačuvaj'),
        ),
      ],
    );
  }
}

class _TherapistRosterData {
  const _TherapistRosterData({
    required this.weekDays,
    required this.therapists,
  });

  final List<DateTime> weekDays;
  final List<_RosterTherapist> therapists;

  factory _TherapistRosterData.empty() {
    final start = DateTime.now();
    return _TherapistRosterData(
      weekDays: List.generate(7, (i) => start.add(Duration(days: i))),
      therapists: const [],
    );
  }
}

class _RosterTherapist {
  const _RosterTherapist({
    required this.zaposlenik,
    required this.name,
    required this.role,
    required this.rating,
    required this.reviews,
    required this.specializations,
    required this.weekDays,
    required this.weekStatuses,
    required this.paidAppointments,
    required this.revenue,
  });

  final Zaposlenik zaposlenik;
  final String name;
  final String role;
  final double? rating;
  final int reviews;
  final List<String> specializations;
  final List<DateTime> weekDays;
  final List<_AvailabilityStatus> weekStatuses;
  final int paidAppointments;
  final double revenue;

  String get rosterStatus {
    if (weekStatuses.every((x) => x == _AvailabilityStatus.available)) {
      return 'Available';
    }
    if (weekStatuses.every((x) => x == _AvailabilityStatus.unavailable)) {
      return 'Offline';
    }
    return 'Partially Booked';
  }
}

enum _AvailabilityStatus { available, partial, unavailable }
