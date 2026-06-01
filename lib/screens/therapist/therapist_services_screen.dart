import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/api/services/api_service.dart';
import '../../core/auth/app_permissions.dart';
import '../../models/kategorija_usluga.dart';
import '../../models/usluga.dart';
import '../../models/zaposlenik.dart';
import '../../providers/auth_provider.dart';
import '../../ui/navigation/desktop_nav.dart';
import '../catalog/service_details_screen.dart';
import 'therapist_portal_scaffold.dart';
import '../../ui/widgets/service_network_image.dart';

abstract final class _SvcUi {
  static const bgTop = Color(0xFF07040F);
  static const bgBottom = Color(0xFF120A24);
  static const textPrimary = Color(0xFFF5F3FA);
  static const textSecondary = Color(0xA6FFFFFF);
  static const purple = Color(0xFF7B4DFF);
  static const lavender = Color(0xFF9D6BFF);
  static const gold = Color(0xFFF5B942);
  static const cardRadius = 24.0;
  static const heroRadius = 30.0;
  static const gap = 24.0;
  static const sidebarWidth = 340.0;
  static const contentPadding = 32.0;
}

class _ServicesData {
  const _ServicesData({
    required this.me,
    required this.linked,
    required this.categories,
  });

  final Zaposlenik? me;
  final List<Usluga> linked;
  final List<KategorijaUsluga> categories;
}

List<String> _specializationTags(String raw) => raw
    .split(RegExp(r'[,;/]'))
    .map((e) => e.trim())
    .where((e) => e.isNotEmpty)
    .toList();

List<Usluga> _linkedServices(Zaposlenik me, List<Usluga> all) {
  final katId = me.kategorijaUslugaId;
  if (katId != null && katId > 0) {
    return all.where((u) => u.kategorijaUslugaId == katId).toList()
      ..sort((a, b) => a.naziv.compareTo(b.naziv));
  }
  final tags = _specializationTags(me.specijalizacija)
      .map((e) => e.toLowerCase())
      .toSet();
  if (tags.isEmpty) return const [];
  return all
      .where((u) => tags.contains(u.naziv.trim().toLowerCase()))
      .toList()
    ..sort((a, b) => a.naziv.compareTo(b.naziv));
}

List<KategorijaUsluga> _categoriesFromServices(List<Usluga> services) {
  final seen = <int>{};
  final out = <KategorijaUsluga>[];
  for (final s in services) {
    final id = s.kategorijaUslugaId;
    if (id <= 0 || !seen.add(id)) continue;
    out.add(KategorijaUsluga(id: id, naziv: s.kategorija));
  }
  out.sort((a, b) => a.naziv.compareTo(b.naziv));
  return out;
}

String _durationLabel(Usluga u) {
  if (u.trajanjeMinuta > 0) return '${u.trajanjeMinuta} min';
  final m = RegExp(r'(\d+)').firstMatch(u.trajanje);
  if (m != null) return '${m.group(1)} min';
  return u.trajanje;
}

String _tierLabel(Usluga u, List<Usluga> linked) {
  if (linked.isEmpty) return 'Standard';
  final prices = linked.map((e) => e.cijena).toList()..sort();
  final median = prices[prices.length ~/ 2];
  final name = u.naziv.toLowerCase();
  if (name.contains('facial') && u.cijena <= median) return 'Standard';
  if (u.trajanjeMinuta >= 75 || u.cijena > median) return 'Premium';
  return 'Standard';
}

List<Usluga> _sortServices(List<Usluga> list, String mode) {
  final copy = [...list];
  switch (mode) {
    case 'Z to A':
      copy.sort((a, b) => b.naziv.compareTo(a.naziv));
    case 'Duration':
      copy.sort((a, b) => b.trajanjeMinuta.compareTo(a.trajanjeMinuta));
    case 'Price: High to Low':
      copy.sort((a, b) => b.cijena.compareTo(a.cijena));
    default:
      copy.sort((a, b) => a.naziv.compareTo(b.naziv));
  }
  return copy;
}

List<(String, int)> _topCertificationRows(List<String> tags) {
  const weights = [40, 30, 20, 10];
  final rows = <(String, int)>[];
  for (var i = 0; i < tags.length && i < 4; i++) {
    rows.add((tags[i], weights[i]));
  }
  return rows;
}

class TherapistServicesScreen extends StatefulWidget {
  const TherapistServicesScreen({super.key});

  @override
  State<TherapistServicesScreen> createState() =>
      _TherapistServicesScreenState();
}

