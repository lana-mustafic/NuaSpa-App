import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/services/api_service.dart';
import '../../models/usluga.dart';
import '../../models/zaposlenik.dart';
import '../../models/zaposlenik_status.dart';

/// Adds [service] to a therapist's specialization via existing update API.
Future<bool> showAssignTherapistToServiceDialog(
  BuildContext context, {
  required Usluga service,
  required Set<int> alreadyLinkedIds,
}) async {
  final api = ApiService();
  final categoryId = service.kategorijaUslugaId;
  if (categoryId <= 0) {
    if (!context.mounted) return false;
    await _showInfoDialog(
      context,
      title: 'Cannot assign therapist',
      message: 'This service has no category. Edit the service and set a category first.',
    );
    return false;
  }

  if (!context.mounted) return false;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const Center(
      child: CircularProgressIndicator(strokeWidth: 2),
    ),
  );

  final categoryTherapists = await api.getZaposleniciForCategory(
    categoryId,
    bookableOnly: false,
  );
  if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

  final serviceName = service.naziv.trim();
  final candidates = categoryTherapists.where((z) {
    if (alreadyLinkedIds.contains(z.id)) return false;
    return !_specIncludesService(z.specijalizacija, serviceName);
  }).toList()
    ..sort((a, b) => a.fullName.compareTo(b.fullName));

  if (!context.mounted) return false;

  if (categoryTherapists.isEmpty) {
    await _showInfoDialog(
      context,
      title: 'No therapists in category',
      message:
          'There are no therapists in "${service.kategorija}". '
          'Add a therapist in Admin > Therapists and set this category first.',
    );
    return false;
  }

  if (candidates.isEmpty) {
    await _showInfoDialog(
      context,
      title: 'No therapists available',
      message:
          'All therapists in "${service.kategorija}" are already linked to '
          '"$serviceName", or their specialization must be updated in the therapist editor.',
    );
    return false;
  }

  final selected = await showDialog<Zaposlenik>(
    context: context,
    builder: (ctx) => _AssignTherapistPickerDialog(
      service: service,
      candidates: candidates,
    ),
  );
  if (selected == null || !context.mounted) return false;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const Center(
      child: CircularProgressIndicator(strokeWidth: 2),
    ),
  );

  final newSpec = _appendServiceToSpec(selected.specijalizacija, serviceName);
  final payload = selected.copyWith(specijalizacija: newSpec);
  final result = await api.updateZaposlenik(payload);

  if (context.mounted) {
    Navigator.of(context, rootNavigator: true).pop();
  }

  if (!context.mounted) return false;

  if (result.error != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.error!)),
    );
    return false;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('${selected.fullName} is now linked to $serviceName.'),
    ),
  );
  return true;
}

List<String> _parseSpecTags(String raw) => raw
    .split(RegExp(r'[,;/]+'))
    .map((e) => e.trim())
    .where((e) => e.isNotEmpty)
    .toList();

bool _specIncludesService(String spec, String serviceName) {
  final target = serviceName.trim().toLowerCase();
  return _parseSpecTags(spec)
      .any((tag) => tag.toLowerCase() == target);
}

String _appendServiceToSpec(String spec, String serviceName) {
  final name = serviceName.trim();
  final tags = _parseSpecTags(spec);
  if (tags.any((t) => t.toLowerCase() == name.toLowerCase())) {
    return tags.join(', ');
  }
  tags.add(name);
  return tags.join(', ');
}

Future<void> _showInfoDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF120A24),
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

class _AssignTherapistPickerDialog extends StatelessWidget {
  const _AssignTherapistPickerDialog({
    required this.service,
    required this.candidates,
  });

  final Usluga service;
  final List<Zaposlenik> candidates;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF120A24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      title: Text(
        'Assign therapist',
        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Select a therapist to link to "${service.naziv}". '
              'Their specialization will include this service.',
              style: GoogleFonts.inter(
                fontSize: 13.5,
                height: 1.45,
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: candidates.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final z = candidates[index];
                  return Material(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.pop(context, z),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: const Color(0xFF7B4DFF)
                                  .withValues(alpha: 0.22),
                              child: Text(
                                _initials(z),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    z.fullName,
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    z.specijalizacija.trim().isEmpty
                                        ? 'No specialties yet'
                                        : z.specijalizacija,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: Colors.white.withValues(alpha: 0.55),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              z.status.label,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: z.status == ZaposlenikStatus.active
                                    ? const Color(0xFF5CE0A0)
                                    : Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  static String _initials(Zaposlenik z) {
    final i = z.ime.trim().isNotEmpty ? z.ime.trim()[0] : '';
    final p = z.prezime.trim().isNotEmpty ? z.prezime.trim()[0] : '';
    final s = '$i$p'.toUpperCase();
    return s.isEmpty ? '?' : s;
  }
}
