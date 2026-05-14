import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/services/api_service.dart';
import '../../models/usluga.dart';
import '../../providers/auth_provider.dart';
import '../../providers/mobile_nav_provider.dart';
import '../../providers/service_provider.dart';
import '../../ui/theme/mobile_spa_theme.dart';
import '../../ui/widgets/load_retry_panel.dart';
import 'service_details_screen.dart';
import 'service_category_manager_panel.dart';
import 'service_editor_dialog.dart';

/// Premium glass "Service Catalog" experience (English marketing copy per brief).
class MobileServiceCatalogScreen extends StatefulWidget {
  const MobileServiceCatalogScreen({
    super.key,
    this.onOpenMenu,
  });

  final VoidCallback? onOpenMenu;

  @override
  State<MobileServiceCatalogScreen> createState() =>
      _MobileServiceCatalogScreenState();
}

class _CategoryPill {
  const _CategoryPill(this.label, this.keywords);
  final String label;
  final List<String>? keywords;
}

const _kPills = <_CategoryPill>[
  _CategoryPill('All Services', null),
  _CategoryPill('Massages', ['masaž', 'massage', 'masa', 'massag']),
  _CategoryPill('Facials', ['facial', 'lice', 'lica', 'lič']),
  _CategoryPill('Body Treatments', ['body', 'tijelo', 'tjelesn']),
  _CategoryPill('Rituals', ['ritual', 'rituali']),
];

class _MobileServiceCatalogScreenState extends State<MobileServiceCatalogScreen> {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _search = TextEditingController();
  int _pillIndex = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<ServiceProvider>().fetchServices();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _openServiceEditor(Usluga? existing) async {
    final ok = await showServiceEditorDialog(context, existing: existing);
    if (!mounted) return;
    if (ok) {
      await context.read<ServiceProvider>().fetchServices();
    }
  }

