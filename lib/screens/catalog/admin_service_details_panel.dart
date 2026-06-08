import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/recenzija.dart';
import '../../models/usluga.dart';
import '../../models/zaposlenik.dart';
import '../../models/zaposlenik_status.dart';
import '../../ui/widgets/service_network_image.dart';

/// Admin-only service detail layout (catalog management).
abstract final class _AdminStyle {
  static const Color bgDeep = Color(0xFF07040F);
  static const Color bgMid = Color(0xFF120A24);
  static const Color textPrimary = Color(0xFFF5F3FA);
  static const Color textSecondary = Color(0xA6FFFFFF);
  static const Color accentPurple = Color(0xFF7B4DFF);
  static const Color gold = Color(0xFFF5B942);
  static const double radius = 18;

  static TextStyle title(BuildContext context) => GoogleFonts.inter(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: textPrimary,
      );

  static TextStyle sectionTitle(BuildContext context) => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      );

  static TextStyle body(BuildContext context) => GoogleFonts.inter(
        fontSize: 14,
        height: 1.55,
        color: textSecondary,
      );

  static TextStyle label(BuildContext context) => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: textSecondary,
      );

  static BoxDecoration glassCard() => BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      );
}

class AdminServiceDetailsPanel extends StatefulWidget {
  const AdminServiceDetailsPanel({
    super.key,
    required this.service,
    required this.benefits,
    required this.therapists,
    required this.therapistsLoading,
    required this.therapistsError,
    required this.recenzijeFuture,
    required this.onRefreshReviews,
    required this.onEdit,
    required this.onDelete,
    required this.onBack,
    required this.onAssignTherapist,
  });

  final Usluga service;
  final List<String> benefits;
  final List<Zaposlenik> therapists;
  final bool therapistsLoading;
  final String? therapistsError;
  final Future<RecenzijeLoadResult> recenzijeFuture;
  final VoidCallback onRefreshReviews;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onBack;
  final VoidCallback onAssignTherapist;

  @override
  State<AdminServiceDetailsPanel> createState() =>
      _AdminServiceDetailsPanelState();
}

