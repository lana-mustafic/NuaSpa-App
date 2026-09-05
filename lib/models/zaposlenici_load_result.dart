import 'zaposlenik.dart';

class ZaposleniciLoadResult {
  const ZaposleniciLoadResult({
    this.items = const [],
    this.error,
  });

  final List<Zaposlenik> items;
  final String? error;

  bool get hasError => error != null && error!.isNotEmpty;
}
