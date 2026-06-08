import 'usluga.dart';

class ServiceLoadResult {
  const ServiceLoadResult({
    this.service,
    this.error,
    this.notFound = false,
  });

  final Usluga? service;
  final String? error;
  final bool notFound;
}
