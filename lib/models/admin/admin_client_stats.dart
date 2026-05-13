class AdminClientStats {
  const AdminClientStats({
    required this.ukupnoKlijenata,
    required this.vipKlijenata,
    required this.ukupnoPosjeta,
    required this.ukupnaPotrosnja,
  });

  final int ukupnoKlijenata;
  final int vipKlijenata;
  final int ukupnoPosjeta;
  final double ukupnaPotrosnja;

  factory AdminClientStats.fromJson(Map<String, dynamic> json) {
    return AdminClientStats(
      ukupnoKlijenata: (json['ukupnoKlijenata'] as num?)?.toInt() ?? 0,
      vipKlijenata: (json['vipKlijenata'] as num?)?.toInt() ?? 0,
      ukupnoPosjeta: (json['ukupnoPosjeta'] as num?)?.toInt() ?? 0,
      ukupnaPotrosnja: (json['ukupnaPotrosnja'] as num?)?.toDouble() ?? 0,
    );
  }
}
