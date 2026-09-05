/// Outcome of a read that can succeed with an empty collection or fail.
class ApiListResult<T> {
  const ApiListResult({
    this.items = const [],
    this.error,
  });

  final List<T> items;
  final String? error;

  bool get hasError => error != null && error!.isNotEmpty;
}

/// Outcome of a read that returns a single value (count, id set, …).
class ApiValueResult<T> {
  const ApiValueResult({
    this.value,
    this.error,
  });

  final T? value;
  final String? error;

  bool get hasError => error != null && error!.isNotEmpty;
}
