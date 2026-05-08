class TopSpender {
  final int korisnikId;
  final String imePrezime;
  final String? email;
  final int brojPosjeta;
  final double ukupnoPotroseno;
  final DateTime? zadnjaPosjeta;

  const TopSpender({
    required this.korisnikId,
    required this.imePrezime,
    required this.email,
    required this.brojPosjeta,
    required this.ukupnoPotroseno,
    required this.zadnjaPosjeta,
  });

  factory TopSpender.fromJson(Map<String, dynamic> json) {
    return TopSpender(
      korisnikId: (json['korisnikId'] as num?)?.toInt() ?? 0,
      imePrezime: (json['imePrezime'] as String?) ?? '',
      email: json['email'] as String?,
      brojPosjeta: (json['brojPosjeta'] as num?)?.toInt() ?? 0,
      ukupnoPotroseno: (json['ukupnoPotroseno'] as num?)?.toDouble() ?? 0,
      zadnjaPosjeta: (json['zadnjaPosjeta'] as String?) == null
          ? null
          : DateTime.parse(json['zadnjaPosjeta'] as String),
    );
  }
}

