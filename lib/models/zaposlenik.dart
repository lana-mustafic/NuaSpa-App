class Zaposlenik {
  final int id;
  final String ime;
  final String prezime;
  final String specijalizacija;
  final String? telefon;
  final DateTime? datumZaposlenja;

  Zaposlenik({
    required this.id,
    required this.ime,
    required this.prezime,
    required this.specijalizacija,
    required this.telefon,
    this.datumZaposlenja,
  });

  factory Zaposlenik.fromJson(Map<String, dynamic> json) {
    final dz = json['datumZaposlenja'];
    return Zaposlenik(
      id: (json['id'] as num).toInt(),
      ime: json['ime'] as String,
      prezime: json['prezime'] as String,
      specijalizacija: json['specijalizacija'] as String,
      telefon: json['telefon'] as String?,
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
    DateTime? datumZaposlenja,
  }) {
    return Zaposlenik(
      id: id ?? this.id,
      ime: ime ?? this.ime,
      prezime: prezime ?? this.prezime,
      specijalizacija: specijalizacija ?? this.specijalizacija,
      telefon: telefon ?? this.telefon,
      datumZaposlenja: datumZaposlenja ?? this.datumZaposlenja,
    );
  }
}
