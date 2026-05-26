import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/services/api_service.dart';
import '../../core/validation/nua_validators.dart';
import '../../widgets/forms/luxury_modal_text_field.dart';
import '../../models/kategorija_usluga.dart';
import '../../models/usluga.dart';
import '../../ui/theme/luxury_modal_style.dart';

String _fileNameFromPath(String path) {
  final normalized = path.replaceAll(r'\', '/');
  final i = normalized.lastIndexOf('/');
  return i >= 0 ? normalized.substring(i + 1) : normalized;
}

class _ServiceEditorFormData {
  const _ServiceEditorFormData({
    required this.naziv,
    required this.cijena,
    required this.trajanjeMinuta,
    required this.opis,
    required this.categoryId,
    this.pickedImagePath,
  });

  final String naziv;
  final double cijena;
  final int trajanjeMinuta;
  final String opis;
  final int categoryId;
  final String? pickedImagePath;
}

/// Opens a luxury modal to create or edit a service (Admin API).
/// Returns `true` if the record was saved successfully.
Future<bool> showServiceEditorDialog(
  BuildContext context, {
  Usluga? existing,
}) async {
  final api = ApiService();
  final katList = await api.getKategorijeUsluga();
  if (!context.mounted) return false;

  if (katList.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Nema kategorija. Dodajte barem jednu kategoriju usluga.',
        ),
      ),
    );
    return false;
  }

  final isNew = existing == null;

  final formData = await showGeneralDialog<_ServiceEditorFormData>(
    context: context,
    barrierDismissible: true,
    barrierLabel: isNew ? 'Close add service' : 'Close edit service',
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
            Center(
              child: _LuxuryServiceEditorShell(
                isNew: isNew,
                existing: existing,
                categories: katList,
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
          scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );

  if (formData == null || !context.mounted) {
    return false;
  }

  final naziv = formData.naziv;
  final cijena = formData.cijena;
  final trajanje = formData.trajanjeMinuta;
  final opis = formData.opis;
  final katId = formData.categoryId;
  final pickedImagePath = formData.pickedImagePath;

  if (naziv.isEmpty || cijena <= 0 || katId <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Provjerite naziv, cijenu i kategoriju usluge.'),
      ),
    );
    return false;
  }

  String slikaUrl;
  if (pickedImagePath != null) {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Image upload is not available in the web browser.'),
        ),
      );
      return false;
    }
    final uploaded = await api.uploadUslugaImage(pickedImagePath);
    if (!context.mounted) return false;
    if (uploaded == null || uploaded.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Image upload failed. Check your connection and permissions.',
          ),
        ),
      );
      return false;
    }
    slikaUrl = uploaded;
  } else if (existing != null &&
      !existing.slikaUrl.contains('picsum.photos')) {
    slikaUrl = existing.slikaUrl;
  } else {
    slikaUrl = 'https://picsum.photos/seed/new/400/300';
  }

  final draft = Usluga(
    id: existing?.id ?? 0,
    naziv: naziv,
    cijena: cijena,
    trajanje: '$trajanje min',
    slikaUrl: slikaUrl,
    kategorija: katList.firstWhere((k) => k.id == katId).naziv,
    trajanjeMinuta: trajanje,
    opis: opis,
    kategorijaUslugaId: katId,
  );

  final ok = existing == null
      ? await api.createUsluga(draft) != null
      : await api.updateUsluga(draft) != null;

  if (!context.mounted) return false;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        ok
            ? (existing == null
                ? 'Usluga je uspješno dodana.'
                : 'Usluga je uspješno ažurirana.')
            : 'Spremanje usluge nije uspjelo. Provjerite unos.',
      ),
    ),
  );
  return ok;
}

class _LuxuryServiceEditorShell extends StatefulWidget {
  const _LuxuryServiceEditorShell({
    required this.isNew,
    required this.existing,
    required this.categories,
  });

  final bool isNew;
  final Usluga? existing;
  final List<KategorijaUsluga> categories;

  @override
  State<_LuxuryServiceEditorShell> createState() =>
      _LuxuryServiceEditorShellState();
}