class _TherapistServicesScreenState extends State<TherapistServicesScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  Future<_ServicesData>? _future;
  final _scrollCtrl = ScrollController();
  int? _categoryFilterId;
  String _sortMode = 'A to Z';
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
    _scrollCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
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
        if (me == null) {
          return const _ServicesData(me: null, linked: [], categories: []);
        }
        final linked = _linkedServices(me, all);
        return _ServicesData(
          me: me,
          linked: linked,
          categories: _categoriesFromServices(linked),
        );
      }();
    });
  }

  List<Usluga> _filterList(List<Usluga> linked) {
    var list = linked.where((u) {
      if (_categoryFilterId != null &&
          u.kategorijaUslugaId != _categoryFilterId) {
        return false;
      }
      return true;
    }).toList();
    return _sortServices(list, _sortMode);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        width: 440,
      ),
    );
  }

  void _openFilterSheet(List<KategorijaUsluga> categories) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _SvcUi.bgBottom,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Filter by category',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _SvcUi.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _FilterChip(
                      label: 'All',
                      selected: _categoryFilterId == null,
                      onTap: () {
                        setState(() => _categoryFilterId = null);
                        Navigator.pop(ctx);
                      },
                    ),
                    for (final c in categories)
                      _FilterChip(
                        label: c.naziv,
                        selected: _categoryFilterId == c.id,
                        onTap: () {
                          setState(() => _categoryFilterId = c.id);
                          Navigator.pop(ctx);
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!AppPermissions.of(auth).has(AppPermission.viewOwnTherapistData)) {
      return const _ServicesShell(
        child: TherapistEmptyState(message: 'Therapist login required.'),
      );
    }

    return _ServicesShell(
      child: RefreshIndicator(
        color: _SvcUi.lavender,
        onRefresh: _reload,
        child: FutureBuilder<_ServicesData>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 200),
                  Center(
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ],
              );
            }

            final data = snap.data;
            final me = data?.me;
            if (data == null || me == null) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(_SvcUi.contentPadding),
                children: [
                  _SvcGlass(
                    child: Column(
                      children: [
                        Text(
                          'Could not load your service list.',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w800,
                            color: _SvcUi.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _PrimaryButton(
                          label: 'Try again',
                          icon: Icons.refresh_rounded,
                          onTap: _reload,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            final tags = _specializationTags(me.specijalizacija);
            final filtered = _filterList(data.linked);
            final katName = me.kategorijaUslugaNaziv?.trim();

            return FadeTransition(
              opacity: _fadeAnim,
              child: LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth >= 1100;
                  final main = _MainColumn(
                    me: me,
                    linked: data.linked,
                    filtered: filtered,
                    tags: tags,
                    categoryName: katName,
                    categoriesCount: data.categories.length,
                    sortMode: _sortMode,
                    onSort: (v) => setState(() => _sortMode = v),
                    onFilter: () => _openFilterSheet(data.categories),
                    onOpenService: (id) {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ServiceDetailsScreen(serviceId: id),
                        ),
                      );
                    },
                  );
                  final sidebar = _Sidebar(
                    me: me,
                    linkedCount: data.linked.length,
                    tags: tags,
                    onRequestCert: () => _snack(
                      'Your admin will review certification requests for additional treatments.',
                    ),
                    onUpdateAvailability: () {
                      _snack('Availability updates are coordinated with your spa admin.');
                      context.read<DesktopNav>().goTo(DesktopRouteKey.schedule);
                    },
                  );

                  return SingleChildScrollView(
                    controller: _scrollCtrl,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      _SvcUi.contentPadding,
                      8,
                      _SvcUi.contentPadding,
                      40,
                    ),
                    child: wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: main),
                              const SizedBox(width: _SvcUi.gap),
                              SizedBox(
                                width: _SvcUi.sidebarWidth,
                                child: sidebar,
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              main,
                              const SizedBox(height: _SvcUi.gap),
                              sidebar,
                            ],
                          ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: _SvcUi.purple.withValues(alpha: 0.35),
      checkmarkColor: Colors.white,
      labelStyle: GoogleFonts.inter(
        fontWeight: FontWeight.w700,
        color: selected ? Colors.white : _SvcUi.textSecondary,
      ),
    );
  }
}

class _ServicesShell extends StatelessWidget {
  const _ServicesShell({required this.child});

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
              colors: [_SvcUi.bgTop, _SvcUi.bgBottom],
            ),
          ),
        ),
        Positioned(
          top: -50,
          right: 60,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _SvcUi.purple.withValues(alpha: 0.2),
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

class _MainColumn extends StatelessWidget {
  const _MainColumn({
    required this.me,
    required this.linked,
    required this.filtered,
    required this.tags,
    required this.categoryName,
    required this.categoriesCount,
    required this.sortMode,
    required this.onSort,
    required this.onFilter,
    required this.onOpenService,
  });

  final Zaposlenik me;
  final List<Usluga> linked;
  final List<Usluga> filtered;
  final List<String> tags;
  final String? categoryName;
  final int categoriesCount;
  final String sortMode;
  final ValueChanged<String> onSort;
  final VoidCallback onFilter;
  final ValueChanged<int> onOpenService;

  @override
  Widget build(BuildContext context) {
    final catLabel = categoryName ?? 'your profile';
    final heroSubtitle =
        'Treatments in $catLabel — ${linked.length} service${linked.length == 1 ? '' : 's'} linked to your profile.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeroCard(
          subtitle: heroSubtitle,
          linkedCount: linked.length,
          categoriesCount: categoriesCount,
          certifiedCount: tags.length,
        ),
        const SizedBox(height: _SvcUi.gap),
        _LinkedServicesCard(
          services: filtered,
          allLinked: linked,
          sortMode: sortMode,
          onSort: onSort,
          onFilter: onFilter,
          onOpenService: onOpenService,
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.subtitle,
    required this.linkedCount,
    required this.categoriesCount,
    required this.certifiedCount,
  });

  final String subtitle;
  final int linkedCount;
  final int categoriesCount;
  final int certifiedCount;

  @override
  Widget build(BuildContext context) {
    return _SvcGlass(
      radius: _SvcUi.heroRadius,
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, c) {
          final stack = c.maxWidth < 760;
          final illustration = const _SpaHeroIllustration();
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(
                    colors: [
                      _SvcUi.purple.withValues(alpha: 0.5),
                      _SvcUi.lavender.withValues(alpha: 0.35),
                    ],
                  ),
                  border: Border.all(
                    color: _SvcUi.lavender.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  'Certified Therapist',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Your Service Catalog',
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: _SvcUi.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.45,
                  color: _SvcUi.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _HeroStat(value: '$linkedCount', label: 'Linked Services'),
                  _HeroStat(value: '$categoriesCount', label: 'Categories'),
                  _HeroStat(value: '$certifiedCount', label: 'Certified Tags'),
                ],
              ),
            ],
          );

          if (stack) {
            return Column(
              children: [
                illustration,
                const SizedBox(height: 20),
                content,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              illustration,
              const SizedBox(width: 28),
              Expanded(child: content),
            ],
          );
        },
      ),
    );
  }
}

