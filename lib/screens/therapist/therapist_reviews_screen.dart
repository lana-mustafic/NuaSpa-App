import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/api/services/api_service.dart';
import '../../core/auth/app_permissions.dart';
import '../../core/platform/nua_spa_platform.dart';
import '../../models/admin/therapist_admin_profile.dart';
import '../../models/therapist/therapist_my_reviews_summary.dart';
import '../../providers/auth_provider.dart';
import '../../ui/navigation/desktop_nav.dart';
import 'therapist_appointments_screen.dart';
import 'therapist_portal_scaffold.dart';

abstract final class _RevUi {
  static const bgTop = Color(0xFF07040F);
  static const bgBottom = Color(0xFF120A24);
  static const textPrimary = Color(0xFFF5F3FA);
  static const textSecondary = Color(0xA6FFFFFF);
  static const purple = Color(0xFF7B4DFF);
  static const lavender = Color(0xFF9D6BFF);
  static const gold = Color(0xFFF5B942);
  static const cardRadius = 24.0;
  static const gap = 20.0;
  static const contentPadding = 32.0;
  static const pageSize = 20;
}

String _formatShortDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final loc = d.toLocal();
  return '${months[loc.month - 1]} ${loc.day}, ${loc.year}';
}

String _clientInitial(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  return String.fromCharCode(trimmed.runes.first).toUpperCase();
}

int _clampStars(int stars) => stars.clamp(0, 5);

List<TherapistReviewRow> _filterReviews(
  List<TherapistReviewRow> all, {
  required String ratingFilter,
  required String query,
}) {
  var list = [...all];
  switch (ratingFilter) {
    case '5★':
      list = list.where((r) => r.ocjena == 5).toList();
    case '4★':
      list = list.where((r) => r.ocjena == 4).toList();
    case '3★':
      list = list.where((r) => r.ocjena == 3).toList();
    case '2★':
      list = list.where((r) => r.ocjena == 2).toList();
    case '1★':
      list = list.where((r) => r.ocjena == 1).toList();
    default:
      break;
  }
  final q = query.trim().toLowerCase();
  if (q.isNotEmpty) {
    list = list
        .where(
          (r) =>
              r.korisnikIme.toLowerCase().contains(q) ||
              r.uslugaNaziv.toLowerCase().contains(q) ||
              r.komentar.toLowerCase().contains(q) ||
              (r.adminOdgovor ?? '').toLowerCase().contains(q),
        )
        .toList();
  }
  return list;
}

List<TherapistReviewRow> _sortReviews(
  List<TherapistReviewRow> list,
  String mode,
) {
  final copy = [...list];
  switch (mode) {
    case 'Oldest First':
      copy.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    case 'Highest Rating':
      copy.sort((a, b) => b.ocjena.compareTo(a.ocjena));
    case 'Lowest Rating':
      copy.sort((a, b) => a.ocjena.compareTo(b.ocjena));
    default:
      copy.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
  return copy;
}

String _reviewsHeaderSubtitle(TherapistMyReviewsSummary summary) {
  if (summary.totalCount == 0) {
    return 'Client feedback from appointments you performed.';
  }
  final avg = summary.averageRating.toStringAsFixed(1);
  if (summary.totalCount == 1) {
    return '1 review · $avg average rating.';
  }
  return '${summary.totalCount} reviews · $avg average rating.';
}

void _applyReviewsHeader(
  BuildContext context, {
  required TherapistMyReviewsSummary summary,
}) {
  const title = 'My Reviews';
  final subtitle = _reviewsHeaderSubtitle(summary);
  if (!nuaspaUseMobileShell()) {
    context.read<DesktopNav>().setTherapistReviewsHeader(
      title: title,
      subtitle: subtitle,
    );
  }
}

void _openAppointments(BuildContext context) {
  if (nuaspaUseMobileShell()) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TherapistAppointmentsScreen(
          filterDay: DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
          ),
        ),
      ),
    );
    return;
  }
  context.read<DesktopNav>().goTo(DesktopRouteKey.therapistAppointments);
}

class _ReviewsData {
  const _ReviewsData({
    required this.summary,
    required this.reviews,
    required this.totalReviews,
    required this.currentPage,
    this.loadError,
    this.summaryError,
  });

  final TherapistMyReviewsSummary summary;
  final List<TherapistReviewRow> reviews;
  final int totalReviews;
  final int currentPage;
  final String? loadError;
  final String? summaryError;

