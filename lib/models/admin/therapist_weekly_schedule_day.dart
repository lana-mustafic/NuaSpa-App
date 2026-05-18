class TherapistWeeklyScheduleDay {
  const TherapistWeeklyScheduleDay({
    required this.danUSedmici,
    required this.label,
    required this.hoursText,
    required this.isWorking,
  });

  final int danUSedmici;
  final String label;
  final String hoursText;
  final bool isWorking;

  factory TherapistWeeklyScheduleDay.fromJson(Map<String, dynamic> json) {
    return TherapistWeeklyScheduleDay(
      danUSedmici: (json['danUSedmici'] as num?)?.toInt() ?? 0,
      label: json['label'] as String? ?? '',
      hoursText: json['hoursText'] as String? ?? 'Day off',
      isWorking: json['isWorking'] as bool? ?? false,
    );
  }
}
