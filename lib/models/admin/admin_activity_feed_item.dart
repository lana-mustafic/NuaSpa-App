class AdminActivityFeedItem {
  const AdminActivityFeedItem({
    required this.tip,
    required this.naslov,
    this.podnaslov,
    required this.datumVrijeme,
  });

  /// booking | payment | review | client
  final String tip;
  final String naslov;
  final String? podnaslov;
  final DateTime datumVrijeme;

  factory AdminActivityFeedItem.fromJson(Map<String, dynamic> json) {
    final raw = json['datumVrijeme'];
    DateTime at;
    if (raw is String) {
      at = DateTime.parse(raw);
    } else if (raw is DateTime) {
      at = raw;
    } else {
      at = DateTime.fromMillisecondsSinceEpoch(0);
    }
    return AdminActivityFeedItem(
      tip: (json['tip'] as String?)?.trim() ?? '',
      naslov: (json['naslov'] as String?)?.trim() ?? '',
      podnaslov: (json['podnaslov'] as String?)?.trim(),
      datumVrijeme: at,
    );
  }
}
