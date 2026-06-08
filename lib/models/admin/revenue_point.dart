class RevenuePoint {
  final DateTime datum;
  final int brojRezervacija;
  final int brojPlacanja;
  final int brojPotvrdjenih;
  final int brojOtkazanih;
  final double prihod;

  const RevenuePoint({
    required this.datum,
    required this.brojRezervacija,
    this.brojPlacanja = 0,
    this.brojPotvrdjenih = 0,
    this.brojOtkazanih = 0,
    required this.prihod,
  });

  factory RevenuePoint.fromJson(Map<String, dynamic> json) {
    return RevenuePoint(
      datum: DateTime.parse(json['datum'] as String),
      brojRezervacija: (json['brojRezervacija'] as num?)?.toInt() ?? 0,
      brojPlacanja: (json['brojPlacanja'] as num?)?.toInt() ?? 0,
      brojPotvrdjenih: (json['brojPotvrdjenih'] as num?)?.toInt() ?? 0,
      brojOtkazanih: (json['brojOtkazanih'] as num?)?.toInt() ?? 0,
      prihod: (json['prihod'] as num?)?.toDouble() ?? 0,
    );
  }
}

