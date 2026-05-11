import 'package:flutter/material.dart';

import '../../core/api/services/api_service.dart';
import '../../models/zaposlenik.dart';
import '../../ui/theme/nua_luxury_tokens.dart';
import '../../ui/widgets/luxury/luxury_glass_panel.dart';

class AdminTherapistRosterScreen extends StatefulWidget {
  const AdminTherapistRosterScreen({super.key});

  @override
  State<AdminTherapistRosterScreen> createState() =>
      _AdminTherapistRosterScreenState();
}

class _AdminTherapistRosterScreenState
    extends State<AdminTherapistRosterScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _specialty = TextEditingController();
  late Future<List<Zaposlenik>> _future;
  String _status = 'All Status';

  @override
  void initState() {
    super.initState();
    _future = _api.getZaposlenici();
  }

  @override
  void dispose() {
    _specialty.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Zaposlenik>>(
      future: _future,
      builder: (context, snap) {
        final therapists = _rosterFromApi(snap.data ?? const <Zaposlenik>[]);
        final filtered = therapists.where((t) {
          final s = _specialty.text.trim().toLowerCase();
          final matchesSpecialty =
              s.isEmpty ||
              t.specializations.any((x) => x.toLowerCase().contains(s));
          return matchesSpecialty;
        }).toList();

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
                    onStatusChanged: (value) => setState(() => _status = value),
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: snap.connectionState == ConnectionState.waiting
                        ? const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : _TherapistRosterList(therapists: filtered),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  List<_RosterTherapist> _rosterFromApi(List<Zaposlenik> api) {
    const fallbackNames = ['Amara', 'Lana', 'Mia', 'Zara', 'Marko'];
    const fallbackSpecs = [
      ['Deep Tissue', 'Swedish', 'Aromatherapy'],
      ['Prenatal', 'Facial', 'Thai Massage'],
      ['Facial', 'Aromatherapy', 'Stretching'],
      ['Sports Massage', 'Rehabilitation', 'Deep Tissue'],
      ['Thai Massage', 'Sports Massage', 'Swedish'],
    ];

    final rows = <_RosterTherapist>[
      for (var i = 0; i < api.length && i < 5; i++)
        _RosterTherapist(
          name: '${api[i].ime} ${api[i].prezime}'.trim(),
          role: i == 0 || i == 3 ? 'Senior Therapist' : 'Therapist',
          rating: (4.75 + (i * 0.04)).clamp(4.7, 4.95),
          reviews: 128 - (i * 13),
          specializations: _tags(api[i].specijalizacija, fallbackSpecs[i]),
          seed: api[i].id + i,
        ),
    ];

    for (var i = rows.length; i < 5; i++) {
      rows.add(
        _RosterTherapist(
          name: fallbackNames[i],
          role: i == 0 || i == 3 ? 'Senior Therapist' : 'Therapist',
          rating: [4.9, 4.8, 4.9, 4.7, 4.8][i],
          reviews: [128, 96, 142, 88, 74][i],
          specializations: fallbackSpecs[i],
          seed: i + 1,
        ),
      );
    }
    return rows;
  }

  List<String> _tags(String raw, List<String> fallback) {
    final tags = raw
        .split(RegExp(r'[,;/]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(4)
        .toList();
    return tags.isEmpty ? fallback : tags;
  }
}

class _TherapistActionBar extends StatelessWidget {
  const _TherapistActionBar({
    required this.status,
    required this.specialty,
    required this.onStatusChanged,
    required this.onChanged,
  });

  final String status;
  final TextEditingController specialty;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onChanged;

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
        _AddTherapistButton(),
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
            onPressed: () {},
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
  const _TherapistRosterList({required this.therapists});

  final List<_RosterTherapist> therapists;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 18),
            itemCount: therapists.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, i) =>
                _TherapistRosterCard(therapist: therapists[i], index: i),
          ),
        ),
        const _RosterPagination(),
      ],
    );
  }
}

class _TherapistRosterCard extends StatefulWidget {
  const _TherapistRosterCard({required this.therapist, required this.index});

  final _RosterTherapist therapist;
  final int index;

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
                    child: _WeeklyAvailability(seed: t.seed + widget.index),
                  ),
                  const SizedBox(width: 18),
                  const _RosterActions(),
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
                t.role,
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
                    t.rating.toStringAsFixed(1),
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '(${t.reviews} reviews)',
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
  const _WeeklyAvailability({required this.seed});

  final int seed;

  static final _week = List.generate(
    7,
    (i) => DateTime(2025, 5, 19).add(Duration(days: i)),
  );

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
              'May 19 – May 25, 2025',
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
            for (var i = 0; i < _week.length; i++)
              Expanded(
                child: _DayStatus(day: _week[i], status: _statusFor(seed, i)),
              ),
          ],
        ),
      ],
    );
  }

  _AvailabilityStatus _statusFor(int seed, int index) {
    final value = (seed + index) % 5;
    if (value == 0) return _AvailabilityStatus.unavailable;
    if (value == 2 || value == 4) return _AvailabilityStatus.partial;
    return _AvailabilityStatus.available;
  }
}

class _DayStatus extends StatelessWidget {
  const _DayStatus({required this.day, required this.status});

  final DateTime day;
  final _AvailabilityStatus status;

  @override
  Widget build(BuildContext context) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final color = switch (status) {
      _AvailabilityStatus.available => const Color(0xFF6EE7B7),
      _AvailabilityStatus.partial => NuaLuxuryTokens.champagneGold,
      _AvailabilityStatus.unavailable => NuaLuxuryTokens.softPurpleGlow,
    };
    return Column(
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
    );
  }
}

class _RosterActions extends StatelessWidget {
  const _RosterActions();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _RosterActionButton(icon: Icons.edit_outlined),
        SizedBox(height: 10),
        _RosterActionButton(icon: Icons.more_horiz_rounded),
      ],
    );
  }
}

class _RosterActionButton extends StatefulWidget {
  const _RosterActionButton({required this.icon});

  final IconData icon;

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
    );
  }
}

class _RosterPagination extends StatelessWidget {
  const _RosterPagination();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Showing 1 to 5 of 15 therapists',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: NuaLuxuryTokens.lavenderWhisper.withValues(alpha: 0.58),
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        _PageButton(label: '<'),
        const SizedBox(width: 8),
        _PageButton(label: '1', active: true),
        const SizedBox(width: 8),
        _PageButton(label: '2'),
        const SizedBox(width: 8),
        _PageButton(label: '3'),
        const SizedBox(width: 8),
        _PageButton(label: '>'),
      ],
    );
  }
}

class _PageButton extends StatelessWidget {
  const _PageButton({required this.label, this.active = false});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
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
                  color: NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.28),
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

class _RosterTherapist {
  const _RosterTherapist({
    required this.name,
    required this.role,
    required this.rating,
    required this.reviews,
    required this.specializations,
    required this.seed,
  });

  final String name;
  final String role;
  final double rating;
  final int reviews;
  final List<String> specializations;
  final int seed;
}

enum _AvailabilityStatus { available, partial, unavailable }
