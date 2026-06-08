import '../zaposlenik.dart';
import 'therapist_kpi.dart';
import 'therapist_top_service.dart';
import 'therapist_weekly_schedule_day.dart';

class TherapistReviewRow {
  TherapistReviewRow({
    required this.createdAt,
    required this.korisnikIme,
    required this.ocjena,
    required this.komentar,
    required this.uslugaNaziv,
    this.adminOdgovor,
  });

  final DateTime createdAt;
  final String korisnikIme;
  final int ocjena;
  final String komentar;
  final String uslugaNaziv;
  final String? adminOdgovor;

  factory TherapistReviewRow.fromJson(Map<String, dynamic> json) {
    final rawCreated = json['createdAt'];
    final created = rawCreated is String
        ? DateTime.tryParse(rawCreated) ?? DateTime.fromMillisecondsSinceEpoch(0)
        : DateTime.fromMillisecondsSinceEpoch(0);

    return TherapistReviewRow(
      createdAt: created,
      korisnikIme: json['korisnikIme'] as String? ?? '',
      ocjena: (json['ocjena'] as num?)?.toInt() ?? 0,
      komentar: json['komentar'] as String? ?? '',
      uslugaNaziv: json['uslugaNaziv'] as String? ?? '',
      adminOdgovor: json['adminOdgovor'] as String?,
    );
  }
}

class TherapistAdminProfile {
  TherapistAdminProfile({
    required this.terapeut,
    required this.povezanEmail,
    required this.imaKorisnickiNalog,
    required this.internaNapomena,
    required this.nedavneRecenzije,
    this.lokacijaPrikaz,
    this.uloga,
    this.kpi,
    this.sedmicniRaspored = const [],
    this.topUsluge = const [],
  });

  final Zaposlenik terapeut;
  final String? povezanEmail;
  final bool imaKorisnickiNalog;
  final String? internaNapomena;
  final List<TherapistReviewRow> nedavneRecenzije;
  final String? lokacijaPrikaz;
  final String? uloga;
  final TherapistKpi? kpi;
  final List<TherapistWeeklyScheduleDay> sedmicniRaspored;
  final List<TherapistTopService> topUsluge;

  factory TherapistAdminProfile.fromJson(Map<String, dynamic> json) {
    final t = json['terapeut'];
    final rawReviews = json['nedavneRecenzije'];
    if (t is! Map<String, dynamic>) {
      throw const FormatException('terapeut');
    }

    final rawKpi = json['kpi'];
    final rawSchedule = json['sedmicniRaspored'];
    final rawTop = json['topUsluge'];

    return TherapistAdminProfile(
      terapeut: Zaposlenik.fromJson(t),
      povezanEmail: json['povezanEmail'] as String?,
      imaKorisnickiNalog: json['imaKorisnickiNalog'] as bool? ?? false,
      internaNapomena: json['internaNapomena'] as String?,
      nedavneRecenzije: rawReviews is List
          ? rawReviews
              .whereType<Map>()
              .map(
                (e) => TherapistReviewRow.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList()
          : const [],
      lokacijaPrikaz: json['lokacijaPrikaz'] as String?,
      uloga: json['uloga'] as String?,
      kpi: rawKpi is Map<String, dynamic>
          ? TherapistKpi.fromJson(rawKpi)
          : null,
      sedmicniRaspored: rawSchedule is List
          ? rawSchedule
              .whereType<Map>()
              .map(
                (e) => TherapistWeeklyScheduleDay.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList()
          : const [],
      topUsluge: rawTop is List
          ? rawTop
              .whereType<Map>()
              .map(
                (e) =>
                    TherapistTopService.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList()
          : const [],
    );
  }
}
