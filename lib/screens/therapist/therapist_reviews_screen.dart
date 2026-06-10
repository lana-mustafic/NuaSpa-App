import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/api/services/api_service.dart';
import '../../core/auth/app_permissions.dart';
import '../../models/admin/therapist_admin_profile.dart';
import '../../providers/auth_provider.dart';
import '../../ui/navigation/desktop_nav.dart';
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
}

class _ReviewStats {
  const _ReviewStats({
    required this.averageRating,
    required this.total,
    this.mostReviewedService,
    this.latestReview,
  });

  final double averageRating;
  final int total;
  final String? mostReviewedService;
  final TherapistReviewRow? latestReview;
}

_ReviewStats _computeStats(List<TherapistReviewRow> reviews) {
  if (reviews.isEmpty) {
    return const _ReviewStats(averageRating: 0, total: 0);
  }

  final total = reviews.length;
  final sum = reviews.fold<int>(0, (s, r) => s + r.ocjena);
  final avg = sum / total;

  final byService = <String, int>{};
  for (final r in reviews) {
    final key = r.uslugaNaziv.trim().isEmpty ? 'Service' : r.uslugaNaziv.trim();
    byService[key] = (byService[key] ?? 0) + 1;
  }
  String? topService;
  var topCount = 0;
  for (final e in byService.entries) {
    if (e.value > topCount) {
      topCount = e.value;
      topService = e.key;
    }
  }

  final sorted = [...reviews]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  return _ReviewStats(
    averageRating: avg,
    total: total,
    mostReviewedService: topService,
    latestReview: sorted.first,
  );
}

String _formatShortDate(DateTime d) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final loc = d.toLocal();
  return '${months[loc.month - 1]} ${loc.day}, ${loc.year}';
}

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
              r.komentar.toLowerCase().contains(q),
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

class TherapistReviewsScreen extends StatefulWidget {
  const TherapistReviewsScreen({super.key});

  @override
  State<TherapistReviewsScreen> createState() => _TherapistReviewsScreenState();
}

class _TherapistReviewsScreenState extends State<TherapistReviewsScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  Future<(List<TherapistReviewRow> items, String? error)>? _future;
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String _ratingFilter = 'All';
  String _sortMode = 'Newest First';
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
      _future = _api.getTherapistMyReviews();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!AppPermissions.of(auth).has(AppPermission.viewOwnTherapistData)) {
      return const _ReviewsShell(
        child: TherapistEmptyState(message: 'Therapist login required.'),
      );
    }

    return _ReviewsShell(
      child: RefreshIndicator(
        color: _RevUi.lavender,
        onRefresh: _reload,
        child: FutureBuilder<(List<TherapistReviewRow> items, String? error)>(
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

            final loadError = snap.data?.$2;
            if (loadError != null) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(32),
                children: [
                  Text(
                    loadError,
                    style: GoogleFonts.inter(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  TextButton(onPressed: _reload, child: const Text('Retry')),
                ],
              );
            }

            final all = snap.data?.$1 ?? [];
            final stats = _computeStats(all);
            final filtered = _sortReviews(
              _filterReviews(
                all,
                ratingFilter: _ratingFilter,
                query: _searchCtrl.text,
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
                    _CompactHero(stats: stats),
                    const SizedBox(height: _RevUi.gap),
                    _SummaryStrip(stats: stats),
                    const SizedBox(height: _RevUi.gap),
                    _ReviewsSection(
                      allReviews: all,
                      filtered: filtered,
                      ratingFilter: _ratingFilter,
                      sortMode: _sortMode,
                      searchCtrl: _searchCtrl,
                      onSearchChanged: () => setState(() {}),
                      onRatingFilter: (f) => setState(() => _ratingFilter = f),
                      onSort: (s) => setState(() => _sortMode = s),
                    ),
                  ],
                ),
              ),
            );
          },
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

class _CompactHero extends StatelessWidget {
  const _CompactHero({required this.stats});

  final _ReviewStats stats;

