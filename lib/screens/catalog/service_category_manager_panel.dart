import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/services/api_service.dart';
import '../../core/catalog/catalog_admin_messages.dart';
import '../../models/kategorija_usluga.dart';
import '../../ui/theme/luxury_modal_style.dart';
import '../../widgets/forms/luxury_modal_text_field.dart';

/// Category list + CRUD (Admin API), embedded in the luxury modal or admin tab.
class ServiceCategoryManagerPanel extends StatefulWidget {
  const ServiceCategoryManagerPanel({
    super.key,
    this.showInlineHeader = false,
  });

  /// When true, shows a compact header with an add action (admin dashboard tab).
  final bool showInlineHeader;

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

  void openCreateCategory() => _editCategory(null);

  Future<void> _editCategory(KategorijaUsluga? existing) async {
    final naziv = await showGeneralDialog<String?>(
      context: context,
      barrierDismissible: true,
      barrierLabel: existing == null ? 'Close add category' : 'Close edit category',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 240),
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
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    color: LuxuryModalStyle.bgDeep.withValues(alpha: 0.72),
                  ),
                ),
              ),
              Center(
                child: _LuxuryCategoryEditorDialog(
                  existing: existing,
                ),
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
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );

    if (naziv == null || !mounted) return;

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
    final yes = await _showLuxuryConfirmDialog(
      context: context,
      title: 'Delete category',
      message:
          'Delete "${k.naziv}"? Services in this category must be moved or removed first.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (yes != true || !mounted) return;

    final err = await _api.deleteKategorijaUsluga(k.id);
    if (!mounted) return;
    if (err != null) {
      await _showLuxuryConfirmDialog(
        context: context,
        title: 'Couldn\'t delete category',
        message: CatalogAdminMessages.categoryDeleteError(err),
        confirmLabel: 'OK',
        destructive: false,
        showCancel: false,
      );
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
                color: LuxuryModalStyle.accentPurple,
              ),
            ),
          );
        }

        final list = snap.data ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.showInlineHeader) ...[
              _InlineCategoryHeader(
                count: list.length,
                onAdd: openCreateCategory,
              ),
              const SizedBox(height: 16),
            ],
            Expanded(
              child: list.isEmpty
                  ? const _CategoryEmptyState(onAdd: null)
                  : Scrollbar(
                      controller: _scrollController,
                      thumbVisibility: list.length > 5,
                      child: ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(bottom: 4),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
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
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _InlineCategoryHeader extends StatelessWidget {
  const _InlineCategoryHeader({
    required this.count,
    required this.onAdd,
  });

  final int count;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            count == 1 ? '1 category' : '$count categories',
            style: LuxuryModalStyle.subtitleStyle(context),
          ),
        ),
        _LuxuryTextButton(
          label: 'Add category',
          icon: Icons.add_rounded,
          onPressed: onAdd,
        ),
      ],
    );
  }
}

