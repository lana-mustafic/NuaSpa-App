class TherapistDayAvailability {
  const TherapistDayAvailability({
    required this.date,
    required this.zaposlenikId,
    required this.therapistName,
    required this.therapistStatus,
    required this.isSpaClosed,
    required this.isTherapistUnavailable,
    required this.workingHoursLabel,
    required this.appointmentCount,
    required this.load,
    required this.bookings,
    required this.availableSlots,
  });

  final DateTime date;
  final int zaposlenikId;
  final String therapistName;
  final String therapistStatus;
  final bool isSpaClosed;
  final bool isTherapistUnavailable;
  final String? workingHoursLabel;
  final int appointmentCount;
  final String load;
  final List<TherapistDayBookedSlot> bookings;
  final List<DateTime> availableSlots;

  factory TherapistDayAvailability.fromJson(Map<String, dynamic> json) {
    final bookingsJson = json['bookings'];
    final slotsJson = json['availableSlots'];
    return TherapistDayAvailability(
      date: DateTime.parse(json['date'] as String),
      zaposlenikId: (json['zaposlenikId'] as num).toInt(),
      therapistName: json['therapistName'] as String? ?? '',
      therapistStatus: json['therapistStatus'] as String? ?? 'Active',
      isSpaClosed: json['isSpaClosed'] as bool? ?? false,
      isTherapistUnavailable:
          json['isTherapistUnavailable'] as bool? ?? false,
      workingHoursLabel: json['workingHoursLabel'] as String?,
      appointmentCount: (json['appointmentCount'] as num?)?.toInt() ?? 0,
      load: json['load'] as String? ?? 'off',
      bookings: bookingsJson is List
          ? bookingsJson
              .whereType<Map>()
              .map(
                (e) => TherapistDayBookedSlot.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList()
          : const [],
      availableSlots: slotsJson is List
          ? slotsJson
              .map((e) {
                if (e is String) return DateTime.parse(e);
                return DateTime.parse(e.toString());
              })
              .toList()
          : const [],
    );
  }
}

class TherapistDayBookedSlot {
  const TherapistDayBookedSlot({
    required this.rezervacijaId,
    required this.start,
    required this.durationMinutes,
    required this.serviceName,
    required this.clientName,
    required this.status,
  });

  final int rezervacijaId;
  final DateTime start;
  final int durationMinutes;
  final String serviceName;
  final String clientName;
  final String status;

  factory TherapistDayBookedSlot.fromJson(Map<String, dynamic> json) {
    return TherapistDayBookedSlot(
      rezervacijaId: (json['rezervacijaId'] as num).toInt(),
      start: DateTime.parse(json['start'] as String),
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 60,
      serviceName: json['serviceName'] as String? ?? 'Service',
      clientName: json['clientName'] as String? ?? 'Client',
      status: json['status'] as String? ?? 'Pending',
    );
  }
}
