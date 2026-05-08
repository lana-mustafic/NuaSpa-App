class SpaCentar {
  final int id;
  final String naziv;
  final String? adresa;
  final String? email;
  final String? telefon;
  final String? opis;

  const SpaCentar({
    required this.id,
    required this.naziv,
    required this.adresa,
    required this.email,
    required this.telefon,
    required this.opis,
  });

  factory SpaCentar.fromJson(Map<String, dynamic> json) {
    return SpaCentar(
      id: (json['id'] as num?)?.toInt() ?? 0,
      naziv: (json['naziv'] as String?) ?? '',
      adresa: json['adresa'] as String?,
      email: json['email'] as String?,
      telefon: json['telefon'] as String?,
      opis: json['opis'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'naziv': naziv,
        'adresa': adresa,
        'email': email,
        'telefon': telefon,
        'opis': opis,
      };
}

