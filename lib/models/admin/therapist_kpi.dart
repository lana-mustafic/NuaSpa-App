class TherapistKpi {
  final int zaposlenikId;
  final DateTime from;
  final DateTime to;
  final int ukupnoRezervacija;
  final int brojRecenzija;
  final int potvrdjeneRezervacije;
  final int otkazaneRezervacije;
  final int placeneRezervacije;
  final double prihod;
  final double prosjecnaOcjena;
  final double stopaOtkazivanjaPostotak;
  final int? zadovoljstvoKlijenataPostotak;
  final String uloga;
  final double? trendUkupnoRezervacijaPostotak;
  final double? trendPotvrdjenePostotak;
  final double? trendOtkazanePostotak;
  final double? trendProsjecnaOcjenaDelta;
  final double? trendPrihodPostotak;
  final double? trendZadovoljstvoPostotak;

  const TherapistKpi({
    required this.zaposlenikId,
    required this.from,
    required this.to,
    required this.ukupnoRezervacija,
    this.brojRecenzija = 0,
    required this.potvrdjeneRezervacije,
    required this.otkazaneRezervacije,
    required this.placeneRezervacije,
    required this.prihod,
    required this.prosjecnaOcjena,
    this.stopaOtkazivanjaPostotak = 0,
    this.zadovoljstvoKlijenataPostotak,
    this.uloga = 'Therapist',
    this.trendUkupnoRezervacijaPostotak,
    this.trendPotvrdjenePostotak,
    this.trendOtkazanePostotak,
    this.trendProsjecnaOcjenaDelta,
    this.trendPrihodPostotak,
    this.trendZadovoljstvoPostotak,
  });

  factory TherapistKpi.fromJson(Map<String, dynamic> json) {
    return TherapistKpi(
      zaposlenikId: (json['zaposlenikId'] as num?)?.toInt() ?? 0,
      from: DateTime.parse(json['from'] as String),
      to: DateTime.parse(json['to'] as String),
      ukupnoRezervacija: (json['ukupnoRezervacija'] as num?)?.toInt() ?? 0,
      brojRecenzija: (json['brojRecenzija'] as num?)?.toInt() ?? 0,
      potvrdjeneRezervacije:
          (json['potvrdjeneRezervacije'] as num?)?.toInt() ?? 0,
      otkazaneRezervacije: (json['otkazaneRezervacije'] as num?)?.toInt() ?? 0,
      placeneRezervacije: (json['placeneRezervacije'] as num?)?.toInt() ?? 0,
      prihod: (json['prihod'] as num?)?.toDouble() ?? 0,
      prosjecnaOcjena: (json['prosjecnaOcjena'] as num?)?.toDouble() ?? 0,
      stopaOtkazivanjaPostotak:
          (json['stopaOtkazivanjaPostotak'] as num?)?.toDouble() ?? 0,
      zadovoljstvoKlijenataPostotak:
          (json['zadovoljstvoKlijenataPostotak'] as num?)?.toInt(),
      uloga: json['uloga'] as String? ?? 'Therapist',
      trendUkupnoRezervacijaPostotak:
          (json['trendUkupnoRezervacijaPostotak'] as num?)?.toDouble(),
      trendPotvrdjenePostotak:
          (json['trendPotvrdjenePostotak'] as num?)?.toDouble(),
      trendOtkazanePostotak:
          (json['trendOtkazanePostotak'] as num?)?.toDouble(),
      trendProsjecnaOcjenaDelta:
          (json['trendProsjecnaOcjenaDelta'] as num?)?.toDouble(),
      trendPrihodPostotak: (json['trendPrihodPostotak'] as num?)?.toDouble(),
      trendZadovoljstvoPostotak:
          (json['trendZadovoljstvoPostotak'] as num?)?.toDouble(),
    );
  }

  /// Formats a percent trend for badges, e.g. `+12%` or `−2%`.
  static String? badgePercent(double? value) {
    if (value == null) return null;
    final rounded = value.round();
    if (rounded == 0) return null;
    final sign = rounded > 0 ? '+' : '−';
    return '$sign${rounded.abs()}%';
  }

  /// Formats rating delta, e.g. `+0.2`.
  static String? badgeRatingDelta(double? delta) {
    if (delta == null || delta == 0) return null;
    final sign = delta > 0 ? '+' : '−';
    return '$sign${delta.abs().toStringAsFixed(1)}';
  }
}
