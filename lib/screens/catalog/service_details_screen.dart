import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/services/api_service.dart';
import '../../core/platform/nua_spa_platform.dart';
import '../../models/recenzija.dart';
import '../../models/usluga.dart';
import '../../ui/theme/mobile_spa_theme.dart';
import '../../ui/theme/luxury_modal_style.dart';

/// Premium dark spa palette for service details.
abstract final class _DetailsStyle {
  static const Color bgDeep = Color(0xFF07040F);
  static const Color bgMid = Color(0xFF120A24);
  static const Color textPrimary = Color(0xFFF5F3FA);
  static const Color textSecondary = Color(0xA6FFFFFF);
  static const Color accentPurple = Color(0xFF7B4DFF);
  static const Color gold = Color(0xFFF5B942);
  static const double cardRadius = 26;

  static TextStyle displayTitle(BuildContext context) => GoogleFonts.inter(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.15,
        color: textPrimary,
      );

  static TextStyle sectionTitle(BuildContext context) => GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: textPrimary,
      );

  static TextStyle body(BuildContext context) => GoogleFonts.inter(
        fontSize: 14.5,
        height: 1.55,
        color: textSecondary,
      );

  static TextStyle label(BuildContext context) => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: textSecondary,
      );

  static BoxDecoration glassCard({double radius = cardRadius}) => BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: accentPurple.withValues(alpha: 0.18),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      );
}

class ServiceDetailsScreen extends StatefulWidget {
  final int serviceId;

  const ServiceDetailsScreen({super.key, required this.serviceId});

  @override
  State<ServiceDetailsScreen> createState() => _ServiceDetailsScreenState();
}

class _ServiceDetailsScreenState extends State<ServiceDetailsScreen> {
  final ApiService _apiService = ApiService();
  final ScrollController _rightScrollController = ScrollController();

  Future<Usluga?> get _serviceFuture => _apiService.getUslugaById(widget.serviceId);
  late Future<List<Recenzija>> _recenzijeFuture;

  final TextEditingController _komentarController = TextEditingController();
  int _ocjena = 5;
  int _commentLength = 0;

  static const int _maxCommentLength = 500;

  @override
  void initState() {
    super.initState();
    _recenzijeFuture = _apiService.getRecenzijeByUsluga(widget.serviceId);
    _komentarController.addListener(() {
      setState(() => _commentLength = _komentarController.text.length);
    });
  }

  @override
  void dispose() {
    _komentarController.dispose();
    _rightScrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshRecenzije() async {
    setState(() {
      _recenzijeFuture = _apiService.getRecenzijeByUsluga(widget.serviceId);
    });
  }

  Future<void> _submitReview() async {
    final komentar = _komentarController.text.trim();
    if (komentar.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a comment.')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final created = await _apiService.createRecenzija(
      uslugaId: widget.serviceId,
      ocjena: _ocjena,
      komentar: komentar,
    );

    if (!mounted) return;

    if (created == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to submit review.')),
      );
      return;
    }

    _komentarController.clear();
    await _refreshRecenzije();
    messenger.showSnackBar(
      const SnackBar(content: Text('Review added.')),
    );
  }

