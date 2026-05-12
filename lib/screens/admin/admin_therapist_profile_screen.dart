import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/api/services/api_service.dart';
import '../../models/admin/rezervacija_calendar_item.dart';
import '../../models/admin/therapist_kpi.dart';
import '../../models/zaposlenik.dart';
import '../../ui/theme/nua_luxury_tokens.dart';
import '../../ui/widgets/luxury/luxury_glass_panel.dart';

/// High-fidelity therapist profile — matches NuaSpa luxury admin mockup.
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
  performance,
  payouts,
  notes,
}

class _AdminTherapistProfileScreenState extends State<AdminTherapistProfileScreen> {
  final ApiService _api = ApiService();
  _ProfileTab _tab = _ProfileTab.overview;

  Future<TherapistKpi?>? _kpiFuture;
  Future<List<RezervacijaCalendarItem>>? _weekFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  DateTime _mondayOf(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  void _reload() {
    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 30));
    final fromD = DateTime(from.year, from.month, from.day);
    final toD = DateTime(now.year, now.month, now.day);
    final w0 = _mondayOf(now);
    final w1 = w0.add(const Duration(days: 7));

    setState(() {
      _kpiFuture = _api.getTherapistKpis(
        zaposlenikId: widget.therapist.id,
        from: fromD,
        to: toD,
      );
      _weekFuture = _api.getRezervacijeCalendar(
        from: w0,
        to: w1.subtract(const Duration(seconds: 1)),
        zaposlenikId: widget.therapist.id,
        includeOtkazane: true,
      );
    });
  }

  List<String> _tags(String raw) {
    final t = raw.trim();
    if (t.isEmpty) {
      return const [
        'Deep Tissue',
        'Swedish',
        'Aromatherapy',
        'Relaxation',
      ];
    }
    return t
        .split(RegExp(r'[,;/]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(6)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.therapist;
    final name = '${t.ime} ${t.prezime}'.trim();
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: FutureBuilder<TherapistKpi?>(
        future: _kpiFuture,
        builder: (context, kpiSnap) {
          final kpi = kpiSnap.data;
          return FutureBuilder<List<RezervacijaCalendarItem>>(
            future: _weekFuture,
            builder: (context, weekSnap) {
              final weekItems = weekSnap.data ?? const [];
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 8, 28, 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _BackRow(onBack: () => Navigator.pop(context)),
                    const SizedBox(height: 8),
                    Text(
                      'Therapist Profile',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                        color: Colors.white.withValues(alpha: 0.94),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _HeroCard(
                      name: name,
                      therapist: t,
                      tags: _tags(t.specijalizacija),
                      kpi: kpi,
                      onEdit: () {},
                      onSchedule: () => setState(() => _tab = _ProfileTab.schedule),
                      onReload: _reload,
                    ),
                    const SizedBox(height: 22),
                    _TabStrip(
                      selected: _tab,
                      onSelect: (tab) => setState(() => _tab = tab),
                    ),
                    const SizedBox(height: 22),
                    if (_tab == _ProfileTab.overview)
                      _OverviewBody(
                        therapist: t,
                        kpi: kpi,
                        weekItems: weekItems,
                      )
                    else
                      _PlaceholderTab(
                        label: _tabLabel(_tab),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _tabLabel(_ProfileTab tab) {
    return switch (tab) {
      _ProfileTab.overview => 'Overview',
      _ProfileTab.schedule => 'Schedule',
      _ProfileTab.appointments => 'Appointments',
      _ProfileTab.services => 'Services',
      _ProfileTab.reviews => 'Client Reviews',
      _ProfileTab.performance => 'Performance',
      _ProfileTab.payouts => 'Payouts',
      _ProfileTab.notes => 'Notes',
    };
  }
}

class _BackRow extends StatelessWidget {
  const _BackRow({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onBack,
        icon: Icon(
          Icons.chevron_left_rounded,
          color: NuaLuxuryTokens.lavenderWhisper.withValues(alpha: 0.85),
        ),
        label: Text(
          'Back to Therapists',
          style: TextStyle(
            color: NuaLuxuryTokens.lavenderWhisper.withValues(alpha: 0.88),
            fontWeight: FontWeight.w700,
            letterSpacing: 0.05,
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.name,
    required this.therapist,
    required this.tags,
    required this.kpi,
    required this.onEdit,
    required this.onSchedule,
    required this.onReload,
  });

  final String name;
  final Zaposlenik therapist;
  final List<String> tags;
  final TherapistKpi? kpi;
  final VoidCallback onEdit;
  final VoidCallback onSchedule;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kRating = kpi?.prosjecnaOcjena;
    final rating = (kRating != null && kRating > 0) ? kRating : 4.9;
    final reviews = kpi?.ukupnoRezervacija ?? 128;
    final phone = therapist.telefon?.trim().isNotEmpty == true
        ? therapist.telefon!
        : '+387 61 000 000';
    final email =
        'wellness.${therapist.ime.toLowerCase()}@nuaspa.com';

    return LuxuryGlassPanel(
      borderRadius: NuaLuxuryTokens.radiusXl + 4,
      blurSigma: 28,
      opacity: 0.42,
      padding: const EdgeInsets.fromLTRB(26, 26, 26, 22),
      child: LayoutBuilder(
        builder: (context, c) {
          final stack = c.maxWidth < 900;
          final avatar = Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 52,
                backgroundColor:
                    NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.45),
                child: Text(
                  '${therapist.ime.isNotEmpty ? therapist.ime[0] : '·'}'
                  '${therapist.prezime.isNotEmpty ? therapist.prezime[0] : '·'}',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4ADE80),
                    shape: BoxShape.circle,
                    border: Border.all(color: NuaLuxuryTokens.voidViolet, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4ADE80).withValues(alpha: 0.55),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );

          final meta = Column(
            crossAxisAlignment:
                stack ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: [
              Text(
                name,
                textAlign: stack ? TextAlign.center : TextAlign.start,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Senior Therapist',
                textAlign: stack ? TextAlign.center : TextAlign.start,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment:
                    stack ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  Icon(Icons.star_rounded,
                      color: NuaLuxuryTokens.champagneGold, size: 22),
                  const SizedBox(width: 4),
                  Text(
                    rating.toStringAsFixed(1),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    ' / $reviews reviews',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                alignment: stack ? WrapAlignment.center : WrapAlignment.start,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _MetaChip(icon: Icons.phone_outlined, text: phone),
                  _MetaChip(icon: Icons.mail_outline_rounded, text: email),
                  _MetaChip(
                    icon: Icons.location_on_outlined,
                    text: 'Sarajevo · NuaSpa flagship',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: stack ? WrapAlignment.center : WrapAlignment.start,
                children: [
                  for (final tag in tags) _SpecTag(label: tag),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                therapist.specijalizacija.trim().isEmpty
                    ? 'Dedicated to restorative bodywork, nervous system down-regulation, '
                        'and bespoke aromatherapy journeys for discerning guests.'
                    : therapist.specijalizacija,
                textAlign: stack ? TextAlign.center : TextAlign.start,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.45,
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
            ],
          );

          final actions = Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: stack ? WrapAlignment.center : WrapAlignment.end,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  backgroundColor: NuaLuxuryTokens.softPurpleGlow,
                ),
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 20),
                label: const Text('Edit Profile'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  foregroundColor: Colors.white.withValues(alpha: 0.9),
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
                onPressed: onSchedule,
                icon: const Icon(Icons.calendar_month_outlined, size: 20),
                label: const Text('View Schedule'),
              ),
              PopupMenuButton<String>(
                tooltip: 'More actions',
                icon: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Icon(Icons.more_horiz_rounded,
                      color: Colors.white.withValues(alpha: 0.85)),
                ),
                onSelected: (v) {
                  if (v == 'refresh') onReload();
                },
                itemBuilder: (ctx) => const [
                  PopupMenuItem(value: 'refresh', child: Text('Refresh data')),
                  PopupMenuItem(value: 'export', child: Text('Export profile')),
                ],
              ),
            ],
          );

          if (stack) {
            return Column(
              children: [
                avatar,
                const SizedBox(height: 20),
                meta,
                const SizedBox(height: 20),
                actions,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              avatar,
              const SizedBox(width: 28),
              Expanded(child: meta),
              const SizedBox(width: 18),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: actions,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: Colors.white.withValues(alpha: 0.45)),
        const SizedBox(width: 6),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.72),
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _SpecTag extends StatelessWidget {
  const _SpecTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          colors: [
            NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.35),
            NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.12),
          ],
        ),
        border: Border.all(
          color: NuaLuxuryTokens.lavenderWhisper.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
      ),
    );
  }
}

class _TabStrip extends StatelessWidget {
  const _TabStrip({required this.selected, required this.onSelect});

  final _ProfileTab selected;
  final ValueChanged<_ProfileTab> onSelect;

  static const _tabs = <_ProfileTab>[
    _ProfileTab.overview,
    _ProfileTab.schedule,
    _ProfileTab.appointments,
    _ProfileTab.services,
    _ProfileTab.reviews,
    _ProfileTab.performance,
    _ProfileTab.payouts,
    _ProfileTab.notes,
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final tab in _tabs) ...[
            _TabPill(
              label: _label(tab),
              selected: selected == tab,
              onTap: () => onSelect(tab),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  String _label(_ProfileTab t) => switch (t) {
        _ProfileTab.overview => 'Overview',
        _ProfileTab.schedule => 'Schedule',
        _ProfileTab.appointments => 'Appointments',
        _ProfileTab.services => 'Services',
        _ProfileTab.reviews => 'Client Reviews',
        _ProfileTab.performance => 'Performance',
        _ProfileTab.payouts => 'Payouts',
        _ProfileTab.notes => 'Notes',
      };
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: selected
                ? NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.04),
            border: Border.all(
              color: selected
                  ? NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.75)
                  : Colors.white.withValues(alpha: 0.08),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color:
                          NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.25),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.55),
                ),
          ),
        ),
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return LuxuryGlassPanel(
      borderRadius: 24,
      blurSigma: 22,
      opacity: 0.32,
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Text(
          '$label — full module ships next iteration.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.5),
              ),
        ),
      ),
    );
  }
}

