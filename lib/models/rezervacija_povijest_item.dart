class RezervacijaPovijestItem {
  const RezervacijaPovijestItem({
    required this.id,
    required this.datumRezervacije,
    required this.uslugaNaziv,
    required this.isPotvrdjena,
    required this.isPlacena,
    required this.isOtkazana,
    this.status = 'Pending',
  });

  final int id;
  final DateTime datumRezervacije;
  final String? uslugaNaziv;
  final bool isPotvrdjena;
  final bool isPlacena;
  final bool isOtkazana;
  final String status;

  /// Resolved lifecycle label for admin UI (API status with legacy fallback).
  String get displayStatus {
    final s = status.trim();
    if (s == 'Cancelled' || isOtkazana) return 'Cancelled';
    if (s == 'Completed') return 'Completed';
    if (s == 'Confirmed' || (isPotvrdjena && !isOtkazana)) return 'Confirmed';
    if (s == 'Pending') return 'Pending';
    if (isOtkazana) return 'Cancelled';
    if (isPotvrdjena) return 'Confirmed';
    return 'Pending';
  }

  factory RezervacijaPovijestItem.fromJson(Map<String, dynamic> json) {
    return RezervacijaPovijestItem(
      id: (json['id'] as num).toInt(),
      datumRezervacije: DateTime.parse(json['datumRezervacije'] as String),
      uslugaNaziv: json['uslugaNaziv'] as String?,
      isPotvrdjena: json['isPotvrdjena'] as bool? ?? false,
      isPlacena: json['isPlacena'] as bool? ?? false,
      isOtkazana: json['isOtkazana'] as bool? ?? false,
      status: (json['status'] as String?) ?? 'Pending',
    );
  }
}
