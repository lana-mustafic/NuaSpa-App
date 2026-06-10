import '../../models/usluga.dart';
import '../../models/zaposlenik.dart';
import '../../models/zaposlenik_status.dart';

/// Mirrors backend [TherapistServiceEligibility] for client-side fallbacks.
List<String> parseTherapistSpecNames(String raw) => raw
    .split(RegExp(r'[,;/]'))
    .map((e) => e.trim())
    .where((e) => e.isNotEmpty)
    .fold<List<String>>([], (acc, name) {
      if (!acc.any((e) => e.toLowerCase() == name.toLowerCase())) {
        acc.add(name);
      }
      return acc;
    });

bool therapistIsEligibleForService(
  Zaposlenik therapist,
  Usluga service, {
  bool requireActive = false,
}) {
  if (requireActive && therapist.status != ZaposlenikStatus.active) {
    return false;
  }

  final katId = therapist.kategorijaUslugaId;
  if (katId == null || katId <= 0 || katId != service.kategorijaUslugaId) {
    return false;
  }

  final serviceName = service.naziv.trim();
  if (serviceName.isEmpty) return false;

  final target = serviceName.toLowerCase();
  return parseTherapistSpecNames(therapist.specijalizacija)
      .any((name) => name.toLowerCase() == target);
}

List<Usluga> linkedServicesForTherapist(
  Zaposlenik therapist,
  List<Usluga> all, {
  bool requireActive = false,
}) {
  return all
      .where(
        (u) => therapistIsEligibleForService(
          therapist,
          u,
          requireActive: requireActive,
        ),
      )
      .toList()
    ..sort((a, b) => a.naziv.compareTo(b.naziv));
}

List<String> specializationTagsFor(Zaposlenik therapist) =>
    parseTherapistSpecNames(therapist.specijalizacija);

String therapistInitials(Zaposlenik therapist) {
  String firstChar(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    return String.fromCharCode(trimmed.runes.first).toUpperCase();
  }

  final a = firstChar(therapist.ime);
  final b = firstChar(therapist.prezime);
  final s = '$a$b';
  return s.isEmpty ? 'TH' : s;
}
