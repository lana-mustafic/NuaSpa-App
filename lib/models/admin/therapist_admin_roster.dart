import '../zaposlenik.dart';

class TherapistAdminRoster {
  const TherapistAdminRoster({
    required this.weekStart,
    required this.weekEnd,
    required this.kpiFrom,
    required this.kpiTo,
    required this.therapists,
  });

  final DateTime weekStart;
  final DateTime weekEnd;
  final DateTime kpiFrom;
  final DateTime kpiTo;
  final List<TherapistRosterRow> therapists;

  factory TherapistAdminRoster.fromJson(Map<String, dynamic> json) {
    final therapistsJson = json['therapists'];
    return TherapistAdminRoster(
      weekStart: DateTime.parse(json['weekStart'] as String),
      weekEnd: DateTime.parse(json['weekEnd'] as String),
      kpiFrom: DateTime.parse(json['kpiFrom'] as String),
      kpiTo: DateTime.parse(json['kpiTo'] as String),
      therapists: therapistsJson is List
          ? therapistsJson
              .whereType<Map>()
              .map(
                (e) => TherapistRosterRow.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList()
          : const [],
    );
  }
}

class TherapistRosterRow {
  const TherapistRosterRow({
    required this.terapeut,
    required this.prosjecnaOcjena,
    required this.ukupnoRezervacija,
    required this.brojRecenzija,
    required this.uloga,
    required this.weekDays,
  });

  final Zaposlenik terapeut;
  final double prosjecnaOcjena;
  final int ukupnoRezervacija;
  final int brojRecenzija;
  final String uloga;
  final List<TherapistRosterDay> weekDays;

  factory TherapistRosterRow.fromJson(Map<String, dynamic> json) {
    final terapeutJson = json['terapeut'];
    final weekJson = json['weekDays'];
    return TherapistRosterRow(
      terapeut: terapeutJson is Map<String, dynamic>
          ? Zaposlenik.fromJson(terapeutJson)
          : Zaposlenik.fromJson(Map<String, dynamic>.from(terapeutJson as Map)),
      prosjecnaOcjena: (json['prosjecnaOcjena'] as num?)?.toDouble() ?? 0,
      ukupnoRezervacija: (json['ukupnoRezervacija'] as num?)?.toInt() ?? 0,
      brojRecenzija: (json['brojRecenzija'] as num?)?.toInt() ?? 0,
      uloga: json['uloga'] as String? ?? 'Therapist',
      weekDays: weekJson is List
          ? weekJson
              .whereType<Map>()
              .map(
                (e) => TherapistRosterDay.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList()
          : const [],
    );
  }
}

class TherapistRosterDay {
  const TherapistRosterDay({
    required this.date,
    required this.appointmentCount,
    required this.load,
  });

  final DateTime date;
  final int appointmentCount;
  /// off | light | moderate | heavy
  final String load;

  factory TherapistRosterDay.fromJson(Map<String, dynamic> json) {
    return TherapistRosterDay(
      date: DateTime.parse(json['date'] as String),
      appointmentCount: (json['appointmentCount'] as num?)?.toInt() ?? 0,
      load: json['load'] as String? ?? 'off',
    );
  }
}
