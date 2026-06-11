import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/api/services/api_service.dart';
import '../../core/platform/nua_spa_platform.dart';
import '../../models/admin/therapist_admin_profile.dart';
import '../../models/therapist/therapist_service_detail.dart';
import '../../models/zaposlenik_status.dart';
import '../../ui/navigation/desktop_nav.dart';
import '../../ui/widgets/service_network_image.dart';
import 'therapist_appointments_screen.dart';
import 'therapist_portal_scaffold.dart';
import 'therapist_schedule_screen.dart';

abstract final class _Ui {
  static const bgDeep = Color(0xFF07040F);
  static const bgMid = Color(0xFF120A24);
  static const textPrimary = Color(0xFFF5F3FA);
  static const textSecondary = Color(0xA6FFFFFF);
  static const purple = Color(0xFF7B4DFF);
  static const gold = Color(0xFFF5B942);
  static const green = Color(0xFF22C55E);
  static const cardRadius = 26.0;

  static BoxDecoration glassCard() => BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: purple.withValues(alpha: 0.18),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      );
}

String _employmentLabel(ZaposlenikStatus status) {
  return switch (status) {
    ZaposlenikStatus.active => 'Active',
    ZaposlenikStatus.onLeave => 'On Leave',
    ZaposlenikStatus.inactive => 'Inactive',
  };
}

String _scheduleAvailabilityLabel(TherapistServiceDetail detail) {
  if (detail.isSpaClosedToday) return 'Spa closed today';
  if (detail.isTherapistUnavailableToday) return 'Unavailable today';
  if (detail.availableSlotCountToday > 0) {
    return '${detail.availableSlotCountToday} open slot'
        '${detail.availableSlotCountToday == 1 ? '' : 's'} today';
  }
  final hours = detail.scheduleWorkingHoursLabel?.trim();
  if (hours != null && hours.isNotEmpty) return hours;
  return 'No open slots today';
}

String _formatReviewDate(DateTime date) {
  final local = date.toLocal();
  return '${local.day.toString().padLeft(2, '0')}.'
      '${local.month.toString().padLeft(2, '0')}.'
      '${local.year}';
}

double _imageHeight(BuildContext context) {
  final base = (MediaQuery.sizeOf(context).height - 300).clamp(320.0, 520.0);
  return (base * 0.72).clamp(230.0, 380.0);
}

class TherapistServiceDetailsScreen extends StatefulWidget {
  const TherapistServiceDetailsScreen({super.key, required this.serviceId});

  final int serviceId;

  @override
  State<TherapistServiceDetailsScreen> createState() =>
      _TherapistServiceDetailsScreenState();
}

