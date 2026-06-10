import '../usluga.dart';
import '../zaposlenik.dart';

/// Result of loading the therapist's certified service list.
class TherapistMyServicesResult {
  const TherapistMyServicesResult({
    this.therapist,
    this.services = const [],
    this.error,
    this.profileError,
    this.servicesError,
    this.accountNotLinked = false,
  });

  final Zaposlenik? therapist;
  final List<Usluga> services;
  final String? error;
  final String? profileError;
  final String? servicesError;
  final bool accountNotLinked;

  bool get hasError =>
      error != null || profileError != null || servicesError != null;

  bool get isPartialSuccess =>
      therapist != null && servicesError != null && error == null;
}
