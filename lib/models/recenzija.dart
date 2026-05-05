class Recenzija {
  final int id;
  final int ocjena;
  final String komentar;
  final String korisnikIme;

  Recenzija({
    required this.id,
    required this.ocjena,
    required this.komentar,
    required this.korisnikIme,
  });

  factory Recenzija.fromJson(Map<String, dynamic> json) {
    return Recenzija(
      id: json['id'] as int,
      ocjena: json['ocjena'] as int,
      komentar: (json['komentar'] as String?) ?? '',
      korisnikIme: (json['korisnikIme'] as String?) ?? '',
    );
  }
}