class _TherapistServiceDetailsScreenState
    extends State<TherapistServiceDetailsScreen> {
  final _api = ApiService();
  final _scrollCtrl = ScrollController();

  TherapistServiceDetail? _detail;
  List<TherapistReviewRow> _reviews = [];
  int _reviewPage = 1;
  int _reviewTotal = 0;
  bool _loading = true;
  bool _loadingMoreReviews = false;
  String? _error;
  bool _forbidden = false;
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _clearServicesHeader();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _clearServicesHeader() {
    if (nuaspaUseMobileShell()) return;
    try {
      context.read<DesktopNav>().setTherapistServicesHeader();
    } catch (_) {}
  }

  void _applyServicesHeader(TherapistServiceDetail detail) {
    if (nuaspaUseMobileShell()) return;
    try {
      context.read<DesktopNav>().setTherapistServicesHeader(
        title: detail.service.naziv,
        subtitle:
            '${detail.service.kategorija} · ${detail.completedBookingsCount} completed booking'
            '${detail.completedBookingsCount == 1 ? '' : 's'}',
      );
    } catch (_) {}
  }

  Future<void> _loadAll({bool refresh = false}) async {
    if (!refresh) {
      setState(() {
        _loading = true;
        _error = null;
        _forbidden = false;
        _notFound = false;
      });
    }

    try {
      final detailResult =
          await _api.getTherapistServiceDetail(widget.serviceId);
      if (!mounted) return;

      if (detailResult.detail == null) {
        setState(() {
          _loading = false;
          _error = detailResult.error ?? 'Could not load service.';
          _forbidden = detailResult.forbidden;
          _notFound = detailResult.notFound;
        });
        return;
      }

      final reviewsResult = await _api.getTherapistMyReviewsPage(
        page: 1,
        pageSize: 20,
        uslugaId: widget.serviceId,
      );
      if (!mounted) return;

      final detail = detailResult.detail!;
      _applyServicesHeader(detail);

      setState(() {
        _detail = detail;
        _reviews = reviewsResult.items;
        _reviewPage = reviewsResult.page;
        _reviewTotal = reviewsResult.total;
        _loading = false;
        _error = reviewsResult.error;
      });
    } catch (e, st) {
      debugPrint('TherapistServiceDetailsScreen._loadAll failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load service details.';
      });
    }
  }

  Future<void> _loadMoreReviews() async {
    if (_loadingMoreReviews || !_hasMoreReviews) return;
    setState(() => _loadingMoreReviews = true);
    final nextPage = _reviewPage + 1;
    final result = await _api.getTherapistMyReviewsPage(
      page: nextPage,
      pageSize: 20,
      uslugaId: widget.serviceId,
    );
    if (!mounted) return;
    setState(() {
      _loadingMoreReviews = false;
      if (result.error == null) {
        _reviews = [..._reviews, ...result.items];
        _reviewPage = result.page;
        _reviewTotal = result.total;
      }
    });
  }

  bool get _hasMoreReviews =>
      _reviews.isNotEmpty && (_reviewPage * 20) < _reviewTotal;

  void _openCompletedAppointments() {
    final day = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    if (nuaspaUseMobileShell()) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TherapistAppointmentsScreen(
            filterDay: day,
            initialTab: 'Completed',
            filterUslugaId: widget.serviceId,
          ),
        ),
      );
      return;
    }
    final serviceName = _detail?.service.naziv;
    Navigator.of(context).pop();
    try {
      context.read<DesktopNav>().goToTherapistAppointmentsForService(
        uslugaId: widget.serviceId,
        initialTab: 'Completed',
        serviceName: serviceName,
      );
    } catch (_) {}
  }

  void _openSchedule() {
    final day = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    if (nuaspaUseMobileShell()) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TherapistScheduleScreen(
            filterDay: day,
          ),
        ),
      );
      return;
    }
    try {
      context.read<DesktopNav>().goTo(DesktopRouteKey.schedule);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_Ui.bgDeep, _Ui.bgMid],
          ),
        ),
        child: Center(
          child: CircularProgressIndicator(color: _Ui.purple, strokeWidth: 2),
        ),
      );
    }

    if (_detail == null) {
      return _ErrorScaffold(
        message: _error ?? 'Could not load service.',
        forbidden: _forbidden,
        notFound: _notFound,
        onRetry: _loadAll,
        onBack: () => Navigator.maybePop(context),
      );
    }

    final body = nuaspaUseMobileShell()
        ? _MobileBody(
            detail: _detail!,
            reviews: _reviews,
            hasMoreReviews: _hasMoreReviews,
            loadingMoreReviews: _loadingMoreReviews,
            onRefresh: () => _loadAll(refresh: true),
            onLoadMoreReviews: _loadMoreReviews,
            onOpenCompletedAppointments: _openCompletedAppointments,
            onOpenSchedule: _openSchedule,
          )
        : Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 9,
                  child: _LeftPanel(detail: _detail!),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 15,
                  child: _RightPanel(
                    detail: _detail!,
                    reviews: _reviews,
                    reviewsError: _error,
                    scrollController: _scrollCtrl,
                    hasMoreReviews: _hasMoreReviews,
                    loadingMoreReviews: _loadingMoreReviews,
                    onRefresh: () => _loadAll(refresh: true),
                    onLoadMoreReviews: _loadMoreReviews,
                    onBack: () => Navigator.maybePop(context),
                    onOpenCompletedAppointments: _openCompletedAppointments,
                    onOpenSchedule: _openSchedule,
                  ),
                ),
              ],
            ),
          );

    return Scaffold(
      backgroundColor: _Ui.bgDeep,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_Ui.bgDeep, _Ui.bgMid],
          ),
        ),
        child: body,
      ),
    );
  }
}

