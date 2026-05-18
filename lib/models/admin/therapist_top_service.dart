class TherapistTopService {
  const TherapistTopService({
    required this.naziv,
    required this.broj,
    required this.postotak,
  });

  final String naziv;
  final int broj;
  final double postotak;

  factory TherapistTopService.fromJson(Map<String, dynamic> json) {
    return TherapistTopService(
      naziv: json['naziv'] as String? ?? '',
      broj: (json['broj'] as num?)?.toInt() ?? 0,
      postotak: (json['postotak'] as num?)?.toDouble() ?? 0,
    );
  }
}