class _AdminServiceDetailsPanelState extends State<AdminServiceDetailsPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _handleMoreAction(String? action) {
    if (!mounted || action == null) return;
    final messenger = ScaffoldMessenger.of(context);
    switch (action) {
      case 'duplicate':
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'To duplicate, use Edit Service and save a new entry from the catalog.',
            ),
          ),
        );
      case 'deactivate':
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Deactivate is managed by removing the service from the catalog.',
            ),
          ),
        );
      case 'delete':
        widget.onDelete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_AdminStyle.bgDeep, _AdminStyle.bgMid],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AdminHeader(
            service: service,
            onBack: widget.onBack,
            onEdit: widget.onEdit,
            onMoreAction: _handleMoreAction,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 12),
            child: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              dividerColor: Colors.white.withValues(alpha: 0.08),
              indicatorColor: _AdminStyle.accentPurple,
              labelColor: _AdminStyle.textPrimary,
              unselectedLabelColor: _AdminStyle.textSecondary,
              labelStyle: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Therapists'),
                Tab(text: 'Reviews'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _OverviewTab(
                  service: service,
                  benefits: widget.benefits,
                ),
                _TherapistsTab(
                  therapists: widget.therapists,
                  loading: widget.therapistsLoading,
                  error: widget.therapistsError,
                  onAssign: widget.onAssignTherapist,
                ),
                _ReviewsTab(
                  recenzijeFuture: widget.recenzijeFuture,
                  onRefresh: widget.onRefreshReviews,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminHeader extends StatelessWidget {
  const _AdminHeader({
    required this.service,
    required this.onBack,
    required this.onEdit,
    required this.onMoreAction,
  });

  final Usluga service;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final ValueChanged<String?> onMoreAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 24, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            color: _AdminStyle.textSecondary,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service.naziv, style: _AdminStyle.title(context)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _MetaChip(label: service.kategorija),
                    _MetaChip(
                      label: service.cijenaKm,
                      emphasized: true,
                    ),
                    _MetaChip(
                      label: service.trajanje,
                      icon: Icons.schedule_outlined,
                    ),
                    const _MetaChip(
                      label: 'Active',
                      icon: Icons.check_circle_outline,
                      tone: _ChipTone.success,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit Service'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _AdminStyle.textPrimary,
              side: BorderSide(
                color: _AdminStyle.accentPurple.withValues(alpha: 0.45),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            tooltip: 'More actions',
            color: _AdminStyle.bgMid,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            onSelected: onMoreAction,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
              PopupMenuItem(value: 'deactivate', child: Text('Deactivate')),
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  'Delete',
                  style: TextStyle(color: Color(0xFFFF8A80)),
                ),
              ),
            ],
            icon: const Icon(Icons.more_horiz_rounded),
            style: IconButton.styleFrom(
              foregroundColor: _AdminStyle.textSecondary,
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ChipTone { neutral, success }

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    this.icon,
    this.emphasized = false,
    this.tone = _ChipTone.neutral,
  });

  final String label;
  final IconData? icon;
  final bool emphasized;
  final _ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final accent = tone == _ChipTone.success
        ? const Color(0xFF5CE0A0)
        : _AdminStyle.accentPurple;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: emphasized ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: _AdminStyle.textPrimary),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: emphasized ? FontWeight.w600 : FontWeight.w500,
              color: emphasized ? _AdminStyle.textPrimary : _AdminStyle.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.service,
    required this.benefits,
  });

  final Usluga service;
  final List<String> benefits;

  @override
  Widget build(BuildContext context) {
    final description = service.opis.trim();

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 920;
        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionCard(
              title: 'Description',
              child: Text(
                description.isEmpty
                    ? 'No description provided yet.'
                    : description,
                style: _AdminStyle.body(context).copyWith(
                  color: description.isEmpty
                      ? _AdminStyle.textSecondary
                      : _AdminStyle.textPrimary.withValues(alpha: 0.92),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _SectionCard(
              title: 'Benefits',
              child: benefits.isEmpty
                  ? Text(
                      'Add comma-separated benefits in the service description or edit the service to clarify outcomes.',
                      style: _AdminStyle.body(context),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: benefits
                          .map(
                            (b) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '•  ',
                                    style: _AdminStyle.body(context).copyWith(
                                      color: _AdminStyle.accentPurple,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      _formatBenefitLine(b),
                                      style: _AdminStyle.body(context).copyWith(
                                        color: _AdminStyle.textPrimary
                                            .withValues(alpha: 0.9),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),
            const SizedBox(height: 14),
            _SectionCard(
              title: 'Pricing & duration',
              child: Wrap(
                spacing: 24,
                runSpacing: 12,
                children: [
                  _InfoTile(
                    label: 'Price',
                    value: service.cijenaKm,
                    emphasized: true,
                  ),
                  _InfoTile(label: 'Duration', value: service.trajanje),
                  _InfoTile(label: 'Category', value: service.kategorija),
                ],
              ),
            ),
          ],
        );

        return Scrollbar(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
            child: stacked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _CompactServiceImage(service: service),
                      const SizedBox(height: 18),
                      details,
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: (constraints.maxWidth * 0.36).clamp(240.0, 320.0),
                        child: _CompactServiceImage(service: service),
                      ),
                      const SizedBox(width: 24),
                      Expanded(child: details),
                    ],
                  ),
          ),
        );
      },
    );
  }

  static String _formatBenefitLine(String raw) {
    var line = raw.trim();
    if (line.isEmpty) return line;
    line = line[0].toUpperCase() + line.substring(1);
    final lower = line.toLowerCase();
    if (!lower.startsWith('help') &&
        !lower.startsWith('calm') &&
        !lower.startsWith('improve') &&
        !lower.startsWith('reduce')) {
      if (line.split(' ').length <= 3) {
        return 'Helps $line'.replaceAll('Helps Helps', 'Helps');
      }
    }
    return line.endsWith('.') ? line : '$line.';
  }
}

