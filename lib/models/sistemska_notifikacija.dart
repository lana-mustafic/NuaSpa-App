class SistemskaNotifikacija {
  final int id;
  final String tip;
  final String naslov;
  final String tekst;
  final bool procitana;
  final DateTime datumVrijeme;
  final int? rezervacijaId;

  SistemskaNotifikacija({
    required this.id,
    required this.tip,
    required this.naslov,
    required this.tekst,
    required this.procitana,
    required this.datumVrijeme,
    this.rezervacijaId,
  });

  factory SistemskaNotifikacija.fromJson(Map<String, dynamic> json) {
    return SistemskaNotifikacija(
      id: (json['id'] as num).toInt(),
      tip: (json['tip'] as num?)?.toInt().toString() ?? json['tip']?.toString() ?? '',
      naslov: json['naslov'] as String? ?? '',
      tekst: json['tekst'] as String? ?? '',
      procitana: json['procitana'] as bool? ?? false,
      datumVrijeme: DateTime.parse(json['datumVrijeme'] as String),
      rezervacijaId: (json['rezervacijaId'] as num?)?.toInt(),
    );
  }
}
