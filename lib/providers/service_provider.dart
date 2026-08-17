import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../models/kategorija_usluga.dart';
import '../models/usluga.dart';
import '../core/api/services/api_service.dart';
import '../core/preporuka/preporuka_tracker.dart';

enum ServiceCatalogTab { all, favorites }

enum ServiceCatalogSort {
  nameAsc,
  nameDesc,
  priceAsc,
  priceDesc,
  durationDesc,
}

extension ServiceCatalogSortLabels on ServiceCatalogSort {
  String get label => switch (this) {
        ServiceCatalogSort.nameAsc => 'A to Z',
        ServiceCatalogSort.nameDesc => 'Z to A',
        ServiceCatalogSort.priceAsc => 'Price: low to high',
        ServiceCatalogSort.priceDesc => 'Price: high to low',
        ServiceCatalogSort.durationDesc => 'Duration: longest first',
      };
}

class ServiceProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<Usluga> _allServices = [];
  List<Usluga> _filteredServices = [];
  List<KategorijaUsluga> _categories = [];
  List<Usluga> _favoriteServices = [];
  bool _isLoading = false;
  bool _favoritesLoading = false;
  Set<int> _favoriteIds = {};
  String? _loadError;
  String? _favoritesError;
  String _searchQuery = '';
  int? _selectedCategoryId;
  ServiceCatalogTab _catalogTab = ServiceCatalogTab.all;
  ServiceCatalogSort _sortMode = ServiceCatalogSort.nameAsc;

  List<Usluga> get services => _filteredServices;

  /// Sve učitane usluge (bez filtera kataloga). Koristiti za dropdowne npr. kod rezervacije.
  List<Usluga> get allServices => List<Usluga>.unmodifiable(_allServices);

  List<KategorijaUsluga> get categories =>
      List<KategorijaUsluga>.unmodifiable(_categories);

  int? get selectedCategoryId => _selectedCategoryId;

  String get searchQuery => _searchQuery;

  ServiceCatalogTab get catalogTab => _catalogTab;

  ServiceCatalogSort get sortMode => _sortMode;

  bool get isFavoritesTab => _catalogTab == ServiceCatalogTab.favorites;

  bool get isLoading => _isLoading;
  bool get favoritesLoading => _favoritesLoading;
  List<Usluga> get favoriteServices =>
      List<Usluga>.unmodifiable(_favoriteServices);
  Set<int> get favoriteIds => _favoriteIds;
  bool isFavorite(int uslugaId) => _favoriteIds.contains(uslugaId);
  String? get favoritesError => _favoritesError;

  /// Postavljen ako zadnji [fetchServices] nije uspio (npr. nema konekcije).
  String? get loadError => _loadError;
  bool get loadFailed => _loadError != null;

  static String _mapLoadError(Object e) {
    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Request timed out. Check your network and that the API is available.';
        case DioExceptionType.connectionError:
          return 'Cannot reach the server. Start the backend or check API_BASE_URL.';
        case DioExceptionType.badCertificate:
          return 'HTTPS certificate issue (dev: use HTTP or a trusted certificate).';
        case DioExceptionType.badResponse:
          final code = e.response?.statusCode;
          if (code == 401) {
            return 'You are not signed in or your session expired. Sign in again.';
          }
          return 'The server returned an error (${code ?? '?'}).';
        default:
          break;
      }
    }
    return 'Something went wrong while loading. Please try again.';
  }

  // Funkcija za povlačenje podataka
  Future<void> fetchServices() async {
    _loadError = null;
    _isLoading = true;
    notifyListeners();

    try {
      final servicesAndCategories = await Future.wait([
        _apiService.getUslugeAll(),
        _apiService.getKategorijeUslugaAll(),
      ]);
      _allServices = servicesAndCategories[0] as List<Usluga>;
      _categories = servicesAndCategories[1] as List<KategorijaUsluga>;

      var favoriteIds = <int>{};
      try {
        favoriteIds = await _apiService.getMyFavoriteIds();
      } catch (e, st) {
        debugPrint('Greška pri dohvatu favorita: $e\n$st');
      }
      _favoriteIds = favoriteIds;
      _favoriteServices = _allServices
          .where((u) => _favoriteIds.contains(u.id))
          .toList();
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
      _favoriteServices = [];
      _favoriteIds = {};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchFavorites() async {
    _favoritesLoading = true;
    _favoritesError = null;
    notifyListeners();

    try {
      final list = await _apiService.getMyFavorites();
      _applyFavoriteList(list);
      _favoritesError = null;
    } catch (e, st) {
      debugPrint('Greška pri dohvatu favorita: $e\n$st');
      _favoritesError = _mapLoadError(e);
    } finally {
      _favoritesLoading = false;
      notifyListeners();
    }
  }

  void _applyFavoriteList(List<Usluga> list) {
    _favoriteServices = list;
    _favoriteIds = list.map((u) => u.id).toSet();
  }

  Future<bool> toggleFavorite(int uslugaId) async {
    final wasFavorite = _favoriteIds.contains(uslugaId);
    final previousIds = Set<int>.from(_favoriteIds);

    if (wasFavorite) {
      _favoriteIds.remove(uslugaId);
    } else {
      _favoriteIds.add(uslugaId);
    }
    _favoriteServices = _allServices
        .where((u) => _favoriteIds.contains(u.id))
        .toList();
    _applyFilters();

    try {
      final ok = wasFavorite
          ? await _apiService.removeFavorite(uslugaId)
          : await _apiService.addFavorite(uslugaId);
      if (!ok) {
        _favoriteIds = previousIds;
        _favoriteServices = _allServices
            .where((u) => _favoriteIds.contains(u.id))
            .toList();
        _applyFilters();
        return false;
      }
      await fetchFavorites();
      _applyFilters();
      return true;
    } catch (e) {
      _favoriteIds = previousIds;
      _favoriteServices = _allServices
          .where((u) => _favoriteIds.contains(u.id))
          .toList();
      _applyFilters();
      debugPrint('Greška pri toggle favorite: $e');
      return false;
    }
  }

  void searchServices(String query, {bool trackForRecommender = true}) {
    _searchQuery = query.trim();
    _applyFilters();
    if (trackForRecommender) {
      PreporukaTracker.instance.trackSearch(_searchQuery);
    }
  }

  void setCategoryFilter(int? categoryId) {
    _selectedCategoryId = categoryId;
    _applyFilters();
  }

  void clearCatalogFilters() {
    _searchQuery = '';
    _selectedCategoryId = null;
    _sortMode = ServiceCatalogSort.nameAsc;
    _applyFilters();
  }

  void setSortMode(ServiceCatalogSort mode) {
    if (_sortMode == mode) return;
    _sortMode = mode;
    _applyFilters();
  }

  void setCatalogTab(ServiceCatalogTab tab) {
    if (_catalogTab == tab) return;
    _catalogTab = tab;
    _applyFilters();
  }

  void _applyFilters() {
    var list = _allServices;
    if (_catalogTab == ServiceCatalogTab.favorites) {
      list = list.where((u) => _favoriteIds.contains(u.id)).toList();
    }
    if (_selectedCategoryId != null) {
      list = list
          .where((u) => u.kategorijaUslugaId == _selectedCategoryId)
          .toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where(
            (u) =>
                u.naziv.toLowerCase().contains(q) ||
                u.kategorija.toLowerCase().contains(q) ||
                u.opis.toLowerCase().contains(q),
          )
          .toList();
    }
    _filteredServices = _sortServices(list);
    notifyListeners();
  }

  List<Usluga> _sortServices(List<Usluga> list) {
    final copy = List<Usluga>.from(list);
    switch (_sortMode) {
      case ServiceCatalogSort.nameDesc:
        copy.sort((a, b) => b.naziv.compareTo(a.naziv));
      case ServiceCatalogSort.priceAsc:
        copy.sort((a, b) => a.cijena.compareTo(b.cijena));
      case ServiceCatalogSort.priceDesc:
        copy.sort((a, b) => b.cijena.compareTo(a.cijena));
      case ServiceCatalogSort.durationDesc:
        copy.sort((a, b) => b.trajanjeMinuta.compareTo(a.trajanjeMinuta));
      case ServiceCatalogSort.nameAsc:
        copy.sort((a, b) => a.naziv.compareTo(b.naziv));
    }
    return copy;
  }
}