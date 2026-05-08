class RezervacijaCalendarItem {
  final int id;
  final DateTime datumRezervacije;
  final bool isPotvrdjena;
  final bool isPlacena;
  final bool isOtkazana;
  final int zaposlenikId;
  final String? zaposlenikIme;
  final int? prostorijaId;
  final String? prostorijaNaziv;
  final String? korisnikIme;
  final String? uslugaNaziv;

  const RezervacijaCalendarItem({
    required this.id,
    required this.datumRezervacije,
    required this.isPotvrdjena,
    required this.isPlacena,
    required this.isOtkazana,
    required this.zaposlenikId,
    required this.zaposlenikIme,
    required this.prostorijaId,
    required this.prostorijaNaziv,
    required this.korisnikIme,
    required this.uslugaNaziv,
  });

  factory RezervacijaCalendarItem.fromJson(Map<String, dynamic> json) {
    return RezervacijaCalendarItem(
      id: (json['id'] as num).toInt(),
      datumRezervacije: DateTime.parse(json['datumRezervacije'] as String),
      isPotvrdjena: (json['isPotvrdjena'] as bool?) ?? false,
      isPlacena: (json['isPlacena'] as bool?) ?? false,
      isOtkazana: (json['isOtkazana'] as bool?) ?? false,
      zaposlenikId: (json['zaposlenikId'] as num?)?.toInt() ?? 0,
      zaposlenikIme: json['zaposlenikIme'] as String?,
      prostorijaId: (json['prostorijaId'] as num?)?.toInt(),
      prostorijaNaziv: json['prostorijaNaziv'] as String?,
      korisnikIme: json['korisnikIme'] as String?,
      uslugaNaziv: json['uslugaNaziv'] as String?,
    );
  }
}

