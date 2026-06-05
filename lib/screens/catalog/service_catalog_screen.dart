import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/api/services/api_service.dart';
import '../../core/format/km_format.dart';
import '../../models/usluga.dart';
import '../../providers/auth_provider.dart';
import '../../providers/service_provider.dart';
import '../../ui/navigation/desktop_nav.dart';
import '../../ui/theme/nua_luxury_tokens.dart';
import '../../ui/widgets/luxury/luxury_desktop_header.dart';
import '../../ui/widgets/page_header.dart';
import '../../ui/widgets/service_category_filter_bar.dart';
import '../../ui/widgets/service_network_image.dart';
import 'service_details_screen.dart';
import 'service_category_manager_panel.dart';
import 'service_editor_dialog.dart';

class ServiceCatalogScreen extends StatefulWidget {
  const ServiceCatalogScreen({super.key});

  @override
  State<ServiceCatalogScreen> createState() => _ServiceCatalogScreenState();
}

class _ServiceCatalogScreenState extends State<ServiceCatalogScreen> {
  final ScrollController _scrollController = ScrollController();
  int _handledServiceAddRequest = 0;
  String _syncedCatalogQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      Provider.of<ServiceProvider>(context, listen: false).fetchServices();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final nav = Provider.of<DesktopNav>(context, listen: false);
        final pending = nav.takePendingCatalogSearch();
        final q = (pending ?? nav.catalogSearchQuery).trim();
        if (q.isNotEmpty) {
          _syncCatalogSearchFromNav(q);
        }
      });
    });
  }

  void _syncCatalogSearchFromNav(String query) {
    final trimmed = query.trim();
    if (trimmed == _syncedCatalogQuery) return;
    _syncedCatalogQuery = trimmed;
    context.read<ServiceProvider>().searchServices(
          trimmed,
          trackForRecommender: trimmed.isNotEmpty,
        );
  }

  void _clearFilters() {
    _syncedCatalogQuery = '';
    context.read<ServiceProvider>().clearCatalogFilters();
    context.read<DesktopNav>().setCatalogSearchQuery('');
  }

  void _handleServiceAddRequest(DesktopNav nav) {
    if (nav.serviceAddRequest == _handledServiceAddRequest) return;
    _handledServiceAddRequest = nav.serviceAddRequest;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showServiceEditorDialog(context, existing: null);
      if (!mounted) return;
      await context.read<ServiceProvider>().fetchServices();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
        title: const Text('Delete service'),
        content: Text(
          'Delete "${u.naziv}"? If the service has bookings or payments, '
          'deletion may be refused.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
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
        const SnackBar(content: Text('Service deleted.')),
      );
      await context.read<ServiceProvider>().fetchServices();
    }
  }

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<DesktopNav>();
    _handleServiceAddRequest(nav);

    final serviceProvider = Provider.of<ServiceProvider>(context);
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.isAdmin;
    final canFavorite = !auth.isZaposlenik;
    final catalogQuery = nav.catalogSearchQuery;

    if (catalogQuery != _syncedCatalogQuery) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _syncCatalogSearchFromNav(catalogQuery);
      });
    }

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: LuxuryPageChrome.bodyPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isAdmin)
              _CatalogAdminToolbar(
                onManageCategories: () =>
                    showServiceCategoryManagerDialog(context),
                onAddService: () => _openServiceEditor(null),
              )
            else
              PageHeader(
                title: 'Services',
                subtitle: 'Browse treatments and save your favorites.',
                trailing: const _BackIfPossible(),
              ),
            const SizedBox(height: 16),
            if (!serviceProvider.isLoading && !serviceProvider.loadFailed)
              _CatalogSummaryRow(
                totalServices: serviceProvider.allServices.length,
                categoryCount: serviceProvider.categories.length,
                favoriteCount: serviceProvider.favoriteIds.length,
                averagePrice: _averagePrice(serviceProvider.allServices),
              ),
            if (!serviceProvider.isLoading && !serviceProvider.loadFailed)
              const SizedBox(height: 16),
            if (serviceProvider.categories.isNotEmpty) ...[
              ServiceCategoryFilterBar(
                categories: serviceProvider.categories,
                selectedCategoryId: serviceProvider.selectedCategoryId,
                onSelected: serviceProvider.setCategoryFilter,
              ),
              const SizedBox(height: 16),
            ],
            Expanded(
              child: _buildCatalogBody(
                context,
                serviceProvider,
                isAdmin,
                canFavorite,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _averagePrice(List<Usluga> services) {
    if (services.isEmpty) return null;
    final sum = services.fold<double>(0, (a, u) => a + u.cijena);
    return formatKm(sum / services.length);
  }

  Widget _buildCatalogBody(
    BuildContext context,
    ServiceProvider serviceProvider,
    bool isAdmin,
    bool canFavorite,
  ) {
    if (serviceProvider.isLoading) {
      return _CatalogSkeletonGrid(scrollController: _scrollController);
    }
    if (serviceProvider.loadFailed) {
      return _CatalogErrorState(
        onRetry: () => serviceProvider.fetchServices(),
      );
    }
    if (serviceProvider.services.isEmpty) {
      final hasFilters = serviceProvider.selectedCategoryId != null ||
          serviceProvider.searchQuery.isNotEmpty;
      return _CatalogEmptyState(
        hasFilters: hasFilters,
        isAdmin: isAdmin,
        onClearFilters: hasFilters ? _clearFilters : null,
        onAddService: isAdmin ? () => _openServiceEditor(null) : null,
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final crossAxisCount = w >= 1400
            ? 5
            : (w >= 1100 ? 4 : (w >= 760 ? 3 : (w >= 480 ? 2 : 1)));

        return Scrollbar(
          controller: _scrollController,
          child: GridView.builder(
            controller: _scrollController,
            primary: false,
            padding: EdgeInsets.zero,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 1.34,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            itemCount: serviceProvider.services.length,
            itemBuilder: (context, index) {
              final usluga = serviceProvider.services[index];
              final isFav = serviceProvider.isFavorite(usluga.id);

              return _ServiceCatalogCard(
                usluga: usluga,
                isAdmin: isAdmin,
                canFavorite: canFavorite,
                isFavorite: isFav,
                onOpen: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ServiceDetailsScreen(serviceId: usluga.id),
                    ),
                  );
                },
                onEdit: () => _openServiceEditor(usluga),
                onDelete: () => _confirmDeleteService(usluga),
                onToggleFavorite: () async {
                  final ok =
                      await serviceProvider.toggleFavorite(usluga.id);
                  if (!context.mounted || ok) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Could not save favorite. Sign in as a client or admin.',
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _CatalogAdminToolbar extends StatelessWidget {
  const _CatalogAdminToolbar({
    required this.onManageCategories,
    required this.onAddService,
  });

  final VoidCallback onManageCategories;
  final VoidCallback onAddService;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Spacer(),
        OutlinedButton.icon(
          onPressed: onManageCategories,
          icon: const Icon(Icons.category_outlined, size: 18),
          label: const Text('Categories'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white.withValues(alpha: 0.82),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
        const SizedBox(width: 10),
        FilledButton.icon(
          onPressed: onAddService,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add service'),
          style: FilledButton.styleFrom(
            backgroundColor: NuaLuxuryTokens.softPurpleGlow,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
        const _BackIfPossible(),
      ],
    );
  }
}

class _CatalogSummaryRow extends StatelessWidget {
  const _CatalogSummaryRow({
    required this.totalServices,
    required this.categoryCount,
    required this.favoriteCount,
    required this.averagePrice,
  });

  final int totalServices;
  final int categoryCount;
  final int favoriteCount;
  final String? averagePrice;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final compact = c.maxWidth < 720;
        final cards = [
          _SummaryMetricCard(
            label: 'Total Services',
            value: '$totalServices',
            icon: Icons.spa_outlined,
            accent: const Color(0xFF9B7BFF),
          ),
          _SummaryMetricCard(
            label: 'Categories',
            value: '$categoryCount',
            icon: Icons.grid_view_rounded,
            accent: const Color(0xFF7B4DFF),
          ),
          _SummaryMetricCard(
            label: 'Favorites',
            value: '$favoriteCount',
            icon: Icons.favorite_border_rounded,
            accent: const Color(0xFFD4AF7A),
          ),
          _SummaryMetricCard(
            label: 'Average Price',
            value: averagePrice ?? '—',
            icon: Icons.payments_outlined,
            accent: const Color(0xFFC8B6E8),
          ),
        ];

        if (compact) {
          return SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: cards.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) => SizedBox(width: 168, child: cards[i]),
            ),
          );
        }

        return SizedBox(
          height: 96,
          child: Row(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: cards[i]),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SummaryMetricCard extends StatelessWidget {
  const _SummaryMetricCard({
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 11, 14, 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.045),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: accent.withValues(alpha: 0.28)),
                ),
                child: Icon(icon, size: 14, color: accent),
              ),
              const Spacer(),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFF5F3FA),
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceCatalogCard extends StatefulWidget {
  const _ServiceCatalogCard({
    required this.usluga,
    required this.isAdmin,
    required this.canFavorite,
    required this.isFavorite,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleFavorite,
  });

  final Usluga usluga;
  final bool isAdmin;
  final bool canFavorite;
  final bool isFavorite;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleFavorite;

  @override
  State<_ServiceCatalogCard> createState() => _ServiceCatalogCardState();
}

class _ServiceCatalogCardState extends State<_ServiceCatalogCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final u = widget.usluga;
    final categoryLabel =
        ServiceCategoryFilterBar.displayLabel(u.kategorija);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _hover
                ? const Color(0xFF9B7BFF).withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.08),
          ),
          boxShadow: [
            if (_hover)
              BoxShadow(
                color: const Color(0xFF9B7BFF).withValues(alpha: 0.16),
                blurRadius: 22,
                offset: const Offset(0, 10),
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Material(
            color: Colors.white.withValues(alpha: 0.04),
            child: InkWell(
              onTap: widget.onOpen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 13,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ServiceNetworkImage(
                          imageUrl: u.slikaUrl,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          error: ColoredBox(
                            color: NuaLuxuryTokens.softPurpleGlow
                                .withValues(alpha: 0.08),
                            child: Icon(
                              Icons.spa_outlined,
                              size: 36,
                              color: NuaLuxuryTokens.softPurpleGlow
                                  .withValues(alpha: 0.45),
                            ),
                          ),
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.42),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 10,
                          bottom: 10,
                          child: _CategoryBadge(label: categoryLabel),
                        ),
                        if (widget.canFavorite)
                          Positioned(
                            top: 8,
                            right: widget.isAdmin ? 40 : 8,
                            child: _CardIconButton(
                              tooltip: widget.isFavorite
                                  ? 'Remove from favorites'
                                  : 'Add to favorites',
                              icon: widget.isFavorite
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              iconColor: widget.isFavorite
                                  ? const Color(0xFFFF8A80)
                                  : Colors.white.withValues(alpha: 0.9),
                              visible: _hover || widget.isFavorite,
                              onPressed: widget.onToggleFavorite,
                            ),
                          ),
                        if (widget.isAdmin)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: _ServiceCardMenu(
                              visible: _hover,
                              isFavorite: widget.isFavorite,
                              canFavorite: widget.canFavorite,
                              onEdit: widget.onEdit,
                              onDelete: widget.onDelete,
                              onToggleFavorite: widget.onToggleFavorite,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 9,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            u.naziv,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFF5F3FA),
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Text(
                                u.cijenaKm,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF9B7BFF),
                                ),
                              ),
                              Text(
                                ' · ',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.35),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  u.trajanje,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.58),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
          ),
        ),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.92),
          ),
        ),
      ),
    );
  }
}

