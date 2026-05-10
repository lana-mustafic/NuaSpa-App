class RezervacijaPovijestItem {
  const RezervacijaPovijestItem({
    required this.id,
    required this.datumRezervacije,
    required this.uslugaNaziv,
    required this.isPotvrdjena,
    required this.isPlacena,
    required this.isOtkazana,
  });

  final int id;
  final DateTime datumRezervacije;
  final String? uslugaNaziv;
  final bool isPotvrdjena;
  final bool isPlacena;
  final bool isOtkazana;

  factory RezervacijaPovijestItem.fromJson(Map<String, dynamic> json) {
    return RezervacijaPovijestItem(
      id: (json['id'] as num).toInt(),
      datumRezervacije: DateTime.parse(json['datumRezervacije'] as String),
      uslugaNaziv: json['uslugaNaziv'] as String?,
      isPotvrdjena: json['isPotvrdjena'] as bool? ?? false,
      isPlacena: json['isPlacena'] as bool? ?? false,
      isOtkazana: json['isOtkazana'] as bool? ?? false,
    );
  }
}