  bool get hasMore => reviews.length < totalReviews;
}

class TherapistReviewsScreen extends StatefulWidget {
  const TherapistReviewsScreen({super.key});

  @override
  State<TherapistReviewsScreen> createState() => _TherapistReviewsScreenState();
}

class _TherapistReviewsScreenState extends State<TherapistReviewsScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  Future<_ReviewsData>? _future;
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String _ratingFilter = 'All';
  String _sortMode = 'Newest First';
  String _searchQuery = '';
  String _lastNavSearch = '';
  String _headerTitle = 'My Reviews';
  String _headerSubtitle =
      'Client feedback from appointments you performed.';
  Timer? _searchDebounce;
  bool _loadingMore = false;
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
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (nuaspaUseMobileShell()) return;
    final search = context.read<DesktopNav>().therapistReviewsSearchQuery;
    if (search == _lastNavSearch) return;
    _lastNavSearch = search;
    if (_searchCtrl.text != search) {
      _searchCtrl.text = search;
    }
    setState(() => _searchQuery = search.trim().toLowerCase());
  }

  Future<_ReviewsData> _fetchPage({required int page, _ReviewsData? prior}) async {
    final summaryFuture = page == 1
        ? _api.getTherapistMyReviewsSummary()
        : null;
    final pageFuture = _api.getTherapistMyReviewsPage(
      page: page,
      pageSize: _RevUi.pageSize,
    );

    final summaryResult = summaryFuture != null
        ? await summaryFuture
        : null;
    final pageResult = await pageFuture;

    if (summaryResult?.accountNotLinked == true || pageResult.accountNotLinked) {
      throw _ReviewsLoadException(
        summaryResult?.error ??
            pageResult.error ??
            'Your account is not linked to a therapist profile.',
        accountNotLinked: true,
      );
    }

    final summary = summaryResult?.summary ??
        prior?.summary ??
        const TherapistMyReviewsSummary();
    final summaryError = summaryResult?.error;

    if (pageResult.error != null && page == 1 && summaryError != null) {
      throw _ReviewsLoadException(pageResult.error!);
    }

    final merged = page == 1
        ? pageResult.items
        : [...?prior?.reviews, ...pageResult.items];

    return _ReviewsData(
      summary: summary,
      reviews: merged,
      totalReviews: pageResult.total > 0
          ? pageResult.total
          : (summary.totalCount > 0 ? summary.totalCount : merged.length),
      currentPage: pageResult.page,
      loadError: pageResult.error,
      summaryError: summaryError,
    );
  }

  Future<void> _reload() async {
    setState(() {
      _future = _fetchPage(page: 1);
    });
    final data = await _future;
    if (!mounted) return;

    final summary = data?.summary ?? const TherapistMyReviewsSummary();
    const title = 'My Reviews';
    final subtitle = _reviewsHeaderSubtitle(summary);
    _applyReviewsHeader(
      context,
      summary: summary,
    );
    if (nuaspaUseMobileShell()) {
      setState(() {
        _headerTitle = title;
        _headerSubtitle = subtitle;
      });
    }

    _fadeCtrl.forward(from: 0);
  }

  Future<void> _loadMore(_ReviewsData data) async {
    if (_loadingMore || !data.hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final next = await _fetchPage(page: data.currentPage + 1, prior: data);
      if (!mounted) return;
      setState(() {
        _future = Future.value(next);
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _searchQuery = value.trim().toLowerCase());
    });
  }

  Widget _wrapForPlatform(Widget child) {
    if (!nuaspaUseMobileShell()) return child;
    return TherapistMobilePageShell(
      title: _headerTitle,
      subtitle: _headerSubtitle,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!AppPermissions.of(auth).has(AppPermission.viewOwnTherapistData)) {
      return _wrapForPlatform(
        const _ReviewsShell(
          child: TherapistEmptyState(
            message:
                'Therapist login required. Your account must be linked to a therapist profile.',
          ),
        ),
      );
    }

    return _wrapForPlatform(
      _ReviewsShell(
      child: RefreshIndicator(
        color: _RevUi.lavender,
        onRefresh: _reload,
        child: FutureBuilder<_ReviewsData>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting && !_loadingMore) {
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

            if (snap.hasError) {
              final err = snap.error;
              final message = err is _ReviewsLoadException
                  ? err.message
                  : 'Something went wrong while loading reviews.';
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(_RevUi.contentPadding),
                children: [
                  _ErrorCard(message: message, onRetry: _reload),
                ],
              );
            }

            final data = snap.data;
            if (data == null) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(_RevUi.contentPadding),
                children: [
                  _ErrorCard(
                    message: 'Could not load reviews.',
                    onRetry: _reload,
                  ),
                ],
              );
            }

            if (data.loadError != null && data.reviews.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(_RevUi.contentPadding),
                children: [
                  _ErrorCard(message: data.loadError!, onRetry: _reload),
                ],
              );
            }

            final filtered = _sortReviews(
              _filterReviews(
                data.reviews,
                ratingFilter: _ratingFilter,
                query: _searchQuery,
              ),
              _sortMode,
            );

            return FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                controller: _scrollCtrl,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  _RevUi.contentPadding,
                  8,
                  _RevUi.contentPadding,
                  40,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (data.summaryError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _InfoBanner(message: data.summaryError!),
                      ),
                    _SummaryStrip(summary: data.summary),
                    const SizedBox(height: _RevUi.gap),
                    _ReviewsSection(
                      summary: data.summary,
                      loadedCount: data.reviews.length,
                      filtered: filtered,
                      hasLoadedReviews: data.reviews.isNotEmpty,
                      hasMore: data.hasMore,
                      loadingMore: _loadingMore,
                      ratingFilter: _ratingFilter,
                      sortMode: _sortMode,
                      searchCtrl: _searchCtrl,
                      showInlineSearch: nuaspaUseMobileShell(),
                      isFilteringLoadedOnly: data.hasMore,
                      onSearchChanged: _onSearchChanged,
                      onRatingFilter: (f) => setState(() => _ratingFilter = f),
                      onSort: (s) => setState(() => _sortMode = s),
                      onLoadMore: () => _loadMore(data),
                      onViewAppointments: () => _openAppointments(context),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      ),
    );
  }
}

