class AdminClientRow {
  final int id;
  final String ime;
  final String prezime;
  final String email;
  final String userName;
  final String telefon;
  final DateTime datumRegistracije;
  final DateTime? zadnjaPosjeta;
  final int ukupnoPosjeta;
  final double ukupnoPotroseno;
  final bool isVip;

  /// Preferirani terapeut (Korisnik.ZaposlenikId) — iz API-ja.
  final int? preferiraniZaposlenikId;

  /// Prikazani terapeut (preferirani ili zadnja posjeta) — iz API-ja.
  final int? terapeutZaposlenikId;
  final String? terapeutIme;
  final String? terapeutPrezime;

  /// Ručni VIP flag u bazi; [isVip] uključuje i heuristiku.
  final bool isVipKlijent;

  /// Account active (API: status).
  final bool isActive;

  final int gradId;
  final String? gradNaziv;
  final String? napomenaZaTerapeuta;

  const AdminClientRow({
    required this.id,
    required this.ime,
    required this.prezime,
    required this.email,
    this.userName = '',
    required this.telefon,
    required this.datumRegistracije,
    required this.zadnjaPosjeta,
    required this.ukupnoPosjeta,
    required this.ukupnoPotroseno,
    required this.isVip,
    this.preferiraniZaposlenikId,
    this.terapeutZaposlenikId,
    this.terapeutIme,
    this.terapeutPrezime,
    this.isVipKlijent = false,
    this.isActive = true,
    this.gradId = 0,
    this.gradNaziv,
    this.napomenaZaTerapeuta,
  });

  /// VIP earned via visits/spend (may coexist with manual flag).
  bool get isVipFromActivity =>
      ukupnoPosjeta >= 10 || ukupnoPotroseno >= 600;

  String get punoIme => '$ime $prezime'.trim();

  String? get terapeutPunoIme {
    final i = terapeutIme ?? '';
    final p = terapeutPrezime ?? '';
    final s = '$i $p'.trim();
    return s.isEmpty ? null : s;
  }

  factory AdminClientRow.fromJson(Map<String, dynamic> json) {
    return AdminClientRow(
      id: (json['id'] as num?)?.toInt() ?? 0,
      ime: (json['ime'] as String?) ?? '',
      prezime: (json['prezime'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      userName: (json['userName'] as String?) ?? '',
      telefon: (json['telefon'] as String?) ?? '',
      datumRegistracije: DateTime.parse(json['datumRegistracije'] as String),
      zadnjaPosjeta: (json['zadnjaPosjeta'] as String?) == null
          ? null
          : DateTime.parse(json['zadnjaPosjeta'] as String),
      ukupnoPosjeta: (json['ukupnoPosjeta'] as num?)?.toInt() ?? 0,
      ukupnoPotroseno: (json['ukupnoPotroseno'] as num?)?.toDouble() ?? 0,
      isVip: (json['isVip'] as bool?) ?? false,
      preferiraniZaposlenikId: (json['preferiraniZaposlenikId'] as num?)?.toInt(),
      terapeutZaposlenikId: (json['terapeutZaposlenikId'] as num?)?.toInt(),
      terapeutIme: json['terapeutIme'] as String?,
      terapeutPrezime: json['terapeutPrezime'] as String?,
      isVipKlijent: (json['isVipKlijent'] as bool?) ?? false,
      isActive: (json['status'] as bool?) ?? true,
      gradId: (json['gradId'] as num?)?.toInt() ?? 0,
      gradNaziv: json['gradNaziv'] as String?,
      napomenaZaTerapeuta: json['napomenaZaTerapeuta'] as String?,
    );
  }
}

