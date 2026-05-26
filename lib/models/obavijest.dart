class Obavijest {
  final int id;
  final String naslov;
  final String tekst;
  final String? slikaUrl;
  final DateTime datumObjave;
  final bool aktivna;

  Obavijest({
    required this.id,
    required this.naslov,
    required this.tekst,
    required this.slikaUrl,
    required this.datumObjave,
    required this.aktivna,
  });

  factory Obavijest.fromJson(Map<String, dynamic> json) {
    return Obavijest(
      id: (json['id'] as num).toInt(),
      naslov: json['naslov'] as String? ?? '',
      tekst: json['tekst'] as String? ?? '',
      slikaUrl: json['slikaUrl'] as String?,
      datumObjave: DateTime.parse(json['datumObjave'] as String),
      aktivna: json['aktivna'] as bool? ?? true,
    );
  }
}
