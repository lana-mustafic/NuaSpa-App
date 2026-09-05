class DrzavaLookup {
  const DrzavaLookup({
    required this.id,
    required this.naziv,
    this.pozivniBroj = '',
  });

  final int id;
  final String naziv;
  final String pozivniBroj;

  factory DrzavaLookup.fromJson(Map<String, dynamic> json) {
    return DrzavaLookup(
      id: (json['id'] as num?)?.toInt() ?? 0,
      naziv: (json['naziv'] as String?) ?? '',
      pozivniBroj: (json['pozivniBroj'] as String?) ?? '',
    );
  }
}
