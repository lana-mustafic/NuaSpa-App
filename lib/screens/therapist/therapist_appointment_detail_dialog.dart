import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/therapist/therapist_appointment_utils.dart';
import '../../models/rezervacija.dart';
import '../../models/therapist/therapist_dashboard.dart';
import '../../ui/theme/luxury_modal_style.dart';
import '../../ui/theme/nua_luxury_tokens.dart';

abstract final class _TherapistApptDialogUi {
  static const textPrimary = Color(0xFFF5F3FA);
  static const purple = Color(0xFF7B4DFF);
  static const purple2 = Color(0xFF9D6BFF);
  static const lavender = Color(0xFFC8B6E8);

  static const radius = 20.0;
  static const maxWidth = 500.0;
  static const fieldGap = 6.0;
  static const sectionGap = 12.0;
  static const fieldHeight = 56.0;
  static const padding = EdgeInsets.fromLTRB(20, 18, 20, 18);
}

Future<void> showTherapistRezervacijaDetailDialog(
  BuildContext context,
  Rezervacija r, {
  Future<void> Function(bool confirmed)? onConfirmChanged,
}) {
  final status = TherapistAppointmentUtils.statusOfRezervacija(r);
  final timeRange = TherapistAppointmentUtils.formatTimeRange(
    start: r.datumRezervacije,
    durationMinutes: r.uslugaTrajanjeMinuta,
  );

  return _showTherapistApptDetailDialog(
    context,
    title: r.uslugaNaziv ?? 'Appointment',
    subtitle: timeRange,
    statusLabel: status.label,
    statusColor: status.color,
    isVip: r.isVip,
    isPremiumClient: r.premiumKlijent,
    clientName: r.korisnikIme ?? 'Client',
    phone: r.korisnikTelefon?.trim(),
    email: r.korisnikEmail?.trim(),
    durationMinutes: r.uslugaTrajanjeMinuta,
    isPaid: r.isPlacena,
    room: r.prostorijaNaziv?.trim(),
    cancelReason: r.razlogOtkaza?.trim(),
    notes: r.napomenaZaTerapeuta?.trim(),
    isCancelled: r.isOtkazana,
    initialConfirmed: r.isPotvrdjena,
    onConfirmChanged: onConfirmChanged,
  );
}

Future<void> showTherapistAppointmentDetailDialog(
  BuildContext context,
  TherapistDashboardAppointmentRow row,
) {
  final status = TherapistAppointmentUtils.statusOfDashboardRow(row);
  final timeRange = TherapistAppointmentUtils.formatTimeRange(
    start: row.datumRezervacije,
    durationMinutes: row.uslugaTrajanjeMinuta,
  );

  return _showTherapistApptDetailDialog(
    context,
    title: row.uslugaNaziv ?? 'Appointment',
    subtitle: timeRange,
    statusLabel: status.label,
    statusColor: status.color,
    clientName: row.korisnikIme ?? 'Client',
    durationMinutes: row.uslugaTrajanjeMinuta,
    room: row.prostorijaNaziv?.trim(),
    notes: row.napomenaZaTerapeuta?.trim(),
    isCancelled: row.isOtkazana,
  );
}

Future<void> _showTherapistApptDetailDialog(
  BuildContext context, {
  required String title,
  required String subtitle,
  required String statusLabel,
  required Color statusColor,
  required String clientName,
  required int durationMinutes,
  bool isVip = false,
  bool isPremiumClient = false,
  String? phone,
  String? email,
  bool? isPaid,
  String? room,
  String? cancelReason,
  String? notes,
  bool isCancelled = false,
  bool initialConfirmed = false,
  Future<void> Function(bool confirmed)? onConfirmChanged,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return Material(
        type: MaterialType.transparency,
        child: _TherapistApptDialogOverlay(
          animation: animation,
          child: _TherapistApptDetailDialog(
          title: title,
          subtitle: subtitle,
          statusLabel: statusLabel,
          statusColor: statusColor,
          clientName: clientName,
          durationMinutes: durationMinutes,
          isVip: isVip,
          isPremiumClient: isPremiumClient,
          phone: phone,
          email: email,
          isPaid: isPaid,
          room: room,
          cancelReason: cancelReason,
          notes: notes,
          isCancelled: isCancelled,
          initialConfirmed: initialConfirmed,
          onConfirmChanged: onConfirmChanged,
          ),
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

class _TherapistApptDialogOverlay extends StatelessWidget {
  const _TherapistApptDialogOverlay({
    required this.animation,
    required this.child,
  });

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: const SizedBox.expand(),
        ),
        FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
              child: child,
            ),
          ),
        ),
      ],
    );
  }
}

