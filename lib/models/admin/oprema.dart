class Oprema {
  final int id;
  final int spaCentarId;
  final String naziv;
  final String? napomena;
  final int kolicina;
  final bool isIspravna;

  const Oprema({
    required this.id,
    required this.spaCentarId,
    required this.naziv,
    required this.napomena,
    required this.kolicina,
    required this.isIspravna,
  });

  factory Oprema.fromJson(Map<String, dynamic> json) {
    return Oprema(
      id: (json['id'] as num?)?.toInt() ?? 0,
      spaCentarId: (json['spaCentarId'] as num?)?.toInt() ?? 0,
      naziv: (json['naziv'] as String?) ?? '',
      napomena: json['napomena'] as String?,
      kolicina: (json['kolicina'] as num?)?.toInt() ?? 1,
      isIspravna: (json['isIspravna'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'spaCentarId': spaCentarId,
        'naziv': naziv,
        'napomena': napomena,
        'kolicina': kolicina,
        'isIspravna': isIspravna,
      };
}

