enum ZaposlenikStatus {
  active(0, 'Active'),
  inactive(1, 'Inactive'),
  onLeave(2, 'On Leave');

  const ZaposlenikStatus(this.apiValue, this.label);

  final int apiValue;
  final String label;

  static ZaposlenikStatus fromApi(dynamic value) {
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
