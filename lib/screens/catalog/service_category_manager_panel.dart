import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/services/api_service.dart';
import '../../core/validation/nua_validators.dart';
import '../../models/kategorija_usluga.dart';

/// Luxury modal palette for service category management.
abstract final class _CategoryModalStyle {
  static const Color bgDeep = Color(0xFF0B0717);
  static const Color bgMid = Color(0xFF120A24);
  static const Color textPrimary = Color(0xFFF5F5F7);
  static const Color textMuted = Color(0xFFA7A1BC);
  static const Color accentPurple = Color(0xFF7B4DFF);
  static const Color accentGold = Color(0xFFD4AF7A);

  static const double modalWidth = 540;
  static const double modalRadius = 28;
  static const double rowHeight = 72;
  static const double rowRadius = 20;

  static TextStyle titleStyle(BuildContext context) =>
      GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: textPrimary,
        height: 1.2,
      );

  static TextStyle subtitleStyle(BuildContext context) =>
      GoogleFonts.inter(
        fontSize: 13.5,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: textMuted,
      );

  static TextStyle rowTitleStyle(BuildContext context) =>
      GoogleFonts.inter(
        fontSize: 15.5,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.15,
        color: textPrimary,
      );

  static List<BoxShadow> modalGlow = [
    BoxShadow(
      color: accentPurple.withValues(alpha: 0.28),
      blurRadius: 48,
      spreadRadius: 2,
      offset: const Offset(0, 20),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.55),
      blurRadius: 40,
      offset: const Offset(0, 24),
    ),
  ];
}

/// Category list + CRUD (Admin API), embedded in the luxury modal.
class ServiceCategoryManagerPanel extends StatefulWidget {
  const ServiceCategoryManagerPanel({super.key});

  @override
  State<ServiceCategoryManagerPanel> createState() =>
      _ServiceCategoryManagerPanelState();
}

class _ServiceCategoryManagerPanelState extends State<ServiceCategoryManagerPanel> {
  final ApiService _api = ApiService();
  final ScrollController _scrollController = ScrollController();
  Future<List<KategorijaUsluga>>? _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = _api.getKategorijeUsluga();
    });
  }

  Future<void> _editCategory(KategorijaUsluga? existing) async {
    final ctrl = TextEditingController(text: existing?.naziv ?? '');
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _CategoryModalStyle.bgMid,
        title: Text(
          existing == null ? 'New category' : 'Edit category',
          style: _CategoryModalStyle.titleStyle(ctx).copyWith(fontSize: 18),
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            autofocus: true,
            style: const TextStyle(color: _CategoryModalStyle.textPrimary),
            decoration: InputDecoration(
              labelText: 'Category name',
              labelStyle: const TextStyle(color: _CategoryModalStyle.textMuted),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: _CategoryModalStyle.accentPurple),
              ),
              errorStyle: const TextStyle(height: 1.2),
            ),
            validator: NuaValidators.categoryName,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    final naziv = ctrl.text.trim();
    ctrl.dispose();

    if (saved != true || !mounted) return;

    final ok = existing == null
        ? await _api.createKategorijaUsluga(naziv) != null
        : await _api.updateKategorijaUsluga(
                KategorijaUsluga(id: existing.id, naziv: naziv),
              ) !=
              null;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (existing == null
                  ? 'Category added successfully.'
                  : 'Category updated successfully.')
              : 'Could not save category.',
        ),
      ),
    );
    if (ok) _reload();
  }

  Future<void> _delete(KategorijaUsluga k) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _CategoryModalStyle.bgMid,
        title: Text(
          'Delete category',
          style: _CategoryModalStyle.titleStyle(ctx).copyWith(fontSize: 18),
        ),
        content: Text(
          'Delete "${k.naziv}"?',
          style: _CategoryModalStyle.subtitleStyle(ctx),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;

    final err = await _api.deleteKategorijaUsluga(k.id);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category deleted.')),
      );
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<KategorijaUsluga>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _CategoryModalStyle.accentPurple,
              ),
            ),
          );
        }

        final list = snap.data ?? [];

        if (list.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
              child: Text(
                'No categories yet. Tap + to add your first category.',
                textAlign: TextAlign.center,
                style: _CategoryModalStyle.subtitleStyle(context),
              ),
            ),
          );
        }

        return Scrollbar(
          controller: _scrollController,
          thumbVisibility: list.length > 4,
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.only(bottom: 8),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, i) {
              final k = list[i];
              return _LuxuryCategoryRow(
                name: k.naziv,
                onTap: () => _editCategory(k),
                onEdit: () => _editCategory(k),
                onDelete: () => _delete(k),
              );
            },
          ),
        );
      },
    );
  }
}

