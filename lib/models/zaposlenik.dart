class Zaposlenik {
  final int id;
  final String ime;
  final String prezime;
  final String specijalizacija;
  final String? telefon;
  final int? kategorijaUslugaId;
  final DateTime? datumZaposlenja;

  Zaposlenik({
    required this.id,
    required this.ime,
    required this.prezime,
    required this.specijalizacija,
    required this.telefon,
    this.kategorijaUslugaId,
    this.datumZaposlenja,
  });

  factory Zaposlenik.fromJson(Map<String, dynamic> json) {
    final dz = json['datumZaposlenja'];
    final katId = json['kategorijaUslugaId'];
    return Zaposlenik(
      id: (json['id'] as num).toInt(),
      ime: json['ime'] as String,
      prezime: json['prezime'] as String,
      specijalizacija: json['specijalizacija'] as String,
      telefon: json['telefon'] as String?,
      kategorijaUslugaId:
          katId == null ? null : (katId as num).toInt(),
      datumZaposlenja:
          dz == null ? null : DateTime.tryParse(dz.toString()),
    );
  }

  Map<String, dynamic> toJson({bool includeId = true}) {
    return {
      if (includeId) 'id': id,
      'ime': ime,
      'prezime': prezime,
      'specijalizacija': specijalizacija,
      'telefon': telefon,
      if (kategorijaUslugaId != null) 'kategorijaUslugaId': kategorijaUslugaId,
      if (datumZaposlenja != null)
        'datumZaposlenja': datumZaposlenja!.toIso8601String(),
    };
  }

  Zaposlenik copyWith({
    int? id,
    String? ime,
    String? prezime,
    String? specijalizacija,
    String? telefon,
    int? kategorijaUslugaId,
    DateTime? datumZaposlenja,
  }) {
    return Zaposlenik(
      id: id ?? this.id,
      ime: ime ?? this.ime,
      prezime: prezime ?? this.prezime,
      specijalizacija: specijalizacija ?? this.specijalizacija,
      telefon: telefon ?? this.telefon,
      kategorijaUslugaId: kategorijaUslugaId ?? this.kategorijaUslugaId,
      datumZaposlenja: datumZaposlenja ?? this.datumZaposlenja,
    );
  }
}
