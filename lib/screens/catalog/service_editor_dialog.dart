import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/services/api_service.dart';
import '../../models/kategorija_usluga.dart';
import '../../models/usluga.dart';
import '../../ui/theme/luxury_modal_style.dart';

String _fileNameFromPath(String path) {
  final normalized = path.replaceAll(r'\', '/');
  final i = normalized.lastIndexOf('/');
  return i >= 0 ? normalized.substring(i + 1) : normalized;
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
          'No categories yet. Open Service categories and add at least one.',
        ),
      ),
    );
    return false;
  }

  final nazivCtrl = TextEditingController(text: existing?.naziv ?? '');
  final cijenaCtrl = TextEditingController(
    text: existing != null ? existing.cijena.toStringAsFixed(2) : '',
  );
  final trajanjeCtrl = TextEditingController(
    text: '${existing?.trajanjeMinuta ?? 60}',
  );
  final opisCtrl = TextEditingController(text: existing?.opis ?? '');

  var katId = existing?.kategorijaUslugaId ?? katList.first.id;
  if (!katList.any((k) => k.id == katId)) {
    katId = katList.first.id;
  }

  String? pickedImagePath;
  final isNew = existing == null;

  final saved = await showGeneralDialog<bool>(
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
              onTap: () => Navigator.of(ctx).pop(false),
              behavior: HitTestBehavior.opaque,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  color: LuxuryModalStyle.bgDeep.withValues(alpha: 0.38),
                ),
              ),
            ),
            Center(
              child: _LuxuryServiceEditorShell(
                isNew: isNew,
                categories: katList,
                nazivCtrl: nazivCtrl,
                cijenaCtrl: cijenaCtrl,
                trajanjeCtrl: trajanjeCtrl,
                opisCtrl: opisCtrl,
                initialCategoryId: katId,
                onCategoryChanged: (id) => katId = id,
                onImagePicked: (path) => pickedImagePath = path,
                pickedImagePath: () => pickedImagePath,
                onCancel: () => Navigator.of(ctx).pop(false),
                onSave: () => Navigator.of(ctx).pop(true),
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

  void disposeCtrls() {
    nazivCtrl.dispose();
    cijenaCtrl.dispose();
    trajanjeCtrl.dispose();
    opisCtrl.dispose();
  }

  if (saved != true || !context.mounted) {
    disposeCtrls();
    return false;
  }

  final naziv = nazivCtrl.text.trim();
  final cijena =
      double.tryParse(cijenaCtrl.text.replaceAll(',', '.')) ?? 0;
  final trajanje = int.tryParse(trajanjeCtrl.text.trim()) ?? 60;
  final opis = opisCtrl.text.trim();

  disposeCtrls();

  if (naziv.isEmpty || cijena <= 0 || katId <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Check name, price and category.')),
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
    final uploaded = await api.uploadUslugaImage(pickedImagePath!);
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
    SnackBar(content: Text(ok ? 'Saved.' : 'Error saving.')),
  );
  return ok;
}

class _LuxuryServiceEditorShell extends StatefulWidget {
  const _LuxuryServiceEditorShell({
    required this.isNew,
    required this.categories,
    required this.nazivCtrl,
    required this.cijenaCtrl,
    required this.trajanjeCtrl,
    required this.opisCtrl,
    required this.initialCategoryId,
    required this.onCategoryChanged,
    required this.onImagePicked,
    required this.pickedImagePath,
    required this.onCancel,
    required this.onSave,
  });

  final bool isNew;
  final List<KategorijaUsluga> categories;
  final TextEditingController nazivCtrl;
  final TextEditingController cijenaCtrl;
  final TextEditingController trajanjeCtrl;
  final TextEditingController opisCtrl;
  final int initialCategoryId;
  final ValueChanged<int> onCategoryChanged;
  final ValueChanged<String?> onImagePicked;
  final String? Function() pickedImagePath;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  State<_LuxuryServiceEditorShell> createState() =>
      _LuxuryServiceEditorShellState();
}

class _LuxuryServiceEditorShellState extends State<_LuxuryServiceEditorShell> {
  late int _categoryId;
  String? _localImagePath;
  bool _closeHover = false;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.initialCategoryId;
    _localImagePath = widget.pickedImagePath();
  }

  Future<void> _pickImage() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: false,
    );
    if (r != null && r.files.isNotEmpty && r.files.single.path != null) {
      final path = r.files.single.path;
      setState(() => _localImagePath = path);
      widget.onImagePicked(path);
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
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(28, 4, 28, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _LuxuryField(
                            label: 'Service name',
                            child: TextField(
                              controller: widget.nazivCtrl,
                              style: LuxuryModalStyle.fieldStyle(context),
                              decoration: LuxuryModalStyle.fieldDecoration(
                                hint: 'e.g. Swedish Massage',
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: _LuxuryField(
                                  label: 'Price (KM)',
                                  child: TextField(
                                    controller: widget.cijenaCtrl,
                                    keyboardType: TextInputType.number,
                                    style:
                                        LuxuryModalStyle.fieldStyle(context),
                                    decoration:
                                        LuxuryModalStyle.fieldDecoration(
                                      hint: '80.00',
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _LuxuryField(
                                  label: 'Duration (minutes)',
                                  child: TextField(
                                    controller: widget.trajanjeCtrl,
                                    keyboardType: TextInputType.number,
                                    style:
                                        LuxuryModalStyle.fieldStyle(context),
                                    decoration:
                                        LuxuryModalStyle.fieldDecoration(
                                      hint: '60',
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _LuxuryField(
                            label: 'Description',
                            child: SizedBox(
                              height: 120,
                              child: TextField(
                                controller: widget.opisCtrl,
                                maxLines: null,
                                expands: true,
                                textAlignVertical: TextAlignVertical.top,
                                style: LuxuryModalStyle.fieldStyle(context),
                                decoration: LuxuryModalStyle.fieldDecoration(
                                  hint:
                                      'Describe the treatment, benefits and experience...',
                                  contentPadding: const EdgeInsets.fromLTRB(
                                    18,
                                    16,
                                    18,
                                    16,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          _LuxuryField(
                            label: 'Category',
                            child: _LuxuryCategoryDropdown(
                              categories: widget.categories,
                              selectedId: _categoryId,
                              onSelected: (id) {
                                setState(() => _categoryId = id);
                                widget.onCategoryChanged(id);
                              },
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
                                        : () {
                                            setState(
                                              () => _localImagePath = null,
                                            );
                                            widget.onImagePicked(null);
                                          },
                                  ),
                          ),
                        ],
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
              onPressed: widget.onCancel,
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
            onPressed: widget.onCancel,
          ),
          const SizedBox(width: 12),
          _LuxuryPrimaryButton(
            label: widget.isNew ? 'Save Service' : 'Save Changes',
            onPressed: widget.onSave,
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
