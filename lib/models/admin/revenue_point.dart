class RevenuePoint {
  final DateTime datum;
  final int brojRezervacija;
  final double prihod;

  const RevenuePoint({
    required this.datum,
    required this.brojRezervacija,
    required this.prihod,
  });

  factory RevenuePoint.fromJson(Map<String, dynamic> json) {
    return RevenuePoint(
      datum: DateTime.parse(json['datum'] as String),
      brojRezervacija: (json['brojRezervacija'] as num?)?.toInt() ?? 0,
      prihod: (json['prihod'] as num?)?.toDouble() ?? 0,
    );
  }
}

