class Zaposlenik {
  final int id;
  final String ime;
  final String prezime;
  final String specijalizacija;
  final String? telefon;

  Zaposlenik({
    required this.id,
    required this.ime,
    required this.prezime,
    required this.specijalizacija,
    required this.telefon,
  });

  factory Zaposlenik.fromJson(Map<String, dynamic> json) {
    return Zaposlenik(
      id: json['id'] as int,
      ime: json['ime'] as String,
      prezime: json['prezime'] as String,
      specijalizacija: json['specijalizacija'] as String,
      telefon: json['telefon'] as String?,
    );
  }
}

