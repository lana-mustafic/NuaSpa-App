import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/api/services/api_service.dart';
import '../../../models/kategorija_usluga.dart';
import '../../../models/usluga.dart';
import '../../../models/zaposlenik.dart';
import '../../../ui/theme/luxury_modal_style.dart';

/// Add / edit therapist — shared by roster and profile screens.
Future<Zaposlenik?> showAdminTherapistEditorDialog(
  BuildContext context, {
  Zaposlenik? existing,
}) {
  return showGeneralDialog<Zaposlenik>(
    context: context,
    barrierDismissible: true,
    barrierLabel: existing == null ? 'Close add therapist' : 'Close edit therapist',
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
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(color: Colors.transparent),
              ),
            ),
            Center(
              child: AdminTherapistEditorDialog(existing: existing),
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

class AdminTherapistEditorDialog extends StatefulWidget {
  const AdminTherapistEditorDialog({super.key, this.existing});

  final Zaposlenik? existing;

  bool get isNew => existing == null;

  @override
  State<AdminTherapistEditorDialog> createState() =>
      _AdminTherapistEditorDialogState();
}

class _AdminTherapistEditorDialogState extends State<AdminTherapistEditorDialog> {
  static const Color _modalGlass = Color(0xEB120A24);

  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _scrollCtrl = ScrollController();

  late final TextEditingController _ime = TextEditingController(
    text: widget.existing?.ime ?? '',
  );
  late final TextEditingController _prezime = TextEditingController(
    text: widget.existing?.prezime ?? '',
  );
  late final TextEditingController _telefon = TextEditingController(
    text: widget.existing?.telefon ?? '',
  );

  bool _loading = true;
  String? _loadError;
  bool _closeHover = false;
  List<KategorijaUsluga> _categories = [];
  List<Usluga> _services = [];

  int? _categoryId;
  final Set<int> _selectedServiceIds = {};
  String? _specializationError;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final results = await Future.wait([
        _api.getKategorijeUsluga(),
        _api.getUsluge(),
      ]);
      if (!mounted) return;

      final categories = results[0] as List<KategorijaUsluga>;
      final services = results[1] as List<Usluga>;
      final existingTags = _parseTags(widget.existing?.specijalizacija ?? '');

      int? categoryId = widget.existing?.kategorijaUslugaId;
      if (categoryId == null || categoryId <= 0) {
        categoryId = _inferCategoryId(services, existingTags);
      }
      if (categoryId == null && categories.isNotEmpty) {
        categoryId = categories.first.id;
      }

      final selectedIds = <int>{};
      if (categoryId != null) {
        for (final service in services.where(
          (u) => u.kategorijaUslugaId == categoryId,
        )) {
          final matchesTag = existingTags.any(
            (t) => t.toLowerCase() == service.naziv.trim().toLowerCase(),
          );
          if (matchesTag) selectedIds.add(service.id);
        }
      }

      setState(() {
        _categories = categories;
        _services = services;
        _categoryId = categoryId;
        _selectedServiceIds
          ..clear()
          ..addAll(selectedIds);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Failed to load categories and services.';
        _loading = false;
      });
    }
  }

  List<String> _parseTags(String raw) => raw
      .split(RegExp(r'[,;/]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  int? _inferCategoryId(List<Usluga> services, List<String> tags) {
    if (tags.isEmpty) return null;
    final counts = <int, int>{};
    for (final service in services) {
      final hit = tags.any(
        (t) => t.toLowerCase() == service.naziv.trim().toLowerCase(),
      );
      if (hit) {
        counts[service.kategorijaUslugaId] =
            (counts[service.kategorijaUslugaId] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return null;
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  List<Usluga> get _servicesInCategory {
    final catId = _categoryId;
    if (catId == null) return const [];
    final list =
        _services.where((u) => u.kategorijaUslugaId == catId).toList();
    list.sort((a, b) => a.naziv.compareTo(b.naziv));
    return list;
  }

  String get _categoryLabel {
    if (_categoryId == null || _categories.isEmpty) {
      return 'Select specialties';
    }
    for (final k in _categories) {
      if (k.id == _categoryId) return k.naziv;
    }
    return 'Select specialties';
  }

  String get _specialtiesSummary {
    if (_selectedServiceIds.isEmpty) return 'Select specialties';
    final names = _servicesInCategory
        .where((u) => _selectedServiceIds.contains(u.id))
        .map((u) => u.naziv)
        .toList();
    if (names.isEmpty) return _categoryLabel;
    if (names.length <= 2) return names.join(', ');
    return '${names.take(2).join(', ')} +${names.length - 2}';
  }

  void _onCategoryChanged(int id) {
    setState(() {
      _categoryId = id;
      _selectedServiceIds.clear();
      _specializationError = null;
    });
  }

  void _toggleService(int serviceId) {
    setState(() {
      if (_selectedServiceIds.contains(serviceId)) {
        _selectedServiceIds.remove(serviceId);
      } else {
        _selectedServiceIds.add(serviceId);
      }
      _specializationError = null;
    });
  }

  String _buildSpecijalizacija() {
    final names = _servicesInCategory
        .where((u) => _selectedServiceIds.contains(u.id))
        .map((u) => u.naziv.trim())
        .where((n) => n.isNotEmpty)
        .toList();
    return names.join(', ');
  }

  void _close() => Navigator.of(context).pop();

  void _save() {
    if (_loading || _loadError != null) return;
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) return;
    if (_selectedServiceIds.isEmpty) {
      setState(() {
        _specializationError = 'Select at least one specialty.';
      });
      return;
    }

    Navigator.pop(
      context,
      Zaposlenik(
        id: widget.existing?.id ?? 0,
        ime: _ime.text.trim(),
        prezime: _prezime.text.trim(),
        specijalizacija: _buildSpecijalizacija(),
        telefon: _telefon.text.trim().isEmpty ? null : _telefon.text.trim(),
        kategorijaUslugaId: _categoryId,
      ),
    );
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _ime.dispose();
    _prezime.dispose();
    _telefon.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.88;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 540, maxHeight: maxH),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _modalGlass,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                  color: LuxuryModalStyle.accentPurple.withValues(alpha: 0.25),
                  blurRadius: 80,
                  offset: const Offset(0, 24),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                Flexible(
                  child: _loading
                      ? const Padding(
                          padding: EdgeInsets.all(48),
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: LuxuryModalStyle.accentPurple,
                            ),
                          ),
                        )
                      : _loadError != null
                          ? Padding(
                              padding: const EdgeInsets.all(28),
                              child: Text(
                                _loadError!,
                                style: LuxuryModalStyle.subtitleStyle(context),
                              ),
                            )
                          : Form(
                              key: _formKey,
                              child: Scrollbar(
                                controller: _scrollCtrl,
                                thumbVisibility: true,
                                child: SingleChildScrollView(
                                  controller: _scrollCtrl,
                                  primary: false,
                                  padding: const EdgeInsets.fromLTRB(
                                    28,
                                    4,
                                    28,
                                    8,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _LuxuryTherapistField(
                                        label: 'Name',
                                        icon: Icons.person_outline_rounded,
                                        child: _LuxuryTextInput(
                                          controller: _ime,
                                          hint: 'Enter therapist name',
                                          validator: (v) =>
                                              v == null || v.trim().isEmpty
                                                  ? 'Name is required.'
                                                  : null,
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      _LuxuryTherapistField(
                                        label: 'Surname',
                                        icon: Icons.person_outline_rounded,
                                        child: _LuxuryTextInput(
                                          controller: _prezime,
                                          hint: 'Enter therapist surname',
                                          validator: (v) =>
                                              v == null || v.trim().isEmpty
                                                  ? 'Surname is required.'
                                                  : null,
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      _LuxuryTherapistField(
                                        label: 'Specialties',
                                        icon: Icons.star_outline_rounded,
                                        helper:
                                            'You can select multiple specialties, e.g., Swedish, Facial',
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            if (_categories.isEmpty)
                                              Text(
                                                'No categories yet. Add service categories first.',
                                                style: LuxuryModalStyle
                                                    .subtitleStyle(context),
                                              )
                                            else if (_categoryId != null) ...[
                                              _TherapistCategoryDropdown(
                                                label: _categoryLabel,
                                                categories: _categories,
                                                selectedId: _categoryId!,
                                                onSelected: _onCategoryChanged,
                                              ),
                                              const SizedBox(height: 12),
                                              if (_servicesInCategory.isEmpty)
                                                Text(
                                                  'No services in this category yet.',
                                                  style: LuxuryModalStyle
                                                      .subtitleStyle(context)
                                                      .copyWith(fontSize: 12.5),
                                                )
                                              else
                                                Container(
                                                  constraints:
                                                      const BoxConstraints(
                                                    maxHeight: 160,
                                                  ),
                                                  padding:
                                                      const EdgeInsets.all(12),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white
                                                        .withValues(alpha: 0.04),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      16,
                                                    ),
                                                    border: Border.all(
                                                      color: Colors.white
                                                          .withValues(
                                                        alpha: 0.08,
                                                      ),
                                                    ),
                                                  ),
                                                  child: SingleChildScrollView(
                                                    child: Wrap(
                                                      spacing: 8,
                                                      runSpacing: 8,
                                                      children: [
                                                        for (final service
                                                            in _servicesInCategory)
                                                          _SpecialtyChip(
                                                            label:
                                                                service.naziv,
                                                            selected:
                                                                _selectedServiceIds
                                                                    .contains(
                                                              service.id,
                                                            ),
                                                            onTap: () =>
                                                                _toggleService(
                                                              service.id,
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              if (_selectedServiceIds
                                                  .isNotEmpty) ...[
                                                const SizedBox(height: 8),
                                                Text(
                                                  _specialtiesSummary,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 12,
                                                    color: LuxuryModalStyle
                                                        .accentLavender,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ],
                                            if (_specializationError != null)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 8,
                                                ),
                                                child: Text(
                                                  _specializationError!,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 12,
                                                    color: const Color(
                                                      0xFFFF6B8A,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      _LuxuryTherapistField(
                                        label: 'Phone (optional)',
                                        icon: Icons.phone_outlined,
                                        child: _LuxuryTextInput(
                                          controller: _telefon,
                                          hint: 'Enter phone number',
                                          keyboardType: TextInputType.phone,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                ),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isNew = widget.isNew;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF7B4DFF),
                  Color(0xFF9B7BFF),
                  Color(0xFFC8B6E8),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: LuxuryModalStyle.accentPurple.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.spa_outlined,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isNew ? 'Add therapist' : 'Edit therapist',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.35,
                    color: const Color(0xFFF5F3FA),
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isNew
                      ? 'Add a new therapist to your team.'
                      : 'Update therapist profile and specialties.',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    height: 1.45,
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
          MouseRegion(
            onEnter: (_) => setState(() => _closeHover = true),
            onExit: (_) => setState(() => _closeHover = false),
            child: GestureDetector(
              onTap: _close,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: _closeHover
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.white.withValues(alpha: 0.05),
                  border: Border.all(
                    color: Colors.white.withValues(
                      alpha: _closeHover ? 0.14 : 0.08,
                    ),
                  ),
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(
          height: 1,
          thickness: 1,
          color: Colors.white.withValues(alpha: 0.08),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 28),
          child: Row(
            children: [
              Expanded(
                child: _TherapistCancelButton(onPressed: _close),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TherapistSaveButton(
                  enabled: !_loading && _loadError == null,
                  onPressed: _save,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LuxuryTherapistField extends StatelessWidget {
  const _LuxuryTherapistField({
    required this.label,
    required this.icon,
    required this.child,
    this.helper,
  });

  final String label;
  final IconData icon;
  final Widget child;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: LuxuryModalStyle.textMuted),
            const SizedBox(width: 8),
            Text(label, style: LuxuryModalStyle.labelStyle(context)),
          ],
        ),
        const SizedBox(height: 8),
        child,
        if (helper != null) ...[
          const SizedBox(height: 6),
          Text(
            helper!,
            style: LuxuryModalStyle.subtitleStyle(context).copyWith(
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

class _LuxuryTextInput extends StatefulWidget {
  const _LuxuryTextInput({
    required this.controller,
    required this.hint,
    this.validator,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;

  @override
  State<_LuxuryTextInput> createState() => _LuxuryTextInputState();
}

class _LuxuryTextInputState extends State<_LuxuryTextInput> {
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      validator: widget.validator,
      style: GoogleFonts.inter(
        fontSize: 15,
        color: const Color(0xFFF5F3FA),
      ),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: GoogleFonts.inter(
          fontSize: 15,
          color: Colors.white.withValues(alpha: 0.45),
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        constraints: const BoxConstraints(minHeight: 54),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: LuxuryModalStyle.accentPurple.withValues(alpha: 0.65),
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFFF6B8A)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFFF6B8A)),
        ),
      ).copyWith(
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: LuxuryModalStyle.accentPurple.withValues(alpha: 0.65),
          ),
        ),
      ),
    );
  }
}

class _TherapistCategoryDropdown extends StatefulWidget {
  const _TherapistCategoryDropdown({
    required this.label,
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  final String label;
  final List<KategorijaUsluga> categories;
  final int selectedId;
  final ValueChanged<int> onSelected;

  @override
  State<_TherapistCategoryDropdown> createState() =>
      _TherapistCategoryDropdownState();
}

class _TherapistCategoryDropdownState extends State<_TherapistCategoryDropdown> {
  bool _hover = false;
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      onOpen: () => setState(() => _open = true),
      onClose: () => setState(() => _open = false),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(
          LuxuryModalStyle.bgMid.withValues(alpha: 0.98),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
        ),
      ),
      builder: (context, controller, child) {
        return MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            onTap: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _open || _hover
                      ? LuxuryModalStyle.accentPurple.withValues(alpha: 0.65)
                      : Colors.white.withValues(alpha: 0.08),
                ),
                boxShadow: _open
                    ? [
                        BoxShadow(
                          color: LuxuryModalStyle.accentPurple
                              .withValues(alpha: 0.1),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.label,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: widget.label == 'Select specialties'
                            ? Colors.white.withValues(alpha: 0.45)
                            : const Color(0xFFF5F3FA),
                      ),
                    ),
                  ),
                  Icon(
                    _open
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      menuChildren: widget.categories
          .map(
            (k) => MenuItemButton(
              onPressed: () => widget.onSelected(k.id),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (k.id == widget.selectedId) {
                    return LuxuryModalStyle.accentPurple.withValues(alpha: 0.12);
                  }
                  return Colors.transparent;
                }),
              ),
              child: SizedBox(
                width: 420,
                child: Text(
                  k.naziv,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFF5F3FA),
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _SpecialtyChip extends StatefulWidget {
  const _SpecialtyChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_SpecialtyChip> createState() => _SpecialtyChipState();
}

class _SpecialtyChipState extends State<_SpecialtyChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: widget.selected
                ? LuxuryModalStyle.accentPurple.withValues(alpha: 0.28)
                : Colors.white.withValues(alpha: _hover ? 0.08 : 0.04),
            border: Border.all(
              color: widget.selected
                  ? LuxuryModalStyle.accentPurple.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.1),
            ),
            boxShadow: widget.selected
                ? [
                    BoxShadow(
                      color: LuxuryModalStyle.accentPurple
                          .withValues(alpha: 0.2),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: Text(
            widget.label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: widget.selected
                  ? const Color(0xFFF5F3FA)
                  : Colors.white.withValues(alpha: 0.78),
            ),
          ),
        ),
      ),
    );
  }
}

class _TherapistCancelButton extends StatefulWidget {
  const _TherapistCancelButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_TherapistCancelButton> createState() => _TherapistCancelButtonState();
}

class _TherapistCancelButtonState extends State<_TherapistCancelButton> {
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
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: _hover
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.transparent,
            border: Border.all(
              color: Colors.white.withValues(alpha: _hover ? 0.14 : 0.1),
            ),
          ),
          child: Text(
            'Cancel',
            style: GoogleFonts.inter(
              color: const Color(0xFFF5F3FA),
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _TherapistSaveButton extends StatefulWidget {
  const _TherapistSaveButton({
    required this.onPressed,
    required this.enabled,
  });

  final VoidCallback onPressed;
  final bool enabled;

  @override
  State<_TherapistSaveButton> createState() => _TherapistSaveButtonState();
}

class _TherapistSaveButtonState extends State<_TherapistSaveButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.enabled ? widget.onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          height: 50,
          transform: Matrix4.translationValues(
            0,
            widget.enabled && _hover ? -1 : 0,
            0,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.enabled
                  ? (_hover
                      ? [
                          const Color(0xFF8F5FFF),
                          LuxuryModalStyle.accentLavender,
                        ]
                      : [
                          LuxuryModalStyle.accentPurple,
                          const Color(0xFF9B7BFF),
                          LuxuryModalStyle.accentLavender
                              .withValues(alpha: 0.9),
                        ])
                  : [
                      Colors.white.withValues(alpha: 0.12),
                      Colors.white.withValues(alpha: 0.08),
                    ],
            ),
            boxShadow: widget.enabled
                ? [
                    BoxShadow(
                      color: LuxuryModalStyle.accentPurple
                          .withValues(alpha: _hover ? 0.48 : 0.32),
                      blurRadius: _hover ? 24 : 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_rounded,
                size: 18,
                color: Colors.white.withValues(
                  alpha: widget.enabled ? 1 : 0.5,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Save therapist',
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(
                    alpha: widget.enabled ? 1 : 0.5,
                  ),
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
