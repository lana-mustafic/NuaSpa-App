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
  static const green = Color(0xFF22C55E);
  static const orange = Color(0xFFF97316);
  static const cardRadius = 24.0;
  static const heroRadius = 30.0;
  static const gap = 24.0;
  static const sidebarWidth = 340.0;
  static const contentPadding = 32.0;
}

class _ReviewStats {
  const _ReviewStats({
    required this.averageRating,
    required this.total,
    required this.satisfactionPct,
    required this.positiveCount,
    required this.fiveStarPct,
    required this.topServices,
  });

  final double averageRating;
  final int total;
  final int satisfactionPct;
  final int positiveCount;
  final int fiveStarPct;
  final List<_ServiceRating> topServices;
}

class _ServiceRating {
  const _ServiceRating({
    required this.name,
    required this.avg,
    required this.count,
  });

  final String name;
  final double avg;
  final int count;
}

_ReviewStats _computeStats(List<TherapistReviewRow> reviews) {
  if (reviews.isEmpty) {
    return const _ReviewStats(
      averageRating: 0,
      total: 0,
      satisfactionPct: 0,
      positiveCount: 0,
      fiveStarPct: 0,
      topServices: [],
    );
  }
  final total = reviews.length;
  final sum = reviews.fold<int>(0, (s, r) => s + r.ocjena);
  final avg = sum / total;
  final positive = reviews.where((r) => r.ocjena >= 4).length;
  final five = reviews.where((r) => r.ocjena >= 5).length;
  final satPct = ((positive / total) * 100).round();

  final byService = <String, List<int>>{};
  for (final r in reviews) {
    final key = r.uslugaNaziv.trim().isEmpty ? 'Service' : r.uslugaNaziv.trim();
    byService.putIfAbsent(key, () => []).add(r.ocjena);
  }
  final top = byService.entries
      .map(
        (e) => _ServiceRating(
          name: e.key,
          avg: e.value.reduce((a, b) => a + b) / e.value.length,
          count: e.value.length,
        ),
      )
      .toList()
    ..sort((a, b) => b.avg.compareTo(a.avg));

  return _ReviewStats(
    averageRating: avg,
    total: total,
    satisfactionPct: satPct,
    positiveCount: positive,
    fiveStarPct: ((five / total) * 100).round(),
    topServices: top.take(5).toList(),
  );
}

String _formatReviewDate(DateTime d) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final loc = d.toLocal();
  return 'Completed on ${months[loc.month - 1]} ${loc.day}, ${loc.year}';
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

String _sentimentLabel(int stars) {
  if (stars >= 4) return 'Positive';
  if (stars == 3) return 'Neutral';
  return 'Critical';
}

Color _sentimentColor(String label) {
  switch (label) {
    case 'Positive':
      return _RevUi.green;
    case 'Neutral':
      return _RevUi.lavender;
    default:
      return _RevUi.orange;
  }
}

