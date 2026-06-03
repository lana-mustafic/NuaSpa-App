import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/api/services/api_service.dart';
import '../../../models/admin/therapist_account_status.dart';
import '../../../models/zaposlenik.dart';
import 'admin_therapist_invite_feedback.dart';

/// Admin controls for therapist portal account (invite / status).
class AdminTherapistPortalAccessCard extends StatefulWidget {
  const AdminTherapistPortalAccessCard({
    super.key,
    required this.therapist,
    required this.accountStatus,
    required this.onChanged,
    this.accountError,
  });

  final Zaposlenik therapist;
  final TherapistAccountStatus? accountStatus;
  final String? accountError;
  final VoidCallback onChanged;

  @override
  State<AdminTherapistPortalAccessCard> createState() =>
      _AdminTherapistPortalAccessCardState();
}

class _AdminTherapistPortalAccessCardState
    extends State<AdminTherapistPortalAccessCard> {
  final _api = ApiService();
  bool _inviting = false;

  String get _statusLabel {
    final s = widget.accountStatus;
    if (s == null) return 'Loading…';
    if (s.hasPassword && s.accountActive) return 'Active — can sign in';
    if (s.invitePending) return 'Invitation pending';
    if (s.hasLinkedAccount) return 'Linked — awaiting password';
    return 'No portal account';
  }

  Color get _statusColor {
    if (widget.accountError != null) return const Color(0xFFF87171);
    final s = widget.accountStatus;
    if (s == null) return Colors.white54;
    if (s.hasPassword && s.accountActive) return const Color(0xFF4ADE80);
    if (s.invitePending) return const Color(0xFFF5B942);
    return const Color(0xFF9D6BFF);
  }

  Future<void> _invite() async {
    final emailCtrl = TextEditingController(
      text: widget.therapist.email?.trim() ?? '',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF120A24),
        title: Text(
          'Invite to therapist portal',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            color: const Color(0xFFF5F3FA),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'The therapist will receive an activation link to set their own password. You never share a permanent password.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.7),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Work email',
                labelStyle: GoogleFonts.inter(color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF7B4DFF),
            ),
            child: const Text('Send invite'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) {
      emailCtrl.dispose();
      return;
    }

    setState(() => _inviting = true);
    final result = await _api.inviteTherapistAccount(
      zaposlenikId: widget.therapist.id,
      email: emailCtrl.text,
    );
    emailCtrl.dispose();
    if (!mounted) return;
    setState(() => _inviting = false);

    widget.onChanged();
    await showTherapistPortalInviteFeedback(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.accountStatus;
    final canInvite = s?.canInvite ?? false;
    final showInvite = s != null &&
        !(s.hasPassword && s.accountActive) &&
        canInvite;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: const Color(0xFF7B4DFF).withValues(alpha: 0.25),
                ),
                child: const Icon(
                  Icons.vpn_key_outlined,
                  color: Color(0xFF9D6BFF),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Portal access',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFF5F3FA),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Therapist login is separate from the staff profile. Invite them to set a password.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        height: 1.4,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: _statusColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  _statusLabel,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFF5F3FA),
                  ),
                ),
              ),
            ],
          ),
          if (s?.linkedEmail != null) ...[
            const SizedBox(height: 14),
            Text(
              'Linked email: ${s!.linkedEmail}',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
          ],
          if (widget.accountError != null) ...[
            const SizedBox(height: 8),
            Text(
              widget.accountError!,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFFF87171).withValues(alpha: 0.9),
              ),
            ),
          ],
          if (s?.message != null) ...[
            const SizedBox(height: 8),
            Text(
              s!.message!,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
          if (showInvite) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _inviting ? null : _invite,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7B4DFF),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: _inviting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                s.hasLinkedAccount && !s.hasPassword
                    ? 'Resend portal invite'
                    : 'Invite to portal',
                style: GoogleFonts.inter(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