  List<String> _benefitTags(Usluga service) {
    final opis = service.opis.trim();
    if (opis.isEmpty) return const [];

    final parts = opis
        .split(RegExp(r'[,;\n•]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e.length <= 42)
        .toList();

    if (parts.length >= 2) {
      return parts.take(4).toList();
    }

    final words = opis.split(RegExp(r'\s+')).where((w) => w.length > 3).toList();
    if (words.length >= 3) {
      return words.take(4).map((w) {
        final c = w[0].toUpperCase() + w.substring(1);
        return c.length > 24 ? '${c.substring(0, 22)}…' : c;
      }).toList();
    }

    return const [];
  }

  Widget _buildMobileSpaDetails(BuildContext context, Usluga service) {
    final tt = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: MobileSpaColors.softWhite,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 288,
            backgroundColor: MobileSpaColors.softWhite,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Center(
                child: Material(
                  color: Colors.white.withValues(alpha: 0.88),
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.pop(context),
                    child: const SizedBox(
                      width: 42,
                      height: 42,
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 17,
                        color: MobileSpaColors.royalPurple,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    service.slikaUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return ColoredBox(
                        color: MobileSpaColors.lavender.withValues(alpha: 0.28),
                        child: Icon(
                          Icons.spa_outlined,
                          size: 56,
                          color: MobileSpaColors.royalPurple.withValues(alpha: 0.28),
                        ),
                      );
                    },
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.1),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.32),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(22, 16, 22, 32 + bottomInset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(service.naziv, style: tt.headlineSmall),
                  const SizedBox(height: 14),
                  Text('${service.cijenaKm} · ${service.trajanje}'),
                  const SizedBox(height: 8),
                  Text(service.kategorija, style: tt.bodySmall),
                  const SizedBox(height: 22),
                  if (service.opis.trim().isNotEmpty)
                    Text(service.opis, style: tt.bodyMedium),
                  const SizedBox(height: 26),
                  _MobileReviewsBlock(
                    recenzijeFuture: _recenzijeFuture,
                    ocjena: _ocjena,
                    onRatingChanged: (v) => setState(() => _ocjena = v),
                    komentarController: _komentarController,
                    onRefresh: _refreshRecenzije,
                    onSubmit: _submitReview,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopDetails(BuildContext context, Usluga service) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_DetailsStyle.bgDeep, _DetailsStyle.bgMid],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 11,
              child: _LeftServicePanel(
                service: service,
                benefitTags: _benefitTags(service),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 13,
              child: _RightDetailsPanel(
                service: service,
                scrollController: _rightScrollController,
                recenzijeFuture: _recenzijeFuture,
                ocjena: _ocjena,
                onRatingChanged: (v) => setState(() => _ocjena = v),
                komentarController: _komentarController,
                commentLength: _commentLength,
                maxCommentLength: _maxCommentLength,
                onRefresh: _refreshRecenzije,
                onSubmit: _submitReview,
                onBack: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: FutureBuilder<Usluga?>(
        future: _serviceFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            if (nuaspaUseMobileShell()) {
              return const Scaffold(
                backgroundColor: MobileSpaColors.softWhite,
                body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            return const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_DetailsStyle.bgDeep, _DetailsStyle.bgMid],
                ),
              ),
              child: Center(
                child: CircularProgressIndicator(
                  color: _DetailsStyle.accentPurple,
                ),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading: ${snapshot.error}',
                style: _DetailsStyle.body(context),
              ),
            );
          }

          final service = snapshot.data;
          if (service == null) {
            return Center(
              child: Text(
                'Service not found.',
                style: _DetailsStyle.body(context),
              ),
            );
          }

          if (nuaspaUseMobileShell()) {
            return _buildMobileSpaDetails(context, service);
          }

          return _buildDesktopDetails(context, service);
        },
      ),
    );
  }
}

class _LeftServicePanel extends StatelessWidget {
  const _LeftServicePanel({
    required this.service,
    required this.benefitTags,
  });

  final Usluga service;
  final List<String> benefitTags;