class _TherapistApptDetailDialog extends StatefulWidget {
  const _TherapistApptDetailDialog({
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.statusColor,
    required this.clientName,
    required this.durationMinutes,
    required this.isVip,
    required this.isPremiumClient,
    this.phone,
    this.email,
    this.isPaid,
    this.room,
    this.cancelReason,
    this.notes,
    required this.isCancelled,
    required this.initialConfirmed,
    this.onConfirmChanged,
  });

  final String title;
  final String subtitle;
  final String statusLabel;
  final Color statusColor;
  final String clientName;
  final int durationMinutes;
  final bool isVip;
  final bool isPremiumClient;
  final String? phone;
  final String? email;
  final bool? isPaid;
  final String? room;
  final String? cancelReason;
  final String? notes;
  final bool isCancelled;
  final bool initialConfirmed;
  final Future<void> Function(bool confirmed)? onConfirmChanged;

  @override
  State<_TherapistApptDetailDialog> createState() =>
      _TherapistApptDetailDialogState();
}

class _TherapistApptDetailDialogState extends State<_TherapistApptDetailDialog> {
  late bool _confirmed;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _confirmed = widget.initialConfirmed;
  }

  Future<void> _toggleConfirm(bool value) async {
    final handler = widget.onConfirmChanged;
    if (handler == null || _saving) return;
    setState(() {
      _confirmed = value;
      _saving = true;
    });
    await handler(value);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.88;
    final phone = widget.phone?.trim();
    final email = widget.email?.trim();
    final room = widget.room?.trim();
    final notes = widget.notes?.trim();
    final cancelReason = widget.cancelReason?.trim();

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: _TherapistApptDialogUi.maxWidth,
        minWidth: 360,
        maxHeight: maxH,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_TherapistApptDialogUi.radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xEB120A24),
              borderRadius:
                  BorderRadius.circular(_TherapistApptDialogUi.radius),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: LuxuryModalStyle.modalGlow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: _TherapistApptDialogUi.padding.copyWith(bottom: 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: const LinearGradient(
                            colors: [
                              _TherapistApptDialogUi.purple,
                              _TherapistApptDialogUi.purple2,
                            ],
                          ),
                        ),
                        child: const Icon(
                          Icons.spa_outlined,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: _TherapistApptDialogUi.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.subtitle,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _TherapistApptCloseButton(
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      _TherapistApptDialogUi.padding.left,
                      _TherapistApptDialogUi.sectionGap,
                      _TherapistApptDialogUi.padding.right,
                      8,
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _TherapistApptMetaChip(
                                label: widget.statusLabel,
                                color: widget.statusColor,
                                accent: true,
                              ),
                              if (widget.isPaid != null)
                                _TherapistApptMetaChip(
                                  label: widget.isPaid! ? 'Paid' : 'Unpaid',
                                  color: widget.isPaid!
                                      ? const Color(0xFF2DD4BF)
                                      : const Color(0xFFF5B942),
                                ),
                              if (widget.isVip)
                                const _TherapistApptMetaChip(
                                  label: 'VIP',
                                  color: NuaLuxuryTokens.champagneGold,
                                ),
                              if (widget.isPremiumClient)
                                const _TherapistApptMetaChip(
                                  label: 'Premium client',
                                  color: NuaLuxuryTokens.champagneGold,
                                ),
                            ],
                          ),
                          const SizedBox(height: _TherapistApptDialogUi.sectionGap),
                          _TherapistApptSectionTitle(title: 'Client information'),
                          _TherapistApptFieldCard(
                            icon: Icons.person_outline_rounded,
                            label: 'Client',
                            value: widget.clientName,
                          ),
                          if (phone != null && phone.isNotEmpty ||
                              email != null && email.isNotEmpty) ...[
                            const SizedBox(height: _TherapistApptDialogUi.fieldGap),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (phone != null && phone.isNotEmpty)
                                  Expanded(
                                    child: _TherapistApptFieldCard(
                                      icon: Icons.phone_outlined,
                                      label: 'Phone',
                                      value: phone,
                                    ),
                                  ),
                                if (phone != null &&
                                    phone.isNotEmpty &&
                                    email != null &&
                                    email.isNotEmpty)
                                  const SizedBox(width: 8),
                                if (email != null && email.isNotEmpty)
                                  Expanded(
                                    child: _TherapistApptFieldCard(
                                      icon: Icons.email_outlined,
                                      label: 'Email',
                                      value: email,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                          const SizedBox(height: _TherapistApptDialogUi.sectionGap),
                          _TherapistApptSectionTitle(title: 'Appointment details'),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _TherapistApptFieldCard(
                                  icon: Icons.timer_outlined,
                                  label: 'Duration',
                                  value: '${widget.durationMinutes} min',
                                ),
                              ),
                              if (room != null && room.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _TherapistApptFieldCard(
                                    icon: Icons.meeting_room_outlined,
                                    label: 'Room',
                                    value: room,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (notes != null && notes.isNotEmpty) ...[
                            const SizedBox(height: _TherapistApptDialogUi.sectionGap),
                            _TherapistApptSectionTitle(title: 'Notes'),
                            _TherapistApptNotesCard(
                              icon: Icons.notes_outlined,
                              label: 'Client notes',
                              value: notes,
                            ),
                          ],
                          if (cancelReason != null && cancelReason.isNotEmpty) ...[
                            const SizedBox(height: _TherapistApptDialogUi.fieldGap),
                            _TherapistApptNotesCard(
                              icon: Icons.cancel_outlined,
                              label: 'Cancellation reason',
                              value: cancelReason,
                            ),
                          ],
                          if (widget.onConfirmChanged != null &&
                              !widget.isCancelled) ...[
                            const SizedBox(height: _TherapistApptDialogUi.sectionGap),
                            _TherapistApptConfirmStrip(
                              value: _confirmed,
                              saving: _saving,
                              onChanged: _toggleConfirm,
                            ),
                          ],
                        ],
                      ),
                    ),
                ),
                Padding(
                  padding: _TherapistApptDialogUi.padding,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _TherapistApptCancelButton(
                        onPressed: () => Navigator.of(context).pop(),
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

class _TherapistApptSectionTitle extends StatelessWidget {
  const _TherapistApptSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: _TherapistApptDialogUi.lavender.withValues(alpha: 0.75),
        ),
      ),
    );
  }
}

