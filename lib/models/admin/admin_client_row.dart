class AdminClientRow {
  final int id;
  final String ime;
  final String prezime;
  final String email;
  final String telefon;
  final DateTime datumRegistracije;
  final DateTime? zadnjaPosjeta;
  final int ukupnoPosjeta;
  final double ukupnoPotroseno;
  final bool isVip;

  const AdminClientRow({
    required this.id,
    required this.ime,
    required this.prezime,
    required this.email,
    required this.telefon,
    required this.datumRegistracije,
    required this.zadnjaPosjeta,
    required this.ukupnoPosjeta,
    required this.ukupnoPotroseno,
    required this.isVip,
  });

  String get punoIme => '$ime $prezime'.trim();

  factory AdminClientRow.fromJson(Map<String, dynamic> json) {
    return AdminClientRow(
      id: (json['id'] as num?)?.toInt() ?? 0,
      ime: (json['ime'] as String?) ?? '',
      prezime: (json['prezime'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      telefon: (json['telefon'] as String?) ?? '',
      datumRegistracije: DateTime.parse(json['datumRegistracije'] as String),
      zadnjaPosjeta: (json['zadnjaPosjeta'] as String?) == null
          ? null
          : DateTime.parse(json['zadnjaPosjeta'] as String),
      ukupnoPosjeta: (json['ukupnoPosjeta'] as num?)?.toInt() ?? 0,
      ukupnoPotroseno: (json['ukupnoPotroseno'] as num?)?.toDouble() ?? 0,
      isVip: (json['isVip'] as bool?) ?? false,
    );
  }
}

