import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/admin/therapist_account_status.dart';

/// Snackbar / dialog after admin sends a therapist portal invitation.
Future<void> showTherapistPortalInviteFeedback(
  BuildContext context,
  TherapistInviteResult? result,
) async {
  if (!context.mounted) return;

  if (result == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite request failed.')),
    );
    return;
  }

  if (!result.success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
    return;
  }

  if (!result.emailQueued) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  if (result.inviteUrl != null) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF120A24),
        title: Text(
          result.emailQueued ? 'Invitation created' : 'Invitation saved',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            color: const Color(0xFFF5F3FA),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!result.emailQueued) ...[
              Text(
                'Email was not queued. Copy the link and send it to the therapist.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 12),
            ],
            SelectableText(
              result.inviteUrl!,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: result.inviteUrl!));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Activation link copied.')),
              );
            },
            child: const Text('Copy link'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(result.message)),
  );
}
