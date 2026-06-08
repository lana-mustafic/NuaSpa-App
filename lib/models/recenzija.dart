class RecenzijeLoadResult {
  const RecenzijeLoadResult({
    this.items = const [],
    this.error,
    this.truncated = false,
  });

  final List<Recenzija> items;
  final String? error;
  final bool truncated;
}

class Recenzija {
  final int id;
  final int ocjena;
  final String komentar;
  final String korisnikIme;
  final String? uslugaNaziv;
  final String? zaposlenikIme;
  final DateTime? createdAt;
  final String? adminOdgovor;

  Recenzija({
    required this.id,
    required this.ocjena,
    required this.komentar,
    required this.korisnikIme,
    this.uslugaNaziv,
    this.zaposlenikIme,
    this.createdAt,
    this.adminOdgovor,
  });

  factory Recenzija.fromJson(Map<String, dynamic> json) {
    DateTime? created;
    final rawCreated = json['createdAt'];
    if (rawCreated is String && rawCreated.isNotEmpty) {
      created = DateTime.tryParse(rawCreated);
    }

    return Recenzija(
      id: (json['id'] as num).toInt(),
      ocjena: (json['ocjena'] as num).toInt(),
      komentar: (json['komentar'] as String?) ?? '',
      korisnikIme: (json['korisnikIme'] as String?) ?? '',
      uslugaNaziv: json['uslugaNaziv'] as String?,
      zaposlenikIme: json['zaposlenikIme'] as String?,
      createdAt: created,
      adminOdgovor: json['adminOdgovor'] as String?,
    );
  }
}