class _ReviewsLoadException implements Exception {
  _ReviewsLoadException(this.message, {this.accountNotLinked = false});

  final String message;
  final bool accountNotLinked;

  @override
  String toString() => message;
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _RevGlass(
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w800,
              color: _RevUi.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
            style: TextButton.styleFrom(foregroundColor: _RevUi.lavender),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: _RevUi.gold.withValues(alpha: 0.1),
        border: Border.all(color: _RevUi.gold.withValues(alpha: 0.3)),
      ),
      child: Text(
        message,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _RevUi.textPrimary,
        ),
      ),
    );
  }
}

class _ReviewsShell extends StatelessWidget {
  const _ReviewsShell({required this.child});

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
              colors: [_RevUi.bgTop, _RevUi.bgBottom],
            ),
          ),
        ),
        Positioned(
          top: -60,
          right: 40,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _RevUi.purple.withValues(alpha: 0.18),
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

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.summary});

  final TherapistMyReviewsSummary summary;

  @override
  Widget build(BuildContext context) {
    final avg = summary.totalCount > 0
        ? summary.averageRating.toStringAsFixed(1)
        : '—';
    final topService = summary.mostReviewedServiceName?.trim().isNotEmpty == true
        ? summary.mostReviewedServiceName!.trim()
        : '—';

    return _RevGlass(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: LayoutBuilder(
        builder: (context, c) {
          final stack = c.maxWidth < 720;
          final items = [
            _SummaryCell(
              label: 'Average Rating',
              value: summary.totalCount > 0 ? '$avg / 5' : '—',
            ),
            _SummaryCell(
              label: 'Total Reviews',
              value: summary.totalCount.toString(),
            ),
            _SummaryCell(
              label: 'Most Reviewed Service',
              value: topService,
            ),
          ];

          if (stack) {
            return Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  items[i],
                  if (i < items.length - 1) const SizedBox(height: 12),
                ],
              ],
            );
          }

          return Row(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                Expanded(child: items[i]),
                if (i < items.length - 1)
                  Container(
                    width: 1,
                    height: 36,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCell extends StatelessWidget {
  const _SummaryCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _RevUi.textSecondary,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: _RevUi.textPrimary,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _ReviewsSection extends StatelessWidget {
  const _ReviewsSection({
    required this.summary,
    required this.loadedCount,
    required this.filtered,
    required this.hasLoadedReviews,
    required this.hasMore,
    required this.loadingMore,
    required this.ratingFilter,
    required this.sortMode,
    required this.searchCtrl,
    required this.showInlineSearch,
    required this.isFilteringLoadedOnly,
    required this.onSearchChanged,
    required this.onRatingFilter,
    required this.onSort,
    required this.onLoadMore,
    required this.onViewAppointments,
  });

  final TherapistMyReviewsSummary summary;
  final int loadedCount;
  final List<TherapistReviewRow> filtered;
  final bool hasLoadedReviews;
  final bool hasMore;
  final bool loadingMore;
  final String ratingFilter;
  final String sortMode;
  final TextEditingController searchCtrl;
  final bool showInlineSearch;
  final bool isFilteringLoadedOnly;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onRatingFilter;
  final ValueChanged<String> onSort;
  final VoidCallback onLoadMore;
  final VoidCallback onViewAppointments;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Reviews',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _RevUi.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '(${summary.totalCount})',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _RevUi.textSecondary,
              ),
            ),
          ],
        ),
        if (isFilteringLoadedOnly && loadedCount < summary.totalCount) ...[
          const SizedBox(height: 6),
          Text(
            'Showing $loadedCount of ${summary.totalCount} reviews. Load more to search older feedback.',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: _RevUi.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: 14),
        _FilterToolbar(
          searchCtrl: searchCtrl,
          ratingFilter: ratingFilter,
          sortMode: sortMode,
          showInlineSearch: showInlineSearch,
          onSearchChanged: onSearchChanged,
          onRatingFilter: onRatingFilter,
          onSort: onSort,
        ),
        const SizedBox(height: 16),
        if (!hasLoadedReviews)
          _ReviewsEmptyState(onViewAppointments: onViewAppointments)
        else if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Text(
              'No reviews match your filters.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: _RevUi.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          Column(
            children: [
              for (var i = 0; i < filtered.length; i++) ...[
                _ReviewCard(review: filtered[i]),
                if (i < filtered.length - 1) const SizedBox(height: 12),
              ],
              if (hasMore) ...[
                const SizedBox(height: 16),
                Center(
                  child: loadingMore
                      ? const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : TextButton(
                          onPressed: onLoadMore,
                          style: TextButton.styleFrom(
                            foregroundColor: _RevUi.lavender,
                          ),
                          child: Text(
                            'Load more reviews ($loadedCount of ${summary.totalCount})',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                          ),
                        ),
                ),
              ],
            ],
          ),
      ],
    );
  }
}

