import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/api_error_messages.dart';
import '../../core/api/services/api_service.dart';
import '../../models/obavijest.dart';
import '../../ui/theme/mobile_spa_theme.dart';
import '../../ui/theme/nua_luxury_tokens.dart';
import '../../ui/widgets/service_network_image.dart';
import 'news_detail_screen.dart';

class NewsListScreen extends StatefulWidget {
  const NewsListScreen({
    super.key,
    this.luxury = false,
    this.embedded = false,
  });

  final bool luxury;
  final bool embedded;

  @override
  State<NewsListScreen> createState() => _NewsListScreenState();
}

class _NewsListScreenState extends State<NewsListScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<Obavijest> _items = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _api.getObavijesti();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ApiErrorMessages.fromObject(e);
      });
    }
  }

  void _open(Obavijest item) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => NewsDetailScreen(item: item, luxury: widget.luxury),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildBody();
    if (widget.embedded) {
      return body;
    }
    if (widget.luxury) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('News'),
        ),
        body: body,
      );
    }
    return Scaffold(
      backgroundColor: MobileSpaColors.softWhite,
      appBar: AppBar(title: const Text('News')),
      body: body,
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _reload, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Text(
          'No spa news yet.',
          style: widget.luxury
              ? GoogleFonts.manrope(
                  color: NuaLuxuryTokens.lavenderWhisper.withValues(alpha: 0.7),
                )
              : Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final item = _items[i];
          return widget.luxury
              ? _LuxuryNewsCard(item: item, onTap: () => _open(item))
              : _MobileNewsCard(item: item, onTap: () => _open(item));
        },
      ),
    );
  }
}

class _MobileNewsCard extends StatelessWidget {
  const _MobileNewsCard({required this.item, required this.onTap});

  final Obavijest item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Material(
      color: Colors.white.withValues(alpha: 0.82),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: MobileSpaColors.lavender.withValues(alpha: 0.35),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            SizedBox(
              width: 96,
              height: 96,
              child: item.slikaUrl == null || item.slikaUrl!.isEmpty
                  ? ColoredBox(
                      color: MobileSpaColors.lavender.withValues(alpha: 0.22),
                      child: Icon(
                        Icons.campaign_outlined,
                        color: MobileSpaColors.royalPurple.withValues(alpha: 0.4),
                      ),
                    )
                  : ServiceNetworkImage(imageUrl: item.slikaUrl!),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.naslov,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.publishedLabel,
                      style: tt.bodySmall?.copyWith(
                        color: MobileSpaColors.royalPurple.withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.excerpt,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall,
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

class _LuxuryNewsCard extends StatelessWidget {
  const _LuxuryNewsCard({required this.item, required this.onTap});

  final Obavijest item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF161022),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            SizedBox(
              width: 120,
              height: 108,
              child: item.slikaUrl == null || item.slikaUrl!.isEmpty
                  ? ColoredBox(
                      color: Colors.white.withValues(alpha: 0.04),
                      child: Icon(
                        Icons.campaign_outlined,
                        color: NuaLuxuryTokens.lavenderWhisper.withValues(
                          alpha: 0.45,
                        ),
                      ),
                    )
                  : ServiceNetworkImage(imageUrl: item.slikaUrl!),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.naslov,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFF5F3FA),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.publishedLabel,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: NuaLuxuryTokens.lavenderWhisper.withValues(
                          alpha: 0.65,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.excerpt,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
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