  Future<void> _confirmDeleteService(Usluga u) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Brisanje usluge'),
        content: Text(
          'Obrisati „${u.naziv}“? Ako usluga ima rezervacije ili plaćanja, '
          'brisanje može biti odbijeno.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Otkaži'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Obriši'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;

    final err = await ApiService().deleteUsluga(u.id);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usluga obrisana.')),
      );
      await context.read<ServiceProvider>().fetchServices();
    }
  }

  bool _categoryMatches(Usluga u, List<String>? keywords) {
    if (keywords == null) return true;
    final k = u.kategorija.toLowerCase();
    return keywords.any((w) => k.contains(w));
  }

  List<Usluga> _visible(ServiceProvider sp) {
    final q = _search.text.trim().toLowerCase();
    var list = sp.allServices;
    final kw = _kPills[_pillIndex].keywords;
    if (kw != null) {
      list = list.where((u) => _categoryMatches(u, kw)).toList();
    }
    if (q.isNotEmpty) {
      list = list
          .where((u) => u.naziv.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  String? _badgeFor(Usluga u) {
    final h = u.id % 7;
    if (h == 0 || h == 3) return 'POPULAR';
    if (h == 1) return 'NEW';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<ServiceProvider>();
    final tt = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final visible = _visible(sp);
    final isAdmin = context.watch<AuthProvider>().isAdmin;

    if (sp.isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (sp.loadFailed) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: LoadRetryPanel(
          message: sp.loadError ?? 'Unknown error.',
          onRetry: () => sp.fetchServices(),
        ),
      );
    }

    return CustomScrollView(
      controller: _scroll,
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildHeader(context, tt, isAdmin)),
        SliverToBoxAdapter(child: _buildSearchRow(context)),
        SliverToBoxAdapter(child: _buildPills(context)),
        if (visible.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 120),
              child: Text(
                'No treatments match your search yet.',
                style: tt.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 120 + bottomInset),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 14,
                childAspectRatio: 0.58,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final u = visible[index];
                  return _ServiceCard(
                    usluga: u,
                    badge: _badgeFor(u),
                    onOpen: () {
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => ServiceDetailsScreen(serviceId: u.id),
                        ),
                      );
                    },
                    onAddTap: () {
                      context.read<ServiceProvider>().toggleFavorite(u.id);
                    },
                    isFavorite: sp.isFavorite(u.id),
                    onAdminEdit:
                        isAdmin ? () => _openServiceEditor(u) : null,
                    onAdminDelete:
                        isAdmin ? () => _confirmDeleteService(u) : null,
                  );
                },
                childCount: visible.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, TextTheme tt, bool isAdmin) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              16,
              8 + MediaQuery.paddingOf(context).top,
              16,
              22,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  MobileSpaColors.lavender.withValues(alpha: 0.65),
                  MobileSpaColors.softWhite.withValues(alpha: 0.3),
                  MobileSpaColors.softWhite,
                ],
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _GlassCircleButton(
                      icon: Icons.menu_rounded,
                      onTap: widget.onOpenMenu ?? () {},
                    ),
                    const Spacer(),
                    if (isAdmin) ...[
                      _GlassCircleButton(
                        icon: Icons.category_outlined,
                        onTap: () => showServiceCategoryManagerDialog(context),
                      ),
                      const SizedBox(width: 10),
                      _GlassCircleButton(
                        icon: Icons.add_rounded,
                        onTap: () => _openServiceEditor(null),
                      ),
                      const SizedBox(width: 10),
                    ],
                    _GlassCircleButton(
                      icon: Icons.notifications_none_rounded,
                      badgeCount: 2,
                      onTap: () {},
                    ),
                    const SizedBox(width: 10),
                    _GlassCircleButton(
                      icon: Icons.person_outline_rounded,
                      onTap: () =>
                          context.read<MobileNavProvider>().setTab(3),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'NuaSpa',
                  style: tt.headlineMedium?.copyWith(letterSpacing: 1),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Relax. Renew. Rejuvenate.',
                  style: tt.bodyMedium?.copyWith(
                    color: MobileSpaColors.royalPurple.withValues(alpha: 0.52),
                    letterSpacing: 0.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: MobileSpaColors.lavender.withValues(alpha: 0.35),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: MobileSpaColors.royalPurple.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    style: Theme.of(context).textTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'Search for treatments, massages…',
                      hintStyle: Theme.of(context).inputDecorationTheme.hintStyle,
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: MobileSpaColors.royalPurple.withValues(alpha: 0.45),
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Material(
            color: MobileSpaColors.royalPurple,
            shape: const CircleBorder(),
            elevation: 0,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                showModalBottomSheet<void>(
                  context: context,
                  backgroundColor: MobileSpaColors.softWhite,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  builder: (ctx) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Filters',
                          style: Theme.of(ctx).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'More sorting and filter options will appear here.',
                          style: Theme.of(ctx).textTheme.bodyMedium,
                        ),
                        SizedBox(height: MediaQuery.paddingOf(ctx).bottom + 8),
                      ],
                    ),
                  ),
                );
              },
              child: const SizedBox(
                width: 52,
                height: 52,
                child: Icon(Icons.tune_rounded, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPills(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _kPills.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final selected = i == _pillIndex;
          return GestureDetector(
            onTap: () => setState(() => _pillIndex = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: selected
                    ? MobileSpaColors.royalPurple
                    : MobileSpaColors.lavender.withValues(alpha: 0.38),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected
                      ? MobileSpaColors.royalPurple
                      : MobileSpaColors.lavender.withValues(alpha: 0.5),
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: MobileSpaColors.royalPurple.withValues(alpha: 0.25),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                _kPills[i].label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: selected
                          ? Colors.white
                          : MobileSpaColors.royalPurple.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GlassCircleButton extends StatelessWidget {
  const _GlassCircleButton({
    required this.icon,
    required this.onTap,
    this.badgeCount,
  });

  final IconData icon;
  final VoidCallback onTap;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.38),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Icon(
                icon,
                size: 22,
                color: MobileSpaColors.royalPurple.withValues(alpha: 0.85),
              ),
              if (badgeCount != null && badgeCount! > 0)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: MobileSpaColors.gold,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$badgeCount',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: MobileSpaColors.royalPurple,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.usluga,
    required this.onOpen,
    required this.onAddTap,
    required this.isFavorite,
    this.badge,
    this.onAdminEdit,
    this.onAdminDelete,
  });

  final Usluga usluga;
  final VoidCallback onOpen;
  final VoidCallback onAddTap;
  final bool isFavorite;
  final String? badge;
  final VoidCallback? onAdminEdit;
  final VoidCallback? onAdminDelete;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final desc = usluga.opis.trim().isEmpty
        ? 'A restorative experience tailored to your needs.'
        : (usluga.opis.length > 72
            ? '${usluga.opis.substring(0, 72)}…'
            : usluga.opis);

    return Material(
      color: Colors.white.withValues(alpha: 0.82),
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: MobileSpaColors.lavender.withValues(alpha: 0.25),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    usluga.slikaUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            MobileSpaColors.lavender.withValues(alpha: 0.35),
                            MobileSpaColors.softWhite,
                          ],
                        ),
                      ),
                      child: Icon(
                        Icons.spa_outlined,
                        size: 48,
                        color: MobileSpaColors.royalPurple.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
                  if (badge != null)
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: MobileSpaColors.gold.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Text(
                          badge!,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: MobileSpaColors.royalPurple,
                          ),
                        ),
                      ),
                    ),
                  if (onAdminEdit != null)
                    Positioned(
                      right: 10,
                      top: 10,
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.38),
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onAdminEdit,
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (onAdminDelete != null)
                    Positioned(
                      left: 10,
                      bottom: 10,
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.38),
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onAdminDelete,
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: Color(0xFFFFAB91),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      usluga.naziv,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Text(
                        desc,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodySmall,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: MobileSpaColors.lavender.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${usluga.cijena.toStringAsFixed(0)} KM',
                            style: tt.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: MobileSpaColors.royalPurple,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.schedule_rounded,
                          size: 14,
                          color: MobileSpaColors.royalPurple.withValues(alpha: 0.45),
                        ),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            usluga.trajanje,
                            style: tt.labelSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Spacer(),
                        Material(
                          color: MobileSpaColors.royalPurple,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: onAddTap,
                            child: SizedBox(
                              width: 34,
                              height: 34,
                              child: Icon(
                                isFavorite ? Icons.favorite : Icons.add,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
