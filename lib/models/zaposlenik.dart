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

  Map<String, dynamic> toJson({bool includeId = true}) {
    return {
      if (includeId) 'id': id,
      'ime': ime,
      'prezime': prezime,
      'specijalizacija': specijalizacija,
      'telefon': telefon,
    };
  }

  Zaposlenik copyWith({
    int? id,
    String? ime,
    String? prezime,
    String? specijalizacija,
    String? telefon,
  }) {
    return Zaposlenik(
      id: id ?? this.id,
      ime: ime ?? this.ime,
      prezime: prezime ?? this.prezime,
      specijalizacija: specijalizacija ?? this.specijalizacija,
      telefon: telefon ?? this.telefon,
    );
  }
}
