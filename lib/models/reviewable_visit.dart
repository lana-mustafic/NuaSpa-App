class ReviewableVisit {
  const ReviewableVisit({
    required this.rezervacijaId,
    required this.zaposlenikId,
    required this.zaposlenikIme,
    required this.datumRezervacije,
  });

  final int rezervacijaId;
  final int zaposlenikId;
  final String zaposlenikIme;
  final DateTime datumRezervacije;

  factory ReviewableVisit.fromJson(Map<String, dynamic> json) {
    return ReviewableVisit(
      rezervacijaId: (json['rezervacijaId'] as num).toInt(),
      zaposlenikId: (json['zaposlenikId'] as num).toInt(),
      zaposlenikIme: (json['zaposlenikIme'] as String?) ?? '',
      datumRezervacije: DateTime.parse(json['datumRezervacije'] as String),
    );
  }
}

class ReviewableVisitsLoadResult {
  const ReviewableVisitsLoadResult({
    this.items = const [],
    this.error,
  });

  final List<ReviewableVisit> items;
  final String? error;
}
