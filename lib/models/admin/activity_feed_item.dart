class ActivityFeedItem {
  const ActivityFeedItem({
    required this.tip,
    required this.naslov,
    this.podnaslov,
    required this.datumVrijeme,
  });

  final String tip;
  final String naslov;
  final String? podnaslov;
  final DateTime datumVrijeme;

  factory ActivityFeedItem.fromJson(Map<String, dynamic> json) {
    return ActivityFeedItem(
      tip: (json['tip'] as String?) ?? 'booking',
      naslov: (json['naslov'] as String?) ?? '',
      podnaslov: json['podnaslov'] as String?,
      datumVrijeme: DateTime.tryParse((json['datumVrijeme'] ?? '') as String) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}
