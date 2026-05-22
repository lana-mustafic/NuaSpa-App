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
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  int? _categoryFilterId;
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
          return const _ServicesData(
            me: null,
            linked: [],
            categories: [],
          );
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
    return linked.where((u) {
      if (_categoryFilterId != null &&
          u.kategorijaUslugaId != _categoryFilterId) {
        return false;
      }
      if (q.isEmpty) return true;
      final blob =
          '${u.naziv} ${u.kategorija} ${u.opis}'.toLowerCase();
      return blob.contains(q);
    }).toList();
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
                children: [
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
                        const Text(
                          'Could not load your service list.',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _SvcUi.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _PrimaryGradientButton(
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

            final filtered = _filterList(data.linked);
            final tags = _specializationTags(me.specijalizacija);

            return FadeTransition(
              opacity: _fadeAnim,
              child: LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth >= 1100;
                  final main = _MainServicesColumn(
                    me: me,
                    linked: data.linked,
                    filtered: filtered,
                    categories: data.categories,
                    tags: tags,
                    categoryFilterId: _categoryFilterId,
                    searchCtrl: _searchCtrl,
                    scrollCtrl: _scrollCtrl,
                    onSearchChanged: () => setState(() {}),
                    onCategory: (id) => setState(() => _categoryFilterId = id),
                    onRefresh: _reload,
                    onOpenService: (id) {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ServiceDetailsScreen(serviceId: id),
                        ),
                      );
                    },
                  );
                  final sidebar = _ServicesSidebar(
                    me: me,
                    linkedCount: data.linked.length,
                    tags: tags,
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
          top: -40,
          left: 100,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _SvcUi.purple.withValues(alpha: 0.18),
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

class _MainServicesColumn extends StatelessWidget {
  const _MainServicesColumn({
    required this.me,
    required this.linked,
    required this.filtered,
    required this.categories,
    required this.tags,
    required this.categoryFilterId,
    required this.searchCtrl,
    required this.scrollCtrl,
    required this.onSearchChanged,
    required this.onCategory,
    required this.onRefresh,
    required this.onOpenService,
  });

  final Zaposlenik me;
  final List<Usluga> linked;
  final List<Usluga> filtered;
  final List<KategorijaUsluga> categories;
  final List<String> tags;
  final int? categoryFilterId;
  final TextEditingController searchCtrl;
  final ScrollController scrollCtrl;
  final VoidCallback onSearchChanged;
  final ValueChanged<int?> onCategory;
  final VoidCallback onRefresh;
  final ValueChanged<int> onOpenService;

  @override
  Widget build(BuildContext context) {
    final katName = me.kategorijaUslugaNaziv?.trim();
    final hasCategory = (me.kategorijaUslugaId ?? 0) > 0 &&
        katName != null &&
        katName.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ServicesHeroCard(
          categoryName: hasCategory ? katName : null,
          totalServices: linked.length,
          certifiedCount: tags.length,
        ),
        const SizedBox(height: _SvcUi.gap),
        _KpiRow(
          total: linked.length,
          categories: categories.length,
          certified: tags.length,
          hasCategory: hasCategory,
        ),
        const SizedBox(height: _SvcUi.gap),
        _FilterBar(
          searchCtrl: searchCtrl,
          categories: categories,
          categoryFilterId: categoryFilterId,
          onSearchChanged: onSearchChanged,
          onCategory: onCategory,
          onRefresh: onRefresh,
          resultCount: filtered.length,
        ),
        const SizedBox(height: _SvcUi.gap),
        if (tags.isNotEmpty) ...[
          _CertifiedTagsCard(tags: tags),
          const SizedBox(height: _SvcUi.gap),
        ],
        _ServicesCatalogCard(
          filtered: filtered,
          hasCategory: hasCategory,
          categoryName: katName,
          onOpenService: onOpenService,
        ),
      ],
    );
  }
}

class _ServicesHeroCard extends StatelessWidget {
  const _ServicesHeroCard({
    required this.categoryName,
    required this.totalServices,
    required this.certifiedCount,
  });

  final String? categoryName;
  final int totalServices;
  final int certifiedCount;

  @override
  Widget build(BuildContext context) {
    return _SvcGlass(
      radius: _SvcUi.heroRadius,
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 200),
        child: Row(
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  colors: [_SvcUi.purple, _SvcUi.lavender],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _SvcUi.purple.withValues(alpha: 0.4),
                    blurRadius: 28,
                  ),
                ],
              ),
              child: const Icon(
                Icons.spa_rounded,
                size: 44,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 22),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Your Service Catalog',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: _SvcUi.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    categoryName != null
                        ? 'Treatments in $categoryName — $totalServices services linked to your profile.'
                        : certifiedCount > 0
                        ? 'Certified for $certifiedCount treatments from your specialization profile.'
                        : 'Treatments you are certified to perform at NuaSpa.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.45,
                      color: _SvcUi.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({
    required this.total,
    required this.categories,
    required this.certified,
    required this.hasCategory,
  });

  final int total;
  final int categories;
  final int certified;
  final bool hasCategory;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 900 ? 3 : 1;
        final w = (c.maxWidth - 16 * (cols - 1)) / cols;
        final cards = [
          _MiniKpi(
            label: 'Linked Services',
            value: '$total',
            icon: Icons.design_services_rounded,
            accent: _SvcUi.purple,
          ),
          _MiniKpi(
            label: 'Categories',
            value: '$categories',
            icon: Icons.category_rounded,
            accent: _SvcUi.lavender,
          ),
          _MiniKpi(
            label: hasCategory ? 'Certified Tags' : 'Specializations',
            value: '$certified',
            icon: Icons.verified_rounded,
            accent: _SvcUi.gold,
          ),
        ];
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final card in cards)
              SizedBox(
                width: w.clamp(200, c.maxWidth),
                child: card,
              ),
          ],
        );
      },
    );
  }
}

