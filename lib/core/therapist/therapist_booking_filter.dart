import '../../models/usluga.dart';
import '../../models/zaposlenik.dart';
import '../../models/zaposlenik_status.dart';

/// Filters therapists eligible for a service (client-side fallback).
List<Zaposlenik> filterTherapistsForService(
  List<Zaposlenik> therapists,
  Usluga? service, {
  bool bookableOnly = true,
}) {
  if (service == null) {
    return bookableOnly
        ? therapists.where((t) => t.status.isBookable).toList()
        : therapists;
  }

  final serviceName = service.naziv.trim().toLowerCase();
  return therapists.where((t) {
    if (bookableOnly && !t.status.isBookable) return false;
    if (t.kategorijaUslugaId != null &&
        t.kategorijaUslugaId != service.kategorijaUslugaId) {
      return false;
    }
    final specs = t.specijalizacija
        .split(RegExp(r'[,;/]'))
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty);
    return specs.any((s) => s == serviceName);
  }).toList();
}