List<TherapistReviewRow> _filterReviews(
  List<TherapistReviewRow> all, {
  required String pill,
  required String query,
}) {
  var list = [...all];
  switch (pill) {
    case '5 Stars':
      list = list.where((r) => r.ocjena >= 5).toList();
    case '4 Stars':
      list = list.where((r) => r.ocjena == 4).toList();
    case 'Positive':
      list = list.where((r) => r.ocjena >= 4).toList();
    case 'Critical':
      list = list.where((r) => r.ocjena <= 2).toList();
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
  Future<List<TherapistReviewRow>>? _future;
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String _filterPill = 'All Reviews';
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
        child: FutureBuilder<List<TherapistReviewRow>>(
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

            final all = snap.data ?? [];
            final stats = _computeStats(all);
            final filtered = _sortReviews(
              _filterReviews(
                all,
                pill: _filterPill,
                query: _searchCtrl.text,
              ),
              _sortMode,
            );

            return FadeTransition(
              opacity: _fadeAnim,
              child: LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth >= 1100;
                  final main = _MainColumn(
                    allReviews: all,
                    filtered: filtered,
                    stats: stats,
                    filterPill: _filterPill,
                    sortMode: _sortMode,
                    searchCtrl: _searchCtrl,
                    onSearchChanged: () => setState(() {}),
                    onPill: (p) {
                      setState(() => _filterPill = p);
                      _fadeCtrl.forward(from: 0);
                    },
                    onSort: (s) => setState(() => _sortMode = s),
                    onRefresh: _reload,
                  );
                  final sidebar = _ReviewsSidebar(
                    stats: stats,
                    onViewAppointments: () => context
                        .read<DesktopNav>()
                        .goTo(DesktopRouteKey.therapistAppointments),
                  );

                  return SingleChildScrollView(
                    controller: _scrollCtrl,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      _RevUi.contentPadding,
                      8,
                      _RevUi.contentPadding,
                      40,
                    ),
                    child: wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: main),
                              const SizedBox(width: _RevUi.gap),
                              SizedBox(
                                width: _RevUi.sidebarWidth,
                                child: sidebar,
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              main,
                              const SizedBox(height: _RevUi.gap),
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
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _RevUi.purple.withValues(alpha: 0.22),
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
    required this.allReviews,
    required this.filtered,
    required this.stats,
    required this.filterPill,
    required this.sortMode,
    required this.searchCtrl,
    required this.onSearchChanged,
    required this.onPill,
    required this.onSort,
    required this.onRefresh,
  });

  final List<TherapistReviewRow> allReviews;
  final List<TherapistReviewRow> filtered;
  final _ReviewStats stats;
  final String filterPill;
  final String sortMode;
  final TextEditingController searchCtrl;
  final VoidCallback onSearchChanged;
  final ValueChanged<String> onPill;
  final ValueChanged<String> onSort;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeroSummaryCard(stats: stats),
        const SizedBox(height: _RevUi.gap),
        _FilterActionBar(
          searchCtrl: searchCtrl,
          filterPill: filterPill,
          sortMode: sortMode,
          onSearchChanged: onSearchChanged,
          onPill: onPill,
          onSort: onSort,
          onRefresh: onRefresh,
        ),
        const SizedBox(height: _RevUi.gap),
        _RecentReviewsCard(
          reviews: filtered,
          hasAny: allReviews.isNotEmpty,
        ),
      ],
    );
  }
}

class _HeroSummaryCard extends StatelessWidget {
  const _HeroSummaryCard({required this.stats});

  final _ReviewStats stats;

