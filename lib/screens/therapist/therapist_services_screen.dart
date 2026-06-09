import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/api/services/api_service.dart';
import '../../core/auth/app_permissions.dart';
import '../../models/kategorija_usluga.dart';
import '../../models/usluga.dart';
import '../../models/zaposlenik.dart';
import '../../providers/auth_provider.dart';
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
  static const green = Color(0xFF22C55E);
  static const cardRadius = 24.0;
  static const gap = 24.0;
  static const sidebarWidth = 260.0;
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
  final _searchCtrl = TextEditingController();
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
    _searchCtrl.dispose();
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
    final q = _searchCtrl.text.trim().toLowerCase();
    var list = linked;
    if (q.isNotEmpty) {
      list = list
          .where(
            (u) =>
                u.naziv.toLowerCase().contains(q) ||
                u.kategorija.toLowerCase().contains(q),
          )
          .toList();
    }
    return _sortServices(list, _sortMode);
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
                    linked: data.linked,
                    filtered: filtered,
                    categoryName: katName,
                    sortMode: _sortMode,
                    searchCtrl: _searchCtrl,
                    onSearchChanged: () => setState(() {}),
                    onSort: (v) => setState(() => _sortMode = v),
                    onOpenService: (id) {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ServiceDetailsScreen(serviceId: id),
                        ),
                      );
                    },
                  );
                  final sidebar = _ServiceSummarySidebar(
                    totalServices: data.linked.length,
                    categoriesCount: data.categories.length,
                    certificationsCount: tags.length,
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
                              Expanded(flex: 7, child: main),
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
    required this.linked,
    required this.filtered,
    required this.categoryName,
    required this.sortMode,
    required this.searchCtrl,
    required this.onSearchChanged,
    required this.onSort,
    required this.onOpenService,
  });

  final List<Usluga> linked;
  final List<Usluga> filtered;
  final String? categoryName;
  final String sortMode;
  final TextEditingController searchCtrl;
  final VoidCallback onSearchChanged;
  final ValueChanged<String> onSort;
  final ValueChanged<int> onOpenService;

  @override
  Widget build(BuildContext context) {
    final catLabel = categoryName?.trim().isNotEmpty == true
        ? categoryName!.trim()
        : 'Your specialty';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeroCard(
          categoryName: catLabel,
          subtitle:
              'Services you are certified to perform at NuaSpa.',
        ),
        const SizedBox(height: 18),
        _LinkedServicesCard(
          totalCount: linked.length,
          services: filtered,
          sortMode: sortMode,
          searchCtrl: searchCtrl,
          onSearchChanged: onSearchChanged,
          onSort: onSort,
          onOpenService: onOpenService,
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.categoryName,
    required this.subtitle,
  });

  final String categoryName;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return _SvcGlass(
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, c) {
          final stack = c.maxWidth < 640;
          final illustration = const _SpaHeroIllustration();
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                categoryName,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _SvcUi.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.4,
                  color: _SvcUi.textSecondary,
                ),
              ),
            ],
          );

          if (stack) {
            return Column(
              children: [
                illustration,
                const SizedBox(height: 12),
                content,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              illustration,
              const SizedBox(width: 18),
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
      width: 120,
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
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
          const Icon(Icons.spa_rounded, size: 36, color: _SvcUi.lavender),
          Positioned(
            left: 4,
            bottom: 14,
            child: _IllustrationOrb(icon: Icons.water_drop_outlined, size: 24),
          ),
          Positioned(
            right: 2,
            top: 12,
            child: _IllustrationOrb(
              icon: Icons.self_improvement_rounded,
              size: 22,
            ),
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

class _LinkedServicesCard extends StatelessWidget {
  const _LinkedServicesCard({
    required this.totalCount,
    required this.services,
    required this.sortMode,
    required this.searchCtrl,
    required this.onSearchChanged,
    required this.onSort,
    required this.onOpenService,
  });

  final int totalCount;
  final List<Usluga> services;
  final String sortMode;
  final TextEditingController searchCtrl;
  final VoidCallback onSearchChanged;
  final ValueChanged<String> onSort;
  final ValueChanged<int> onOpenService;

  @override
  Widget build(BuildContext context) {
    return _SvcGlass(
      radius: _SvcUi.cardRadius,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Services ($totalCount)',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _SvcUi.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, c) {
              final stack = c.maxWidth < 720;
              final search = Expanded(
                child: _SvcGlass(
                  radius: 14,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextField(
                    controller: searchCtrl,
                    onChanged: (_) => onSearchChanged(),
                    style: GoogleFonts.inter(
                      color: _SvcUi.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search services…',
                      hintStyle: GoogleFonts.inter(
                        color: _SvcUi.textSecondary,
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      icon: Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: _SvcUi.lavender.withValues(alpha: 0.8),
                      ),
                      isDense: true,
                    ),
                  ),
                ),
              );
              final sort = _SortDropdown(value: sortMode, onChanged: onSort);
              if (stack) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    search,
                    const SizedBox(height: 10),
                    sort,
                  ],
                );
              }
              return Row(
                children: [
                  search,
                  const SizedBox(width: 10),
                  sort,
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          if (services.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(
                    Icons.spa_outlined,
                    size: 40,
                    color: _SvcUi.lavender.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No services match your search.',
                    style: GoogleFonts.inter(
                      color: _SvcUi.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: services.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _ServiceRow(
                service: services[i],
                onViewDetails: () => onOpenService(services[i].id),
              ),
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
    required this.onViewDetails,
  });

  final Usluga service;
  final VoidCallback onViewDetails;

  @override
  State<_ServiceRow> createState() => _ServiceRowState();
}

class _ServiceRowState extends State<_ServiceRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final u = widget.service;
    final category = u.kategorija.trim().isNotEmpty ? u.kategorija.trim() : 'General';

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: _hover
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.white.withValues(alpha: 0.025),
          border: Border.all(
            color: _hover
                ? _SvcUi.purple.withValues(alpha: 0.28)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, c) {
            final narrow = c.maxWidth < 760;
            final thumb = _ServiceThumbnail(service: u);
            final info = Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    u.naziv,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _SvcUi.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _durationLabel(u),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _SvcUi.lavender.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ServiceBadge(
                        label: category,
                        color: _SvcUi.lavender,
                      ),
                      _ServiceBadge(
                        label: 'Certified',
                        color: _SvcUi.green,
                      ),
                    ],
                  ),
                ],
              ),
            );

            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [thumb, const SizedBox(width: 14), info],
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _OutlinedButton(
                      label: 'View Details',
                      onTap: widget.onViewDetails,
                    ),
                  ),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                thumb,
                const SizedBox(width: 18),
                info,
                const SizedBox(width: 16),
                _OutlinedButton(
                  label: 'View Details',
                  onTap: widget.onViewDetails,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ServiceBadge extends StatelessWidget {
  const _ServiceBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
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
        width: 88,
        height: 66,
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

class _ServiceSummarySidebar extends StatelessWidget {
  const _ServiceSummarySidebar({
    required this.totalServices,
    required this.categoriesCount,
    required this.certificationsCount,
  });

  final int totalServices;
  final int categoriesCount;
  final int certificationsCount;

  @override
  Widget build(BuildContext context) {
    return _SvcGlass(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Service Summary',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _SvcUi.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          _SummaryLine(label: 'Total Services', value: '$totalServices'),
          const SizedBox(height: 10),
          _SummaryLine(label: 'Categories', value: '$categoriesCount'),
          const SizedBox(height: 10),
          _SummaryLine(
            label: 'Certifications',
            value: '$certificationsCount',
          ),
        ],
      ),
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