class _ErrorScaffold extends StatelessWidget {
  const _ErrorScaffold({
    required this.message,
    required this.forbidden,
    required this.notFound,
    required this.onRetry,
    required this.onBack,
  });

  final String message;
  final bool forbidden;
  final bool notFound;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final title = forbidden
        ? 'Access denied'
        : notFound
            ? 'Service not found'
            : 'Could not load service';

    return Scaffold(
      backgroundColor: _Ui.bgDeep,
      appBar: AppBar(
        backgroundColor: _Ui.bgDeep,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: onBack,
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                forbidden ? Icons.lock_outline_rounded : Icons.error_outline,
                size: 48,
                color: _Ui.purple.withValues(alpha: 0.55),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _Ui.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: _Ui.textSecondary,
                  height: 1.45,
                ),
              ),
              if (!forbidden && !notFound) ...[
                const SizedBox(height: 16),
                FilledButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileBody extends StatelessWidget {
  const _MobileBody({
    required this.detail,
    required this.reviews,
    required this.hasMoreReviews,
    required this.loadingMoreReviews,
    required this.onRefresh,
    required this.onLoadMoreReviews,
    required this.onOpenCompletedAppointments,
    required this.onOpenSchedule,
  });

  final TherapistServiceDetail detail;
  final List<TherapistReviewRow> reviews;
  final bool hasMoreReviews;
  final bool loadingMoreReviews;
  final VoidCallback onRefresh;
  final VoidCallback onLoadMoreReviews;
  final VoidCallback onOpenCompletedAppointments;
  final VoidCallback onOpenSchedule;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return TherapistMobilePageShell(
      title: detail.service.naziv,
      subtitle: detail.service.kategorija,
      child: RefreshIndicator(
        color: _Ui.purple,
        onRefresh: () async => onRefresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + bottomInset),
          child: _DetailsBody(
            detail: detail,
            reviews: reviews,
            hasMoreReviews: hasMoreReviews,
            loadingMoreReviews: loadingMoreReviews,
            onLoadMoreReviews: onLoadMoreReviews,
            onOpenCompletedAppointments: onOpenCompletedAppointments,
            onOpenSchedule: onOpenSchedule,
          ),
        ),
      ),
    );
  }
}

class _LeftPanel extends StatelessWidget {
  const _LeftPanel({required this.detail});

  final TherapistServiceDetail detail;