  @override
  Widget build(BuildContext context) {
    final description = service.opis.trim();
    final imageHeight = (MediaQuery.sizeOf(context).height - 300).clamp(320.0, 520.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(_DetailsStyle.cardRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: DecoratedBox(
          decoration: _DetailsStyle.glassCard(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(_DetailsStyle.cardRadius),
                        ),
                        child: Image.network(
                          service.slikaUrl,
                          height: imageHeight,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: imageHeight,
                              color: _DetailsStyle.accentPurple
                                  .withValues(alpha: 0.12),
                              child: Icon(
                                Icons.spa_outlined,
                                size: 72,
                                color: _DetailsStyle.accentPurple
                                    .withValues(alpha: 0.35),
                              ),
                            );
                          },
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.28),
                          border: Border(
                            top: BorderSide(
                              color: Colors.white.withValues(alpha: 0.06),
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              service.naziv,
                              style: _DetailsStyle.displayTitle(context),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Text(
                                  service.cijenaKm,
                                  style: GoogleFonts.inter(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: _DetailsStyle.accentPurple,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Icon(
                                  Icons.schedule_rounded,
                                  size: 18,
                                  color: _DetailsStyle.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  service.trajanje,
                                  style: _DetailsStyle.body(context),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _CategoryPill(label: service.kategorija),
                            if (benefitTags.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: benefitTags
                                    .map((t) => _BenefitTag(label: t))
                                    .toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: _DescriptionMiniCard(text: description),
                        ),
                    ],
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

class _RightDetailsPanel extends StatelessWidget {
  const _RightDetailsPanel({
    required this.service,
    required this.scrollController,
    required this.recenzijeFuture,
    required this.ocjena,
    required this.onRatingChanged,
    required this.komentarController,
    required this.commentLength,
    required this.maxCommentLength,
    required this.onRefresh,
    required this.onSubmit,
    required this.onBack,
  });

  final Usluga service;
  final ScrollController scrollController;
  final Future<List<Recenzija>> recenzijeFuture;
  final int ocjena;
  final ValueChanged<int> onRatingChanged;
  final TextEditingController komentarController;
  final int commentLength;
  final int maxCommentLength;
  final VoidCallback onRefresh;
  final VoidCallback onSubmit;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final description = service.opis.trim();

    return ClipRRect(
      borderRadius: BorderRadius.circular(_DetailsStyle.cardRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: DecoratedBox(
          decoration: _DetailsStyle.glassCard(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 20, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _IconCircle(icon: Icons.description_outlined),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Service details',
                            style: _DetailsStyle.sectionTitle(context),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Service overview and reviews.',
                            style: _DetailsStyle.body(context),
                          ),
                        ],
                      ),
                    ),
                    _GlassIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Back',
                      onPressed: onBack,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Scrollbar(
                  controller: scrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: scrollController,
                    primary: false,
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _DescriptionGlassBox(
                          text: description.isEmpty
                              ? 'Description coming soon.'
                              : description,
                          muted: description.isEmpty,
                        ),
                        const SizedBox(height: 24),
                        FutureBuilder<List<Recenzija>>(
                          future: recenzijeFuture,
                          builder: (context, snapshot) {
                            final loading =
                                snapshot.connectionState == ConnectionState.waiting;
                            final reviews = snapshot.data ?? [];

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    const _IconCircle(
                                      icon: Icons.star_outline_rounded,
                                      size: 40,
                                      iconSize: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Reviews',
                                      style: _DetailsStyle.sectionTitle(context)
                                          .copyWith(fontSize: 18),
                                    ),
                                    const SizedBox(width: 10),
                                    _ReviewCountBadge(count: reviews.length),
                                    const Spacer(),
                                    _GlassIconButton(
                                      icon: Icons.refresh_rounded,
                                      tooltip: 'Refresh',
                                      onPressed: onRefresh,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                if (loading)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 20),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: _DetailsStyle.accentPurple,
                                      ),
                                    ),
                                  )
                                else if (reviews.isEmpty)
                                  Text(
                                    'Be the first to review this service.',
                                    style: _DetailsStyle.body(context),
                                  )
                                else
                                  ...reviews.map(
                                    (r) => Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: _ReviewCard(review: r),
                                    ),
                                  ),
                                const SizedBox(height: 24),
                                Text(
                                  'Add a review',
                                  style: _DetailsStyle.sectionTitle(context)
                                      .copyWith(fontSize: 18),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'Your rating',
                                  style: _DetailsStyle.label(context),
                                ),
                                const SizedBox(height: 10),
                                _GoldStarRating(
                                  value: ocjena,
                                  onChanged: onRatingChanged,
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  'Comment',
                                  style: _DetailsStyle.label(context),
                                ),
                                const SizedBox(height: 8),
                                _CommentField(
                                  controller: komentarController,
                                  maxLength: maxCommentLength,
                                  length: commentLength,
                                ),
                                const SizedBox(height: 18),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: _SubmitReviewButton(onPressed: onSubmit),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
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

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: _DetailsStyle.accentPurple.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: _DetailsStyle.accentPurple.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: _DetailsStyle.textPrimary,
        ),
      ),
    );
  }
}

class _BenefitTag extends StatelessWidget {
  const _BenefitTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: _DetailsStyle.textSecondary,
        ),
      ),
    );
  }
}

