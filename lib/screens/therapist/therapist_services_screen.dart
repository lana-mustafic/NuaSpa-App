import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/api/services/api_service.dart';
import '../../core/auth/app_permissions.dart';
import '../../core/therapist/therapist_service_eligibility.dart';
import '../../models/therapist/therapist_my_services_result.dart';
import '../../models/usluga.dart';
import '../../models/zaposlenik.dart';
import '../../models/zaposlenik_status.dart';
import '../../providers/auth_provider.dart';
import '../catalog/service_details_screen.dart';
import 'therapist_portal_scaffold.dart';
import '../../ui/widgets/service_network_image.dart';

abstract final class _SvcUi {
  static const bgTop = Color(0xFF07040F);
  static const bgBottom = Color(0xFF120A24);
  static const textPrimary = Color(0xFFF5F3FA);
  static const textSecondary = Color(0xA6FFFFFF);
  static const purple = Color(0xFF7B4DFF);
  static const lavender = Color(0xFF9D6BFF);
  static const green = Color(0xFF22C55E);
  static const gold = Color(0xFFF5B942);
  static const orange = Color(0xFFF97316);
  static const cardRadius = 24.0;
  static const gap = 24.0;
  static const sidebarWidth = 260.0;
  static const contentPadding = 32.0;
}

String _durationLabel(Usluga u) {
  if (u.trajanjeMinuta > 0) return '${u.trajanjeMinuta} min';
  final m = RegExp(r'(\d+)').firstMatch(u.trajanje);
  if (m != null) return '${m.group(1)} min';
  return u.trajanje;
}

List<Usluga> _sortServices(List<Usluga> list, String mode) {
  final copy = [...list];
  switch (mode) {
    case 'Z to A':
      copy.sort((a, b) => b.naziv.compareTo(a.naziv));
    case 'Duration':
      copy.sort((a, b) => b.trajanjeMinuta.compareTo(a.trajanjeMinuta));
    case 'Price: High to Low':
      copy.sort((a, b) => b.cijena.compareTo(a.cijena));
    default:
      copy.sort((a, b) => a.naziv.compareTo(b.naziv));
  }
  return copy;
}

String _statusLabel(ZaposlenikStatus status) {
  switch (status) {
    case ZaposlenikStatus.active:
      return 'Active';
    case ZaposlenikStatus.onLeave:
      return 'On leave';
    case ZaposlenikStatus.inactive:
      return 'Inactive';
  }
}

Color _statusColor(ZaposlenikStatus status) {
  switch (status) {
    case ZaposlenikStatus.active:
      return _SvcUi.green;
    case ZaposlenikStatus.onLeave:
      return _SvcUi.gold;
    case ZaposlenikStatus.inactive:
      return _SvcUi.orange;
  }
}

class TherapistServicesScreen extends StatefulWidget {
  const TherapistServicesScreen({super.key});

  @override
  State<TherapistServicesScreen> createState() =>
      _TherapistServicesScreenState();
}

