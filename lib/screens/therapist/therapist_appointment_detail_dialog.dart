import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/therapist/therapist_appointment_utils.dart';
import '../../models/therapist/therapist_dashboard.dart';
import '../../ui/theme/nua_luxury_tokens.dart';

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
            width: 72,
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