class _CompactServiceImage extends StatelessWidget {
  const _CompactServiceImage({required this.service});

  final Usluga service;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_AdminStyle.radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: DecoratedBox(
          decoration: _AdminStyle.glassCard(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(_AdminStyle.radius),
                ),
                child: ServiceNetworkImage(
                  imageUrl: service.slikaUrl,
                  height: 168,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  error: Container(
                    height: 168,
                    color: _AdminStyle.accentPurple.withValues(alpha: 0.12),
                    child: Icon(
                      Icons.spa_outlined,
                      size: 48,
                      color: _AdminStyle.accentPurple.withValues(alpha: 0.35),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'Service image',
                  style: _AdminStyle.label(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TherapistsTab extends StatelessWidget {
  const _TherapistsTab({
    required this.therapists,
    required this.loading,
    required this.error,
    required this.onAssign,
  });

  final List<Zaposlenik> therapists;
  final bool loading;
  final String? error;
  final VoidCallback onAssign;

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
        child: _SectionCard(
          title: 'Linked Therapists',
          trailing: therapists.isNotEmpty
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${therapists.length} linked',
                      style: _AdminStyle.label(context),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: onAssign,
                      icon: const Icon(Icons.person_add_alt_1_outlined, size: 16),
                      label: const Text('Assign'),
                      style: TextButton.styleFrom(
                        foregroundColor: _AdminStyle.accentPurple,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ],
                )
              : null,
          child: _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: _AdminStyle.accentPurple,
          ),
        ),
      );
    }
    if (error != null) {
      return Text(error!, style: _AdminStyle.body(context));
    }
    if (therapists.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No therapists linked.',
            style: _AdminStyle.sectionTitle(context).copyWith(fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            'Assign a therapist so clients can book this service.',
            style: _AdminStyle.body(context),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onAssign,
            icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
            label: const Text('Assign therapist'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _AdminStyle.textPrimary,
              side: BorderSide(
                color: _AdminStyle.accentPurple.withValues(alpha: 0.4),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        for (var i = 0; i < therapists.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _TherapistRow(therapist: therapists[i]),
        ],
      ],
    );
  }
}

class _TherapistRow extends StatelessWidget {
  const _TherapistRow({required this.therapist});

  final Zaposlenik therapist;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(therapist);
    final status = therapist.status;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: _AdminStyle.accentPurple.withValues(alpha: 0.2),
            child: Text(
              initials,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: _AdminStyle.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  therapist.fullName,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: _AdminStyle.textPrimary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  therapist.specijalizacija.trim().isEmpty
                      ? 'Specialization not set'
                      : therapist.specijalizacija,
                  style: _AdminStyle.body(context),
                ),
              ],
            ),
          ),
          _StatusBadge(status: status),
          if (status.isBookable) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _AdminStyle.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: _AdminStyle.gold.withValues(alpha: 0.28),
                ),
              ),
              child: Text(
                'Bookable',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _AdminStyle.gold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _initials(Zaposlenik z) {
    final i = z.ime.trim().isNotEmpty ? z.ime.trim()[0] : '';
    final p = z.prezime.trim().isNotEmpty ? z.prezime.trim()[0] : '';
    final s = '$i$p'.toUpperCase();
    return s.isEmpty ? '?' : s;
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final ZaposlenikStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ZaposlenikStatus.active => const Color(0xFF5CE0A0),
      ZaposlenikStatus.onLeave => const Color(0xFFF5B942),
      ZaposlenikStatus.inactive => const Color(0xFFFF8A80),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        status.label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _ReviewsTab extends StatelessWidget {
  const _ReviewsTab({
    required this.recenzijeFuture,
    required this.onRefresh,
  });

  final Future<RecenzijeLoadResult> recenzijeFuture;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RecenzijeLoadResult>(
      future: recenzijeFuture,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final result = snapshot.data;
        final reviews = result?.items ?? [];
        final loadError = result?.error;
        final average = _averageRating(reviews);

        return Scrollbar(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionCard(
                  title: 'Customer Reviews',
                  trailing: IconButton(
                    tooltip: 'Refresh reviews',
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    color: _AdminStyle.textSecondary,
                  ),
                  child: loading
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 28),
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _AdminStyle.accentPurple,
                            ),
                          ),
                        )
                      : loadError != null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(loadError, style: _AdminStyle.body(context)),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: onRefresh,
                                  child: const Text('Retry'),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                _RatingSummary(
                                  average: average,
                                  count: reviews.length,
                                ),
                              ],
                            ),
                ),
                if (!loading && loadError == null) ...[
                  const SizedBox(height: 14),
                  if (reviews.isEmpty)
                    _SectionCard(
                      title: 'Review list',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No reviews yet.',
                            style: _AdminStyle.sectionTitle(context)
                                .copyWith(fontSize: 15),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Customer reviews will appear here after completed appointments.',
                            style: _AdminStyle.body(context),
                          ),
                        ],
                      ),
                    )
                  else
                    ...reviews.map(
                      (r) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _AdminReviewCard(review: r),
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  static double _averageRating(List<Recenzija> reviews) {
    if (reviews.isEmpty) return 0;
    final sum = reviews.fold<int>(0, (a, r) => a + r.ocjena);
    return sum / reviews.length;
  }
}

