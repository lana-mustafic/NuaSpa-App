class KategorijaUsluga {
  final int id;
  final String naziv;

  const KategorijaUsluga({
    required this.id,
    required this.naziv,
  });

  factory KategorijaUsluga.fromJson(Map<String, dynamic> json) {
    return KategorijaUsluga(
      id: json['id'] as int,
      naziv: json['naziv'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'naziv': naziv,
      };
}