  @override
  Widget build(BuildContext context) {
    final avg = stats.total > 0
        ? stats.averageRating.toStringAsFixed(1)
        : '—';

    return _RevGlass(
      radius: _RevUi.heroRadius,
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 240),
        child: LayoutBuilder(
          builder: (context, c) {
            final stack = c.maxWidth < 900;
            final left = const _StarHeroIllustration();
            final center = Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Your Client Feedback',
                    style: GoogleFonts.inter(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: _RevUi.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Track ratings, reviews and client satisfaction from completed appointments.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.45,
                      color: _RevUi.textSecondary,
                    ),
                  ),
                ],
              ),
            );
            final statsRow = Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _HeroStatTile(
                  icon: Icons.star_rounded,
                  label: 'Average Rating',
                  value: stats.total > 0 ? '$avg / 5' : '—',
                  accent: _RevUi.gold,
                ),
                _HeroStatTile(
                  icon: Icons.reviews_outlined,
                  label: 'Total Reviews',
                  value: '${stats.total}',
                  accent: _RevUi.purple,
                ),
                _HeroStatTile(
                  icon: Icons.sentiment_satisfied_alt_rounded,
                  label: 'Satisfaction Rate',
                  value: stats.total > 0 ? '${stats.satisfactionPct}%' : '—',
                  accent: _RevUi.green,
                ),
                _HeroStatTile(
                  icon: Icons.thumb_up_alt_outlined,
                  label: 'Positive Reviews',
                  value: '${stats.positiveCount}',
                  accent: _RevUi.lavender,
                ),
              ],
            );

            if (stack) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [left, const SizedBox(width: 20), center],
                  ),
                  const SizedBox(height: 20),
                  statsRow,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                left,
                const SizedBox(width: 24),
                center,
                const SizedBox(width: 16),
                SizedBox(width: 280, child: statsRow),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StarHeroIllustration extends StatelessWidget {
  const _StarHeroIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                colors: [
                  _RevUi.purple.withValues(alpha: 0.45),
                  _RevUi.lavender.withValues(alpha: 0.15),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: _RevUi.gold.withValues(alpha: 0.35),
                  blurRadius: 32,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const Icon(Icons.star_rounded, size: 56, color: _RevUi.gold),
          Positioned(
            top: 8,
            right: 4,
            child: Icon(
              Icons.star_rounded,
              size: 22,
              color: _RevUi.gold.withValues(alpha: 0.7),
            ),
          ),
          Positioned(
            bottom: 10,
            left: 6,
            child: Icon(
              Icons.star_rounded,
              size: 18,
              color: _RevUi.lavender.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStatTile extends StatelessWidget {
  const _HeroStatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 128,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: accent),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _RevUi.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: _RevUi.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterActionBar extends StatelessWidget {
  const _FilterActionBar({
    required this.searchCtrl,
    required this.filterPill,
    required this.sortMode,
    required this.onSearchChanged,
    required this.onPill,
    required this.onSort,
    required this.onRefresh,
  });

  final TextEditingController searchCtrl;
  final String filterPill;
  final String sortMode;
  final VoidCallback onSearchChanged;
  final ValueChanged<String> onPill;
  final ValueChanged<String> onSort;
  final VoidCallback onRefresh;

  static const _pills = [
    'All Reviews',
    '5 Stars',
    '4 Stars',
    'Positive',
    'Critical',
  ];

  @override
  Widget build(BuildContext context) {
    return _RevGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RevGlass(
            radius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: TextField(
              controller: searchCtrl,
              onChanged: (_) => onSearchChanged(),
              style: GoogleFonts.inter(color: _RevUi.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search client or service…',
                hintStyle: GoogleFonts.inter(
                  color: _RevUi.textSecondary,
                  fontSize: 14,
                ),
                border: InputBorder.none,
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: _RevUi.lavender.withValues(alpha: 0.85),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, c) {
              final stack = c.maxWidth < 800;
              final pills = SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final p in _pills) ...[
                      _FilterPill(
                        label: p,
                        selected: filterPill == p,
                        onTap: () => onPill(p),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              );
              final actions = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SortDropdown(value: sortMode, onChanged: onSort),
                  const SizedBox(width: 8),
                  _GlassIconButton(
                    icon: Icons.refresh_rounded,
                    onTap: onRefresh,
                  ),
                ],
              );
              if (stack) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [pills, const SizedBox(height: 12), actions],
                );
              }
              return Row(
                children: [
                  Expanded(child: pills),
                  const SizedBox(width: 12),
                  actions,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatefulWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_FilterPill> createState() => _FilterPillState();
}

class _FilterPillState extends State<_FilterPill> {
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
                    colors: [_RevUi.purple, _RevUi.lavender],
                  )
                : null,
            color: widget.selected
                ? null
                : Colors.white.withValues(alpha: _hover ? 0.08 : 0.04),
            border: Border.all(
              color: widget.selected
                  ? _RevUi.lavender.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.12),
            ),
            boxShadow: widget.selected || _hover
                ? [
                    BoxShadow(
                      color: _RevUi.purple.withValues(
                        alpha: widget.selected ? 0.4 : 0.15,
                      ),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: Text(
            widget.label,
            style: GoogleFonts.inter(
              fontSize: 13,
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

class _RecentReviewsCard extends StatelessWidget {
  const _RecentReviewsCard({
    required this.reviews,
    required this.hasAny,
  });

  final List<TherapistReviewRow> reviews;
  final bool hasAny;

  @override
  Widget build(BuildContext context) {
    return _RevGlass(
      radius: _RevUi.heroRadius,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Recent Reviews',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _RevUi.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Latest client feedback from completed appointments.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: _RevUi.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          if (!hasAny)
            _ReviewsEmptyState(
              onViewAppointments: () => context
                  .read<DesktopNav>()
                  .goTo(DesktopRouteKey.therapistAppointments),
            )
          else if (reviews.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
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
                for (var i = 0; i < reviews.length; i++) ...[
                  _ReviewCard(review: reviews[i]),
                  if (i < reviews.length - 1) const SizedBox(height: 14),
                ],
              ],
            ),
        ],
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
    final sentiment = _sentimentLabel(r.ocjena);
    final sColor = _sentimentColor(sentiment);
    final initials = r.korisnikIme.trim().isNotEmpty
        ? r.korisnikIme.trim()[0].toUpperCase()
        : '?';
    final comment = r.komentar.trim().isEmpty
        ? 'No written comment provided.'
        : r.komentar.trim();

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_RevUi.cardRadius),
          color: Colors.white.withValues(alpha: _hover ? 0.06 : 0.04),
          border: Border.all(
            color: _RevUi.purple.withValues(alpha: _hover ? 0.35 : 0.15),
          ),
          boxShadow: _hover
              ? [
                  BoxShadow(
                    color: _RevUi.purple.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: LayoutBuilder(
          builder: (context, c) {
            final narrow = c.maxWidth < 720;
            final avatar = _ClientAvatar(initials: initials);
            final bodyContent = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        r.korisnikIme.isEmpty ? 'Client' : r.korisnikIme,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _RevUi.textPrimary,
                        ),
                      ),
                      _ServiceBadge(label: r.uslugaNaziv),
                      _StarRating(stars: r.ocjena),
                      Text(
                        _formatShortDate(r.createdAt),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _RevUi.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    comment,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.5,
                      color: _RevUi.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _formatReviewDate(r.createdAt),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _RevUi.lavender.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              );
            final trailing = Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _SentimentBadge(label: sentiment, color: sColor),
                const SizedBox(height: 8),
                PopupMenuButton<String>(
                  tooltip: 'More',
                  color: _RevUi.bgBottom,
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'view',
                      child: Text('View details'),
                    ),
                  ],
                  onSelected: (_) {},
                ),
              ],
            );

            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      avatar,
                      const SizedBox(width: 14),
                      Expanded(child: bodyContent),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerRight, child: trailing),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                avatar,
                const SizedBox(width: 18),
                Expanded(child: bodyContent),
                const SizedBox(width: 12),
                trailing,
              ],
            );
          },
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
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            _RevUi.purple.withValues(alpha: 0.5),
            _RevUi.lavender.withValues(alpha: 0.25),
          ],
        ),
        border: Border.all(color: _RevUi.lavender.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: _RevUi.purple.withValues(alpha: 0.35),
            blurRadius: 14,
          ),
        ],
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _StarRating extends StatelessWidget {
  const _StarRating({required this.stars});

  final int stars;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++)
          Icon(
            i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 16,
            color: _RevUi.gold,
          ),
      ],
    );
  }
}

