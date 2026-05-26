import 'dart:async';

import '../api/services/api_service.dart';

/// Šalje signale pretrage/pregleda na backend (debounce za pretragu).
class PreporukaTracker {
  PreporukaTracker._();
  static final PreporukaTracker instance = PreporukaTracker._();

  final ApiService _api = ApiService();
  Timer? _searchDebounce;
  String _lastLoggedSearch = '';

  void trackSearch(String query) {
    final term = query.trim();
    if (term.length < 2) return;
    if (term == _lastLoggedSearch) return;

    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 750), () async {
      _lastLoggedSearch = term;
      await _api.logPreporukaAktivnost(
        tip: 0,
        searchTerm: term,
      );
    });
  }

  void trackServiceView(int uslugaId) {
    _api.logPreporukaAktivnost(
      tip: 1,
      uslugaId: uslugaId,
    ).ignore();
  }
}