class _LuxuryServiceEditorShellState extends State<_LuxuryServiceEditorShell> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nazivCtrl;
  late final TextEditingController _cijenaCtrl;
  late final TextEditingController _trajanjeCtrl;
  late final TextEditingController _opisCtrl;
  late final ScrollController _scrollCtrl;

  late int _categoryId;
  String? _localImagePath;
  bool _closeHover = false;
  bool _attemptedSubmit = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nazivCtrl = TextEditingController(text: existing?.naziv ?? '');
    _cijenaCtrl = TextEditingController(
      text: existing != null ? existing.cijena.toStringAsFixed(2) : '',
    );
    _trajanjeCtrl = TextEditingController(
      text: '${existing?.trajanjeMinuta ?? 60}',
    );
    _opisCtrl = TextEditingController(text: existing?.opis ?? '');
    _scrollCtrl = ScrollController();

    _categoryId = existing?.kategorijaUslugaId ?? widget.categories.first.id;
    if (!widget.categories.any((k) => k.id == _categoryId)) {
      _categoryId = widget.categories.first.id;
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _nazivCtrl.dispose();
    _cijenaCtrl.dispose();
    _trajanjeCtrl.dispose();
    _opisCtrl.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  void _submit() {
    setState(() => _attemptedSubmit = true);
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId <= 0) return;

    final naziv = _nazivCtrl.text.trim();
    final cijena = double.parse(_cijenaCtrl.text.trim().replaceAll(',', '.'));
    final trajanje = int.parse(_trajanjeCtrl.text.trim());
    final opis = _opisCtrl.text.trim();

    Navigator.of(context).pop(
      _ServiceEditorFormData(
        naziv: naziv,
        cijena: cijena,
        trajanjeMinuta: trajanje,
        opis: opis,
        categoryId: _categoryId,
        pickedImagePath: _localImagePath,
      ),
    );
  }

  Future<void> _pickImage() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: false,
    );
    if (r != null && r.files.isNotEmpty && r.files.single.path != null) {
      setState(() => _localImagePath = r.files.single.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final modalHeight = (MediaQuery.sizeOf(context).height * 0.9)
        .clamp(520.0, 720.0)
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
                _buildHeader(),
                Expanded(
                  child: Scrollbar(
                    controller: _scrollCtrl,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _scrollCtrl,
                      primary: false,
                      padding: const EdgeInsets.fromLTRB(28, 4, 28, 12),
                      child: Form(
                        key: _formKey,
                        autovalidateMode: _attemptedSubmit
                            ? AutovalidateMode.onUserInteraction
                            : AutovalidateMode.disabled,
                        child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _LuxuryField(
                            label: 'Naziv usluge',
                            child: LuxuryModalTextField(
                              controller: _nazivCtrl,
                              hint: 'npr. Švedska masaža',
                              validator: NuaValidators.serviceName,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: _LuxuryField(
                                  label: 'Cijena (KM)',
                                  child: LuxuryModalTextField(
                                    controller: _cijenaCtrl,
                                    hint: '80.00',
                                    keyboardType: const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                    validator: NuaValidators.positivePrice,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _LuxuryField(
                                  label: 'Trajanje (min)',
                                  child: LuxuryModalTextField(
                                    controller: _trajanjeCtrl,
                                    hint: '60',
                                    keyboardType: TextInputType.number,
                                    validator: NuaValidators.durationMinutes,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _LuxuryField(
                            label: 'Opis',
                            child: SizedBox(
                              height: 120,
                              child: LuxuryModalTextField(
                                controller: _opisCtrl,
                                hint:
                                    'Opišite tretman, benefite i iskustvo...',
                                maxLines: null,
                                expands: true,
                                minHeight: 120,
                                textAlignVertical: TextAlignVertical.top,
                                contentPadding: const EdgeInsets.fromLTRB(
                                  18,
                                  16,
                                  18,
                                  16,
                                ),
                                validator: NuaValidators.serviceDescription,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          _LuxuryField(
                            label: 'Category',
                            child: _LuxuryCategoryDropdown(
                              categories: widget.categories,
                              selectedId: _categoryId,
                              onSelected: (id) => setState(() => _categoryId = id),
                            ),
                          ),
                          const SizedBox(height: 18),
                          _LuxuryField(
                            label: 'Service image',
                            child: kIsWeb
                                ? Text(
                                    'Image upload from files is not supported in the browser; use the desktop or mobile app.',
                                    style: LuxuryModalStyle.subtitleStyle(
                                      context,
                                    ),
                                  )
                                : _LuxuryImageUploadBox(
                                    fileName: _localImagePath == null
                                        ? null
                                        : _fileNameFromPath(_localImagePath!),
                                    onTap: _pickImage,
                                    onRemove: _localImagePath == null
                                        ? null
                                        : () => setState(() => _localImagePath = null),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 26, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isNew ? 'Add New Service' : 'Edit Service',
                  style: LuxuryModalStyle.titleStyle(context),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.isNew
                      ? 'Create and organize premium spa treatments for your clients.'
                      : 'Update treatment details, pricing and catalog presentation.',
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
              onPressed: _close,
              style: IconButton.styleFrom(
                backgroundColor: _closeHover
                    ? LuxuryModalStyle.accentPurple.withValues(alpha: 0.22)
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
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _LuxurySecondaryButton(
            label: 'Cancel',
            onPressed: _close,
          ),
          const SizedBox(width: 12),
          _LuxuryPrimaryButton(
            label: widget.isNew ? 'Save Service' : 'Save Changes',
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

class _LuxuryField extends StatelessWidget {
  const _LuxuryField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: LuxuryModalStyle.labelStyle(context)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _LuxuryCategoryDropdown extends StatefulWidget {
  const _LuxuryCategoryDropdown({
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  final List<KategorijaUsluga> categories;
  final int selectedId;
  final ValueChanged<int> onSelected;

  @override
  State<_LuxuryCategoryDropdown> createState() =>
      _LuxuryCategoryDropdownState();
}

class _LuxuryCategoryDropdownState extends State<_LuxuryCategoryDropdown> {
  bool _hover = false;
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.categories.firstWhere(
      (k) => k.id == widget.selectedId,
      orElse: () => widget.categories.first,
    );

    return MenuAnchor(
      onOpen: () => setState(() => _open = true),
      onClose: () => setState(() => _open = false),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(
          LuxuryModalStyle.bgMid.withValues(alpha: 0.98),
        ),
        elevation: const WidgetStatePropertyAll(12),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
        ),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 6)),
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
              duration: const Duration(milliseconds: 180),
              height: LuxuryModalStyle.fieldHeight,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: LuxuryModalStyle.fieldBg.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(LuxuryModalStyle.fieldRadius),
                border: Border.all(
                  color: _open || _hover
                      ? LuxuryModalStyle.accentPurple.withValues(alpha: 0.55)
                      : Colors.white.withValues(alpha: 0.08),
                ),
                boxShadow: _open || _hover
                    ? [
                        BoxShadow(
                          color: LuxuryModalStyle.accentPurple
                              .withValues(alpha: 0.12),
                          blurRadius: 16,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      selected.naziv,
                      style: LuxuryModalStyle.fieldStyle(context),
                    ),
                  ),
                  Icon(
                    _open
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: LuxuryModalStyle.textMuted,
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
                foregroundColor: WidgetStatePropertyAll(
                  k.id == widget.selectedId
                      ? LuxuryModalStyle.textPrimary
                      : LuxuryModalStyle.textMuted,
                ),
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.hovered)) {
                    return LuxuryModalStyle.accentPurple.withValues(alpha: 0.2);
                  }
                  if (k.id == widget.selectedId) {
                    return LuxuryModalStyle.accentPurple.withValues(alpha: 0.12);
                  }
                  return Colors.transparent;
                }),
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              child: SizedBox(
                width: 440,
                child: Text(
                  k.naziv,
                  style: LuxuryModalStyle.fieldStyle(context),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _LuxuryImageUploadBox extends StatefulWidget {
  const _LuxuryImageUploadBox({
    required this.onTap,
    this.fileName,
    this.onRemove,
  });

  final VoidCallback onTap;
  final String? fileName;
  final VoidCallback? onRemove;

  @override
  State<_LuxuryImageUploadBox> createState() => _LuxuryImageUploadBoxState();
}

class _LuxuryImageUploadBoxState extends State<_LuxuryImageUploadBox> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final hasFile = widget.fileName != null;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: LuxuryModalStyle.fieldBg.withValues(alpha: 0.45),
            boxShadow: _hover
                ? [
                    BoxShadow(
                      color: LuxuryModalStyle.accentPurple.withValues(alpha: 0.15),
                      blurRadius: 20,
                    ),
                  ]
                : null,
          ),
          child: CustomPaint(
            painter: _DashedBorderPainter(
              color: LuxuryModalStyle.accentPurple.withValues(
                alpha: _hover ? 0.5 : 0.35,
              ),
              radius: 20,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: hasFile
                  ? Row(
                      children: [
                        Icon(
                          Icons.image_outlined,
                          color: LuxuryModalStyle.accentPurple
                              .withValues(alpha: 0.9),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.fileName!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: LuxuryModalStyle.fieldStyle(context),
                          ),
                        ),
                        if (widget.onRemove != null)
                          TextButton(
                            onPressed: widget.onRemove,
                            child: Text(
                              'Remove',
                              style: GoogleFonts.inter(
                                color: LuxuryModalStyle.textMuted,
                                fontSize: 13,
                              ),
                            ),
                          ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cloud_upload_outlined,
                          size: 32,
                          color: LuxuryModalStyle.accentPurple
                              .withValues(alpha: 0.75),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Drag & drop image here',
                          style: LuxuryModalStyle.fieldStyle(context).copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'or browse files',
                          style: LuxuryModalStyle.subtitleStyle(context)
                              .copyWith(fontSize: 12.5),
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

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final len = (distance + 6).clamp(0.0, metric.length) - distance;
        final extract = metric.extractPath(distance, distance + len);
        canvas.drawPath(extract, paint);
        distance += 10;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
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