class _ServiceBadge extends StatelessWidget {
  const _ServiceBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final text = label.trim().isEmpty ? 'Service' : label.trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: _RevUi.purple.withValues(alpha: 0.15),
        border: Border.all(color: _RevUi.purple.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _RevUi.lavender,
        ),
      ),
    );
  }
}

class _SentimentBadge extends StatelessWidget {
  const _SentimentBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.15),
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

class _ReviewsEmptyState extends StatelessWidget {
  const _ReviewsEmptyState({required this.onViewAppointments});

  final VoidCallback onViewAppointments;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 420),
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_RevUi.heroRadius),
        color: Colors.white.withValues(alpha: 0.03),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _RevUi.gold.withValues(alpha: 0.25),
                  _RevUi.purple.withValues(alpha: 0.08),
                ],
              ),
            ),
            child: const Icon(
              Icons.rate_review_outlined,
              size: 64,
              color: _RevUi.lavender,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No reviews yet',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _RevUi.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Client reviews will appear here after completed appointments.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.45,
              color: _RevUi.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          _OutlinedButton(
            label: 'View Completed Appointments',
            icon: Icons.event_available_rounded,
            onTap: onViewAppointments,
          ),
        ],
      ),
    );
  }
}

class _ReviewsSidebar extends StatelessWidget {
  const _ReviewsSidebar({
    required this.stats,
    required this.onViewAppointments,
  });

  final _ReviewStats stats;
  final VoidCallback onViewAppointments;

