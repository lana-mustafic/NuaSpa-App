class RadnoVrijeme {
  final int id;
  final int spaCentarId;
  final int danUSedmici; // 1..7
  final bool isClosed;
  final int? otvaraMin;
  final int? zatvaraMin;

  const RadnoVrijeme({
    required this.id,
    required this.spaCentarId,
    required this.danUSedmici,
    required this.isClosed,
    required this.otvaraMin,
    required this.zatvaraMin,
  });

  factory RadnoVrijeme.fromJson(Map<String, dynamic> json) {
    return RadnoVrijeme(
      id: (json['id'] as num?)?.toInt() ?? 0,
      spaCentarId: (json['spaCentarId'] as num?)?.toInt() ?? 0,
      danUSedmici: (json['danUSedmici'] as num?)?.toInt() ?? 1,
      isClosed: (json['isClosed'] as bool?) ?? false,
      otvaraMin: (json['otvaraMin'] as num?)?.toInt(),
      zatvaraMin: (json['zatvaraMin'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'spaCentarId': spaCentarId,
        'danUSedmici': danUSedmici,
        'isClosed': isClosed,
        'otvaraMin': otvaraMin,
        'zatvaraMin': zatvaraMin,
      };
}

