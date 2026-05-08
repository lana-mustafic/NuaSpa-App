class TherapistKpi {
  final int zaposlenikId;
  final DateTime from;
  final DateTime to;
  final int ukupnoRezervacija;
  final int potvrdjeneRezervacije;
  final int otkazaneRezervacije;
  final int placeneRezervacije;
  final double prihod;
  final double prosjecnaOcjena;

  const TherapistKpi({
    required this.zaposlenikId,
    required this.from,
    required this.to,
    required this.ukupnoRezervacija,
    required this.potvrdjeneRezervacije,
    required this.otkazaneRezervacije,
    required this.placeneRezervacije,
    required this.prihod,
    required this.prosjecnaOcjena,
  });

  factory TherapistKpi.fromJson(Map<String, dynamic> json) {
    return TherapistKpi(
      zaposlenikId: (json['zaposlenikId'] as num?)?.toInt() ?? 0,
      from: DateTime.parse(json['from'] as String),
      to: DateTime.parse(json['to'] as String),
      ukupnoRezervacija: (json['ukupnoRezervacija'] as num?)?.toInt() ?? 0,
      potvrdjeneRezervacije:
          (json['potvrdjeneRezervacije'] as num?)?.toInt() ?? 0,
      otkazaneRezervacije: (json['otkazaneRezervacije'] as num?)?.toInt() ?? 0,
      placeneRezervacije: (json['placeneRezervacije'] as num?)?.toInt() ?? 0,
      prihod: (json['prihod'] as num?)?.toDouble() ?? 0,
      prosjecnaOcjena: (json['prosjecnaOcjena'] as num?)?.toDouble() ?? 0,
    );
  }
}

