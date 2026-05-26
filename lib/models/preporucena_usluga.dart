import 'usluga.dart';

/// Jedna preporuka s objašnjenjem (content-based recommender).
class PreporucenaUsluga {
  final Usluga usluga;
  final String razlogKod;
  final String razlogTekst;
  final double skor;

  const PreporucenaUsluga({
    required this.usluga,
    required this.razlogKod,
    required this.razlogTekst,
    required this.skor,
  });

  factory PreporucenaUsluga.fromJson(Map<String, dynamic> json) {
    final uslugaJson = json['usluga'] as Map<String, dynamic>?;
    return PreporucenaUsluga(
      usluga: uslugaJson != null
          ? Usluga.fromJson(uslugaJson)
          : Usluga.fromJson(json),
      razlogKod: json['razlogKod'] as String? ?? '',
      razlogTekst: json['razlogTekst'] as String? ?? '',
      skor: (json['skor'] as num?)?.toDouble() ?? 0,
    );
  }
}
