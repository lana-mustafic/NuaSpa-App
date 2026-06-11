enum ZaposlenikStatus {
  active(0, 'Active'),
  inactive(1, 'Inactive'),
  onLeave(2, 'On Leave');

  const ZaposlenikStatus(this.apiValue, this.label);

  final int apiValue;
  final String label;

  static ZaposlenikStatus fromApi(dynamic value) {
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      for (final status in ZaposlenikStatus.values) {
        if (status.label.toLowerCase() == normalized ||
            status.name.toLowerCase() == normalized) {
          return status;
        }
      }
    }
    final n = value is int
        ? value
        : value is num
            ? value.toInt()
            : int.tryParse(value?.toString() ?? '') ?? 0;
    return ZaposlenikStatus.values.firstWhere(
      (s) => s.apiValue == n,
      orElse: () => ZaposlenikStatus.active,
    );
  }

  bool get isBookable => this == ZaposlenikStatus.active;
}