class _LuxuryCategoryRow extends StatefulWidget {
  const _LuxuryCategoryRow({
    required this.name,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final String name;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_LuxuryCategoryRow> createState() => _LuxuryCategoryRowState();
}

class _LuxuryCategoryRowState extends State<_LuxuryCategoryRow> {
  bool _hover = false;
  bool _menuHover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
        height: _CategoryModalStyle.rowHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_CategoryModalStyle.rowRadius),
          color: _hover
              ? const Color(0xFF1E1238).withValues(alpha: 0.92)
              : const Color(0xFF160E2C).withValues(alpha: 0.72),
          border: Border.all(
            color: Colors.white.withValues(alpha: _hover ? 0.14 : 0.08),
          ),
          boxShadow: _hover
              ? [
                  BoxShadow(
                    color: _CategoryModalStyle.accentPurple.withValues(alpha: 0.18),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(_CategoryModalStyle.rowRadius),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: _CategoryModalStyle.accentPurple.withValues(alpha: 0.14),
                      border: Border.all(
                        color: _CategoryModalStyle.accentPurple.withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Icon(
                      Icons.folder_outlined,
                      color: _CategoryModalStyle.accentPurple,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _CategoryModalStyle.rowTitleStyle(context),
                    ),
                  ),
                  MouseRegion(
                    onEnter: (_) => setState(() => _menuHover = true),
                    onExit: (_) => setState(() => _menuHover = false),
                    child: PopupMenuButton<String>(
                      tooltip: 'Category actions',
                      padding: EdgeInsets.zero,
                      offset: const Offset(0, 8),
                      color: _CategoryModalStyle.bgMid,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      onSelected: (v) {
                        if (v == 'edit') widget.onEdit();
                        if (v == 'delete') widget.onDelete();
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Text(
                            'Edit',
                            style: _CategoryModalStyle.rowTitleStyle(context)
                                .copyWith(fontSize: 14),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(
                            'Delete',
                            style: _CategoryModalStyle.rowTitleStyle(context)
                                .copyWith(fontSize: 14, color: const Color(0xFFFFAB91)),
                          ),
                        ),
                      ],
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _menuHover
                              ? _CategoryModalStyle.accentPurple.withValues(alpha: 0.22)
                              : Colors.transparent,
                          boxShadow: _menuHover
                              ? [
                                  BoxShadow(
                                    color: _CategoryModalStyle.accentPurple
                                        .withValues(alpha: 0.35),
                                    blurRadius: 16,
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(
                          Icons.more_horiz_rounded,
                          color: _menuHover
                              ? _CategoryModalStyle.textPrimary
                              : _CategoryModalStyle.textMuted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LuxuryAddCategoryFab extends StatefulWidget {
  const _LuxuryAddCategoryFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_LuxuryAddCategoryFab> createState() => _LuxuryAddCategoryFabState();
}

class _LuxuryAddCategoryFabState extends State<_LuxuryAddCategoryFab> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: _hover ? 1.06 : 1,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: GestureDetector(
          onTap: widget.onPressed,
          child: ClipOval(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _CategoryModalStyle.accentPurple,
                    Color(0xFF9B6BFF),
                    _CategoryModalStyle.accentGold,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _CategoryModalStyle.accentPurple
                        .withValues(alpha: _hover ? 0.55 : 0.4),
                    blurRadius: _hover ? 28 : 20,
                    spreadRadius: _hover ? 2 : 0,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: _CategoryModalStyle.accentGold.withValues(alpha: 0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
            ),
          ),
        ),
      ),
    );
  }
}

class _LuxuryCategoryModalShell extends StatefulWidget {
  const _LuxuryCategoryModalShell();

  @override
  State<_LuxuryCategoryModalShell> createState() =>
      _LuxuryCategoryModalShellState();
}

class _LuxuryCategoryModalShellState extends State<_LuxuryCategoryModalShell> {
  final _panelKey = GlobalKey<_ServiceCategoryManagerPanelState>();

  @override
  Widget build(BuildContext context) {
    final modalHeight = (MediaQuery.sizeOf(context).height * 0.82)
        .clamp(320.0, 620.0)
        .toDouble();

    return ClipRRect(
      borderRadius: BorderRadius.circular(_CategoryModalStyle.modalRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: SizedBox(
          width: _CategoryModalStyle.modalWidth,
          height: modalHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(_CategoryModalStyle.modalRadius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _CategoryModalStyle.bgMid.withValues(alpha: 0.88),
                  _CategoryModalStyle.bgDeep.withValues(alpha: 0.92),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
              boxShadow: _CategoryModalStyle.modalGlow,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _LuxuryCategoryModalHeader(
                      onClose: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 88),
                        child: ServiceCategoryManagerPanel(key: _panelKey),
                      ),
                    ),
                  ],
                ),
                Positioned(
                  right: 24,
                  bottom: 24,
                  child: _LuxuryAddCategoryFab(
                    onPressed: () =>
                        _panelKey.currentState?._editCategory(null),
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

class _LuxuryCategoryModalHeader extends StatefulWidget {
  const _LuxuryCategoryModalHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  State<_LuxuryCategoryModalHeader> createState() =>
      _LuxuryCategoryModalHeaderState();
}

class _LuxuryCategoryModalHeaderState extends State<_LuxuryCategoryModalHeader> {
  bool _closeHover = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: _CategoryModalStyle.accentPurple.withValues(alpha: 0.12),
              border: Border.all(
                color: _CategoryModalStyle.accentPurple.withValues(alpha: 0.45),
              ),
            ),
            child: const Icon(
              Icons.category_outlined,
              color: _CategoryModalStyle.accentPurple,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Service Categories', style: _CategoryModalStyle.titleStyle(context)),
                const SizedBox(height: 6),
                Text(
                  'Categories help organize services in the catalog and make them easier to find.',
                  style: _CategoryModalStyle.subtitleStyle(context),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          MouseRegion(
            onEnter: (_) => setState(() => _closeHover = true),
            onExit: (_) => setState(() => _closeHover = false),
            child: IconButton(
              tooltip: 'Close',
              onPressed: widget.onClose,
              style: IconButton.styleFrom(
                backgroundColor: _closeHover
                    ? _CategoryModalStyle.accentPurple.withValues(alpha: 0.2)
                    : Colors.transparent,
                foregroundColor: _closeHover
                    ? _CategoryModalStyle.textPrimary
                    : _CategoryModalStyle.textMuted,
              ),
              icon: const Icon(Icons.close_rounded, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}

/// Centered luxury modal for managing service categories (desktop catalog).
Future<void> showServiceCategoryManagerDialog(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close service categories',
    barrierColor: Colors.black.withValues(alpha: 0.52),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (ctx, animation, secondaryAnimation) {
      return Material(
        type: MaterialType.transparency,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: () => Navigator.of(ctx).pop(),
              behavior: HitTestBehavior.opaque,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  color: _CategoryModalStyle.bgDeep.withValues(alpha: 0.35),
                ),
              ),
            ),
            Center(
              child: _LuxuryCategoryModalShell(),
            ),
          ],
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}
