class Rezervacija {
  final int id;
  final DateTime datumRezervacije;
  final bool isPotvrdjena;
  final bool isPlacena;
  final String? korisnikIme;
  final String? uslugaNaziv;
  final String? zaposlenikIme;

  Rezervacija({
    required this.id,
    required this.datumRezervacije,
    required this.isPotvrdjena,
    required this.isPlacena,
    this.korisnikIme,
    this.uslugaNaziv,
    this.zaposlenikIme,
  });

  factory Rezervacija.fromJson(Map<String, dynamic> json) {
    return Rezervacija(
      id: json['id'] as int,
      datumRezervacije: DateTime.parse(json['datumRezervacije'] as String),
      isPotvrdjena: json['isPotvrdjena'] as bool,
      isPlacena: (json['isPlacena'] as bool?) ?? false,
      korisnikIme: json['korisnikIme'] as String?,
      uslugaNaziv: json['uslugaNaziv'] as String?,
      zaposlenikIme: json['zaposlenikIme'] as String?,
    );
  }
}

