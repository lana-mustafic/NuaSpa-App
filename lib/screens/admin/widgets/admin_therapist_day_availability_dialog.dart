import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/admin/therapist_day_availability.dart';
import '../../../ui/theme/luxury_modal_style.dart';
import '../../../ui/theme/nua_luxury_tokens.dart';

Future<void> showAdminTherapistDayAvailabilityDialog(
  BuildContext context, {
  required TherapistDayAvailability data,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close day availability',
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
              child: AdminTherapistDayAvailabilityDialog(data: data),
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

class AdminTherapistDayAvailabilityDialog extends StatelessWidget {
  const AdminTherapistDayAvailabilityDialog({super.key, required this.data});

  final TherapistDayAvailability data;

  static const _modalGlass = Color(0xEB120A24);

  @override
  Widget build(BuildContext context) {
    final day = data.date.toLocal();
    final load = _parseLoad(data.load);
    final loadColor = _loadColor(load);
    final loadLabel = _loadLabel(load, data.appointmentCount);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(LuxuryModalStyle.modalRadius),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_modalGlass, Color(0xE60B0717)],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
            ),
            boxShadow: LuxuryModalStyle.modalGlow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(LuxuryModalStyle.modalRadius),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Header(
                  therapistName: data.therapistName,
                  dayLabel: _formatDayLabel(day),
                  loadLabel: loadLabel,
                  loadColor: loadColor,
                  onClose: () => Navigator.of(context).pop(),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SummaryRow(data: data),
                        const SizedBox(height: 20),
                        _SectionTitle(
                          icon: Icons.event_available_outlined,
                          title: 'Booked appointments',
                          count: data.bookings.length,
                        ),
                        const SizedBox(height: 10),
                        if (data.bookings.isEmpty)
                          const _EmptyHint(
                            'No appointments on this day.',
                          )
                        else
                          ...data.bookings.map(
                            (b) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _BookingTile(booking: b),
                            ),
                          ),
                        const SizedBox(height: 18),
                        _SectionTitle(
                          icon: Icons.schedule_outlined,
                          title: 'Open slots',
                          count: data.availableSlots.length,
                        ),
                        const SizedBox(height: 10),
                        if (data.isSpaClosed)
                          const _EmptyHint('Spa is closed on this day.')
                        else if (data.isTherapistUnavailable)
                          const _EmptyHint(
                            'Therapist is not available for bookings.',
                          )
                        else if (data.availableSlots.isEmpty)
                          const _EmptyHint('No open slots remain for this day.')
                        else
                          _SlotGrid(slots: data.availableSlots),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: LuxuryModalStyle.accentLavender,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        'Close',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
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

  static String _formatDayLabel(DateTime day) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${weekdays[day.weekday - 1]}, ${months[day.month - 1]} ${day.day}, ${day.year}';
  }

  static _DayLoad _parseLoad(String raw) => switch (raw) {
        'heavy' => _DayLoad.heavy,
        'moderate' => _DayLoad.moderate,
        'light' => _DayLoad.light,
        _ => _DayLoad.off,
      };

  static Color _loadColor(_DayLoad load) => switch (load) {
        _DayLoad.off => const Color(0xFF6EE7B7),
        _DayLoad.light => const Color(0xFF86EFAC),
        _DayLoad.moderate => NuaLuxuryTokens.champagneGold,
        _DayLoad.heavy => const Color(0xFF9CA3AF),
      };

  static String _loadLabel(_DayLoad load, int count) {
    if (load == _DayLoad.off) return 'Open day';
    if (load == _DayLoad.heavy) return 'Fully booked';
    if (count == 1) return '1 appointment';
    return '$count appointments';
  }
}

enum _DayLoad { off, light, moderate, heavy }

class _Header extends StatefulWidget {
  const _Header({
    required this.therapistName,
    required this.dayLabel,
    required this.loadLabel,
    required this.loadColor,
    required this.onClose,
  });

  final String therapistName;
  final String dayLabel;
  final String loadLabel;
  final Color loadColor;
  final VoidCallback onClose;

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  bool _closeHover = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.therapistName,
                  style: LuxuryModalStyle.titleStyle(context, size: 22),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.dayLabel,
                  style: LuxuryModalStyle.subtitleStyle(context),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: widget.loadColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: widget.loadColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.loadColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.loadLabel,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: widget.loadColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          MouseRegion(
            onEnter: (_) => setState(() => _closeHover = true),
            onExit: (_) => setState(() => _closeHover = false),
            child: IconButton(
              onPressed: widget.onClose,
              tooltip: 'Close',
              icon: Icon(
                Icons.close_rounded,
                color: _closeHover
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.65),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.data});

  final TherapistDayAvailability data;

  @override
  Widget build(BuildContext context) {
    final items = <({IconData icon, String label, String value})>[
      (
        icon: Icons.access_time_rounded,
        label: 'Hours',
        value: data.isSpaClosed
            ? 'Closed'
            : (data.workingHoursLabel ?? '—'),
      ),
      (
        icon: Icons.person_outline_rounded,
        label: 'Status',
        value: data.isTherapistUnavailable
            ? data.therapistStatus
            : 'Available',
      ),
      (
        icon: Icons.event_note_outlined,
        label: 'Booked',
        value: '${data.appointmentCount}',
      ),
      (
        icon: Icons.add_circle_outline_rounded,
        label: 'Open slots',
        value: '${data.availableSlots.length}',
      ),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final item in items)
          _SummaryChip(
            icon: item.icon,
            label: item.label,
            value: item.value,
          ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: LuxuryModalStyle.fieldBg.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: LuxuryModalStyle.accentLavender),
          const SizedBox(width: 8),
          Text(
            '$label · ',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: LuxuryModalStyle.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: LuxuryModalStyle.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.count,
  });

  final IconData icon;
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: LuxuryModalStyle.accentGold),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: LuxuryModalStyle.textPrimary,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '($count)',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: LuxuryModalStyle.textMuted,
          ),
        ),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Text(
        message,
        style: GoogleFonts.inter(
          fontSize: 13,
          color: LuxuryModalStyle.textMuted,
        ),
      ),
    );
  }
}

class _BookingTile extends StatelessWidget {
  const _BookingTile({required this.booking});

  final TherapistDayBookedSlot booking;

  @override
  Widget build(BuildContext context) {
    final start = booking.start.toLocal();
    final end = start.add(Duration(minutes: booking.durationMinutes));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_hm(start)} – ${_hm(end)}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: LuxuryModalStyle.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                booking.serviceName,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: LuxuryModalStyle.accentLavender,
                ),
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                booking.clientName,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: LuxuryModalStyle.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                booking.status,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: LuxuryModalStyle.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _hm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _SlotGrid extends StatelessWidget {
  const _SlotGrid({required this.slots});

  final List<DateTime> slots;

  @override
  Widget build(BuildContext context) {
    final sorted = List<DateTime>.from(slots)..sort();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final slot in sorted)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF6EE7B7).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF6EE7B7).withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              _hm(slot.toLocal()),
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF6EE7B7),
              ),
            ),
          ),
      ],
    );
  }

  static String _hm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
