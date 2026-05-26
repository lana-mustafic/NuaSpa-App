class GradLookup {
  final int id;
  final String naziv;
  final String postanskiBroj;
  final int drzavaId;
  final String? drzavaNaziv;

  const GradLookup({
    required this.id,
    required this.naziv,
    required this.postanskiBroj,
    required this.drzavaId,
    this.drzavaNaziv,
  });

  String get label {
    final pb = postanskiBroj.trim();
    if (pb.isEmpty) return naziv;
    return '$naziv ($pb)';
  }

  factory GradLookup.fromJson(Map<String, dynamic> json) {
    return GradLookup(
      id: (json['id'] as num?)?.toInt() ?? 0,
      naziv: (json['naziv'] as String?) ?? '',
      postanskiBroj: (json['postanskiBroj'] as String?) ?? '',
      drzavaId: (json['drzavaId'] as num?)?.toInt() ?? 0,
      drzavaNaziv: json['drzavaNaziv'] as String?,
    );
  }
}
