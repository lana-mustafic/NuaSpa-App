import '../zaposlenik.dart';

class TherapistReviewRow {
  TherapistReviewRow({
    required this.createdAt,
    required this.korisnikIme,
    required this.ocjena,
    required this.komentar,
    required this.uslugaNaziv,
  });

  final DateTime createdAt;
  final String korisnikIme;
  final int ocjena;
  final String komentar;
  final String uslugaNaziv;

  factory TherapistReviewRow.fromJson(Map<String, dynamic> json) {
    return TherapistReviewRow(
      createdAt: DateTime.parse(json['createdAt'] as String),
      korisnikIme: json['korisnikIme'] as String? ?? '',
      ocjena: (json['ocjena'] as num?)?.toInt() ?? 0,
      komentar: json['komentar'] as String? ?? '',
      uslugaNaziv: json['uslugaNaziv'] as String? ?? '',
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
  });

  final Zaposlenik terapeut;
  final String? povezanEmail;
  final bool imaKorisnickiNalog;
  final String? internaNapomena;
  final List<TherapistReviewRow> nedavneRecenzije;

  factory TherapistAdminProfile.fromJson(Map<String, dynamic> json) {
    final t = json['terapeut'];
    final rawReviews = json['nedavneRecenzije'];
    if (t is! Map<String, dynamic>) {
      throw const FormatException('terapeut');
    }
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
    );
  }
}
