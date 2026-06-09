import 'therapist_appointments_list.dart';

class TherapistScheduleDayOverview {
  final int total;
  final int confirmed;
  final int pending;
  final double hoursBooked;

  const TherapistScheduleDayOverview({
    required this.total,
    required this.confirmed,
    required this.pending,
    required this.hoursBooked,
  });

  factory TherapistScheduleDayOverview.fromJson(Map<String, dynamic> json) {
    return TherapistScheduleDayOverview(
      total: (json['total'] as num?)?.toInt() ?? 0,
      confirmed: (json['confirmed'] as num?)?.toInt() ?? 0,
      pending: (json['pending'] as num?)?.toInt() ?? 0,
      hoursBooked: (json['hoursBooked'] as num?)?.toDouble() ?? 0,
    );
  }
}

class TherapistScheduleAvailabilitySummary {
  final String? workingHoursLabel;
  final int availableSlotCount;
  final bool isSpaClosed;
  final bool isTherapistUnavailable;
  final String load;
  final List<DateTime> availableSlots;

  const TherapistScheduleAvailabilitySummary({
    this.workingHoursLabel,
    this.availableSlotCount = 0,
    this.isSpaClosed = false,
    this.isTherapistUnavailable = false,
    this.load = 'off',
    this.availableSlots = const [],
  });

  factory TherapistScheduleAvailabilitySummary.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawSlots = json['availableSlots'];
    final slots = rawSlots is List
        ? rawSlots
            .map((e) => DateTime.parse(e as String))
            .toList()
        : <DateTime>[];

    return TherapistScheduleAvailabilitySummary(
      workingHoursLabel: json['workingHoursLabel'] as String?,
      availableSlotCount: (json['availableSlotCount'] as num?)?.toInt() ?? 0,
      isSpaClosed: json['isSpaClosed'] as bool? ?? false,
      isTherapistUnavailable:
          json['isTherapistUnavailable'] as bool? ?? false,
      load: (json['load'] as String?) ?? 'off',
      availableSlots: slots,
    );
  }
}

class TherapistSchedule {
  final DateTime day;
  final int calendarYear;
  final int calendarMonth;
  final TherapistScheduleDayOverview overview;
  final List<int> monthMarkerDays;
  final TherapistAppointmentRow? nextAppointment;
  final List<TherapistAppointmentRow> items;
  final TherapistScheduleAvailabilitySummary? availability;

  const TherapistSchedule({
    required this.day,
    required this.calendarYear,
    required this.calendarMonth,
    required this.overview,
    this.monthMarkerDays = const [],
    this.nextAppointment,
    this.items = const [],
    this.availability,
  });

  factory TherapistSchedule.fromJson(Map<String, dynamic> json) {
    TherapistAppointmentRow? next;
    final rawNext = json['nextAppointment'];
    if (rawNext is Map<String, dynamic>) {
      next = TherapistAppointmentRow.fromJson(rawNext);
    }

    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
            .map(
              (e) => TherapistAppointmentRow.fromJson(
                e as Map<String, dynamic>,
              ),
            )
            .toList()
        : <TherapistAppointmentRow>[];

    final rawMarkers = json['monthMarkerDays'];
    final markers = rawMarkers is List
        ? rawMarkers.map((e) => (e as num).toInt()).toList()
        : <int>[];

    TherapistScheduleAvailabilitySummary? availability;
    final rawAvailability = json['availability'];
    if (rawAvailability is Map<String, dynamic>) {
      availability =
          TherapistScheduleAvailabilitySummary.fromJson(rawAvailability);
    }

    final overviewRaw = json['overview'];
    final overview = overviewRaw is Map<String, dynamic>
        ? TherapistScheduleDayOverview.fromJson(overviewRaw)
        : const TherapistScheduleDayOverview(
            total: 0,
            confirmed: 0,
            pending: 0,
            hoursBooked: 0,
          );

    final dayRaw = json['day'] as String?;
    final day = dayRaw != null
        ? DateTime.parse(dayRaw)
        : DateTime.now();

    return TherapistSchedule(
      day: day,
      calendarYear: (json['calendarYear'] as num?)?.toInt() ?? day.year,
      calendarMonth: (json['calendarMonth'] as num?)?.toInt() ?? day.month,
      overview: overview,
      monthMarkerDays: markers,
      nextAppointment: next,
      items: items,
      availability: availability,
    );
  }
}