class _CategoryEmptyState extends StatelessWidget {
  const _CategoryEmptyState({required this.onAdd});

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.category_outlined,
              size: 40,
              color: LuxuryModalStyle.accentPurple.withValues(alpha: 0.55),
            ),
            const SizedBox(height: 14),
            Text(
              'No categories yet',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: LuxuryModalStyle.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a category to organize services in the catalog and filters.',
              textAlign: TextAlign.center,
              style: LuxuryModalStyle.subtitleStyle(context),
            ),
            if (onAdd != null) ...[
              const SizedBox(height: 18),
              _LuxuryPrimaryButton(label: 'Add category', onPressed: onAdd!),
            ],
          ],
        ),
      ),
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

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _hover
                ? LuxuryModalStyle.accentPurple.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.08),
          ),
          boxShadow: [
            if (_hover)
              BoxShadow(
                color: LuxuryModalStyle.accentPurple.withValues(alpha: 0.14),
                blurRadius: 18,
                offset: const Offset(0, 8),
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Material(
            color: Colors.white.withValues(alpha: 0.04),
            child: InkWell(
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: LuxuryModalStyle.textPrimary,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _CategoryRowMenu(
                      visible: _hover,
                      onEdit: widget.onEdit,
                      onDelete: widget.onDelete,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryRowMenu extends StatefulWidget {
  const _CategoryRowMenu({
    required this.visible,
    required this.onEdit,
    required this.onDelete,
  });

  final bool visible;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_CategoryRowMenu> createState() => _CategoryRowMenuState();
}

class _CategoryRowMenuState extends State<_CategoryRowMenu> {
  bool _menuHover = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: widget.visible ? 1 : 0,
      duration: const Duration(milliseconds: 150),
      child: IgnorePointer(
        ignoring: !widget.visible,
        child: MouseRegion(
          onEnter: (_) => setState(() => _menuHover = true),
          onExit: (_) => setState(() => _menuHover = false),
          child: PopupMenuButton<String>(
            tooltip: 'Category actions',
            padding: EdgeInsets.zero,
            offset: const Offset(0, 8),
            color: LuxuryModalStyle.bgMid.withValues(alpha: 0.98),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
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
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: LuxuryModalStyle.textPrimary,
                  ),
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  'Delete',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFFFF8A80),
                  ),
                ),
              ),
            ],
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _menuHover
                    ? LuxuryModalStyle.accentPurple.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.04),
              ),
              child: Icon(
                Icons.more_horiz_rounded,
                size: 20,
                color: _menuHover
                    ? LuxuryModalStyle.textPrimary
                    : LuxuryModalStyle.textMuted,
              ),
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
  bool _closeHover = false;

  @override
  Widget build(BuildContext context) {
    final modalHeight = (MediaQuery.sizeOf(context).height * 0.82)
        .clamp(380.0, 640.0)
        .toDouble();

    return ClipRRect(
      borderRadius: BorderRadius.circular(LuxuryModalStyle.modalRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: SizedBox(
          width: 520,
          height: modalHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(LuxuryModalStyle.modalRadius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  LuxuryModalStyle.bgMid.withValues(alpha: 0.9),
                  LuxuryModalStyle.bgDeep.withValues(alpha: 0.94),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
              boxShadow: LuxuryModalStyle.modalGlow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 26, 20, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Service categories',
                              style: LuxuryModalStyle.titleStyle(context),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Group treatments for catalog filters and reporting. Changes apply across the admin catalog.',
                              style: LuxuryModalStyle.subtitleStyle(context),
                            ),
                          ],
                        ),
                      ),
                      MouseRegion(
                        onEnter: (_) => setState(() => _closeHover = true),
                        onExit: (_) => setState(() => _closeHover = false),
                        child: IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(context).pop(),
                          style: IconButton.styleFrom(
                            backgroundColor: _closeHover
                                ? LuxuryModalStyle.accentPurple
                                    .withValues(alpha: 0.22)
                                : Colors.transparent,
                            foregroundColor: _closeHover
                                ? LuxuryModalStyle.textPrimary
                                : LuxuryModalStyle.textMuted,
                          ),
                          icon: const Icon(Icons.close_rounded, size: 22),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 4, 28, 12),
                    child: ServiceCategoryManagerPanel(key: _panelKey),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 12, 28, 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _LuxurySecondaryButton(
                        label: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 12),
                      _LuxuryPrimaryButton(
                        label: 'Add category',
                        onPressed: () =>
                            _panelKey.currentState?.openCreateCategory(),
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

class _LuxuryCategoryEditorDialog extends StatefulWidget {
  const _LuxuryCategoryEditorDialog({required this.existing});

  final KategorijaUsluga? existing;

  @override
  State<_LuxuryCategoryEditorDialog> createState() =>
      _LuxuryCategoryEditorDialogState();
}

class _LuxuryCategoryEditorDialogState extends State<_LuxuryCategoryEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _ctrl;
  bool _attemptedSubmit = false;
  bool _closeHover = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.existing?.naziv ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() => _attemptedSubmit = true);
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_ctrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(LuxuryModalStyle.modalRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: SizedBox(
          width: 440,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(LuxuryModalStyle.modalRadius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  LuxuryModalStyle.bgMid.withValues(alpha: 0.94),
                  LuxuryModalStyle.bgDeep.withValues(alpha: 0.96),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
              boxShadow: LuxuryModalStyle.modalGlow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 26, 20, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isNew ? 'Add category' : 'Edit category',
                              style: LuxuryModalStyle.titleStyle(context,
                                  size: 22),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isNew
                                  ? 'Create a catalog group for related treatments.'
                                  : 'Rename this category across the catalog.',
                              style: LuxuryModalStyle.subtitleStyle(context),
                            ),
                          ],
                        ),
                      ),
                      MouseRegion(
                        onEnter: (_) => setState(() => _closeHover = true),
                        onExit: (_) => setState(() => _closeHover = false),
                        child: IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(context).pop(),
                          style: IconButton.styleFrom(
                            backgroundColor: _closeHover
                                ? LuxuryModalStyle.accentPurple
                                    .withValues(alpha: 0.22)
                                : Colors.transparent,
                            foregroundColor: _closeHover
                                ? LuxuryModalStyle.textPrimary
                                : LuxuryModalStyle.textMuted,
                          ),
                          icon: const Icon(Icons.close_rounded, size: 22),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: _attemptedSubmit
                        ? AutovalidateMode.onUserInteraction
                        : AutovalidateMode.disabled,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Category name',
                          style: LuxuryModalStyle.labelStyle(context),
                        ),
                        const SizedBox(height: 8),
                        LuxuryModalTextField(
                          controller: _ctrl,
                          hint: 'e.g. Massage',
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Category name is required.';
                            }
                            if (value.trim().length > 100) {
                              return 'Category name must be 100 characters or fewer.';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _LuxurySecondaryButton(
                        label: 'Cancel',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 12),
                      _LuxuryPrimaryButton(
                        label: isNew ? 'Add category' : 'Save changes',
                        onPressed: _submit,
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

Future<bool?> _showLuxuryConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  required bool destructive,
  bool showCancel = true,
}) {
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close dialog',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, animation, secondaryAnimation) {
      return Material(
        type: MaterialType.transparency,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: () => Navigator.of(ctx).pop(showCancel ? false : null),
              behavior: HitTestBehavior.opaque,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  color: LuxuryModalStyle.bgDeep.withValues(alpha: 0.72),
                ),
              ),
            ),
            Center(
              child: ClipRRect(
                borderRadius:
                    BorderRadius.circular(LuxuryModalStyle.modalRadius),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: SizedBox(
                    width: 420,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          LuxuryModalStyle.modalRadius,
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            LuxuryModalStyle.bgMid.withValues(alpha: 0.94),
                            LuxuryModalStyle.bgDeep.withValues(alpha: 0.96),
                          ],
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                        boxShadow: LuxuryModalStyle.modalGlow,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(28, 26, 28, 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              title,
                              style: LuxuryModalStyle.titleStyle(ctx, size: 22),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              message,
                              style: LuxuryModalStyle.subtitleStyle(ctx),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (showCancel) ...[
                                  _LuxurySecondaryButton(
                                    label: 'Cancel',
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(false),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                destructive
                                    ? _LuxuryDestructiveButton(
                                        label: confirmLabel,
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(true),
                                      )
                                    : _LuxuryPrimaryButton(
                                        label: confirmLabel,
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(true),
                                      ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
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
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _LuxuryTextButton extends StatefulWidget {
  const _LuxuryTextButton({
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  State<_LuxuryTextButton> createState() => _LuxuryTextButtonState();
}

class _LuxuryTextButtonState extends State<_LuxuryTextButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: _hover
                ? LuxuryModalStyle.accentPurple.withValues(alpha: 0.14)
                : Colors.transparent,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: 18,
                  color: LuxuryModalStyle.accentPurple,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: LuxuryModalStyle.accentPurple,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LuxurySecondaryButton extends StatefulWidget {
  const _LuxurySecondaryButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  State<_LuxurySecondaryButton> createState() => _LuxurySecondaryButtonState();
}

class _LuxurySecondaryButtonState extends State<_LuxurySecondaryButton> {
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
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: _hover
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.03),
            border: Border.all(
              color: Colors.white.withValues(alpha: _hover ? 0.16 : 0.1),
            ),
          ),
          child: Text(
            widget.label,
            style: GoogleFonts.inter(
              color: LuxuryModalStyle.textPrimary,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _LuxuryPrimaryButton extends StatefulWidget {
  const _LuxuryPrimaryButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  State<_LuxuryPrimaryButton> createState() => _LuxuryPrimaryButtonState();
}

class _LuxuryPrimaryButtonState extends State<_LuxuryPrimaryButton> {
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _hover
                  ? [
                      const Color(0xFF8F5FFF),
                      LuxuryModalStyle.accentLavender,
                    ]
                  : [
                      LuxuryModalStyle.accentPurple,
                      const Color(0xFF9B7BFF),
                      LuxuryModalStyle.accentLavender.withValues(alpha: 0.85),
                    ],
            ),
            boxShadow: [
              BoxShadow(
                color: LuxuryModalStyle.accentPurple
                    .withValues(alpha: _hover ? 0.45 : 0.32),
                blurRadius: _hover ? 22 : 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Text(
            widget.label,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _LuxuryDestructiveButton extends StatefulWidget {
  const _LuxuryDestructiveButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  State<_LuxuryDestructiveButton> createState() =>
      _LuxuryDestructiveButtonState();
}

class _LuxuryDestructiveButtonState extends State<_LuxuryDestructiveButton> {
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: _hover
                ? const Color(0xFFFF6B6B).withValues(alpha: 0.22)
                : const Color(0xFFFF6B6B).withValues(alpha: 0.14),
            border: Border.all(
              color: const Color(0xFFFF8A80)
                  .withValues(alpha: _hover ? 0.65 : 0.4),
            ),
          ),
          child: Text(
            widget.label,
            style: GoogleFonts.inter(
              color: const Color(0xFFFFB4AB),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
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
    barrierColor: Colors.black.withValues(alpha: 0.55),
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
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  color: LuxuryModalStyle.bgDeep.withValues(alpha: 0.72),
                ),
              ),
            ),
            const Center(
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
