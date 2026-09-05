import '../core/reservations/rezervacija_status_flags.dart';

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

  /// Resolved lifecycle label — [status] is authoritative.
  String get displayStatus {
    switch (RezervacijaStatusFlags.normalize(status)) {
      case 'cancelled':
        return 'Cancelled';
      case 'completed':
        return 'Completed';
      case 'confirmed':
        return 'Confirmed';
      default:
        return 'Pending';
    }
  }

  factory RezervacijaPovijestItem.fromJson(Map<String, dynamic> json) {
    final status = (json['status'] as String?) ?? 'Pending';
    return RezervacijaPovijestItem(
      id: (json['id'] as num).toInt(),
      datumRezervacije: DateTime.parse(json['datumRezervacije'] as String),
      uslugaNaziv: json['uslugaNaziv'] as String?,
      isPotvrdjena: RezervacijaStatusFlags.isConfirmedLike(status),
      isPlacena: json['isPlacena'] as bool? ?? false,
      isOtkazana: RezervacijaStatusFlags.isCancelled(status),
      status: status,
    );
  }
}
