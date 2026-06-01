import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/services/api_service.dart';
import '../../models/usluga.dart';
import '../../models/preporucena_usluga.dart';
import '../../ui/widgets/preporuka_service_card.dart';
import '../../providers/auth_provider.dart';
import '../../providers/mobile_nav_provider.dart';
import '../../providers/service_provider.dart';
import '../catalog/service_details_screen.dart';
import '../../ui/theme/mobile_spa_theme.dart';
import '../../ui/widgets/favorites_quick_link.dart';
import '../../ui/widgets/service_network_image.dart';

/// Light zen landing — recommendations + entry into Services tab.
class MobileHomeScreen extends StatefulWidget {
  const MobileHomeScreen({super.key});

  @override
  State<MobileHomeScreen> createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends State<MobileHomeScreen> {
  final ApiService _api = ApiService();
  List<PreporucenaUsluga>? _preporuke;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<ServiceProvider>().fetchFavorites();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.read<AuthProvider>().isZaposlenik) {
        setState(() => _loading = false);
        return;
      }
      _load();
    });
  }

  Future<void> _load() async {
    final list = await _api.getPreporuke(take: 8);
    if (!mounted) return;
    setState(() {
      _preporuke = list;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final auth = context.watch<AuthProvider>();
    final favorites = context.watch<ServiceProvider>().favoriteServices;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        MobileSpaColors.lavender.withValues(alpha: 0.55),
                        Colors.white.withValues(alpha: 0.4),
                        MobileSpaColors.softWhite,
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: MobileSpaColors.royalPurple.withValues(alpha: 0.06),
                        blurRadius: 28,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'NuaSpa',
                        style: tt.headlineMedium?.copyWith(
                          letterSpacing: 0.6,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Relax. Renew. Rejuvenate.',
                        style: tt.bodyMedium?.copyWith(
                          color: MobileSpaColors.royalPurple.withValues(alpha: 0.55),
                          letterSpacing: 0.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'A curated space for calm rituals and restorative care.',
                        style: tt.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (!auth.isZaposlenik)
          SliverToBoxAdapter(
            child: FavoritesQuickLink(count: favorites.length),
          ),
        if (!auth.isZaposlenik && favorites.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 0, 12),
              child: Text('Your favorites', style: tt.titleLarge),
            ),
          ),
        if (!auth.isZaposlenik && favorites.isNotEmpty)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 200,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                scrollDirection: Axis.horizontal,
                itemCount: favorites.length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (context, i) {
                  return _RecommendCard(usluga: favorites[i]);
                },
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
            child: Row(
              children: [
                Text('For you', style: tt.titleLarge),
              ],
            ),
          ),
        ),
        if (_loading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          )
        else if ((_preporuke ?? []).isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Browse treatments in Services to discover your ritual.',
                style: tt.bodyMedium,
              ),
            ),
          )
        else
          SliverToBoxAdapter(
            child: SizedBox(
              height: 248,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                scrollDirection: Axis.horizontal,
                itemCount: _preporuke!.length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (context, i) {
                  final item = _preporuke![i];
                  return PreporukaServiceCard(
                    width: 168,
                    compact: true,
                    item: item,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ServiceDetailsScreen(
                            serviceId: item.usluga.id,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 28, 24, 32 + bottom),
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: MobileSpaColors.royalPurple,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                elevation: 0,
              ),
              onPressed: () =>
                  context.read<MobileNavProvider>().setTab(1),
              child: const Text('Explore all services'),
            ),
          ),
        ),
      ],
    );
  }
}

class _RecommendCard extends StatelessWidget {
  const _RecommendCard({required this.usluga});

  final Usluga usluga;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return SizedBox(
      width: 160,
      child: Material(
        color: Colors.white.withValues(alpha: 0.75),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: MobileSpaColors.lavender.withValues(alpha: 0.3),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => ServiceDetailsScreen(serviceId: usluga.id),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ServiceNetworkImage(
                  imageUrl: usluga.slikaUrl,
                  fit: BoxFit.cover,
                  error: Container(
                    color: MobileSpaColors.lavender.withValues(alpha: 0.2),
                    child: Icon(
                      Icons.spa_outlined,
                      color: MobileSpaColors.royalPurple.withValues(alpha: 0.35),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      usluga.naziv,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleSmall?.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      usluga.cijenaKm,
                      style: tt.bodySmall?.copyWith(
                        color: MobileSpaColors.gold,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
