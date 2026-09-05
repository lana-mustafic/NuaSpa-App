import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/api_error_messages.dart';
import '../../core/api/services/api_service.dart';
import '../../models/obavijest.dart';
import '../../ui/theme/nua_luxury_tokens.dart';
import '../../ui/widgets/luxury/luxury_confirm_dialog.dart';
import '../../ui/widgets/service_network_image.dart';

class AdminNewsScreen extends StatefulWidget {
  const AdminNewsScreen({super.key});

  @override
  State<AdminNewsScreen> createState() => _AdminNewsScreenState();
}

class _AdminNewsScreenState extends State<AdminNewsScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<Obavijest> _items = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _api.getObavijesti();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ApiErrorMessages.fromObject(e);
      });
    }
  }

  Future<void> _edit([Obavijest? existing]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => _NewsEditorDialog(api: _api, existing: existing),
    );
    if (saved == true) await _reload();
  }

  Future<void> _delete(Obavijest row) async {
    final ok = await showLuxuryConfirmDialog(
      context,
      title: 'Delete news',
      message: 'Delete “${row.naslov}”? Guests will no longer see this announcement.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await _api.deleteObavijest(row.id);
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiErrorMessages.fromObject(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'News',
              style: GoogleFonts.manrope(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFF5F3FA),
              ),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: () => _edit(),
              icon: const Icon(Icons.add),
              label: const Text('Add news'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Publish spa announcements that clients and therapists see in the app.',
          style: GoogleFonts.manrope(
            fontSize: 13,
            color: NuaLuxuryTokens.lavenderWhisper.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_items.isEmpty) {
      return const Center(child: Text('No news yet.'));
    }

    return ListView.separated(
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final item = _items[i];
        return DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF161022),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: item.slikaUrl == null || item.slikaUrl!.isEmpty
                        ? ColoredBox(
                            color: Colors.white.withValues(alpha: 0.04),
                            child: const Icon(Icons.campaign_outlined),
                          )
                        : ServiceNetworkImage(imageUrl: item.slikaUrl!),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.naslov,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFF5F3FA),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.publishedLabel,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: NuaLuxuryTokens.lavenderWhisper.withValues(
                            alpha: 0.65,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.aktivna ? 'Published' : 'Hidden',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: item.aktivna
                              ? const Color(0xFF9BE7C4)
                              : const Color(0xFFE8C07A),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit',
                  onPressed: () => _edit(item),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: () => _delete(item),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NewsEditorDialog extends StatefulWidget {
  const _NewsEditorDialog({required this.api, this.existing});

  final ApiService api;
  final Obavijest? existing;

  @override
  State<_NewsEditorDialog> createState() => _NewsEditorDialogState();
}

class _NewsEditorDialogState extends State<_NewsEditorDialog> {
  late final TextEditingController _title;
  late final TextEditingController _text;
  late bool _active;
  String? _imageUrl;
  String? _localPath;
  List<int>? _localBytes;
  String? _localName;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _title = TextEditingController(text: existing?.naslov ?? '');
    _text = TextEditingController(text: existing?.tekst ?? '');
    _active = existing?.aktivna ?? true;
    _imageUrl = existing?.slikaUrl;
  }

  @override
  void dispose() {
    _title.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: kIsWeb,
    );
    final file = r?.files.single;
    if (file == null) return;

    if (kIsWeb) {
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) return;
      setState(() {
        _localBytes = bytes;
        _localName = file.name;
        _localPath = null;
      });
      return;
    }

    final path = file.path;
    if (path == null) return;
    setState(() {
      _localPath = path;
      _localBytes = null;
      _localName = file.name;
    });
  }

  void _clearImage() {
    setState(() {
      _localPath = null;
      _localBytes = null;
      _localName = null;
      _imageUrl = null;
    });
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final text = _text.text.trim();
    if (title.isEmpty || text.isEmpty) {
      setState(() => _error = 'Title and text are required.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      var imageUrl = _imageUrl;
      if (_localBytes != null && _localName != null) {
        imageUrl = await widget.api.uploadObavijestImageBytes(
          _localBytes!,
          fileName: _localName!,
        );
      } else if (_localPath != null) {
        imageUrl = await widget.api.uploadObavijestImage(_localPath!);
      }

      if (widget.existing == null) {
        await widget.api.createObavijest(
          naslov: title,
          tekst: text,
          slikaUrl: imageUrl,
          aktivna: _active,
        );
      } else {
        await widget.api.updateObavijest(
          id: widget.existing!.id,
          naslov: title,
          tekst: text,
          slikaUrl: imageUrl,
          aktivna: _active,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = ApiErrorMessages.fromObject(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _imageUrl;
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add news' : 'Edit news'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _title,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _text,
                maxLength: 8000,
                minLines: 5,
                maxLines: 10,
                decoration: const InputDecoration(labelText: 'Text'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Published'),
                subtitle: const Text('Hidden items are visible only to admins.'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.image_outlined),
                    label: Text(_localName ?? 'Choose image'),
                  ),
                  const SizedBox(width: 8),
                  if (preview != null || _localPath != null || _localBytes != null)
                    TextButton(
                      onPressed: _clearImage,
                      child: const Text('Remove'),
                    ),
                ],
              ),
              if (preview != null &&
                  _localPath == null &&
                  _localBytes == null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: ServiceNetworkImage(imageUrl: preview),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Color(0xFFE8A0A0))),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
