class CancelRezervacijaResult {
  final bool otkazana;
  final bool refundIzvrsen;
  final double? refundiraniIznos;

  CancelRezervacijaResult({
    required this.otkazana,
    required this.refundIzvrsen,
    this.refundiraniIznos,
  });

  factory CancelRezervacijaResult.fromJson(Map<String, dynamic> json) {
    return CancelRezervacijaResult(
      otkazana: json['otkazana'] as bool? ?? false,
      refundIzvrsen: json['refundIzvrsen'] as bool? ?? false,
      refundiraniIznos: (json['refundiraniIznos'] as num?)?.toDouble(),
    );
  }
}
