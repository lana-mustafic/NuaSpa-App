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

  // Getteri
  List<Usluga> get services => _filteredServices;
  bool get isLoading => _isLoading;
  Set<int> get favoriteIds => _favoriteIds;
  bool isFavorite(int uslugaId) => _favoriteIds.contains(uslugaId);

  // Funkcija za povlačenje podataka
  Future<void> fetchServices() async {
    _isLoading = true;
    notifyListeners();

    try {
      _favoriteIds = await _apiService.getMyFavoriteIds();
      _allServices = await _apiService.getUsluge();
      _filteredServices = _allServices; // Na početku, prikazujemo sve
    } catch (e) {
      debugPrint("Greška pri dohvatu usluga: $e");
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
    if (wasFavorite) {
      _favoriteIds.remove(uslugaId);
    } else {
      _favoriteIds.add(uslugaId);
    }
    notifyListeners();

    try {
      if (wasFavorite) {
        await _apiService.removeFavorite(uslugaId);
      } else {
        await _apiService.addFavorite(uslugaId);
      }
    } catch (e) {
      // rollback
      if (wasFavorite) {
        _favoriteIds.add(uslugaId);
      } else {
        _favoriteIds.remove(uslugaId);
      }
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