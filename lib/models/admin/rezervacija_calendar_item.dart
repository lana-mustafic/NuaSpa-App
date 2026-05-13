class RezervacijaCalendarItem {
  final int id;
  final DateTime datumRezervacije;
  final bool isPotvrdjena;
  final bool isPlacena;
  final bool isOtkazana;
  /// Optional; when true, calendar shows VIP gold accent (if API sends it).
  final bool isVip;
  final int zaposlenikId;
  final String? zaposlenikIme;

  final int korisnikId;
  final String? korisnikIme;
  final String? korisnikTelefon;
  final String? korisnikEmail;

  final int uslugaId;
  final String? uslugaNaziv;
  final int uslugaTrajanjeMinuta;
  final double uslugaCijena;
  final String? razlogOtkaza;

  const RezervacijaCalendarItem({
    required this.id,
    required this.datumRezervacije,
    required this.isPotvrdjena,
    required this.isPlacena,
    required this.isOtkazana,
    this.isVip = false,
    required this.zaposlenikId,
    required this.zaposlenikIme,
    required this.korisnikId,
    required this.korisnikIme,
    required this.korisnikTelefon,
    required this.korisnikEmail,
    required this.uslugaId,
    required this.uslugaNaziv,
    required this.uslugaTrajanjeMinuta,
    required this.uslugaCijena,
    required this.razlogOtkaza,
  });

  factory RezervacijaCalendarItem.fromJson(Map<String, dynamic> json) {
    return RezervacijaCalendarItem(
      id: (json['id'] as num).toInt(),
      datumRezervacije: DateTime.parse(json['datumRezervacije'] as String),
      isPotvrdjena: (json['isPotvrdjena'] as bool?) ?? false,
      isPlacena: (json['isPlacena'] as bool?) ?? false,
      isOtkazana: (json['isOtkazana'] as bool?) ?? false,
      isVip: (json['isVip'] as bool?) ?? (json['vip'] as bool?) ?? false,
      zaposlenikId: (json['zaposlenikId'] as num?)?.toInt() ?? 0,
      zaposlenikIme: json['zaposlenikIme'] as String?,
      korisnikId: (json['korisnikId'] as num?)?.toInt() ?? 0,
      korisnikIme: json['korisnikIme'] as String?,
      korisnikTelefon: json['korisnikTelefon'] as String?,
      korisnikEmail: json['korisnikEmail'] as String?,
      uslugaId: (json['uslugaId'] as num?)?.toInt() ?? 0,
      uslugaNaziv: json['uslugaNaziv'] as String?,
      uslugaTrajanjeMinuta: (json['uslugaTrajanjeMinuta'] as num?)?.toInt() ?? 0,
      uslugaCijena: (json['uslugaCijena'] as num?)?.toDouble() ?? 0,
      razlogOtkaza: json['razlogOtkaza'] as String?,
    );
  }
}