  @override
  Widget build(BuildContext context) {
    final service = detail.service;
    final imageHeight = _imageHeight(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(_Ui.cardRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: DecoratedBox(
          decoration: _Ui.glassCard(),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ServiceNetworkImage(
                  imageUrl: service.slikaUrl,
                  height: imageHeight,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  error: Container(
                    height: imageHeight,
                    color: _Ui.purple.withValues(alpha: 0.12),
                    child: Icon(
                      Icons.spa_outlined,
                      size: 56,
                      color: _Ui.purple.withValues(alpha: 0.35),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.naziv,
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: _Ui.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            service.cijenaKm,
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: _Ui.purple,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Icon(Icons.schedule_rounded,
                              size: 16, color: _Ui.textSecondary),
                          const SizedBox(width: 5),
                          Text(
                            service.trajanje,
                            style: GoogleFonts.inter(
                              fontSize: 14.5,
                              color: _Ui.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _CategoryPill(label: service.kategorija),
                          if (detail.isCertified) const _CertifiedBadge(),
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
    );
  }
}

class _RightPanel extends StatelessWidget {
  const _RightPanel({
    required this.detail,
    required this.reviews,
    required this.reviewsError,
    required this.scrollController,
    required this.hasMoreReviews,
    required this.loadingMoreReviews,
    required this.onRefresh,
    required this.onLoadMoreReviews,
    required this.onBack,
    required this.onOpenCompletedAppointments,
    required this.onOpenSchedule,
  });

  final TherapistServiceDetail detail;
  final List<TherapistReviewRow> reviews;
  final String? reviewsError;
  final ScrollController scrollController;
  final bool hasMoreReviews;
  final bool loadingMoreReviews;
  final VoidCallback onRefresh;
  final VoidCallback onLoadMoreReviews;
  final VoidCallback onBack;
  final VoidCallback onOpenCompletedAppointments;
  final VoidCallback onOpenSchedule;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_Ui.cardRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: DecoratedBox(
          decoration: _Ui.glassCard(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 20, 0),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _Ui.purple.withValues(alpha: 0.14),
                        border: Border.all(
                          color: _Ui.purple.withValues(alpha: 0.32),
                        ),
                      ),
                      child: const Icon(
                        Icons.medical_services_outlined,
                        color: _Ui.purple,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Service Overview',
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: _Ui.textPrimary,
                            ),
                          ),
                          Text(
                            'Manage and review your assigned treatment.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _Ui.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: onRefresh,
                      icon: const Icon(Icons.refresh_rounded),
                      color: _Ui.textSecondary,
                    ),
                    IconButton(
                      tooltip: 'Back',
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: _Ui.textSecondary,
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
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                    child: _DetailsBody(
                      detail: detail,
                      reviews: reviews,
                      reviewsError: reviewsError,
                      hasMoreReviews: hasMoreReviews,
                      loadingMoreReviews: loadingMoreReviews,
                      onLoadMoreReviews: onLoadMoreReviews,
                      onOpenCompletedAppointments: onOpenCompletedAppointments,
                      onOpenSchedule: onOpenSchedule,
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

class _DetailsBody extends StatelessWidget {
  const _DetailsBody({
    required this.detail,
    required this.reviews,
    this.reviewsError,
    required this.hasMoreReviews,
    required this.loadingMoreReviews,
    required this.onLoadMoreReviews,
    required this.onOpenCompletedAppointments,
    required this.onOpenSchedule,
  });

  final TherapistServiceDetail detail;
  final List<TherapistReviewRow> reviews;
  final String? reviewsError;
  final bool hasMoreReviews;
  final bool loadingMoreReviews;
  final VoidCallback onLoadMoreReviews;
  final VoidCallback onOpenCompletedAppointments;
  final VoidCallback onOpenSchedule;

  @override
  Widget build(BuildContext context) {
    final service = detail.service;
    final description = service.opis.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatusCard(detail: detail),
        const SizedBox(height: 14),
        _ActionRow(
          onOpenCompletedAppointments: onOpenCompletedAppointments,
          onOpenSchedule: onOpenSchedule,
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Description',
          child: Text(
            description.isEmpty
                ? 'No description provided for this service.'
                : description,
            style: GoogleFonts.inter(
              fontSize: 14.5,
              height: 1.55,
              color: description.isEmpty
                  ? _Ui.textSecondary
                  : _Ui.textPrimary.withValues(alpha: 0.9),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Service Information',
          child: Column(
            children: [
              _InfoRow(
                icon: Icons.schedule_outlined,
                label: 'Duration',
                value: service.trajanje,
              ),
              _InfoRow(
                icon: Icons.category_outlined,
                label: 'Category',
                value: service.kategorija,
              ),
              _InfoRow(
                icon: Icons.verified_outlined,
                label: 'Certification Status',
                value: detail.isCertified ? 'Certified' : 'Not certified',
                valueColor: detail.isCertified ? _Ui.green : const Color(0xFFFF8A80),
              ),
              _InfoRow(
                icon: Icons.badge_outlined,
                label: 'Employment Status',
                value: _employmentLabel(detail.employmentStatus),
                valueColor:
                    detail.isEmployedActive ? _Ui.green : const Color(0xFFF5B942),
              ),
              _InfoRow(
                icon: Icons.event_available_outlined,
                label: 'Schedule Availability',
                value: _scheduleAvailabilityLabel(detail),
                valueColor: detail.isSpaClosedToday ||
                        detail.isTherapistUnavailableToday
                    ? const Color(0xFFF5B942)
                    : detail.availableSlotCountToday > 0
                        ? _Ui.green
                        : _Ui.textSecondary,
              ),
              if (detail.completedBookingsCount > 0)
                _InfoRow(
                  icon: Icons.check_circle_outline,
                  label: 'Completed Bookings',
                  value: '${detail.completedBookingsCount}',
                ),
              if (detail.myReviewCount > 0 && detail.myAverageRating != null)
                _InfoRow(
                  icon: Icons.star_outline_rounded,
                  label: 'Your Average Rating',
                  value: detail.myAverageRating!.toStringAsFixed(1),
                  valueColor: _Ui.gold,
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Your Reviews',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (reviewsError != null)
                Text(
                  reviewsError!,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: _Ui.textSecondary,
                  ),
                )
              else if (reviews.isEmpty)
                const _ReviewsEmptyState()
              else ...[
                Text(
                  '${detail.myReviewCount} review'
                  '${detail.myReviewCount == 1 ? '' : 's'} · '
                  'your average '
                  '${detail.myAverageRating?.toStringAsFixed(1) ?? '—'}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _Ui.gold,
                  ),
                ),
                const SizedBox(height: 12),
                for (final r in reviews)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ReviewCard(review: r),
                  ),
                if (hasMoreReviews)
                  Align(
                    alignment: Alignment.center,
                    child: TextButton(
                      onPressed:
                          loadingMoreReviews ? null : onLoadMoreReviews,
                      child: loadingMoreReviews
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Load more reviews'),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.detail});

  final TherapistServiceDetail detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _Ui.purple.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _Ui.purple.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Status',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _Ui.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _StatusLine(label: 'Certified', active: detail.isCertified),
          const SizedBox(height: 8),
          _StatusLine(
            label: 'Available for bookings',
            active: detail.isEmployedActive &&
                !detail.isTherapistUnavailableToday &&
                !detail.isSpaClosedToday,
          ),
          const SizedBox(height: 8),
          _StatusLine(
            label: 'Authorized to perform this service',
            active: detail.isAuthorized,
          ),
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? _Ui.green : _Ui.textSecondary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          active ? Icons.check_circle_rounded : Icons.cancel_outlined,
          size: 18,
          color: color,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: active
                  ? _Ui.textPrimary.withValues(alpha: 0.92)
                  : _Ui.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.onOpenCompletedAppointments,
    required this.onOpenSchedule,
  });

  final VoidCallback onOpenCompletedAppointments;
  final VoidCallback onOpenSchedule;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        OutlinedButton.icon(
          onPressed: onOpenCompletedAppointments,
          icon: const Icon(Icons.event_available_outlined, size: 18),
          label: const Text('Completed appointments'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _Ui.textPrimary,
            side: BorderSide(color: _Ui.purple.withValues(alpha: 0.4)),
          ),
        ),
        OutlinedButton.icon(
          onPressed: onOpenSchedule,
          icon: const Icon(Icons.calendar_month_outlined, size: 18),
          label: const Text('Manage schedule'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _Ui.textPrimary,
            side: BorderSide(color: _Ui.purple.withValues(alpha: 0.4)),
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _Ui.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 17, color: _Ui.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _Ui.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: valueColor ?? _Ui.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final TherapistReviewRow review;

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
                    color: _Ui.textPrimary,
                    fontSize: 14,
                  ),
                ),
              ),
              _StarRow(value: review.ocjena),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _formatReviewDate(review.createdAt),
            style: GoogleFonts.inter(fontSize: 12, color: _Ui.textSecondary),
          ),
          if (review.komentar.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.komentar,
              style: GoogleFonts.inter(
                fontSize: 14.5,
                height: 1.55,
                color: _Ui.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(
          i < value ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 16,
          color: _Ui.gold,
        ),
      ),
    );
  }
}

class _ReviewsEmptyState extends StatelessWidget {
  const _ReviewsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Icon(
            Icons.rate_review_outlined,
            size: 44,
            color: _Ui.purple.withValues(alpha: 0.45),
          ),
          const SizedBox(height: 14),
          Text(
            'No reviews yet',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _Ui.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Clients will be able to leave reviews after completed appointments.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14.5,
              height: 1.55,
              color: _Ui.textSecondary,
            ),
          ),
        ],
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
        color: _Ui.purple.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _Ui.purple.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: _Ui.textPrimary,
        ),
      ),
    );
  }
}

class _CertifiedBadge extends StatelessWidget {
  const _CertifiedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: _Ui.green.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _Ui.green.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified_rounded, size: 14, color: _Ui.green),
          const SizedBox(width: 5),
          Text(
            'Certified',
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: _Ui.green,
            ),
          ),
        ],
      ),
    );
  }
}