class _TherapistServicesScreenState extends State<TherapistServicesScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  Future<TherapistMyServicesResult>? _future;
  final _scrollCtrl = ScrollController();
  final _searchCtrl = TextEditingController();
  String _sortMode = 'A to Z';
  String _searchQuery = '';
  Timer? _searchDebounce;
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

  Future<void> _reload() async {
    setState(() {
      _future = _api.getTherapistMyServices();
    });
    await _future;
    if (mounted) {
      _fadeCtrl.forward(from: 0);
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _searchQuery = value.trim().toLowerCase());
    });
  }

  List<Usluga> _filterList(List<Usluga> linked) {
    var list = linked;
    if (_searchQuery.isNotEmpty) {
      list = list
          .where(
            (u) =>
                u.naziv.toLowerCase().contains(_searchQuery) ||
                u.kategorija.toLowerCase().contains(_searchQuery),
          )
          .toList();
    }
    return _sortServices(list, _sortMode);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!AppPermissions.of(auth).has(AppPermission.viewOwnTherapistData)) {
      return const _ServicesShell(
        child: TherapistEmptyState(
          message:
              'Therapist login required. Your account must be linked to a therapist profile.',
        ),
      );
    }

    return _ServicesShell(
      child: RefreshIndicator(
        color: _SvcUi.lavender,
        onRefresh: _reload,
        child: FutureBuilder<TherapistMyServicesResult>(
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

            if (snap.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(_SvcUi.contentPadding),
                children: [
                  _ErrorCard(
                    message: 'Something went wrong while loading your services.',
                    onRetry: _reload,
                  ),
                ],
              );
            }

            final result = snap.data;
            if (result == null) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(_SvcUi.contentPadding),
                children: [
                  _ErrorCard(
                    message: 'Could not load your service list.',
                    onRetry: _reload,
                  ),
                ],
              );
            }

            if (result.accountNotLinked) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(_SvcUi.contentPadding),
                children: [
                  _ErrorCard(
                    message: result.error ??
                        'Your account is not linked to a therapist profile.',
                    onRetry: _reload,
                  ),
                ],
              );
            }

            final me = result.therapist;
            if (me == null) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(_SvcUi.contentPadding),
                children: [
                  _ErrorCard(
                    message: result.error ??
                        result.profileError ??
                        'Could not load your therapist profile.',
                    onRetry: _reload,
                  ),
                ],
              );
            }

            final tags = specializationTagsFor(me);
            final linked = result.services;
            final filtered = _filterList(linked);
            final katName = me.kategorijaUslugaNaziv?.trim();
            final isSearching = _searchQuery.isNotEmpty;

            return FadeTransition(
              opacity: _fadeAnim,
              child: LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth >= 1100;
                  final main = _MainColumn(
                    me: me,
                    linked: linked,
                    filtered: filtered,
                    isSearching: isSearching,
                    categoryName: katName,
                    sortMode: _sortMode,
                    searchCtrl: _searchCtrl,
                    onSearchChanged: _onSearchChanged,
                    onSort: (v) => setState(() => _sortMode = v),
                    onOpenService: (id) {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ServiceDetailsScreen(
                            serviceId: id,
                            therapistView: true,
                          ),
                        ),
                      );
                    },
                    partialError: result.isPartialSuccess
                        ? result.servicesError
                        : null,
                  );
                  final sidebar = _TherapistProfileCard(
                    therapist: me,
                    categoryName: katName,
                    certifiedServicesCount: linked.length,
                    specializationsCount: tags.length,
                  );

                  return SingleChildScrollView(
                    controller: _scrollCtrl,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      _SvcUi.contentPadding,
                      8,
                      _SvcUi.contentPadding,
                      40,
                    ),
                    child: wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 7, child: main),
                              const SizedBox(width: _SvcUi.gap),
                              SizedBox(
                                width: _SvcUi.sidebarWidth,
                                child: sidebar,
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              main,
                              const SizedBox(height: _SvcUi.gap),
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

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _SvcGlass(
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w800,
              color: _SvcUi.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          _PrimaryButton(
            label: 'Try again',
            icon: Icons.refresh_rounded,
            onTap: onRetry,
          ),
        ],
      ),
    );
  }
}

class _ServicesShell extends StatelessWidget {
  const _ServicesShell({required this.child});

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
              colors: [_SvcUi.bgTop, _SvcUi.bgBottom],
            ),
          ),
        ),
        Positioned(
          top: -50,
          right: 60,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _SvcUi.purple.withValues(alpha: 0.2),
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
    required this.me,
    required this.linked,
    required this.filtered,
    required this.isSearching,
    required this.categoryName,
    required this.sortMode,
    required this.searchCtrl,
    required this.onSearchChanged,
    required this.onSort,
    required this.onOpenService,
    this.partialError,
  });

  final Zaposlenik me;
  final List<Usluga> linked;
  final List<Usluga> filtered;
  final bool isSearching;
  final String? categoryName;
  final String sortMode;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSort;
  final ValueChanged<int> onOpenService;
  final String? partialError;

  @override
  Widget build(BuildContext context) {
    final catLabel = categoryName?.trim().isNotEmpty == true
        ? categoryName!.trim()
        : 'Your specialty';
    final firstName = me.ime.trim().isNotEmpty ? me.ime.trim() : 'Therapist';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeroCard(
          firstName: firstName,
          categoryName: catLabel,
          status: me.status,
        ),
        if (partialError != null) ...[
          const SizedBox(height: 12),
          _PartialErrorBanner(message: partialError!),
        ],
        const SizedBox(height: 18),
        _LinkedServicesCard(
          totalCount: linked.length,
          services: filtered,
          isSearching: isSearching,
          hasConfiguredProfile: (me.kategorijaUslugaId ?? 0) > 0 &&
              specializationTagsFor(me).isNotEmpty,
          therapistActive: me.status == ZaposlenikStatus.active,
          sortMode: sortMode,
          searchCtrl: searchCtrl,
          onSearchChanged: onSearchChanged,
          onSort: onSort,
          onOpenService: onOpenService,
        ),
      ],
    );
  }
}

