class Rezervacija {
  final int id;
  final DateTime datumRezervacije;
  final bool isPotvrdjena;
  final bool isPlacena;
  final bool isOtkazana;
  final String? razlogOtkaza;
  final DateTime? otkazanaAt;
  final int korisnikId;
  final String? korisnikIme;
  final String? korisnikTelefon;
  final String? korisnikEmail;
  final String? napomenaZaTerapeuta;
  final String? uslugaNaziv;
  final int uslugaId;
  final int uslugaTrajanjeMinuta;
  final double uslugaCijena;
  final int zaposlenikId;
  final String? zaposlenikIme;
  final bool premiumKlijent;
  /// VIP tretman na samoj rezervaciji (postavlja admin).
  final bool isVip;

  Rezervacija({
    required this.id,
    required this.datumRezervacije,
    required this.isPotvrdjena,
    required this.isPlacena,
    required this.isOtkazana,
    required this.razlogOtkaza,
    required this.otkazanaAt,
    this.korisnikId = 0,
    this.korisnikIme,
    this.korisnikTelefon,
    this.korisnikEmail,
    this.napomenaZaTerapeuta,
    this.uslugaNaziv,
    this.uslugaId = 0,
    this.uslugaTrajanjeMinuta = 0,
    this.uslugaCijena = 0,
    this.zaposlenikId = 0,
    this.zaposlenikIme,
    this.premiumKlijent = false,
    this.isVip = false,
  });

  factory Rezervacija.fromJson(Map<String, dynamic> json) {
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
      korisnikId: (json['korisnikId'] as num?)?.toInt() ?? 0,
      korisnikIme: json['korisnikIme'] as String?,
      korisnikTelefon: json['korisnikTelefon'] as String?,
      korisnikEmail: json['korisnikEmail'] as String?,
      napomenaZaTerapeuta: json['napomenaZaTerapeuta'] as String?,
      uslugaNaziv: json['uslugaNaziv'] as String?,
      uslugaId: (json['uslugaId'] as num?)?.toInt() ?? 0,
      uslugaTrajanjeMinuta:
          (json['uslugaTrajanjeMinuta'] as num?)?.toInt() ?? 0,
      uslugaCijena: (json['uslugaCijena'] as num?)?.toDouble() ?? 0,
      zaposlenikId: (json['zaposlenikId'] as num?)?.toInt() ?? 0,
      zaposlenikIme: json['zaposlenikIme'] as String?,
      premiumKlijent: json['premiumKlijent'] as bool? ?? false,
      isVip: json['isVip'] as bool? ?? false,
    );
  }
}