class _FilterToolbar extends StatelessWidget {
  const _FilterToolbar({
    required this.searchCtrl,
    required this.ratingFilter,
    required this.sortMode,
    required this.showInlineSearch,
    required this.onSearchChanged,
    required this.onRatingFilter,
    required this.onSort,
  });

  final TextEditingController searchCtrl;
  final String ratingFilter;
  final String sortMode;
  final bool showInlineSearch;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onRatingFilter;
  final ValueChanged<String> onSort;

  static const _filters = ['All', '5★', '4★', '3★', '2★', '1★'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final stack = c.maxWidth < 720;
            final search = SizedBox(
              width: stack ? double.infinity : 280,
              child: _RevGlass(
                radius: 14,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: searchCtrl,
                    onChanged: onSearchChanged,
                    style: GoogleFonts.inter(
                      color: _RevUi.textPrimary,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search client, service, or comment…',
                      hintStyle: GoogleFonts.inter(
                        color: _RevUi.textSecondary,
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      icon: Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: _RevUi.lavender.withValues(alpha: 0.75),
                      ),
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
            );
            final sort = _SortDropdown(value: sortMode, onChanged: onSort);

            if (!showInlineSearch) {
              return Align(alignment: Alignment.centerLeft, child: sort);
            }
            if (stack) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  search,
                  const SizedBox(height: 10),
                  Align(alignment: Alignment.centerLeft, child: sort),
                ],
              );
            }
            return Row(
              children: [search, const SizedBox(width: 12), sort],
            );
          },
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final f in _filters) ...[
                _RatingFilterChip(
                  label: f,
                  selected: ratingFilter == f,
                  onTap: () => onRatingFilter(f),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RatingFilterChip extends StatefulWidget {
  const _RatingFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_RatingFilterChip> createState() => _RatingFilterChipState();
}

class _RatingFilterChipState extends State<_RatingFilterChip> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: widget.selected
                ? const LinearGradient(
                    colors: [_RevUi.purple, _RevUi.lavender],
                  )
                : null,
            color: widget.selected
                ? null
                : Colors.white.withValues(
                    alpha: (_hover || _pressed) ? 0.07 : 0.04,
                  ),
            border: Border.all(
              color: widget.selected
                  ? _RevUi.lavender.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Text(
            widget.label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: widget.selected ? Colors.white : _RevUi.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _SortDropdown extends StatelessWidget {
  const _SortDropdown({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  static const _options = [
    'Newest First',
    'Oldest First',
    'Highest Rating',
    'Lowest Rating',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 40,
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
              dropdownColor: _RevUi.bgBottom,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _RevUi.textPrimary,
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

class _ReviewCard extends StatefulWidget {
  const _ReviewCard({required this.review});

  final TherapistReviewRow review;

  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  bool _hover = false;
  bool _pressed = false;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.review;
    final clientName =
        r.korisnikIme.trim().isEmpty ? 'Client' : r.korisnikIme.trim();
    final serviceName =
        r.uslugaNaziv.trim().isEmpty ? 'Service' : r.uslugaNaziv.trim();
    final comment = r.komentar.trim().isEmpty
        ? 'No written comment provided.'
        : r.komentar.trim();
    final adminReply = r.adminOdgovor?.trim();
    final stars = _clampStars(r.ocjena);
    final longComment = comment.length > 220;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: (_hover || _pressed)
                ? Colors.white.withValues(alpha: 0.055)
                : Colors.white.withValues(alpha: 0.035),
            border: Border.all(
              color: (_hover || _pressed)
                  ? _RevUi.purple.withValues(alpha: 0.32)
                  : Colors.white.withValues(alpha: 0.08),
            ),
            boxShadow: (_hover || _pressed)
                ? [
                    BoxShadow(
                      color: _RevUi.purple.withValues(alpha: 0.16),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ClientAvatar(initials: _clientInitial(clientName)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                clientName,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: _RevUi.textPrimary,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                serviceName,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: _RevUi.lavender.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _StarRating(stars: stars),
                            const SizedBox(height: 4),
                            Text(
                              _formatShortDate(r.createdAt),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: _RevUi.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      comment,
                      maxLines: _expanded ? null : 4,
                      overflow: _expanded ? null : TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        height: 1.5,
                        color: _RevUi.textSecondary.withValues(alpha: 0.95),
                      ),
                    ),
                    if (longComment)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: GestureDetector(
                          onTap: () => setState(() => _expanded = !_expanded),
                          child: Text(
                            _expanded ? 'Show less' : 'Read more',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _RevUi.lavender,
                            ),
                          ),
                        ),
                      ),
                    if (adminReply != null && adminReply.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white.withValues(alpha: 0.04),
                          border: Border.all(
                            color: _RevUi.purple.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Spa response',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                                color: _RevUi.lavender.withValues(alpha: 0.85),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              adminReply,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                height: 1.45,
                                color: _RevUi.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

class _ClientAvatar extends StatelessWidget {
  const _ClientAvatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            _RevUi.purple.withValues(alpha: 0.5),
            _RevUi.lavender.withValues(alpha: 0.25),
          ],
        ),
        border: Border.all(color: _RevUi.lavender.withValues(alpha: 0.4)),
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _StarRating extends StatelessWidget {
  const _StarRating({required this.stars, this.size = 15});

  final int stars;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++)
          Icon(
            i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            color: _RevUi.gold,
          ),
      ],
    );
  }
}

class _ReviewsEmptyState extends StatelessWidget {
  const _ReviewsEmptyState({required this.onViewAppointments});

  final VoidCallback onViewAppointments;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.03),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.rate_review_outlined,
            size: 48,
            color: _RevUi.lavender.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No reviews yet',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _RevUi.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Client reviews will appear here after completed appointments.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.45,
              color: _RevUi.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: onViewAppointments,
            icon: const Icon(Icons.event_available_outlined, size: 18),
            label: const Text('View Appointments'),
            style: TextButton.styleFrom(foregroundColor: _RevUi.lavender),
          ),
        ],
      ),
    );
  }
}

class _RevGlass extends StatelessWidget {
  const _RevGlass({
    required this.child,
    this.padding,
    this.radius = _RevUi.cardRadius,
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
            color: _RevUi.purple.withValues(alpha: 0.1),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}
