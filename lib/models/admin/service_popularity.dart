class ServicePopularity {
  final int uslugaId;
  final String naziv;
  final int brojRezervacija;
  final double prihod;

  const ServicePopularity({
    required this.uslugaId,
    required this.naziv,
    required this.brojRezervacija,
    required this.prihod,
  });

  factory ServicePopularity.fromJson(Map<String, dynamic> json) {
    return ServicePopularity(
      uslugaId: (json['uslugaId'] as num?)?.toInt() ?? 0,
      naziv: (json['naziv'] as String?) ?? '',
      brojRezervacija: (json['brojRezervacija'] as num?)?.toInt() ?? 0,
      prihod: (json['prihod'] as num?)?.toDouble() ?? 0,
    );
  }
}

