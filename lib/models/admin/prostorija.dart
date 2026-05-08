class Prostorija {
  final int id;
  final int spaCentarId;
  final String naziv;
  final String? opis;
  final int kapacitet;
  final bool isAktivna;

  const Prostorija({
    required this.id,
    required this.spaCentarId,
    required this.naziv,
    required this.opis,
    required this.kapacitet,
    required this.isAktivna,
  });

  factory Prostorija.fromJson(Map<String, dynamic> json) {
    return Prostorija(
      id: (json['id'] as num?)?.toInt() ?? 0,
      spaCentarId: (json['spaCentarId'] as num?)?.toInt() ?? 0,
      naziv: (json['naziv'] as String?) ?? '',
      opis: json['opis'] as String?,
      kapacitet: (json['kapacitet'] as num?)?.toInt() ?? 1,
      isAktivna: (json['isAktivna'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'spaCentarId': spaCentarId,
        'naziv': naziv,
        'opis': opis,
        'kapacitet': kapacitet,
        'isAktivna': isAktivna,
      };
}