class _DescriptionMiniCard extends StatelessWidget {
  const _DescriptionMiniCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.spa_outlined,
            size: 22,
            color: _DetailsStyle.accentPurple.withValues(alpha: 0.75),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: _DetailsStyle.body(context).copyWith(
                  color: _DetailsStyle.textPrimary.withValues(alpha: 0.88),
                )),
          ),
        ],
      ),
    );
  }
}

class _DescriptionGlassBox extends StatelessWidget {
  const _DescriptionGlassBox({
    required this.text,
    this.muted = false,
  });

  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 18, 48, 18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Text(
            text,
            style: _DetailsStyle.body(context).copyWith(
              color: muted
                  ? _DetailsStyle.textSecondary
                  : _DetailsStyle.textPrimary.withValues(alpha: 0.9),
            ),
          ),
        ),
        Positioned(
          right: 14,
          bottom: 12,
          child: Icon(
            Icons.spa_outlined,
            size: 28,
            color: _DetailsStyle.accentPurple.withValues(alpha: 0.22),
          ),
        ),
      ],
    );
  }
}

class _IconCircle extends StatelessWidget {
  const _IconCircle({
    required this.icon,
    this.size = 44,
    this.iconSize = 22,
  });

  final IconData icon;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _DetailsStyle.accentPurple.withValues(alpha: 0.14),
        border: Border.all(
          color: _DetailsStyle.accentPurple.withValues(alpha: 0.32),
        ),
      ),
      child: Icon(icon, size: iconSize, color: _DetailsStyle.accentPurple),
    );
  }
}

class _GlassIconButton extends StatefulWidget {
  const _GlassIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

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
      child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _hover
                  ? _DetailsStyle.accentPurple.withValues(alpha: 0.22)
                  : Colors.white.withValues(alpha: 0.05),
              border: Border.all(
                color: Colors.white.withValues(alpha: _hover ? 0.14 : 0.1),
              ),
              boxShadow: _hover
                  ? [
                      BoxShadow(
                        color: _DetailsStyle.accentPurple.withValues(alpha: 0.25),
                        blurRadius: 14,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              widget.icon,
              size: 20,
              color: _hover ? _DetailsStyle.textPrimary : _DetailsStyle.textSecondary,
            ),
          ),
        ),
    );
  }
}

class _ReviewCountBadge extends StatelessWidget {
  const _ReviewCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Text(
        '$count review${count == 1 ? '' : 's'}',
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: _DetailsStyle.textSecondary,
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final Recenzija review;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  review.korisnikIme.isEmpty ? 'Guest' : review.korisnikIme,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: _DetailsStyle.textPrimary,
                    fontSize: 14,
                  ),
                ),
              ),
              _StarRow(value: review.ocjena, size: 16),
            ],
          ),
          if (review.komentar.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(review.komentar, style: _DetailsStyle.body(context)),
          ],
        ],
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.value, this.size = 18});

  final int value;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(
          i < value ? Icons.star_rounded : Icons.star_outline_rounded,
          size: size,
          color: _DetailsStyle.gold,
        ),
      ),
    );
  }
}

