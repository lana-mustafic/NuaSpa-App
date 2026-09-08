/// Parses API list responses: raw JSON array or paginated `{ items: [...] }`.
List<T> parsePagedItems<T>(
  dynamic data,
  T Function(Map<String, dynamic> json) fromJson,
) {
  if (data is List) {
    return data
        .whereType<Map>()
        .map((e) => fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
  if (data is Map) {
    final items = data['items'];
    if (items is List) {
      return items
          .whereType<Map>()
          .map((e) => fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
  }
  return [];
}

/// Total row count from paginated API (`ukupno`).
int? parsePagedTotal(dynamic data) {
  if (data is Map) {
    return (data['ukupno'] as num?)?.toInt();
  }
  return null;
}

/// Walks every page until the server reports no further items.
Future<List<T>> fetchAllPagedItems<T>({
  required Future<dynamic> Function(int page, int pageSize) fetchPage,
  required T Function(Map<String, dynamic> json) fromJson,
  int pageSize = 100,
  int maxPages = 50,
}) async {
  final all = <T>[];
  for (var page = 1; page <= maxPages; page++) {
    final data = await fetchPage(page, pageSize);
    final items = parsePagedItems(data, fromJson);
    all.addAll(items);
    final total = parsePagedTotal(data);
    if (items.isEmpty ||
        items.length < pageSize ||
        (total != null && all.length >= total)) {
      break;
    }
  }
  return all;
}
