class TherapistDashboard {
  final int todayAppointments;
  final int upcomingAppointments;
  final int completedThisMonth;
  final double prosjecnaOcjena;
  final int reviewCount;
  final double revenueThisMonth;

  const TherapistDashboard({
    required this.todayAppointments,
    required this.upcomingAppointments,
    required this.completedThisMonth,
    required this.prosjecnaOcjena,
    required this.reviewCount,
    required this.revenueThisMonth,
  });

  factory TherapistDashboard.fromJson(Map<String, dynamic> json) {
    return TherapistDashboard(
      todayAppointments: (json['todayAppointments'] as num?)?.toInt() ?? 0,
      upcomingAppointments: (json['upcomingAppointments'] as num?)?.toInt() ?? 0,
      completedThisMonth: (json['completedThisMonth'] as num?)?.toInt() ?? 0,
      prosjecnaOcjena: (json['prosjecnaOcjena'] as num?)?.toDouble() ?? 0,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      revenueThisMonth: (json['revenueThisMonth'] as num?)?.toDouble() ?? 0,
    );
  }
}