class _TherapistApptFieldCard extends StatelessWidget {
  const _TherapistApptFieldCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _TherapistApptDialogUi.fieldHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: _TherapistApptDialogUi.purple.withValues(alpha: 0.18),
            ),
            child: Icon(icon, size: 20, color: _TherapistApptDialogUi.purple2),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _TherapistApptDialogUi.lavender.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _TherapistApptDialogUi.textPrimary,
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

class _TherapistApptNotesCard extends StatelessWidget {
  const _TherapistApptNotesCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: _TherapistApptDialogUi.purple.withValues(alpha: 0.18),
            ),
            child: Icon(icon, size: 20, color: _TherapistApptDialogUi.purple2),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _TherapistApptDialogUi.lavender.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                    color: _TherapistApptDialogUi.textPrimary,
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

class _TherapistApptMetaChip extends StatelessWidget {
  const _TherapistApptMetaChip({
    required this.label,
    required this.color,
    this.accent = false,
  });

  final String label;
  final Color color;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: accent ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: accent ? 0.55 : 0.38)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: accent ? _TherapistApptDialogUi.textPrimary : color,
        ),
      ),
    );
  }
}

class _TherapistApptConfirmStrip extends StatelessWidget {
  const _TherapistApptConfirmStrip({
    required this.value,
    required this.saving,
    required this.onChanged,
  });

  final bool value;
  final bool saving;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: _TherapistApptDialogUi.purple.withValues(alpha: 0.18),
            ),
            child: const Icon(
              Icons.verified_outlined,
              size: 20,
              color: _TherapistApptDialogUi.purple2,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Confirmed',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _TherapistApptDialogUi.textPrimary,
              ),
            ),
          ),
          if (saving)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Material(
              color: Colors.transparent,
              child: Switch.adaptive(
                value: value,
                onChanged: onChanged,
                activeTrackColor: _TherapistApptDialogUi.purple,
              ),
            ),
        ],
      ),
    );
  }
}

class _TherapistApptCloseButton extends StatefulWidget {
  const _TherapistApptCloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_TherapistApptCloseButton> createState() =>
      _TherapistApptCloseButtonState();
}

class _TherapistApptCloseButtonState extends State<_TherapistApptCloseButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: _hover ? 0.1 : 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Icon(
              Icons.close_rounded,
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
        ),
      ),
    );
  }
}

class _TherapistApptCancelButton extends StatefulWidget {
  const _TherapistApptCancelButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_TherapistApptCancelButton> createState() =>
      _TherapistApptCancelButtonState();
}

class _TherapistApptCancelButtonState extends State<_TherapistApptCancelButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: _hover ? 0.08 : 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Text(
              'Close',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
