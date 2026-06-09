import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/therapist/therapist_appointment_utils.dart';
import '../../models/rezervacija.dart';
import '../../models/therapist/therapist_dashboard.dart';
import '../../ui/theme/nua_luxury_tokens.dart';

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
  final notes = r.napomenaZaTerapeuta?.trim();
  final room = r.prostorijaNaziv?.trim();
  final phone = r.korisnikTelefon?.trim();
  final email = r.korisnikEmail?.trim();
  final cancelReason = r.razlogOtkaza?.trim();

  return showDialog<void>(
    context: context,
    builder: (ctx) => _RezervacijaDetailDialog(
      r: r,
      statusLabel: status.label,
      timeRange: timeRange,
      notes: notes,
      room: room,
      phone: phone,
      email: email,
      cancelReason: cancelReason,
      onConfirmChanged: onConfirmChanged,
    ),
  );
}

class _RezervacijaDetailDialog extends StatefulWidget {
  const _RezervacijaDetailDialog({
    required this.r,
    required this.statusLabel,
    required this.timeRange,
    this.notes,
    this.room,
    this.phone,
    this.email,
    this.cancelReason,
    this.onConfirmChanged,
  });

  final Rezervacija r;
  final String statusLabel;
  final String timeRange;
  final String? notes;
  final String? room;
  final String? phone;
  final String? email;
  final String? cancelReason;
  final Future<void> Function(bool confirmed)? onConfirmChanged;

  @override
  State<_RezervacijaDetailDialog> createState() =>
      _RezervacijaDetailDialogState();
}

class _RezervacijaDetailDialogState extends State<_RezervacijaDetailDialog> {
  late bool _confirmed;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _confirmed = widget.r.isPotvrdjena;
  }

  Future<void> _toggleConfirm(bool v) async {
    final handler = widget.onConfirmChanged;
    if (handler == null || _saving) return;
    setState(() {
      _confirmed = v;
      _saving = true;
    });
    await handler(v);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.r;
    return Dialog(
      backgroundColor: const Color(0xFF120A24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                r.uslugaNaziv ?? 'Appointment',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFF5F3FA),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.timeRange,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color:
                      NuaLuxuryTokens.lavenderWhisper.withValues(alpha: 0.85),
                ),
              ),
              if (r.isVip || r.premiumKlijent) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    if (r.isVip) const _FlagChip(label: 'VIP'),
                    if (r.premiumKlijent)
                      const _FlagChip(label: 'Premium client'),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              _DetailLine('Client', r.korisnikIme ?? 'Client'),
              if (widget.phone != null && widget.phone!.isNotEmpty)
                _DetailLine('Phone', widget.phone!),
              if (widget.email != null && widget.email!.isNotEmpty)
                _DetailLine('Email', widget.email!),
              _DetailLine('Duration', '${r.uslugaTrajanjeMinuta} min'),
              _DetailLine('Payment', r.isPlacena ? 'Paid' : 'Unpaid'),
              _DetailLine('Status', widget.statusLabel),
              if (widget.room != null && widget.room!.isNotEmpty)
                _DetailLine('Room', widget.room!),
              if (widget.cancelReason != null &&
                  widget.cancelReason!.isNotEmpty)
                _DetailLine('Cancel reason', widget.cancelReason!),
              if (widget.notes != null && widget.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Client notes',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.notes!,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.45,
                    color: const Color(0xFFF5F3FA),
                  ),
                ),
              ],
              if (widget.onConfirmChanged != null && !r.isOtkazana) ...[
                const SizedBox(height: 14),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Confirmed',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFF5F3FA),
                    ),
                  ),
                  value: _confirmed,
                  onChanged: _saving ? null : _toggleConfirm,
                ),
              ],
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Close',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
  final notes = row.napomenaZaTerapeuta?.trim();

  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: const Color(0xFF120A24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                row.uslugaNaziv ?? 'Appointment',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFF5F3FA),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                timeRange,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: NuaLuxuryTokens.lavenderWhisper.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 16),
              _DetailLine('Client', row.korisnikIme ?? 'Client'),
              _DetailLine('Duration', '${row.uslugaTrajanjeMinuta} min'),
              _DetailLine('Status', status.label),
              if (row.prostorijaNaziv?.trim().isNotEmpty == true)
                _DetailLine('Room', row.prostorijaNaziv!.trim()),
              if (notes != null && notes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Client notes',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notes,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.45,
                    color: const Color(0xFFF5F3FA),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    'Close',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _FlagChip extends StatelessWidget {
  const _FlagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5B942).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFFF5B942).withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: const Color(0xFFF5B942),
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFF5F3FA),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