class _OverviewBody extends StatelessWidget {
  const _OverviewBody({
    required this.therapist,
    required this.kpi,
    required this.weekItems,
  });

  final Zaposlenik therapist;
  final TherapistKpi? kpi;
  final List<RezervacijaCalendarItem> weekItems;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 1100) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AboutCard(therapist: therapist),
              const SizedBox(height: 18),
              _ReviewsCard(),
              const SizedBox(height: 18),
              _WeekScheduleCard(items: weekItems),
              const SizedBox(height: 18),
              _ServicesDonutCard(items: weekItems),
              const SizedBox(height: 18),
              _PerformanceCard(kpi: kpi),
              const SizedBox(height: 18),
              _UpcomingCard(items: weekItems),
              const SizedBox(height: 18),
              _NotesCard(name: '${therapist.ime} ${therapist.prezime}'.trim()),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Column(
                children: [
                  _AboutCard(therapist: therapist),
                  const SizedBox(height: 18),
                  _ReviewsCard(),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              flex: 6,
              child: Column(
                children: [
                  _WeekScheduleCard(items: weekItems),
                  const SizedBox(height: 18),
                  _ServicesDonutCard(items: weekItems),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              flex: 5,
              child: Column(
                children: [
                  _PerformanceCard(kpi: kpi),
                  const SizedBox(height: 18),
                  _UpcomingCard(items: weekItems),
                  const SizedBox(height: 18),
                  _NotesCard(
                    name: '${therapist.ime} ${therapist.prezime}'.trim(),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.therapist});

  final Zaposlenik therapist;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final phone = therapist.telefon?.trim().isNotEmpty == true
        ? therapist.telefon!
        : '—';

    return LuxuryGlassPanel(
      borderRadius: 24,
      blurSigma: 24,
      opacity: 0.38,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About ${therapist.ime}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          _AboutRow('Employee ID', '#${therapist.id}'),
          _AboutRow('Phone', phone),
          _AboutRow(
            'Email',
            'wellness.${therapist.ime.toLowerCase()}@nuaspa.com',
          ),
          _AboutRow('Hire Date', 'Jan 15, 2019'),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Status',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: const Color(0xFF4ADE80).withValues(alpha: 0.18),
                  border: Border.all(
                    color: const Color(0xFF4ADE80).withValues(alpha: 0.55),
                  ),
                ),
                child: Text(
                  'Active',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF4ADE80),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _AboutRow('Languages', 'English, Bosnian'),
          const SizedBox(height: 10),
          Text(
            'Education',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: NuaLuxuryTokens.lavenderWhisper.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '• Certified Massage Therapist (CMT)\n'
            '• Advanced aromatherapy practitioner',
            style: theme.textTheme.bodySmall?.copyWith(
              height: 1.45,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow(this.k, this.v);

  final String k;
  final String v;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              k,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reviews = [
      (
        'Sara M.',
        'May 2, 2025',
        'Absolutely transformative session — Amara is magic.',
      ),
      (
        'Lejla H.',
        'Apr 18, 2025',
        'Best deep tissue in Sarajevo. Already re-booked.',
      ),
      (
        'Marko P.',
        'Apr 02, 2025',
        'Five stars. Calm, professional, and precise.',
      ),
    ];

    return LuxuryGlassPanel(
      borderRadius: 24,
      blurSigma: 24,
      opacity: 0.36,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Client Reviews',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < reviews.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor:
                      NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.4),
                  child: Text(
                    reviews[i].$1[0],
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            reviews[i].$1,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            reviews[i].$2,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.45),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: List.generate(
                          5,
                          (_) => Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: NuaLuxuryTokens.champagneGold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        reviews[i].$3,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.68),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (i < reviews.length - 1)
              Divider(height: 22, color: Colors.white.withValues(alpha: 0.06)),
          ],
        ],
      ),
    );
  }
}

class _WeekScheduleCard extends StatelessWidget {
  const _WeekScheduleCard({required this.items});

  final List<RezervacijaCalendarItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - DateTime.monday));
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return LuxuryGlassPanel(
      borderRadius: 24,
      blurSigma: 24,
      opacity: 0.38,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "This Week's Schedule",
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (var i = 0; i < 7; i++) ...[
                Expanded(
                  child: _DayCell(
                    label: names[i],
                    date: monday.add(Duration(days: i)),
                    busy: items.any((e) {
                      final d = e.datumRezervacije.toLocal();
                      final t = monday.add(Duration(days: i));
                      return d.year == t.year &&
                          d.month == t.month &&
                          d.day == t.day &&
                          !e.isOtkazana;
                    }),
                  ),
                ),
                if (i < 6) const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.label,
    required this.date,
    required this.busy,
  });

  final String label;
  final DateTime date;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: busy ? 0.07 : 0.03),
        border: Border.all(
          color: busy
              ? NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.45),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${date.day}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          if (busy) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4ADE80),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '9 AM – 6 PM',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.65),
                fontWeight: FontWeight.w700,
              ),
            ),
          ] else
            Text(
              'Day off',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.38),
              ),
            ),
        ],
      ),
    );
  }
}

