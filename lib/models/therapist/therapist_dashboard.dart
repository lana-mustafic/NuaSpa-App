import '../admin/therapist_admin_profile.dart';

class TherapistDashboardAppointmentRow {
  final int id;
  final DateTime datumRezervacije;
  final String status;
  final bool isPotvrdjena;
  final bool isOtkazana;
  final String? korisnikIme;
  final String? uslugaNaziv;
  final int uslugaTrajanjeMinuta;
  final String? napomenaZaTerapeuta;
  final String? prostorijaNaziv;

  const TherapistDashboardAppointmentRow({
    required this.id,
    required this.datumRezervacije,
    required this.status,
    required this.isPotvrdjena,
    required this.isOtkazana,
    this.korisnikIme,
    this.uslugaNaziv,
    this.uslugaTrajanjeMinuta = 0,
    this.napomenaZaTerapeuta,
    this.prostorijaNaziv,
  });

  factory TherapistDashboardAppointmentRow.fromJson(Map<String, dynamic> json) {
    return TherapistDashboardAppointmentRow(
      id: (json['id'] as num).toInt(),
      datumRezervacije: DateTime.parse(json['datumRezervacije'] as String),
      status: (json['status'] as String?) ?? 'Pending',
      isPotvrdjena: json['isPotvrdjena'] as bool? ?? false,
      isOtkazana: json['isOtkazana'] as bool? ?? false,
      korisnikIme: json['korisnikIme'] as String?,
      uslugaNaziv: json['uslugaNaziv'] as String?,
      uslugaTrajanjeMinuta:
          (json['uslugaTrajanjeMinuta'] as num?)?.toInt() ?? 0,
      napomenaZaTerapeuta: json['napomenaZaTerapeuta'] as String?,
      prostorijaNaziv: json['prostorijaNaziv'] as String?,
    );
  }
}

class TherapistDashboard {
  final String therapistIme;
  final int todayAppointments;
  final int upcomingAppointments;
  final int completedThisMonth;
  final double prosjecnaOcjena;
  final int reviewCount;
  final double revenueThisMonth;
  final List<TherapistDashboardAppointmentRow> todaySchedule;
  final List<TherapistDashboardAppointmentRow> upcomingSchedule;
  final TherapistReviewRow? latestReview;

  const TherapistDashboard({
    required this.therapistIme,
    required this.todayAppointments,
    required this.upcomingAppointments,
    required this.completedThisMonth,
    required this.prosjecnaOcjena,
    required this.reviewCount,
    required this.revenueThisMonth,
    this.todaySchedule = const [],
    this.upcomingSchedule = const [],
    this.latestReview,
  });

  factory TherapistDashboard.fromJson(Map<String, dynamic> json) {
    TherapistReviewRow? latest;
    final rawLatest = json['latestReview'];
    if (rawLatest is Map<String, dynamic>) {
      latest = TherapistReviewRow.fromJson(rawLatest);
    }

    List<TherapistDashboardAppointmentRow> parseRows(String key) {
      final raw = json[key];
      if (raw is! List) return const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(TherapistDashboardAppointmentRow.fromJson)
          .toList();
    }

    return TherapistDashboard(
      therapistIme: (json['therapistIme'] as String?)?.trim().isNotEmpty == true
          ? (json['therapistIme'] as String).trim()
          : 'Therapist',
      todayAppointments: (json['todayAppointments'] as num?)?.toInt() ?? 0,
      upcomingAppointments:
          (json['upcomingAppointments'] as num?)?.toInt() ?? 0,
      completedThisMonth: (json['completedThisMonth'] as num?)?.toInt() ?? 0,
      prosjecnaOcjena: (json['prosjecnaOcjena'] as num?)?.toDouble() ?? 0,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      revenueThisMonth: (json['revenueThisMonth'] as num?)?.toDouble() ?? 0,
      todaySchedule: parseRows('todaySchedule'),
      upcomingSchedule: parseRows('upcomingSchedule'),
      latestReview: latest,
    );
  }
}
