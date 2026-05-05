class Usluga {
  final int id;
  final String naziv;
  final double cijena;
  final String trajanje;
  final int trajanjeMinuta;
  final String opis;
  final int kategorijaUslugaId;
  final String slikaUrl;
  final String kategorija;

  Usluga({
    required this.id,
    required this.naziv,
    required this.cijena,
    required this.trajanje,
    required this.slikaUrl,
    required this.kategorija,
    this.trajanjeMinuta = 60,
    this.opis = '',
    this.kategorijaUslugaId = 0,
  });

  bool get _isPlaceholderSlika =>
      slikaUrl.contains('picsum.photos');

  /// JSON za admin POST/PUT prema API kontraktu (.NET camelCase).
  Map<String, dynamic> toAdminJson({required bool includeId}) {
    final map = <String, dynamic>{
      'naziv': naziv,
      'cijena': cijena,
      'trajanjeMinuta': trajanjeMinuta,
      'opis': opis,
      'kategorijaUslugaId': kategorijaUslugaId,
    };
    if (includeId) {
      map['id'] = id;
    }
    if (slikaUrl.isNotEmpty && !_isPlaceholderSlika) {
      map['slikaUrl'] = slikaUrl;
    }
    return map;
  }

  factory Usluga.fromJson(Map<String, dynamic> json) {
    final trajanjeTekst = json['trajanjeTekst'] as String?;
    final trajanjeMinutaRaw = json['trajanjeMinuta'];
    var trajanjeMinuta = trajanjeMinutaRaw != null
        ? (trajanjeMinutaRaw as num).toInt()
        : 0;
    if (trajanjeMinuta <= 0 && trajanjeTekst != null) {
      final m = RegExp(r'(\d+)').firstMatch(trajanjeTekst);
      if (m != null) {
        trajanjeMinuta = int.tryParse(m.group(1)!) ?? 0;
      }
    }
    if (trajanjeMinuta <= 0) {
      trajanjeMinuta = 60;
    }

    final trajanje = trajanjeTekst ??
        (trajanjeMinutaRaw != null ? '$trajanjeMinutaRaw min' : '$trajanjeMinuta min');

    final slika = json['slikaUrl'] as String?;
    final slikaUrl = (slika != null && slika.isNotEmpty)
        ? slika
        : 'https://picsum.photos/seed/${json['id']}/400/300';

    final kat = json['kategorijaNaziv'] as String?;
    final katId = (json['kategorijaUslugaId'] as num?)?.toInt() ?? 0;

    return Usluga(
      id: json['id'] as int,
      naziv: json['naziv'] as String,
      cijena: (json['cijena'] as num).toDouble(),
      trajanje: trajanje,
      slikaUrl: slikaUrl,
      kategorija: (kat != null && kat.isNotEmpty) ? kat : 'Nepoznato',
      trajanjeMinuta: trajanjeMinuta,
      opis: json['opis'] as String? ?? '',
      kategorijaUslugaId: katId,
    );
  }
}
