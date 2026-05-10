import 'rezervacija_oprema_item.dart';

class Rezervacija {
  final int id;
  final DateTime datumRezervacije;
  final bool isPotvrdjena;
  final bool isPlacena;
  final bool isOtkazana;
  final String? razlogOtkaza;
  final DateTime? otkazanaAt;
  final int? prostorijaId;
  final String? prostorijaNaziv;
  final List<RezervacijaOpremaItem> oprema;
  final int korisnikId;
  final String? korisnikIme;
  final String? korisnikTelefon;
  final String? napomenaZaTerapeuta;
  final String? uslugaNaziv;
  final int uslugaTrajanjeMinuta;
  final double uslugaCijena;
  final String? zaposlenikIme;
  final bool premiumKlijent;

  Rezervacija({
    required this.id,
    required this.datumRezervacije,
    required this.isPotvrdjena,
    required this.isPlacena,
    required this.isOtkazana,
    required this.razlogOtkaza,
    required this.otkazanaAt,
    required this.prostorijaId,
    required this.prostorijaNaziv,
    required this.oprema,
    this.korisnikId = 0,
    this.korisnikIme,
    this.korisnikTelefon,
    this.napomenaZaTerapeuta,
    this.uslugaNaziv,
    this.uslugaTrajanjeMinuta = 0,
    this.uslugaCijena = 0,
    this.zaposlenikIme,
    this.premiumKlijent = false,
  });

  factory Rezervacija.fromJson(Map<String, dynamic> json) {
    final opremaJson = json['oprema'];
    return Rezervacija(
      id: (json['id'] as num).toInt(),
      datumRezervacije: DateTime.parse(json['datumRezervacije'] as String),
      isPotvrdjena: json['isPotvrdjena'] as bool,
      isPlacena: (json['isPlacena'] as bool?) ?? false,
      isOtkazana: (json['isOtkazana'] as bool?) ?? false,
      razlogOtkaza: json['razlogOtkaza'] as String?,
      otkazanaAt: (json['otkazanaAt'] as String?) == null
          ? null
          : DateTime.parse(json['otkazanaAt'] as String),
      prostorijaId: (json['prostorijaId'] as num?)?.toInt(),
      prostorijaNaziv: json['prostorijaNaziv'] as String?,
      oprema: opremaJson is List
          ? opremaJson
              .whereType<Map>()
              .map((e) =>
                  RezervacijaOpremaItem.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      korisnikId: (json['korisnikId'] as num?)?.toInt() ?? 0,
      korisnikIme: json['korisnikIme'] as String?,
      korisnikTelefon: json['korisnikTelefon'] as String?,
      napomenaZaTerapeuta: json['napomenaZaTerapeuta'] as String?,
      uslugaNaziv: json['uslugaNaziv'] as String?,
      uslugaTrajanjeMinuta:
          (json['uslugaTrajanjeMinuta'] as num?)?.toInt() ?? 0,
      uslugaCijena: (json['uslugaCijena'] as num?)?.toDouble() ?? 0,
      zaposlenikIme: json['zaposlenikIme'] as String?,
      premiumKlijent: json['premiumKlijent'] as bool? ?? false,
    );
  }
}