class _RatingSummary extends StatelessWidget {
  const _RatingSummary({
    required this.average,
    required this.count,
  });

  final double average;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          average > 0 ? average.toStringAsFixed(1) : '—',
          style: GoogleFonts.inter(
            fontSize: 36,
            fontWeight: FontWeight.w700,
            color: _AdminStyle.gold,
            height: 1,
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StarRow(value: average.round().clamp(0, 5)),
            const SizedBox(height: 6),
            Text(
              count == 0
                  ? 'No reviews yet'
                  : '$count review${count == 1 ? '' : 's'}',
              style: _AdminStyle.body(context),
            ),
          ],
        ),
      ],
    );
  }
}

class _AdminReviewCard extends StatelessWidget {
  const _AdminReviewCard({required this.review});

  final Recenzija review;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _AdminStyle.glassCard(),
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
                    color: _AdminStyle.textPrimary,
                    fontSize: 14,
                  ),
                ),
              ),
              _StarRow(value: review.ocjena, size: 15),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (review.createdAt != null)
                Text(
                  _formatDate(review.createdAt!),
                  style: _AdminStyle.label(context),
                ),
              if (review.zaposlenikIme != null &&
                  review.zaposlenikIme!.trim().isNotEmpty)
                Text(
                  'Therapist: ${review.zaposlenikIme!.trim()}',
                  style: _AdminStyle.label(context),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF5CE0A0).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: const Color(0xFF5CE0A0).withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  'Verified visit',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF5CE0A0),
                  ),
                ),
              ),
            ],
          ),
          if (review.komentar.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.komentar.trim(),
              style: _AdminStyle.body(context).copyWith(
                color: _AdminStyle.textPrimary.withValues(alpha: 0.9),
              ),
            ),
          ],
          if (review.adminOdgovor != null &&
              review.adminOdgovor!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _AdminStyle.accentPurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _AdminStyle.accentPurple.withValues(alpha: 0.22),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Salon response',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _AdminStyle.accentPurple,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    review.adminOdgovor!.trim(),
                    style: _AdminStyle.body(context),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.'
        '${local.month.toString().padLeft(2, '0')}.'
        '${local.year}';
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
          color: _AdminStyle.gold,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_AdminStyle.radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: DecoratedBox(
          decoration: _AdminStyle.glassCard(),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title, style: _AdminStyle.sectionTitle(context)),
                    ),
                    if (trailing != null) trailing!,
                  ],
                ),
                const SizedBox(height: 12),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _AdminStyle.label(context)),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: emphasized ? 18 : 15,
            fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
            color: emphasized
                ? _AdminStyle.accentPurple
                : _AdminStyle.textPrimary,
          ),
        ),
      ],
    );
  }
}