  @override
  Widget build(BuildContext context) {
    final nav = context.read<DesktopNav>();
    final avg = stats.total > 0
        ? stats.averageRating.toStringAsFixed(1)
        : '—';

    return Column(
      children: [
        _RevGlass(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Rating Overview',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _RevUi.textPrimary,
                ),
              ),
              const SizedBox(height: 18),
              _OverviewLine(
                label: 'Average Rating',
                value: stats.total > 0 ? '$avg / 5' : '—',
                progress: stats.total > 0 ? stats.averageRating / 5 : 0,
                accent: _RevUi.gold,
              ),
              const SizedBox(height: 14),
              _OverviewLine(
                label: '5★ Reviews',
                value: stats.total > 0 ? '${stats.fiveStarPct}%' : '—',
                progress: stats.fiveStarPct / 100,
                accent: _RevUi.gold,
              ),
              const SizedBox(height: 14),
              _OverviewLine(
                label: 'Client Satisfaction',
                value: stats.total > 0 ? '${stats.satisfactionPct}%' : '—',
                progress: stats.satisfactionPct / 100,
                accent: _RevUi.green,
              ),
              const SizedBox(height: 14),
              _OverviewLine(
                label: 'Total Reviews',
                value: '${stats.total}',
                progress: stats.total > 0 ? 1.0 : 0,
                accent: _RevUi.purple,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _RevGlass(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Top Rated Services',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _RevUi.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              if (stats.topServices.isEmpty)
                Text(
                  'No service ratings yet.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: _RevUi.textSecondary,
                  ),
                )
              else
                for (var i = 0; i < stats.topServices.length; i++) ...[
                  _TopServiceRow(service: stats.topServices[i]),
                  if (i < stats.topServices.length - 1)
                    const SizedBox(height: 12),
                ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        _RevGlass(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Quick Actions',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _RevUi.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              _QuickRow(
                icon: Icons.event_note_rounded,
                label: 'View Appointments',
                onTap: onViewAppointments,
              ),
              const SizedBox(height: 10),
              _QuickRow(
                icon: Icons.calendar_month_rounded,
                label: 'My Schedule',
                onTap: () => nav.goTo(DesktopRouteKey.schedule),
              ),
              const SizedBox(height: 10),
              _QuickRow(
                icon: Icons.spa_outlined,
                label: 'My Services',
                onTap: () => nav.goTo(DesktopRouteKey.therapistServices),
              ),
              const SizedBox(height: 10),
              _QuickRow(
                icon: Icons.person_outline_rounded,
                label: 'Update Profile',
                onTap: () => nav.goTo(DesktopRouteKey.therapistProfile),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OverviewLine extends StatelessWidget {
  const _OverviewLine({
    required this.label,
    required this.value,
    required this.progress,
    required this.accent,
  });

  final String label;
  final String value;
  final double progress;
  final Color accent;

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
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: _RevUi.textSecondary,
                ),
              ),
            ),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _RevUi.textPrimary,
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
                  widthFactor: progress.clamp(0.0, 1.0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accent, accent.withValues(alpha: 0.6)],
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

class _TopServiceRow extends StatelessWidget {
  const _TopServiceRow({required this.service});

  final _ServiceRating service;

  @override
  Widget build(BuildContext context) {
    final pct = (service.avg / 5).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                service.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _RevUi.textPrimary,
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, size: 14, color: _RevUi.gold),
                const SizedBox(width: 4),
                Text(
                  service.avg.toStringAsFixed(1),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _RevUi.gold,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 6,
            child: Stack(
              children: [
                Container(color: Colors.white.withValues(alpha: 0.08)),
                FractionallySizedBox(
                  widthFactor: pct,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_RevUi.purple, _RevUi.lavender],
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
                color: _RevUi.purple.withValues(alpha: _hover ? 0.4 : 0.18),
              ),
            ),
            child: Row(
              children: [
                Icon(widget.icon, color: _RevUi.lavender, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.label,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: _RevUi.textPrimary,
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

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
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
    );
  }
}

class _OutlinedButton extends StatefulWidget {
  const _OutlinedButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
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
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _RevUi.purple.withValues(alpha: _hover ? 0.7 : 0.45),
                width: 1.5,
              ),
              color: _RevUi.purple.withValues(alpha: _hover ? 0.14 : 0.06),
              boxShadow: _hover
                  ? [
                      BoxShadow(
                        color: _RevUi.purple.withValues(alpha: 0.35),
                        blurRadius: 16,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, color: _RevUi.lavender, size: 20),
                const SizedBox(width: 10),
                Text(
                  widget.label,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: _RevUi.textPrimary,
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