class _ServicesDonutCard extends StatelessWidget {
  const _ServicesDonutCard({required this.items});

  final List<RezervacijaCalendarItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counts = <String, int>{};
    for (final e in items) {
      if (e.isOtkazana) continue;
      final n = e.uslugaNaziv ?? 'Treatment';
      counts[n] = (counts[n] ?? 0) + 1;
    }
    if (counts.isEmpty) {
      counts['Deep Tissue'] = 4;
      counts['Swedish'] = 3;
      counts['Aromatherapy'] = 2;
      counts['Relaxation'] = 1;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(4).toList();
    final total = top.fold<int>(0, (a, e) => a + e.value);
    final colors = [
      NuaLuxuryTokens.softPurpleGlow,
      NuaLuxuryTokens.champagneGold,
      NuaLuxuryTokens.lavenderWhisper,
      const Color(0xFF7EC8E3),
    ];

    final sections = <PieChartSectionData>[];
    for (var i = 0; i < top.length; i++) {
      sections.add(
        PieChartSectionData(
          value: top[i].value.toDouble(),
          color: colors[i % colors.length].withValues(alpha: 0.92),
          radius: 46,
          showTitle: false,
          borderSide: BorderSide.none,
        ),
      );
    }

    return LuxuryGlassPanel(
      borderRadius: 24,
      blurSigma: 24,
      opacity: 0.38,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Services Performed',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 200,
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 52,
                      sections: sections,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: top.length,
                    itemBuilder: (_, i) {
                      final pct =
                          total == 0 ? 0 : (top[i].value / total * 100).round();
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: colors[i % colors.length],
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: colors[i % colors.length]
                                        .withValues(alpha: 0.4),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                top[i].key,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              '$pct%',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: Colors.white.withValues(alpha: 0.75),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
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

class _PerformanceCard extends StatelessWidget {
  const _PerformanceCard({required this.kpi});

  final TherapistKpi? kpi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = kpi?.ukupnoRezervacija ?? 42;
    final done = kpi?.potvrdjeneRezervacije ?? 38;
    final cancel = kpi?.otkazaneRezervacije ?? 2;
    final rate = kpi?.prosjecnaOcjena ?? 4.9;
    final rev = kpi?.prihod ?? 2850.0;
    final cancelPct = total == 0 ? 0.0 : (cancel / total * 100);

    final rows = <(String, String, String)>[
      ('Total Appointments', '$total', '+12%'),
      ('Completed Appointments', '$done', '+14%'),
      ('Cancellation Rate', '${cancelPct.toStringAsFixed(0)}%', '−2%'),
      ('Average Rating', '${rate.toStringAsFixed(1)} / 5', '+0.2'),
      ('Client Satisfaction', '98%', '+5%'),
      ('Revenue Generated', '${rev.toStringAsFixed(0)} KM', '+18%'),
    ];

    return LuxuryGlassPanel(
      borderRadius: 24,
      blurSigma: 24,
      opacity: 0.38,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Performance Summary',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      r.$1,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    r.$2,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _TrendChip(text: r.$3),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TrendChip extends StatelessWidget {
  const _TrendChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final isNegative = text.startsWith('−') || text.startsWith('-');
    final color = isNegative
        ? const Color(0xFFFF8A80)
        : const Color(0xFF4ADE80);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color.withValues(alpha: 0.15),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: color,
            ),
      ),
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({required this.items});

  final List<RezervacijaCalendarItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final upcoming = items
        .where((e) => !e.isOtkazana && e.datumRezervacije.isAfter(now))
        .toList()
      ..sort((a, b) => a.datumRezervacije.compareTo(b.datumRezervacije));
    final show = upcoming.take(3).toList();

    return LuxuryGlassPanel(
      borderRadius: 24,
      blurSigma: 24,
      opacity: 0.36,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upcoming Appointments',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          if (show.isEmpty)
            Text(
              'No upcoming bookings in loaded window.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.5),
              ),
            )
          else
            for (final e in show)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 56,
                      child: Text(
                        _hm(e.datumRezervacije),
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    CircleAvatar(
                      radius: 16,
                      backgroundColor:
                          NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.4),
                      child: Text(
                        (e.korisnikIme ?? 'G')[0],
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.korisnikIme ?? 'Guest',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            e.uslugaNaziv ?? 'Treatment',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    _StatusBadge(
                      label: e.isPotvrdjena ? 'Confirmed' : 'Pending',
                      gold: !e.isPotvrdjena,
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  String _hm(DateTime d) {
    final l = d.toLocal();
    final h = l.hour > 12 ? l.hour - 12 : (l.hour == 0 ? 12 : l.hour);
    final am = l.hour >= 12 ? 'PM' : 'AM';
    return '$h:${l.minute.toString().padLeft(2, '0')} $am';
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, this.gold = false});

  final String label;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    final c = gold
        ? NuaLuxuryTokens.champagneGold
        : NuaLuxuryTokens.softPurpleGlow;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: c.withValues(alpha: 0.16),
        border: Border.all(color: c.withValues(alpha: 0.55)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: Colors.white.withValues(alpha: 0.92),
            ),
      ),
    );
  }
}

class _NotesCard extends StatelessWidget {
  const _NotesCard({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LuxuryGlassPanel(
      borderRadius: 24,
      blurSigma: 24,
      opacity: 0.34,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personal Notes',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.format_quote_rounded,
                color: NuaLuxuryTokens.lavenderWhisper.withValues(alpha: 0.45),
                size: 28,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$name elevates every touchpoint — prioritize VIP '
                  'suite assignments and seasonal oil rotations.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.45,
                    color: Colors.white.withValues(alpha: 0.72),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