class _GoldStarRating extends StatefulWidget {
  const _GoldStarRating({
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  State<_GoldStarRating> createState() => _GoldStarRatingState();
}

class _GoldStarRatingState extends State<_GoldStarRating> {
  int? _hovered;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (i) {
        final star = i + 1;
        final filled = star <= (widget.value);
        final hovered = _hovered != null && star <= _hovered!;

        return Padding(
          padding: EdgeInsets.only(right: i < 4 ? 6 : 0),
          child: MouseRegion(
            onEnter: (_) => setState(() => _hovered = star),
            onExit: (_) => setState(() => _hovered = null),
            child: GestureDetector(
              onTap: () => widget.onChanged(star),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                decoration: hovered
                    ? BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _DetailsStyle.gold.withValues(alpha: 0.45),
                            blurRadius: 14,
                          ),
                        ],
                      )
                    : null,
                child: Icon(
                  filled || hovered
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 28,
                  color: filled || hovered
                      ? _DetailsStyle.gold
                      : _DetailsStyle.gold.withValues(alpha: 0.35),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _CommentField extends StatefulWidget {
  const _CommentField({
    required this.controller,
    required this.maxLength,
    required this.length,
  });

  final TextEditingController controller;
  final int maxLength;
  final int length;

  @override
  State<_CommentField> createState() => _CommentFieldState();
}

class _CommentFieldState extends State<_CommentField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 130,
          decoration: BoxDecoration(
            color: LuxuryModalStyle.fieldBg.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _focused
                  ? _DetailsStyle.accentPurple.withValues(alpha: 0.65)
                  : Colors.white.withValues(alpha: 0.08),
            ),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: _DetailsStyle.accentPurple.withValues(alpha: 0.15),
                      blurRadius: 16,
                    ),
                  ]
                : null,
          ),
          child: Focus(
            onFocusChange: (f) => setState(() => _focused = f),
            child: TextField(
            controller: widget.controller,
            maxLength: widget.maxLength,
            maxLines: null,
            expands: true,
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
            style: LuxuryModalStyle.fieldStyle(context),
            decoration: InputDecoration(
              hintText: 'Share your experience…',
              hintStyle: LuxuryModalStyle.hintTextStyle(),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              counterText: '',
              contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${widget.length} / ${widget.maxLength}',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: _DetailsStyle.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _SubmitReviewButton extends StatefulWidget {
  const _SubmitReviewButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_SubmitReviewButton> createState() => _SubmitReviewButtonState();
}

class _SubmitReviewButtonState extends State<_SubmitReviewButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
          width: 180,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: _hover
                  ? [
                      const Color(0xFF8F5FFF),
                      _DetailsStyle.accentPurple,
                    ]
                  : [
                      _DetailsStyle.accentPurple,
                      const Color(0xFF9B7BFF),
                    ],
            ),
            boxShadow: [
              BoxShadow(
                color: _DetailsStyle.accentPurple
                    .withValues(alpha: _hover ? 0.45 : 0.32),
                blurRadius: _hover ? 20 : 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.send_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                'Submit Review',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Simplified mobile reviews block (keeps backend wiring).
class _MobileReviewsBlock extends StatelessWidget {
  const _MobileReviewsBlock({
    required this.recenzijeFuture,
    required this.ocjena,
    required this.onRatingChanged,
    required this.komentarController,
    required this.onRefresh,
    required this.onSubmit,
  });

  final Future<List<Recenzija>> recenzijeFuture;
  final int ocjena;
  final ValueChanged<int> onRatingChanged;
  final TextEditingController komentarController;
  final VoidCallback onRefresh;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Recenzija>>(
      future: recenzijeFuture,
      builder: (context, snapshot) {
        final reviews = snapshot.data ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Reviews', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh)),
              ],
            ),
            if (reviews.isEmpty)
              const Text('No reviews for this service yet.')
            else
              ...reviews.map(
                (r) => ListTile(
                  title: Text(r.korisnikIme.isEmpty ? 'User' : r.korisnikIme),
                  subtitle: Text(r.komentar),
                ),
              ),
            const SizedBox(height: 16),
            _GoldStarRating(value: ocjena, onChanged: onRatingChanged),
            const SizedBox(height: 8),
            TextField(
              controller: komentarController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Comment'),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onSubmit, child: const Text('Submit')),
          ],
        );
      },
    );
  }
}
