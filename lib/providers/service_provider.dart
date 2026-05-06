import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../models/usluga.dart';
// Provjeri da li je putanja tačna prema tvom folderu:
import '../core/api/services/api_service.dart';

class ServiceProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<Usluga> _allServices = [];      // SVE usluge koje dobijemo s API-ja
  List<Usluga> _filteredServices = []; // Samo one koje prikazujemo (nakon pretrage)
  bool _isLoading = false;
  Set<int> _favoriteIds = {};
  String? _loadError;

  // Getteri
  List<Usluga> get services => _filteredServices;

  /// Sve učitane usluge (bez pretrage u katalogu). Koristiti za dropdowne npr. kod rezervacije.
  List<Usluga> get allServices => List<Usluga>.unmodifiable(_allServices);

  bool get isLoading => _isLoading;
  Set<int> get favoriteIds => _favoriteIds;
  bool isFavorite(int uslugaId) => _favoriteIds.contains(uslugaId);

  /// Postavljen ako zadnji [fetchServices] nije uspio (npr. nema konekcije).
  String? get loadError => _loadError;
  bool get loadFailed => _loadError != null;

  static String _mapLoadError(Object e) {
    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Isteklo je vrijeme čekanja. Provjerite mrežu i da li je API dostupan.';
        case DioExceptionType.connectionError:
          return 'Nema veze sa serverom. Pokrenite backend ili provjerite NUASPA_API_BASE_URL.';
        case DioExceptionType.badCertificate:
          return 'Problem sa HTTPS certifikatom (dev: koristite HTTP ili povjereni certifikat).';
        case DioExceptionType.badResponse:
          final code = e.response?.statusCode;
          if (code == 401) {
            return 'Niste prijavljeni ili je sesija istekla. Prijavite se ponovo.';
          }
          return 'Server je vratio grešku (${code ?? '?'}).';
        default:
          break;
      }
    }
    return 'Došlo je do greške pri učitavanju. Pokušajte ponovo.';
  }

  // Funkcija za povlačenje podataka
  Future<void> fetchServices() async {
    _loadError = null;
    _isLoading = true;
    notifyListeners();

    try {
      _favoriteIds = await _apiService.getMyFavoriteIds();
      _allServices = await _apiService.getUsluge();
      _filteredServices = _allServices; // Na početku, prikazujemo sve
      _loadError = null;
    } catch (e, st) {
      debugPrint('Greška pri dohvatu usluga: $e\n$st');
      _loadError = _mapLoadError(e);
      _allServices = [];
      _filteredServices = [];
      _favoriteIds = {};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshFavorites() async {
    try {
      _favoriteIds = await _apiService.getMyFavoriteIds();
      notifyListeners();
    } catch (e) {
      debugPrint("Greška pri dohvatu favorita: $e");
    }
  }

  Future<void> toggleFavorite(int uslugaId) async {
    final wasFavorite = _favoriteIds.contains(uslugaId);
    final previousIds = Set<int>.from(_favoriteIds);

    if (wasFavorite) {
      _favoriteIds.remove(uslugaId);
    } else {
      _favoriteIds.add(uslugaId);
    }
    notifyListeners();

    try {
      final ok = wasFavorite
          ? await _apiService.removeFavorite(uslugaId)
          : await _apiService.addFavorite(uslugaId);
      if (!ok) {
        _favoriteIds = previousIds;
        notifyListeners();
      }
    } catch (e) {
      _favoriteIds = previousIds;
      notifyListeners();
      debugPrint("Greška pri toggle favorite: $e");
    }
  }

  List<Usluga> get favoriteServices =>
      _allServices.where((u) => _favoriteIds.contains(u.id)).toList();

  // Funkcija za pretragu (Search) - pozivaćemo je iz TextField-a
  void searchServices(String query) {
    if (query.isEmpty) {
      _filteredServices = _allServices;
    } else {
      _filteredServices = _allServices
          .where((usluga) =>
              usluga.naziv.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
    notifyListeners(); // Javljamo UI-u da se lista promijenila
  }

  // Opcionalno: Filtriranje po kategoriji
  void filterByCategory(String category) {
    if (category == "Sve") {
      _filteredServices = _allServices;
    } else {
      _filteredServices = _allServices
          .where((usluga) => usluga.kategorija == category)
          .toList();
    }
    notifyListeners();
  }
}