class _SpaHeroIllustration extends StatelessWidget {
  const _SpaHeroIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _SvcUi.purple.withValues(alpha: 0.35),
                  _SvcUi.lavender.withValues(alpha: 0.05),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: _SvcUi.purple.withValues(alpha: 0.35),
                  blurRadius: 40,
                  spreadRadius: 4,
                ),
              ],
            ),
          ),
          const Icon(Icons.spa_rounded, size: 56, color: _SvcUi.lavender),
          Positioned(
            left: 12,
            bottom: 28,
            child: _IllustrationOrb(icon: Icons.water_drop_outlined, size: 36),
          ),
          Positioned(
            right: 8,
            top: 24,
            child: _IllustrationOrb(icon: Icons.self_improvement_rounded, size: 32),
          ),
          Positioned(
            right: 28,
            bottom: 16,
            child: _IllustrationOrb(icon: Icons.dry_cleaning_outlined, size: 28),
          ),
        ],
      ),
    );
  }
}

class _IllustrationOrb extends StatelessWidget {
  const _IllustrationOrb({required this.icon, required this.size});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size + 16,
      height: size + 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: _SvcUi.purple.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: _SvcUi.purple.withValues(alpha: 0.25),
            blurRadius: 12,
          ),
        ],
      ),
      child: Icon(icon, size: size * 0.55, color: _SvcUi.lavender),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _SvcUi.textPrimary,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _SvcUi.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkedServicesCard extends StatelessWidget {
  const _LinkedServicesCard({
    required this.services,
    required this.allLinked,
    required this.sortMode,
    required this.onSort,
    required this.onFilter,
    required this.onOpenService,
  });

  final List<Usluga> services;
  final List<Usluga> allLinked;
  final String sortMode;
  final ValueChanged<String> onSort;
  final VoidCallback onFilter;
  final ValueChanged<int> onOpenService;

  @override
  Widget build(BuildContext context) {
    return _SvcGlass(
      radius: _SvcUi.heroRadius,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, c) {
              final stack = c.maxWidth < 640;
              final header = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Linked Services',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _SvcUi.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'These are the services you are certified to perform.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: _SvcUi.textSecondary,
                    ),
                  ),
                ],
              );
              final actions = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SortDropdown(value: sortMode, onChanged: onSort),
                  const SizedBox(width: 8),
                  _GlassIconButton(
                    icon: Icons.tune_rounded,
                    tooltip: 'Filter',
                    onTap: onFilter,
                  ),
                ],
              );
              if (stack) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
                    const SizedBox(height: 14),
                    actions,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: header),
                  actions,
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          if (services.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(
                    Icons.spa_outlined,
                    size: 48,
                    color: _SvcUi.lavender.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'No linked services match your filters.',
                    style: GoogleFonts.inter(
                      color: _SvcUi.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                for (var i = 0; i < services.length; i++) ...[
                  _ServiceRow(
                    service: services[i],
                    tier: _tierLabel(services[i], allLinked),
                    onViewDetails: () => onOpenService(services[i].id),
                  ),
                  if (i < services.length - 1)
                    Divider(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _SortDropdown extends StatelessWidget {
  const _SortDropdown({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  static const _options = [
    'A to Z',
    'Z to A',
    'Duration',
    'Price: High to Low',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168,
      height: 44,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: _SvcUi.bgBottom,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _SvcUi.textPrimary,
          ),
          icon: Icon(
            Icons.expand_more_rounded,
            color: Colors.white.withValues(alpha: 0.6),
          ),
          items: [
            for (final o in _options)
              DropdownMenuItem(value: o, child: Text(o)),
          ],
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceRow extends StatefulWidget {
  const _ServiceRow({
    required this.service,
    required this.tier,
    required this.onViewDetails,
  });

  final Usluga service;
  final String tier;
  final VoidCallback onViewDetails;

  @override
  State<_ServiceRow> createState() => _ServiceRowState();
}

class _ServiceRowState extends State<_ServiceRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final u = widget.service;
    final isPremium = widget.tier == 'Premium';
    final tierColor = isPremium ? _SvcUi.gold : _SvcUi.lavender;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        color: _hover ? Colors.white.withValues(alpha: 0.04) : Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: LayoutBuilder(
          builder: (context, c) {
            final narrow = c.maxWidth < 720;
            final thumb = _ServiceThumbnail(service: u);
            final info = Expanded(
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: _SvcUi.purple.withValues(alpha: 0.2),
                    ),
                    child: const Icon(
                      Icons.spa_outlined,
                      size: 18,
                      color: _SvcUi.lavender,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          u.naziv,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: _SvcUi.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _durationLabel(u),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: _SvcUi.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
            final badge = Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: tierColor.withValues(alpha: 0.15),
                border: Border.all(color: tierColor.withValues(alpha: 0.45)),
              ),
              child: Text(
                widget.tier,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: tierColor,
                ),
              ),
            );
            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [thumb, const SizedBox(width: 14), info]),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      badge,
                      const Spacer(),
                      _OutlinedButton(
                        label: 'View Details',
                        onTap: widget.onViewDetails,
                      ),
                      const SizedBox(width: 4),
                      PopupMenuButton<String>(
                        tooltip: 'More',
                        color: _SvcUi.bgBottom,
                        icon: Icon(
                          Icons.more_vert_rounded,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        onSelected: (v) {
                          if (v == 'view') widget.onViewDetails();
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'view',
                            child: Text('View Details'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              );
            }

            return Row(
              children: [
                thumb,
                const SizedBox(width: 16),
                info,
                const SizedBox(width: 12),
                badge,
                const SizedBox(width: 12),
                _OutlinedButton(
                  label: 'View Details',
                  onTap: widget.onViewDetails,
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  tooltip: 'More',
                  color: _SvcUi.bgBottom,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  onSelected: (v) {
                    if (v == 'view') widget.onViewDetails();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'view',
                      child: Text('View Details'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ServiceThumbnail extends StatelessWidget {
  const _ServiceThumbnail({required this.service});

  final Usluga service;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 64,
        height: 48,
        child: ServiceNetworkImage(
          imageUrl: service.slikaUrl,
          fit: BoxFit.cover,
          error: Container(
            color: _SvcUi.purple.withValues(alpha: 0.2),
            child: const Icon(Icons.spa_outlined, color: _SvcUi.lavender),
          ),
        ),
      ),
    );
  }
}

class _OutlinedButton extends StatefulWidget {
  const _OutlinedButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_OutlinedButton> createState() => _OutlinedButtonState();
}

class _OutlinedButtonState extends State<_OutlinedButton> {
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
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _SvcUi.purple.withValues(alpha: _hover ? 0.65 : 0.4),
              ),
              color: _SvcUi.purple.withValues(alpha: _hover ? 0.15 : 0.08),
            ),
            child: Center(
              child: Text(
                widget.label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _SvcUi.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.me,
    required this.linkedCount,
    required this.tags,
    required this.onRequestCert,
    required this.onUpdateAvailability,
  });

  final Zaposlenik me;
  final int linkedCount;
  final List<String> tags;
  final VoidCallback onRequestCert;
  final VoidCallback onUpdateAvailability;

  @override
  Widget build(BuildContext context) {
    final nav = context.read<DesktopNav>();
    final katName = me.kategorijaUslugaNaziv?.trim() ?? '—';
    final topRows = _topCertificationRows(tags);

    return Column(
      children: [
        _SvcGlass(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Profile Summary',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _SvcUi.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              _SummaryLine(label: 'Category', value: katName),
              const SizedBox(height: 10),
              _SummaryLine(
                label: 'Linked Services',
                value: '$linkedCount',
              ),
              const SizedBox(height: 10),
              _SummaryLine(
                label: 'Certifications',
                value: '${tags.length}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SvcGlass(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Top Certified Treatments',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _SvcUi.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              if (topRows.isEmpty)
                Text(
                  'No certification tags on your profile yet.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: _SvcUi.textSecondary,
                  ),
                )
              else
                for (var i = 0; i < topRows.length; i++) ...[
                  _ProgressRow(
                    label: topRows[i].$1,
                    percent: topRows[i].$2,
                  ),
                  if (i < topRows.length - 1) const SizedBox(height: 14),
                ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SvcGlass(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Quick Actions',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _SvcUi.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              _QuickRow(
                icon: Icons.event_note_rounded,
                label: 'My Appointments',
                onTap: () => nav.goTo(DesktopRouteKey.therapistAppointments),
              ),
              const SizedBox(height: 10),
              _QuickRow(
                icon: Icons.calendar_month_rounded,
                label: 'My Schedule',
                onTap: () => nav.goTo(DesktopRouteKey.schedule),
              ),
              const SizedBox(height: 10),
              _QuickRow(
                icon: Icons.reviews_outlined,
                label: 'My Reviews',
                onTap: () => nav.goTo(DesktopRouteKey.therapistReviews),
              ),
              const SizedBox(height: 10),
              _QuickRow(
                icon: Icons.event_available_rounded,
                label: 'Update Availability',
                onTap: onUpdateAvailability,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SvcGlass(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Want to add more services?',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _SvcUi.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Contact admin to get certified for more treatments.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.4,
                  color: _SvcUi.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              _PrimaryButton(
                label: 'Request Certification',
                icon: Icons.verified_outlined,
                onTap: onRequestCert,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: _SvcUi.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: _SvcUi.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.label, required this.percent});

  final String label;
  final int percent;

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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _SvcUi.textPrimary,
                ),
              ),
            ),
            Text(
              '$percent%',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _SvcUi.textSecondary,
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
                  widthFactor: percent / 100,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_SvcUi.purple, _SvcUi.lavender],
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
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Colors.white.withValues(alpha: _hover ? 0.08 : 0.04),
              border: Border.all(
                color: _SvcUi.purple.withValues(alpha: _hover ? 0.4 : 0.18),
              ),
            ),
            child: Row(
              children: [
                Icon(widget.icon, color: _SvcUi.lavender, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.label,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: _SvcUi.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Colors.white.withValues(alpha: _hover ? 0.7 : 0.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SvcGlass extends StatelessWidget {
  const _SvcGlass({
    required this.child,
    this.padding,
    this.radius = _SvcUi.cardRadius,
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
            color: _SvcUi.purple.withValues(alpha: 0.1),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white.withValues(alpha: 0.05),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Icon(icon, color: Colors.white.withValues(alpha: 0.85)),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatefulWidget {
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
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
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  _SvcUi.purple.withValues(alpha: _hover ? 1 : 0.92),
                  _SvcUi.lavender.withValues(alpha: _hover ? 1 : 0.92),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: _SvcUi.purple.withValues(alpha: _hover ? 0.45 : 0.3),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
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