  @override
  Widget build(BuildContext context) {
    final avg = stats.total > 0
        ? stats.averageRating.toStringAsFixed(1)
        : '—';
    final latest = stats.latestReview;

    return _RevGlass(
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 900;
          final headline = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Client Feedback',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _RevUi.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Ratings and comments from clients after completed appointments.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.4,
                  color: _RevUi.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _HeroMetric(
                    icon: Icons.star_rounded,
                    value: stats.total > 0 ? '$avg' : '—',
                    label: 'Average Rating',
                    accent: _RevUi.gold,
                  ),
                  const SizedBox(width: 20),
                  _HeroMetric(
                    icon: Icons.rate_review_outlined,
                    value: stats.total.toString(),
                    label: 'Total Reviews',
                    accent: _RevUi.lavender,
                  ),
                ],
              ),
            ],
          );

          if (!wide || latest == null) {
            return headline;
          }

          final previewText = latest.komentar.trim().isEmpty
              ? 'No written comment.'
              : latest.komentar.trim();
          final clipped = previewText.length > 120
              ? '${previewText.substring(0, 117)}…'
              : previewText;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: headline),
              const SizedBox(width: 24),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.white.withValues(alpha: 0.04),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Latest Review',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: _RevUi.lavender.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              latest.korisnikIme.isEmpty
                                  ? 'Client'
                                  : latest.korisnikIme,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _RevUi.textPrimary,
                              ),
                            ),
                          ),
                          _StarRating(stars: latest.ocjena, size: 14),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        clipped,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          height: 1.45,
                          color: _RevUi.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: accent),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _RevUi.textPrimary,
                height: 1,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _RevUi.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.stats});

  final _ReviewStats stats;

  @override
  Widget build(BuildContext context) {
    final avg = stats.total > 0
        ? stats.averageRating.toStringAsFixed(1)
        : '—';
    final topService = stats.mostReviewedService ?? '—';

    return _RevGlass(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: LayoutBuilder(
        builder: (context, c) {
          final stack = c.maxWidth < 720;
          final items = [
            _SummaryCell(
              label: 'Average Rating',
              value: stats.total > 0 ? '$avg / 5' : '—',
            ),
            _SummaryCell(
              label: 'Total Reviews',
              value: stats.total.toString(),
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
    required this.allReviews,
    required this.filtered,
    required this.ratingFilter,
    required this.sortMode,
    required this.searchCtrl,
    required this.onSearchChanged,
    required this.onRatingFilter,
    required this.onSort,
  });

  final List<TherapistReviewRow> allReviews;
  final List<TherapistReviewRow> filtered;
  final String ratingFilter;
  final String sortMode;
  final TextEditingController searchCtrl;
  final VoidCallback onSearchChanged;
  final ValueChanged<String> onRatingFilter;
  final ValueChanged<String> onSort;

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
              '(${allReviews.length})',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _RevUi.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _FilterToolbar(
          searchCtrl: searchCtrl,
          ratingFilter: ratingFilter,
          sortMode: sortMode,
          onSearchChanged: onSearchChanged,
          onRatingFilter: onRatingFilter,
          onSort: onSort,
        ),
        const SizedBox(height: 16),
        if (!allReviews.isNotEmpty)
          _ReviewsEmptyState(
            onViewAppointments: () => context
                .read<DesktopNav>()
                .goTo(DesktopRouteKey.therapistAppointments),
          )
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
    required this.onSearchChanged,
    required this.onRatingFilter,
    required this.onSort,
  });

  final TextEditingController searchCtrl;
  final String ratingFilter;
  final String sortMode;
  final VoidCallback onSearchChanged;
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
                    onChanged: (_) => onSearchChanged(),
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
              children: [
                search,
                const SizedBox(width: 12),
                sort,
              ],
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

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
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
                : Colors.white.withValues(alpha: _hover ? 0.07 : 0.04),
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
    final initial = clientName.isNotEmpty
        ? String.fromCharCode(clientName.runes.first).toUpperCase()
        : '?';

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: _hover
              ? Colors.white.withValues(alpha: 0.055)
              : Colors.white.withValues(alpha: 0.035),
          border: Border.all(
            color: _hover
                ? _RevUi.purple.withValues(alpha: 0.32)
                : Colors.white.withValues(alpha: 0.08),
          ),
          boxShadow: _hover
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
            _ClientAvatar(initials: initial),
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
                          _StarRating(stars: r.ocjena),
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
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.5,
                      color: _RevUi.textSecondary.withValues(alpha: 0.95),
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
            style: TextButton.styleFrom(
              foregroundColor: _RevUi.lavender,
            ),
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
