import 'package:flutter/material.dart';

import '../../models/rezervacija.dart';
import '../../models/therapist/therapist_dashboard.dart';

/// Shared therapist appointment date/status helpers (dashboard + appointments).
abstract final class TherapistAppointmentUtils {
  static DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static String formatTime(DateTime d) {
    final l = d.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  static String formatTimeRange({
    required DateTime start,
    required int durationMinutes,
  }) {
    final local = start.toLocal();
    final end = local.add(Duration(minutes: durationMinutes));
    return '${formatTime(local)} — ${formatTime(end)}';
  }

  static String formatUpcomingDateTime(DateTime d) {
    final l = d.toLocal();
    final now = DateTime.now();
    final today = dayOnly(now);
    final day = dayOnly(l);
    final time = formatTime(l);
    if (day == today) return 'Today, $time';
    final tomorrow = today.add(const Duration(days: 1));
    if (day == tomorrow) return 'Tomorrow, $time';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[l.month - 1]} ${l.day}, $time';
  }

  static ({String label, Color color}) statusOfRezervacija(Rezervacija r) {
    final normalized = r.status.trim().toLowerCase();
    if (r.isOtkazana || normalized == 'cancelled') {
      return (label: 'Cancelled', color: const Color(0xFFEF4444));
    }
    if (normalized == 'completed') {
      return (label: 'Completed', color: const Color(0xFF6366F1));
    }
    if (r.isPotvrdjena || normalized == 'confirmed') {
      return (label: 'Confirmed', color: const Color(0xFF2DD4BF));
    }
    return (label: 'Pending', color: const Color(0xFFF59E0B));
  }

  static ({String label, Color color}) statusOfDashboardRow(
    TherapistDashboardAppointmentRow r,
  ) {
    final normalized = r.status.trim().toLowerCase();
    if (r.isOtkazana || normalized == 'cancelled') {
      return (label: 'Cancelled', color: const Color(0xFFEF4444));
    }
    if (normalized == 'completed') {
      return (label: 'Completed', color: const Color(0xFF6366F1));
    }
    if (r.isPotvrdjena || normalized == 'confirmed') {
      return (label: 'Confirmed', color: const Color(0xFF2DD4BF));
    }
    return (label: 'Pending', color: const Color(0xFFF59E0B));
  }

  static List<Rezervacija> todayAppointments(
    List<Rezervacija> all, {
    DateTime? reference,
  }) {
    final today = dayOnly(reference ?? DateTime.now());
    return all
        .where((r) {
          final d = dayOnly(r.datumRezervacije.toLocal());
          return d == today && !r.isOtkazana;
        })
        .toList()
      ..sort((a, b) => a.datumRezervacije.compareTo(b.datumRezervacije));
  }

  static List<Rezervacija> upcomingWeek(
    List<Rezervacija> all, {
    DateTime? reference,
  }) {
    final now = reference ?? DateTime.now();
    final today = dayOnly(now);
    final end = today.add(const Duration(days: 7));
    return all
        .where((r) {
          final day = dayOnly(r.datumRezervacije.toLocal());
          return day != today &&
              r.datumRezervacije.isAfter(now) &&
              day.isBefore(end) &&
              !r.isOtkazana;
        })
        .toList()
      ..sort((a, b) => a.datumRezervacije.compareTo(b.datumRezervacije));
  }
}
