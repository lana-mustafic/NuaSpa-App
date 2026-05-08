class RezervacijaOpremaItem {
  final int opremaId;
  final int kolicina;

  const RezervacijaOpremaItem({
    required this.opremaId,
    required this.kolicina,
  });

  factory RezervacijaOpremaItem.fromJson(Map<String, dynamic> json) {
    return RezervacijaOpremaItem(
      opremaId: (json['opremaId'] as num?)?.toInt() ?? 0,
      kolicina: (json['kolicina'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'opremaId': opremaId,
        'kolicina': kolicina,
      };
}

