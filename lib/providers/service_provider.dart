import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../models/kategorija_usluga.dart';
import '../models/usluga.dart';
import '../core/api/services/api_service.dart';

class ServiceProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<Usluga> _allServices = [];
  List<Usluga> _filteredServices = [];
  List<KategorijaUsluga> _categories = [];
  bool _isLoading = false;
  Set<int> _favoriteIds = {};
  String? _loadError;
  String _searchQuery = '';
  int? _selectedCategoryId;

  List<Usluga> get services => _filteredServices;

  /// Sve učitane usluge (bez filtera kataloga). Koristiti za dropdowne npr. kod rezervacije.
  List<Usluga> get allServices => List<Usluga>.unmodifiable(_allServices);

  List<KategorijaUsluga> get categories =>
      List<KategorijaUsluga>.unmodifiable(_categories);

  int? get selectedCategoryId => _selectedCategoryId;

  String get searchQuery => _searchQuery;

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
      final results = await Future.wait([
        _apiService.getUsluge(),
        _apiService.getKategorijeUsluga(),
      ]);
      _allServices = results[0] as List<Usluga>;
      _categories = results[1] as List<KategorijaUsluga>;
      if (_selectedCategoryId != null &&
          !_categories.any((c) => c.id == _selectedCategoryId)) {
        _selectedCategoryId = null;
      }
      _applyFilters();
      _loadError = null;
    } catch (e, st) {
      debugPrint('Greška pri dohvatu usluga: $e\n$st');
      _loadError = _mapLoadError(e);
      _allServices = [];
      _filteredServices = [];
      _categories = [];
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

  void searchServices(String query) {
    _searchQuery = query.trim();
    _applyFilters();
  }

  void setCategoryFilter(int? categoryId) {
    _selectedCategoryId = categoryId;
    _applyFilters();
  }

  void clearCatalogFilters() {
    _searchQuery = '';
    _selectedCategoryId = null;
    _applyFilters();
  }

  void _applyFilters() {
    var list = _allServices;
    if (_selectedCategoryId != null) {
      list = list
          .where((u) => u.kategorijaUslugaId == _selectedCategoryId)
          .toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((u) => u.naziv.toLowerCase().contains(q))
          .toList();
    }
    _filteredServices = list;
    notifyListeners();
  }
}