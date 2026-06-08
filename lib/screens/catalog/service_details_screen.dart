import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/api/services/api_service.dart';
import '../../core/auth/app_permissions.dart';
import '../../providers/auth_provider.dart';
import '../../providers/service_provider.dart';
import '../../core/preporuka/preporuka_tracker.dart';
import '../reservations/reservation_create_screen.dart';
import '../../core/catalog/catalog_admin_messages.dart';
import '../../core/platform/nua_spa_platform.dart';
import 'admin_service_details_panel.dart';
import 'assign_therapist_dialog.dart';
import 'service_editor_dialog.dart';
import '../../models/recenzija.dart';
import '../../models/reviewable_visit.dart';
import '../../models/usluga.dart';
import '../../models/zaposlenik.dart';
import '../../ui/theme/mobile_spa_theme.dart';
import '../../ui/theme/luxury_modal_style.dart';
import '../../ui/widgets/service_network_image.dart';

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

  /// When true, renders the admin management layout (catalog / therapist admin).
  final bool adminPanelView;

  /// Preselect a completed visit when opening from bookings ("Rate service").
  final int? initialRezervacijaId;

  const ServiceDetailsScreen({
    super.key,
    required this.serviceId,
    this.adminPanelView = false,
    this.initialRezervacijaId,
  });

  @override
  State<ServiceDetailsScreen> createState() => _ServiceDetailsScreenState();
}

class _ServiceDetailsScreenState extends State<ServiceDetailsScreen> {
  final ApiService _apiService = ApiService();
  final ScrollController _rightScrollController = ScrollController();

  late Future<Usluga?> _serviceFuture;
  late Future<RecenzijeLoadResult> _recenzijeFuture;

  final TextEditingController _komentarController = TextEditingController();
  int _ocjena = 5;
  List<Zaposlenik> _therapists = [];
  int? _selectedZaposlenikId;
  bool _therapistsLoading = false;
  int? _therapistsLoadedForUslugaId;
  String? _therapistsError;
  String? _serviceLoadError;
  bool _serviceNotFound = false;
  bool _submittingReview = false;
  List<ReviewableVisit> _reviewableVisits = [];
  bool _reviewableVisitsLoading = false;
  String? _reviewableVisitsError;
  int? _selectedRezervacijaId;

  static const int _maxCommentLength = 1000;

  bool _clientCanReview(AuthProvider auth) =>
      auth.status == AuthStatus.authenticated &&
      !auth.isZaposlenik &&
      !auth.isAdmin;

  @override
  void initState() {
    super.initState();
    _recenzijeFuture = _apiService.getRecenzijeByUsluga(widget.serviceId);
    _serviceFuture = _loadServiceAndTherapists();
    Future.microtask(() {
      if (!mounted) return;
      context.read<ServiceProvider>().fetchFavorites();
    });
  }