class _CardIconButton extends StatelessWidget {
  const _CardIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.iconColor,
    this.visible = true,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? iconColor;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: visible ? 1 : 0.35,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: IconButton(
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          tooltip: tooltip,
          icon: Icon(icon, size: 17, color: iconColor ?? Colors.white),
          onPressed: onPressed,
        ),
      ),
    );
  }
}

class _ServiceCardMenu extends StatelessWidget {
  const _ServiceCardMenu({
    required this.visible,
    required this.isFavorite,
    required this.canFavorite,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleFavorite,
  });

  final bool visible;
  final bool isFavorite;
  final bool canFavorite;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: visible ? 1 : 0.4,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: SizedBox(
          width: 32,
          height: 32,
          child: PopupMenuButton<String>(
          tooltip: 'Service actions',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: const Icon(Icons.more_horiz_rounded, size: 18, color: Colors.white),
          color: const Color(0xFF1A1228),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          onSelected: (value) {
            switch (value) {
              case 'edit':
                onEdit();
              case 'favorite':
                onToggleFavorite();
              case 'delete':
                onDelete();
            }
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(
              value: 'edit',
              child: Text('Edit'),
            ),
            if (canFavorite)
              PopupMenuItem(
                value: 'favorite',
                child: Text(
                  isFavorite ? 'Remove favorite' : 'Add to favorites',
                ),
              ),
            const PopupMenuItem(
              value: 'delete',
              child: Text(
                'Delete',
                style: TextStyle(color: Color(0xFFFF8A80)),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _CatalogSkeletonGrid extends StatelessWidget {
  const _CatalogSkeletonGrid({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final crossAxisCount = w >= 1400
            ? 5
            : (w >= 1100 ? 4 : (w >= 760 ? 3 : (w >= 480 ? 2 : 1)));

        return GridView.builder(
          controller: scrollController,
          primary: false,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 1.34,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          itemCount: crossAxisCount * 2,
          itemBuilder: (context, index) => const _ServiceCardSkeleton(),
        );
      },
    );
  }
}

class _ServiceCardSkeleton extends StatefulWidget {
  const _ServiceCardSkeleton();

  @override
  State<_ServiceCardSkeleton> createState() => _ServiceCardSkeletonState();
}

class _ServiceCardSkeletonState extends State<_ServiceCardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final alpha = 0.05 + (_pulse.value * 0.04);
        final fill = Colors.white.withValues(alpha: alpha);
        return DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 13,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(18),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 9,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 12,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: fill,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        height: 10,
                        width: 120,
                        decoration: BoxDecoration(
                          color: fill,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CatalogEmptyState extends StatelessWidget {
  const _CatalogEmptyState({
    required this.hasFilters,
    required this.isAdmin,
    this.onClearFilters,
    this.onAddService,
  });

  final bool hasFilters;
  final bool isAdmin;
  final VoidCallback? onClearFilters;
  final VoidCallback? onAddService;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.spa_outlined,
              size: 44,
              color: NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.55),
            ),
            const SizedBox(height: 14),
            Text(
              'No services found',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFF5F3FA),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasFilters
                  ? 'Try changing filters or add a new service.'
                  : 'Add your first treatment to build the catalog.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.58),
                height: 1.4,
              ),
            ),
            if (hasFilters && onClearFilters != null) ...[
              const SizedBox(height: 14),
              TextButton(
                onPressed: onClearFilters,
                child: const Text('Clear filters'),
              ),
            ],
            if (isAdmin && onAddService != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onAddService,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add service'),
                style: FilledButton.styleFrom(
                  backgroundColor: NuaLuxuryTokens.softPurpleGlow,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CatalogErrorState extends StatelessWidget {
  const _CatalogErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 44,
              color: NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 14),
            Text(
              'Couldn\'t load services',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFF5F3FA),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.58),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                backgroundColor: NuaLuxuryTokens.softPurpleGlow,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackIfPossible extends StatelessWidget {
  const _BackIfPossible();

  @override
  Widget build(BuildContext context) {
    if (!Navigator.canPop(context)) return const SizedBox.shrink();
    return IconButton(
      tooltip: 'Back',
      onPressed: () => Navigator.pop(context),
      icon: const Icon(Icons.arrow_back),
    );
  }
}
