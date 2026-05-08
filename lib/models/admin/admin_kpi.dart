class AdminKpi {
  final int ukupnoRezervacija;
  final int rezervacijeDanas;
  final double prihodDanas;
  final int aktivniTerapeuti;
  final double prosjecnaOcjena;

  const AdminKpi({
    required this.ukupnoRezervacija,
    required this.rezervacijeDanas,
    required this.prihodDanas,
    required this.aktivniTerapeuti,
    required this.prosjecnaOcjena,
  });

  factory AdminKpi.fromJson(Map<String, dynamic> json) {
    return AdminKpi(
      ukupnoRezervacija: (json['ukupnoRezervacija'] as num?)?.toInt() ?? 0,
      rezervacijeDanas: (json['rezervacijeDanas'] as num?)?.toInt() ?? 0,
      prihodDanas: (json['prihodDanas'] as num?)?.toDouble() ?? 0,
      aktivniTerapeuti: (json['aktivniTerapeuti'] as num?)?.toInt() ?? 0,
      prosjecnaOcjena: (json['prosjecnaOcjena'] as num?)?.toDouble() ?? 0,
    );
  }
}