  Future<Usluga?> _loadServiceAndTherapists() async {
    final result = await _apiService.getUslugaById(widget.serviceId);
    if (!mounted) return null;

    if (result.service != null) {
      PreporukaTracker.instance.trackServiceView(result.service!.id);
      await _loadTherapistsForService(result.service!);
      await _loadReviewableVisits();
      return result.service;
    }

    setState(() {
      _serviceNotFound = result.notFound;
      _serviceLoadError = result.error;
    });
    return null;
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

  Future<void> _loadTherapistsForService(Usluga service) async {
    if (_therapistsLoading || _therapistsLoadedForUslugaId == service.id) {
      return;
    }
    setState(() {
      _therapistsLoading = true;
      _therapistsError = null;
    });
    final result = await _apiService.getZaposleniciForService(service.id);
    if (!mounted) return;
    final therapists = result.items;
    setState(() {
      _therapists = therapists;
      _therapistsLoading = false;
      _therapistsError = result.error;
      _therapistsLoadedForUslugaId = service.id;
      if (therapists.length == 1) {
        _selectedZaposlenikId = therapists.first.id;
      } else if (_selectedZaposlenikId != null &&
          !therapists.any((z) => z.id == _selectedZaposlenikId)) {
        _selectedZaposlenikId = null;
      }
    });
  }

  Future<void> _openBooking(Usluga service) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => ReservationCreateScreen(initialServiceId: service.id),
      ),
    );
  }

  Future<void> _toggleFavorite(int serviceId) async {
    final ok = await context.read<ServiceProvider>().toggleFavorite(serviceId);
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not save favorite. Sign in as a client or admin.'),
      ),
    );
  }

  Future<void> _loadReviewableVisits() async {
    final auth = context.read<AuthProvider>();
    if (!_clientCanReview(auth)) return;

    setState(() {
      _reviewableVisitsLoading = true;
      _reviewableVisitsError = null;
    });

    final result = await _apiService.getReviewableVisits(widget.serviceId);
    if (!mounted) return;

    ReviewableVisit? initialVisit;
    if (widget.initialRezervacijaId != null) {
      for (final visit in result.items) {
        if (visit.rezervacijaId == widget.initialRezervacijaId) {
          initialVisit = visit;
          break;
        }
      }
    }

    setState(() {
      _reviewableVisits = result.items;
      _reviewableVisitsLoading = false;
      _reviewableVisitsError = result.error;
      if (initialVisit != null) {
        _selectedRezervacijaId = initialVisit.rezervacijaId;
        _selectedZaposlenikId = initialVisit.zaposlenikId;
      } else if (result.items.length == 1) {
        _selectedRezervacijaId = result.items.first.rezervacijaId;
        _selectedZaposlenikId = result.items.first.zaposlenikId;
      } else if (_selectedRezervacijaId != null &&
          !result.items.any((v) => v.rezervacijaId == _selectedRezervacijaId)) {
        _selectedRezervacijaId = null;
        _selectedZaposlenikId = null;
      }
    });
  }

  bool _canShowReviewForm(bool canSubmitReview) =>
      canSubmitReview &&
      !_reviewableVisitsLoading &&
      _reviewableVisitsError == null &&
      _reviewableVisits.isNotEmpty;

  Future<void> _openEditService(Usluga service) async {
    final ok = await showServiceEditorDialog(context, existing: service);
    if (!mounted || !ok) return;
    setState(() {
      _therapistsLoadedForUslugaId = null;
      _serviceFuture = _loadServiceAndTherapists();
      _recenzijeFuture = _apiService.getRecenzijeByUsluga(widget.serviceId);
    });
    await context.read<ServiceProvider>().fetchServices();
  }

  Future<void> _confirmDeleteService(Usluga service) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete service'),
        content: Text(
          'Delete "${service.naziv}"? If the service has bookings or payments, '
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

    final err = await _apiService.deleteUsluga(service.id);
    if (!mounted) return;
    if (err != null) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Couldn\'t delete service'),
          content: Text(CatalogAdminMessages.serviceDeleteError(err)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Service deleted.')),
    );
    await context.read<ServiceProvider>().fetchServices();
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _assignTherapistToService(Usluga service) async {
    final ok = await showAssignTherapistToServiceDialog(
      context,
      service: service,
      alreadyLinkedIds: _therapists.map((t) => t.id).toSet(),
    );
    if (!mounted || !ok) return;
    setState(() => _therapistsLoadedForUslugaId = null);
    await _loadTherapistsForService(service);
  }

  Widget _buildAdminPanelDetails(BuildContext context, Usluga service) {
    return AdminServiceDetailsPanel(
      service: service,
      benefits: _benefitTags(service),
      therapists: _therapists,
      therapistsLoading: _therapistsLoading,
      therapistsError: _therapistsError,
      recenzijeFuture: _recenzijeFuture,
      onRefreshReviews: _refreshRecenzije,
      onEdit: () => _openEditService(service),
      onDelete: () => _confirmDeleteService(service),
      onBack: () => Navigator.pop(context),
      onAssignTherapist: () => _assignTherapistToService(service),
    );
  }

  Future<void> _submitReview() async {
    if (_submittingReview) return;

    final komentar = _komentarController.text.trim();
    final visit = _reviewableVisits.cast<ReviewableVisit?>().firstWhere(
          (v) => v?.rezervacijaId == _selectedRezervacijaId,
          orElse: () => null,
        );
    if (visit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a completed visit to review.')),
      );
      return;
    }
    if (komentar.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a comment.')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _submittingReview = true);
    try {
      final (_, error) = await _apiService.createRecenzija(
        rezervacijaId: visit.rezervacijaId,
        uslugaId: widget.serviceId,
        zaposlenikId: visit.zaposlenikId,
        ocjena: _ocjena,
        komentar: komentar,
      );

      if (!mounted) return;

      if (error != null) {
        messenger.showSnackBar(SnackBar(content: Text(error)));
        return;
      }

      _komentarController.clear();
      await _refreshRecenzije();
      await _loadReviewableVisits();
      messenger.showSnackBar(
        const SnackBar(content: Text('Review added.')),
      );
    } finally {
      if (mounted) {
        setState(() => _submittingReview = false);
      }
    }
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
    final auth = context.watch<AuthProvider>();
    final canSubmitReview = _clientCanReview(auth);
    final canBook = AppPermissions.of(auth).has(AppPermission.bookAppointments);
    final canFavorite = _clientCanReview(auth);
    final isFavorite =
        context.watch<ServiceProvider>().isFavorite(service.id);
    final showReviewForm = _canShowReviewForm(canSubmitReview);

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
            actions: [
              if (canFavorite)
                IconButton(
                  tooltip: isFavorite
                      ? 'Remove from favorites'
                      : 'Add to favorites',
                  onPressed: () => _toggleFavorite(service.id),
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite
                        ? MobileSpaColors.royalPurple
                        : MobileSpaColors.royalPurple.withValues(alpha: 0.72),
                  ),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  ServiceNetworkImage(
                    imageUrl: service.slikaUrl,
                    fit: BoxFit.cover,
                    error: ColoredBox(
                      color: MobileSpaColors.lavender.withValues(alpha: 0.28),
                      child: Icon(
                        Icons.spa_outlined,
                        size: 56,
                        color: MobileSpaColors.royalPurple.withValues(alpha: 0.28),
                      ),
                    ),
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
                  if (canBook) ...[
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _openBooking(service),
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: const Text('Book this service'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 26),
                  _MobileReviewsBlock(
                    recenzijeFuture: _recenzijeFuture,
                    canSubmitReview: canSubmitReview,
                    showReviewForm: showReviewForm,
                    reviewableVisitsError: _reviewableVisitsError,
                    submittingReview: _submittingReview,
                    maxCommentLength: _maxCommentLength,
                    ocjena: _ocjena,
                    onRatingChanged: (v) => setState(() => _ocjena = v),
                    komentarController: _komentarController,
                    reviewableVisits: _reviewableVisits,
                    reviewableVisitsLoading: _reviewableVisitsLoading,
                    selectedRezervacijaId: _selectedRezervacijaId,
                    onVisitChanged: (id) {
                      ReviewableVisit? visit;
                      for (final v in _reviewableVisits) {
                        if (v.rezervacijaId == id) {
                          visit = v;
                          break;
                        }
                      }
                      setState(() {
                        _selectedRezervacijaId = id;
                        _selectedZaposlenikId = visit?.zaposlenikId;
                      });
                    },
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
    final auth = context.watch<AuthProvider>();
    final canSubmitReview = _clientCanReview(auth);
    final canBook = AppPermissions.of(auth).has(AppPermission.bookAppointments);
    final canFavorite = _clientCanReview(auth);
    final isFavorite =
        context.watch<ServiceProvider>().isFavorite(service.id);
    final showReviewForm = _canShowReviewForm(canSubmitReview);

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
                canSubmitReview: canSubmitReview,
                showReviewForm: showReviewForm,
                canBook: canBook,
                canFavorite: canFavorite,
                isFavorite: isFavorite,
                onToggleFavorite: () => _toggleFavorite(service.id),
                onBook: () => _openBooking(service),
                reviewableVisitsError: _reviewableVisitsError,
                submittingReview: _submittingReview,
                ocjena: _ocjena,
                onRatingChanged: (v) => setState(() => _ocjena = v),
                komentarController: _komentarController,
                maxCommentLength: _maxCommentLength,
                reviewableVisits: _reviewableVisits,
                reviewableVisitsLoading: _reviewableVisitsLoading,
                selectedRezervacijaId: _selectedRezervacijaId,
                onVisitChanged: (id) {
                  ReviewableVisit? visit;
                  for (final v in _reviewableVisits) {
                    if (v.rezervacijaId == id) {
                      visit = v;
                      break;
                    }
                  }
                  setState(() {
                    _selectedRezervacijaId = id;
                    _selectedZaposlenikId = visit?.zaposlenikId;
                  });
                },
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
            final message = _serviceNotFound
                ? 'Service not found.'
                : (_serviceLoadError ??
                    'Could not load service. Check your connection.');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(message, style: _DetailsStyle.body(context)),
                    if (!_serviceNotFound) ...[
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _serviceNotFound = false;
                            _serviceLoadError = null;
                            _serviceFuture = _loadServiceAndTherapists();
                          });
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }

          if (widget.adminPanelView) {
            return _buildAdminPanelDetails(context, service);
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
                        child: ServiceNetworkImage(
                          imageUrl: service.slikaUrl,
                          height: imageHeight,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          error: Container(
                            height: imageHeight,
                            color: _DetailsStyle.accentPurple
                                .withValues(alpha: 0.12),
                            child: Icon(
                              Icons.spa_outlined,
                              size: 72,
                              color: _DetailsStyle.accentPurple
                                  .withValues(alpha: 0.35),
                            ),
                          ),
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
    required this.canSubmitReview,
    required this.showReviewForm,
    required this.canBook,
    required this.canFavorite,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onBook,
    required this.reviewableVisitsError,
    required this.submittingReview,
    required this.ocjena,
    required this.onRatingChanged,
    required this.komentarController,
    required this.maxCommentLength,
    required this.reviewableVisits,
    required this.reviewableVisitsLoading,
    required this.selectedRezervacijaId,
    required this.onVisitChanged,
    required this.onRefresh,
    required this.onSubmit,
    required this.onBack,
  });

  final Usluga service;
  final ScrollController scrollController;
  final Future<RecenzijeLoadResult> recenzijeFuture;
  final bool canSubmitReview;
  final bool showReviewForm;
  final bool canBook;
  final bool canFavorite;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onBook;
  final String? reviewableVisitsError;
  final bool submittingReview;
  final int ocjena;
  final ValueChanged<int> onRatingChanged;
  final TextEditingController komentarController;
  final int maxCommentLength;
  final List<ReviewableVisit> reviewableVisits;
  final bool reviewableVisitsLoading;
  final int? selectedRezervacijaId;
  final ValueChanged<int?> onVisitChanged;
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
                    if (canFavorite)
                      _GlassIconButton(
                        icon: isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        tooltip: isFavorite
                            ? 'Remove from favorites'
                            : 'Add to favorites',
                        onPressed: onToggleFavorite,
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
                        if (canBook) ...[
                          const SizedBox(height: 20),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _SubmitReviewButton(
                              label: 'Book this service',
                              icon: Icons.calendar_month_outlined,
                              onPressed: onBook,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        FutureBuilder<RecenzijeLoadResult>(
                          future: recenzijeFuture,
                          builder: (context, snapshot) {
                            final loading =
                                snapshot.connectionState ==
                                        ConnectionState.waiting &&
                                    !snapshot.hasData;
                            final result = snapshot.data;
                            final reviews = result?.items ?? [];
                            final loadError = result?.error;
                            final truncated = result?.truncated ?? false;

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
                                else if (loadError != null)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        loadError,
                                        style: _DetailsStyle.body(context),
                                      ),
                                      const SizedBox(height: 8),
                                      TextButton(
                                        onPressed: onRefresh,
                                        child: const Text('Retry'),
                                      ),
                                    ],
                                  )
                                else if (reviews.isEmpty)
                                  Text(
                                    'Be the first to review this service.',
                                    style: _DetailsStyle.body(context),
                                  )
                                else ...[
                                  if (truncated)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: Text(
                                        'Showing the most recent reviews.',
                                        style: _DetailsStyle.label(context),
                                      ),
                                    ),
                                  ...reviews.map(
                                    (r) => Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: _ReviewCard(
                                        review: r,
                                        lightSurface: false,
                                      ),
                                    ),
                                  ),
                                ],
                                if (canSubmitReview && reviewableVisitsLoading)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: Text(
                                      'Loading your completed visits…',
                                      style: _DetailsStyle.body(context),
                                    ),
                                  )
                                else if (canSubmitReview &&
                                    reviewableVisitsError != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: Text(
                                      reviewableVisitsError!,
                                      style: _DetailsStyle.body(context),
                                    ),
                                  )
                                else if (canSubmitReview &&
                                    reviewableVisits.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: Text(
                                      'No completed visits are available to review for this service.',
                                      style: _DetailsStyle.body(context),
                                    ),
                                  )
                                else if (showReviewForm) ...[
                                  const SizedBox(height: 24),
                                  Text(
                                    'Add a review',
                                    style: _DetailsStyle.sectionTitle(context)
                                        .copyWith(fontSize: 18),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Choose a completed visit, then share your experience.',
                                    style: _DetailsStyle.body(context),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    'Visit',
                                    style: _DetailsStyle.label(context),
                                  ),
                                  const SizedBox(height: 8),
                                  _VisitPicker(
                                    visits: reviewableVisits,
                                    loading: reviewableVisitsLoading,
                                    selectedId: selectedRezervacijaId,
                                    onChanged: onVisitChanged,
                                    lightSurface: false,
                                  ),
                                  const SizedBox(height: 18),
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
                                  ),
                                  const SizedBox(height: 18),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: _SubmitReviewButton(
                                      onPressed: onSubmit,
                                      isSubmitting: submittingReview,
                                    ),
                                  ),
                                ],
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
    final button = MouseRegion(
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

    final tooltip = widget.tooltip;
    if (tooltip == null || tooltip.isEmpty) return button;
    return Tooltip(message: tooltip, child: button);
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
  const _ReviewCard({
    required this.review,
    this.lightSurface = false,
  });

  final Recenzija review;
  final bool lightSurface;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final titleColor =
        lightSurface ? MobileSpaColors.royalPurple : _DetailsStyle.textPrimary;
    final bodyStyle = lightSurface
        ? tt.bodyMedium!
        : _DetailsStyle.body(context);
    final mutedColor = lightSurface
        ? MobileSpaColors.royalPurple.withValues(alpha: 0.55)
        : Colors.white.withValues(alpha: 0.45);
    final cardColor = lightSurface
        ? Colors.white
        : Colors.white.withValues(alpha: 0.04);
    final borderColor = lightSurface
        ? MobileSpaColors.lavender.withValues(alpha: 0.45)
        : Colors.white.withValues(alpha: 0.08);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: lightSurface
            ? [
                BoxShadow(
                  color: MobileSpaColors.lavender.withValues(alpha: 0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
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
                    color: titleColor,
                    fontSize: 14,
                  ),
                ),
              ),
              _StarRow(value: review.ocjena, size: 16),
            ],
          ),
          if (review.zaposlenikIme != null &&
              review.zaposlenikIme!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Therapist: ${review.zaposlenikIme!.trim()}',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: mutedColor,
              ),
            ),
          ],
          if (review.createdAt != null) ...[
            const SizedBox(height: 4),
            Text(
              _formatReviewDate(review.createdAt!),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: mutedColor,
              ),
            ),
          ],
          if (review.komentar.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(review.komentar, style: bodyStyle),
          ],
          if (review.adminOdgovor != null &&
              review.adminOdgovor!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _DetailsStyle.accentPurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _DetailsStyle.accentPurple.withValues(alpha: 0.22),
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
                      color: _DetailsStyle.accentPurple,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    review.adminOdgovor!.trim(),
                    style: bodyStyle,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _formatReviewDate(DateTime date) {
  final local = date.toLocal();
  return '${local.day.toString().padLeft(2, '0')}.'
      '${local.month.toString().padLeft(2, '0')}.'
      '${local.year}';
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
  });

  final TextEditingController controller;
  final int maxLength;

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
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: widget.controller,
          builder: (context, value, _) {
            return Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${value.text.length} / ${widget.maxLength}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: _DetailsStyle.textSecondary,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SubmitReviewButton extends StatefulWidget {
  const _SubmitReviewButton({
    required this.onPressed,
    this.isSubmitting = false,
    this.label = 'Submit Review',
    this.icon = Icons.send_rounded,
  });

  final VoidCallback onPressed;
  final bool isSubmitting;
  final String label;
  final IconData icon;

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
        onTap: widget.isSubmitting ? null : widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
          width: 200,
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
              if (widget.isSubmitting)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                Icon(widget.icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                widget.isSubmitting ? 'Submitting…' : widget.label,
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

class _VisitPicker extends StatelessWidget {
  const _VisitPicker({
    required this.visits,
    required this.loading,
    required this.selectedId,
    required this.onChanged,
    this.lightSurface = false,
  });

  final List<ReviewableVisit> visits;
  final bool loading;
  final int? selectedId;
  final ValueChanged<int?> onChanged;
  final bool lightSurface;

  String _formatVisitLabel(ReviewableVisit visit) {
    final d = visit.datumRezervacije.toLocal();
    final date =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return '$date · ${visit.zaposlenikIme}';
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }

    return _TherapistPickerShell(
      lightSurface: lightSurface,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          value: selectedId,
          hint: const Text('Select a completed visit'),
          items: visits
              .map(
                (v) => DropdownMenuItem(
                  value: v.rezervacijaId,
                  child: Text(_formatVisitLabel(v)),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _TherapistPickerShell extends StatelessWidget {
  const _TherapistPickerShell({
    required this.child,
    required this.lightSurface,
  });

  final Widget child;
  final bool lightSurface;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: lightSurface
            ? Colors.white
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: lightSurface
              ? MobileSpaColors.lavender.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: child,
      ),
    );
  }
}

class _MobileReviewsBlock extends StatelessWidget {
  const _MobileReviewsBlock({
    required this.recenzijeFuture,
    required this.canSubmitReview,
    required this.showReviewForm,
    required this.reviewableVisitsError,
    required this.submittingReview,
    required this.maxCommentLength,
    required this.ocjena,
    required this.onRatingChanged,
    required this.komentarController,
    required this.reviewableVisits,
    required this.reviewableVisitsLoading,
    required this.selectedRezervacijaId,
    required this.onVisitChanged,
    required this.onRefresh,
    required this.onSubmit,
  });

  final Future<RecenzijeLoadResult> recenzijeFuture;
  final bool canSubmitReview;
  final bool showReviewForm;
  final String? reviewableVisitsError;
  final bool submittingReview;
  final int maxCommentLength;
  final int ocjena;
  final ValueChanged<int> onRatingChanged;
  final TextEditingController komentarController;
  final List<ReviewableVisit> reviewableVisits;
  final bool reviewableVisitsLoading;
  final int? selectedRezervacijaId;
  final ValueChanged<int?> onVisitChanged;
  final VoidCallback onRefresh;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RecenzijeLoadResult>(
      future: recenzijeFuture,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData;
        final result = snapshot.data;
        final reviews = result?.items ?? [];
        final loadError = result?.error;
        final truncated = result?.truncated ?? false;

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
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (loadError != null) ...[
              Text(loadError),
              TextButton(onPressed: onRefresh, child: const Text('Retry')),
            ] else if (reviews.isEmpty)
              const Text('No reviews for this service yet.')
            else ...[
              if (truncated)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Showing the most recent reviews.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ...reviews.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ReviewCard(review: r, lightSurface: true),
                ),
              ),
            ],
            if (canSubmitReview && reviewableVisitsLoading)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  'Loading your completed visits…',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              )
            else if (canSubmitReview && reviewableVisitsError != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(reviewableVisitsError!),
              )
            else if (canSubmitReview && reviewableVisits.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  'No completed visits are available to review for this service.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              )
            else if (showReviewForm) ...[
              const SizedBox(height: 16),
              Text(
                'Choose a completed visit, then share your experience.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              _VisitPicker(
                visits: reviewableVisits,
                loading: reviewableVisitsLoading,
                selectedId: selectedRezervacijaId,
                onChanged: onVisitChanged,
                lightSurface: true,
              ),
              const SizedBox(height: 12),
              _GoldStarRating(value: ocjena, onChanged: onRatingChanged),
              const SizedBox(height: 8),
              TextField(
                controller: komentarController,
                minLines: 3,
                maxLines: 5,
                maxLength: maxCommentLength,
                decoration: const InputDecoration(labelText: 'Comment'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: submittingReview ? null : onSubmit,
                child: submittingReview
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit review'),
              ),
            ],
          ],
        );
      },
    );
  }
}