class _MiniKpi extends StatelessWidget {
  const _MiniKpi({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return _SvcGlass(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: accent.withValues(alpha: 0.14),
              border: Border.all(color: accent.withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.28),
                  blurRadius: 14,
                ),
              ],
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _SvcUi.textSecondary,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: _SvcUi.textPrimary,
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

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.searchCtrl,
    required this.categories,
    required this.categoryFilterId,
    required this.onSearchChanged,
    required this.onCategory,
    required this.onRefresh,
    required this.resultCount,
  });

  final TextEditingController searchCtrl;
  final List<KategorijaUsluga> categories;
  final int? categoryFilterId;
  final VoidCallback onSearchChanged;
  final ValueChanged<int?> onCategory;
  final VoidCallback onRefresh;
  final int resultCount;

  @override
  Widget build(BuildContext context) {
    return _SvcGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _SvcGlass(
                  radius: 14,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: TextField(
                    controller: searchCtrl,
                    onChanged: (_) => onSearchChanged(),
                    style: GoogleFonts.inter(color: _SvcUi.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search services…',
                      hintStyle: GoogleFonts.inter(
                        color: _SvcUi.textSecondary,
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: _SvcUi.lavender.withValues(alpha: 0.85),
                      ),
                      suffixIcon: searchCtrl.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 20),
                              onPressed: () {
                                searchCtrl.clear();
                                onSearchChanged();
                              },
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _GlassIconButton(
                icon: Icons.refresh_rounded,
                onTap: onRefresh,
              ),
            ],
          ),
          if (categories.length > 1) ...[
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _CategoryPill(
                    label: 'All services',
                    selected: categoryFilterId == null,
                    onTap: () => onCategory(null),
                  ),
                  for (final c in categories) ...[
                    const SizedBox(width: 8),
                    _CategoryPill(
                      label: c.naziv,
                      selected: categoryFilterId == c.id,
                      onTap: () => onCategory(c.id),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            '$resultCount service${resultCount == 1 ? '' : 's'} shown',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _SvcUi.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryPill extends StatefulWidget {
  const _CategoryPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_CategoryPill> createState() => _CategoryPillState();
}

class _CategoryPillState extends State<_CategoryPill> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: widget.selected
                ? const LinearGradient(
                    colors: [_SvcUi.purple, _SvcUi.lavender],
                  )
                : null,
            color: widget.selected
                ? null
                : Colors.white.withValues(alpha: _hover ? 0.08 : 0.04),
            border: Border.all(
              color: widget.selected
                  ? _SvcUi.lavender.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Text(
            widget.label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: widget.selected ? Colors.white : _SvcUi.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _CertifiedTagsCard extends StatelessWidget {
  const _CertifiedTagsCard({required this.tags});

  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    return _SvcGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Certified Treatments',
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _SvcUi.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'From your therapist profile specialization.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: _SvcUi.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
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
                    borderRadius: BorderRadius.circular(999),
                    color: _SvcUi.purple.withValues(alpha: 0.12),
                    border: Border.all(
                      color: _SvcUi.lavender.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    tag,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      color: _SvcUi.textPrimary,
                      fontSize: 13,
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

class _ServicesCatalogCard extends StatelessWidget {
  const _ServicesCatalogCard({
    required this.filtered,
    required this.hasCategory,
    required this.categoryName,
    required this.onOpenService,
  });

  final List<Usluga> filtered;
  final bool hasCategory;
  final String? categoryName;
  final ValueChanged<int> onOpenService;

  @override
  Widget build(BuildContext context) {
    return _SvcGlass(
      radius: _SvcUi.heroRadius,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Linked Services',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _SvcUi.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hasCategory
                ? 'Services in your assigned category from the NuaSpa catalog.'
                : 'Services matched to your specialization tags.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: _SvcUi.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          if (filtered.isEmpty)
            _ServicesEmptyState(
              hasCategory: hasCategory,
              categoryName: categoryName,
            )
          else
            LayoutBuilder(
              builder: (context, c) {
                final cross = c.maxWidth >= 1100
                    ? 3
                    : c.maxWidth >= 700
                    ? 2
                    : 1;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cross,
                    childAspectRatio: 0.92,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    return _ServiceGridCard(
                      service: filtered[i],
                      onTap: () => onOpenService(filtered[i].id),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ServiceGridCard extends StatefulWidget {
  const _ServiceGridCard({
    required this.service,
    required this.onTap,
  });

  final Usluga service;
  final VoidCallback onTap;

  @override
  State<_ServiceGridCard> createState() => _ServiceGridCardState();
}

class _ServiceGridCardState extends State<_ServiceGridCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final u = widget.service;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            transform: Matrix4.translationValues(0, _hover ? -4 : 0, 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _SvcUi.purple.withValues(alpha: _hover ? 0.45 : 0.2),
              ),
              boxShadow: _hover
                  ? [
                      BoxShadow(
                        color: _SvcUi.purple.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          u.slikaUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: _SvcUi.purple.withValues(alpha: 0.15),
                            child: const Icon(
                              Icons.spa_outlined,
                              size: 48,
                              color: _SvcUi.lavender,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Text(
                              u.kategorija,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    color: Colors.white.withValues(alpha: 0.04),
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          u.naziv,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: _SvcUi.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${u.cijenaKm} · ${u.trajanje}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: _SvcUi.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              'View details',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _SvcUi.lavender,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 14,
                              color: _SvcUi.lavender.withValues(alpha: 0.9),
                            ),
                          ],
                        ),
                      ],
                    ),
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

class _ServicesEmptyState extends StatelessWidget {
  const _ServicesEmptyState({
    required this.hasCategory,
    required this.categoryName,
  });

  final bool hasCategory;
  final String? categoryName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _SvcUi.purple.withValues(alpha: 0.12),
              border: Border.all(color: _SvcUi.purple.withValues(alpha: 0.35)),
            ),
            child: const Icon(
              Icons.spa_outlined,
              size: 48,
              color: _SvcUi.lavender,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'No services to show',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _SvcUi.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            hasCategory
                ? 'No catalog services found for ${categoryName ?? 'your category'}.\nAsk your administrator to link treatments.'
                : 'No services assigned yet.\nAsk your administrator to set your category or specialization.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.5,
              color: _SvcUi.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ServicesSidebar extends StatelessWidget {
  const _ServicesSidebar({
    required this.me,
    required this.linkedCount,
    required this.tags,
  });

  final Zaposlenik me;
  final int linkedCount;
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    final nav = context.read<DesktopNav>();
    final katName = me.kategorijaUslugaNaziv?.trim();

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
              if (katName != null && katName.isNotEmpty) ...[
                _SidebarRow(
                  icon: Icons.category_rounded,
                  label: 'Category',
                  value: katName,
                ),
                const SizedBox(height: 12),
              ],
              _SidebarRow(
                icon: Icons.design_services_rounded,
                label: 'Linked services',
                value: '$linkedCount',
              ),
              const SizedBox(height: 12),
              _SidebarRow(
                icon: Icons.verified_rounded,
                label: 'Certifications',
                value: '${tags.length}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _TopSpecializationsCard(tags: tags),
        const SizedBox(height: 18),
        _QuickActionsCard(
          onAppointments: () =>
              nav.goTo(DesktopRouteKey.therapistAppointments),
          onSchedule: () => nav.goTo(DesktopRouteKey.schedule),
          onReviews: () => nav.goTo(DesktopRouteKey.therapistReviews),
        ),
      ],
    );
  }
}

class _SidebarRow extends StatelessWidget {
  const _SidebarRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: _SvcUi.lavender),
        const SizedBox(width: 12),
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
            fontWeight: FontWeight.w800,
            color: _SvcUi.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _TopSpecializationsCard extends StatelessWidget {
  const _TopSpecializationsCard({required this.tags});

  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    final weights = [40, 30, 20, 10];
    final rows = <(String, int)>[];
    for (var i = 0; i < tags.length && i < 4; i++) {
      rows.add((tags[i], weights[i]));
    }

    return _SvcGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          if (rows.isEmpty)
            Text(
              'No specialization tags on your profile yet.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: _SvcUi.textSecondary,
              ),
            )
          else
            for (var i = 0; i < rows.length; i++) ...[
              _ProgressRow(label: rows[i].$1, percent: rows[i].$2),
              if (i < rows.length - 1) const SizedBox(height: 14),
            ],
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.label, required this.percent});

  final String label;
  final int percent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _SvcUi.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 10),
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
        ),
        const SizedBox(width: 8),
        Text(
          '$percent%',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _SvcUi.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard({
    required this.onAppointments,
    required this.onSchedule,
    required this.onReviews,
  });

  final VoidCallback onAppointments;
  final VoidCallback onSchedule;
  final VoidCallback onReviews;

  @override
  Widget build(BuildContext context) {
    return _SvcGlass(
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
          _QuickActionRow(
            icon: Icons.event_note_rounded,
            label: 'My Appointments',
            onTap: onAppointments,
          ),
          const SizedBox(height: 10),
          _QuickActionRow(
            icon: Icons.calendar_month_rounded,
            label: 'My Schedule',
            onTap: onSchedule,
          ),
          const SizedBox(height: 10),
          _QuickActionRow(
            icon: Icons.reviews_outlined,
            label: 'My Reviews',
            onTap: onReviews,
          ),
        ],
      ),
    );
  }
}

class _QuickActionRow extends StatefulWidget {
  const _QuickActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_QuickActionRow> createState() => _QuickActionRowState();
}

class _QuickActionRowState extends State<_QuickActionRow> {
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

class _GlassIconButton extends StatefulWidget {
  const _GlassIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<_GlassIconButton> {
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
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white.withValues(alpha: _hover ? 0.1 : 0.05),
              border: Border.all(
                color: Colors.white.withValues(alpha: _hover ? 0.2 : 0.1),
              ),
            ),
            child: Icon(widget.icon, color: Colors.white.withValues(alpha: 0.9)),
          ),
        ),
      ),
    );
  }
}

class _PrimaryGradientButton extends StatefulWidget {
  const _PrimaryGradientButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_PrimaryGradientButton> createState() => _PrimaryGradientButtonState();
}

class _PrimaryGradientButtonState extends State<_PrimaryGradientButton> {
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
            padding: const EdgeInsets.symmetric(horizontal: 22),
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