class _PartialErrorBanner extends StatelessWidget {
  const _PartialErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: _SvcUi.orange.withValues(alpha: 0.12),
        border: Border.all(color: _SvcUi.orange.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 18, color: _SvcUi.orange.withValues(alpha: 0.9)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _SvcUi.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.firstName,
    required this.categoryName,
    required this.status,
  });

  final String firstName;
  final String categoryName;
  final ZaposlenikStatus status;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(status);

    return _SvcGlass(
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                colors: [
                  _SvcUi.purple.withValues(alpha: 0.55),
                  _SvcUi.lavender.withValues(alpha: 0.35),
                ],
              ),
              border: Border.all(
                color: _SvcUi.lavender.withValues(alpha: 0.4),
              ),
            ),
            child: const Icon(Icons.spa_rounded, size: 22, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, $firstName',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _SvcUi.lavender.withValues(alpha: 0.9),
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  categoryName,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _SvcUi.textPrimary,
                    letterSpacing: -0.4,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: statusColor.withValues(alpha: 0.14),
                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkedServicesCard extends StatelessWidget {
  const _LinkedServicesCard({
    required this.totalCount,
    required this.services,
    required this.isSearching,
    required this.hasConfiguredProfile,
    required this.therapistActive,
    required this.sortMode,
    required this.searchCtrl,
    required this.onSearchChanged,
    required this.onSort,
    required this.onOpenService,
  });

  final int totalCount;
  final List<Usluga> services;
  final bool isSearching;
  final bool hasConfiguredProfile;
  final bool therapistActive;
  final String sortMode;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSort;
  final ValueChanged<int> onOpenService;

  @override
  Widget build(BuildContext context) {
    return _SvcGlass(
      radius: _SvcUi.cardRadius,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Your Services',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _SvcUi.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '($totalCount)',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _SvcUi.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, c) {
              final stack = c.maxWidth < 720;
              final search = SizedBox(
                width: stack ? double.infinity : 260,
                child: _SvcGlass(
                  radius: 14,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    height: 40,
                    child: TextField(
                      controller: searchCtrl,
                      onChanged: onSearchChanged,
                      style: GoogleFonts.inter(
                        color: _SvcUi.textPrimary,
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Filter services…',
                        hintStyle: GoogleFonts.inter(
                          color: _SvcUi.textSecondary,
                          fontSize: 13,
                        ),
                        border: InputBorder.none,
                        icon: Icon(
                          Icons.search_rounded,
                          size: 18,
                          color: _SvcUi.lavender.withValues(alpha: 0.7),
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
                  const SizedBox(width: 10),
                  sort,
                  const Spacer(),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          if (services.isEmpty)
            _ServicesEmptyState(
              isSearching: isSearching,
              hasConfiguredProfile: hasConfiguredProfile,
              totalCount: totalCount,
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: services.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _ServiceRow(
                service: services[i],
                showCertifiedBadge: therapistActive,
                onViewDetails: () => onOpenService(services[i].id),
              ),
            ),
        ],
      ),
    );
  }
}

class _ServicesEmptyState extends StatelessWidget {
  const _ServicesEmptyState({
    required this.isSearching,
    required this.hasConfiguredProfile,
    required this.totalCount,
  });

  final bool isSearching;
  final bool hasConfiguredProfile;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final String message;
    final String? subtitle;

    if (isSearching) {
      message = 'No services match your filter.';
      subtitle = null;
    } else if (totalCount == 0 && !hasConfiguredProfile) {
      message = 'No certified services yet.';
      subtitle =
          'Ask your spa administrator to set your category and specializations.';
    } else if (totalCount == 0) {
      message = 'No certified services yet.';
      subtitle =
          'Your specializations do not match any active services in your category.';
    } else {
      message = 'No services match your filter.';
      subtitle = null;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(
            Icons.spa_outlined,
            size: 40,
            color: _SvcUi.lavender.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: _SvcUi.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: _SvcUi.textSecondary.withValues(alpha: 0.85),
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SortDropdown extends StatelessWidget {
  const _SortDropdown({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  static const _options = [
    'A to Z',
    'Z to A',
    'Duration',
    'Price: High to Low',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168,
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
              dropdownColor: _SvcUi.bgBottom,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _SvcUi.textPrimary,
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

class _ServiceRow extends StatefulWidget {
  const _ServiceRow({
    required this.service,
    required this.showCertifiedBadge,
    required this.onViewDetails,
  });

  final Usluga service;
  final bool showCertifiedBadge;
  final VoidCallback onViewDetails;

  @override
  State<_ServiceRow> createState() => _ServiceRowState();
}

class _ServiceRowState extends State<_ServiceRow> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final u = widget.service;
    final category =
        u.kategorija.trim().isNotEmpty ? u.kategorija.trim() : 'General';

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: (_hover || _pressed)
                ? Colors.white.withValues(alpha: 0.055)
                : Colors.white.withValues(alpha: 0.025),
            border: Border.all(
              color: (_hover || _pressed)
                  ? _SvcUi.purple.withValues(alpha: 0.38)
                  : Colors.white.withValues(alpha: 0.08),
            ),
            boxShadow: (_hover || _pressed)
                ? [
                    BoxShadow(
                      color: _SvcUi.purple.withValues(alpha: 0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ServiceThumbnail(
                service: u,
                hovered: _hover || _pressed,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      u.naziv,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _SvcUi.textPrimary,
                        letterSpacing: -0.2,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      category,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _SvcUi.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_durationLabel(u)} · ${u.cijenaKm}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _SvcUi.lavender.withValues(alpha: 0.9),
                      ),
                    ),
                    if (widget.showCertifiedBadge) ...[
                      const SizedBox(height: 10),
                      _ServiceBadge(label: 'Certified', color: _SvcUi.green),
                    ],
                    const SizedBox(height: 12),
                    _ViewDetailsAction(
                      hovered: _hover || _pressed,
                      onTap: widget.onViewDetails,
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

class _ServiceBadge extends StatelessWidget {
  const _ServiceBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.14),
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

class _ServiceThumbnail extends StatelessWidget {
  const _ServiceThumbnail({required this.service, required this.hovered});

  final Usluga service;
  final bool hovered;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 84,
        height: 84,
        child: AnimatedScale(
          scale: hovered ? 1.06 : 1.0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
          child: ServiceNetworkImage(
            imageUrl: service.slikaUrl,
            fit: BoxFit.cover,
            error: Container(
              color: _SvcUi.purple.withValues(alpha: 0.2),
              child: const Icon(Icons.spa_outlined, color: _SvcUi.lavender),
            ),
          ),
        ),
      ),
    );
  }
}

class _ViewDetailsAction extends StatelessWidget {
  const _ViewDetailsAction({required this.hovered, required this.onTap});

  final bool hovered;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: hovered
                ? _SvcUi.lavender
                : _SvcUi.textSecondary.withValues(alpha: 0.95),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('View Details'),
              SizedBox(width: 4),
              Text('→'),
            ],
          ),
        ),
      ),
    );
  }
}

class _TherapistProfileCard extends StatelessWidget {
  const _TherapistProfileCard({
    required this.therapist,
    required this.categoryName,
    required this.certifiedServicesCount,
    required this.specializationsCount,
  });

  final Zaposlenik therapist;
  final String? categoryName;
  final int certifiedServicesCount;
  final int specializationsCount;

  @override
  Widget build(BuildContext context) {
    final catLabel = categoryName?.trim().isNotEmpty == true
        ? categoryName!.trim()
        : 'Not set';
    final initials = therapistInitials(therapist);
    final servicesLabel =
        '$certifiedServicesCount certified service${certifiedServicesCount == 1 ? '' : 's'}';
    final specsLabel = specializationsCount == 0
        ? 'None listed'
        : '$specializationsCount specialization${specializationsCount == 1 ? '' : 's'}';

    return _SvcGlass(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Therapist Profile',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _SvcUi.textPrimary,
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_SvcUi.purple, _SvcUi.lavender],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _SvcUi.purple.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Text(
                initials,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              therapist.fullName,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _SvcUi.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0x18FFFFFF), height: 1),
          const SizedBox(height: 14),
          _ProfileStatRow(
            icon: Icons.category_outlined,
            label: 'Category',
            value: catLabel,
          ),
          const SizedBox(height: 12),
          _ProfileStatRow(
            icon: Icons.verified_outlined,
            label: 'Certified Services',
            value: servicesLabel,
          ),
          const SizedBox(height: 12),
          _ProfileStatRow(
            icon: Icons.workspace_premium_outlined,
            label: 'Specializations',
            value: specsLabel,
          ),
        ],
      ),
    );
  }
}

class _ProfileStatRow extends StatelessWidget {
  const _ProfileStatRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: _SvcUi.lavender.withValues(alpha: 0.75)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _SvcUi.textSecondary,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _SvcUi.textPrimary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SvcGlass extends StatelessWidget {
  const _SvcGlass({
    required this.child,
    this.padding,
    this.radius = _SvcUi.cardRadius,
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
            color: _SvcUi.purple.withValues(alpha: 0.1),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _PrimaryButton extends StatefulWidget {
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
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
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  _SvcUi.purple.withValues(alpha: _hover ? 1 : 0.92),
                  _SvcUi.lavender.withValues(alpha: _hover ? 1 : 0.92),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: _SvcUi.purple.withValues(alpha: _hover ? 0.45 : 0.3),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
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
