class RezervacijaCalendarItem {
  final int id;
  final DateTime datumRezervacije;
  final String status;
  final bool isPotvrdjena;
  final bool isPlacena;
  final bool isOtkazana;
  final bool isVip;
  final int zaposlenikId;
  final String? zaposlenikIme;

  final int? prostorijaId;
  final String? prostorijaNaziv;

  final int korisnikId;
  final String? korisnikIme;
  final String? korisnikTelefon;
  final String? korisnikEmail;
  final String? napomenaZaTerapeuta;

  final int uslugaId;
  final String? uslugaNaziv;
  final int uslugaTrajanjeMinuta;
  final double uslugaCijena;
  final String? razlogOtkaza;

  const RezervacijaCalendarItem({
    required this.id,
    required this.datumRezervacije,
    this.status = 'Pending',
    required this.isPotvrdjena,
    required this.isPlacena,
    required this.isOtkazana,
    this.isVip = false,
    required this.zaposlenikId,
    required this.zaposlenikIme,
    this.prostorijaId,
    this.prostorijaNaziv,
    required this.korisnikId,
    required this.korisnikIme,
    required this.korisnikTelefon,
    required this.korisnikEmail,
    this.napomenaZaTerapeuta,
    required this.uslugaId,
    required this.uslugaNaziv,
    required this.uslugaTrajanjeMinuta,
    required this.uslugaCijena,
    required this.razlogOtkaza,
  });

  bool get isCompleted => status == 'Completed';

  factory RezervacijaCalendarItem.fromJson(Map<String, dynamic> json) {
    return RezervacijaCalendarItem(
      id: (json['id'] as num).toInt(),
      datumRezervacije: DateTime.parse(json['datumRezervacije'] as String),
      status: (json['status'] as String?) ?? 'Pending',
      isPotvrdjena: (json['isPotvrdjena'] as bool?) ?? false,
      isPlacena: (json['isPlacena'] as bool?) ?? false,
      isOtkazana: (json['isOtkazana'] as bool?) ?? false,
      isVip: (json['isVip'] as bool?) ?? (json['vip'] as bool?) ?? false,
      zaposlenikId: (json['zaposlenikId'] as num?)?.toInt() ?? 0,
      zaposlenikIme: json['zaposlenikIme'] as String?,
      prostorijaId: (json['prostorijaId'] as num?)?.toInt(),
      prostorijaNaziv: json['prostorijaNaziv'] as String?,
      korisnikId: (json['korisnikId'] as num?)?.toInt() ?? 0,
      korisnikIme: json['korisnikIme'] as String?,
      korisnikTelefon: json['korisnikTelefon'] as String?,
      korisnikEmail: json['korisnikEmail'] as String?,
      napomenaZaTerapeuta: json['napomenaZaTerapeuta'] as String?,
      uslugaId: (json['uslugaId'] as num?)?.toInt() ?? 0,
      uslugaNaziv: json['uslugaNaziv'] as String?,
      uslugaTrajanjeMinuta: (json['uslugaTrajanjeMinuta'] as num?)?.toInt() ?? 0,
      uslugaCijena: (json['uslugaCijena'] as num?)?.toDouble() ?? 0,
      razlogOtkaza: json['razlogOtkaza'] as String?,
    );
  }

  RezervacijaCalendarItem copyWith({
    bool? isVip,
    String? status,
    bool? isPotvrdjena,
    bool? isPlacena,
    bool? isOtkazana,
  }) {
    return RezervacijaCalendarItem(
      id: id,
      datumRezervacije: datumRezervacije,
      status: status ?? this.status,
      isPotvrdjena: isPotvrdjena ?? this.isPotvrdjena,
      isPlacena: isPlacena ?? this.isPlacena,
      isOtkazana: isOtkazana ?? this.isOtkazana,
      isVip: isVip ?? this.isVip,
      zaposlenikId: zaposlenikId,
      zaposlenikIme: zaposlenikIme,
      prostorijaId: prostorijaId,
      prostorijaNaziv: prostorijaNaziv,
      korisnikId: korisnikId,
      korisnikIme: korisnikIme,
      korisnikTelefon: korisnikTelefon,
      korisnikEmail: korisnikEmail,
      napomenaZaTerapeuta: napomenaZaTerapeuta,
      uslugaId: uslugaId,
      uslugaNaziv: uslugaNaziv,
      uslugaTrajanjeMinuta: uslugaTrajanjeMinuta,
      uslugaCijena: uslugaCijena,
      razlogOtkaza: razlogOtkaza,
    );
  }
}

/// Result of a calendar fetch — separates empty data from API failures.
class CalendarFetchResult {
  const CalendarFetchResult({
    required this.items,
    this.error,
  });

  final List<RezervacijaCalendarItem> items;
  final String? error;

  bool get hasError => error != null;
}
