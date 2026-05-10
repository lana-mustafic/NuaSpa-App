import 'package:flutter/material.dart';

enum DesktopRouteKey { home, catalog, reservations, favorites, schedule, admin }

class DesktopNav extends ChangeNotifier {
  DesktopRouteKey _route = DesktopRouteKey.home;

  /// Jednokratni upit za [ServiceCatalogScreen] nakon navigacije iz globalne tračice.
  String? _pendingCatalogSearch;

  DesktopRouteKey get route => _route;

  void goTo(DesktopRouteKey r) {
    if (_route == r) return;
    _route = r;
    notifyListeners();
  }

  /// Otvori katalog i propagiraj početnu pretragu (prazna vrijednost = samo navigacija).
  void goToCatalogWithSearch(String raw) {
    final t = raw.trim();
    _pendingCatalogSearch = t.isEmpty ? null : t;
    goTo(DesktopRouteKey.catalog);
  }

  /// Katalog mora pozvati jednom po mount-u i ostvariti tekst polja ako postoji vrijednost.
  String? takePendingCatalogSearch() {
    final q = _pendingCatalogSearch;
    _pendingCatalogSearch = null;
    return q;
  }
}
