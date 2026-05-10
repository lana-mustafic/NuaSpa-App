import 'package:flutter/material.dart';

import '../../screens/admin/admin_suite_route.dart';

enum DesktopRouteKey {
  commandCenter,
  marketing,
  settings,
  home,
  catalog,
  reservations,
  favorites,
  schedule,
  admin,
}

class DesktopNav extends ChangeNotifier {
  DesktopRouteKey _route = DesktopRouteKey.home;
  AdminSuiteRoute _adminSuiteTarget = AdminSuiteRoute.overview;
  int _adminSuiteMount = 0;
  bool _adminLandingSeeded = false;

  /// Jednokratni upit za [ServiceCatalogScreen] nakon navigacije iz globalne tračice.
  String? _pendingCatalogSearch;

  DesktopRouteKey get route => _route;

  int get adminSuiteMount => _adminSuiteMount;

  AdminSuiteRoute get adminSuiteTarget => _adminSuiteTarget;

  /// Postavi defaultnu landing stranicu za admina (Command Center).
  void seedAdminLandingIfNeeded(bool isAdmin) {
    if (!isAdmin || _adminLandingSeeded) return;
    _adminLandingSeeded = true;
    if (_route == DesktopRouteKey.home) {
      _route = DesktopRouteKey.commandCenter;
      notifyListeners();
    }
  }

  void goTo(DesktopRouteKey r) {
    if (_route == r) return;
    _route = r;
    notifyListeners();
  }

  void goToAdminSuite(AdminSuiteRoute target) {
    _adminSuiteTarget = target;
    _adminSuiteMount++;
    if (_route != DesktopRouteKey.admin) {
      _route = DesktopRouteKey.admin;
    }
    notifyListeners();
  }

  void goToCatalogWithSearch(String raw) {
    final t = raw.trim();
    _pendingCatalogSearch = t.isEmpty ? null : t;
    goTo(DesktopRouteKey.catalog);
  }

  String? takePendingCatalogSearch() {
    final q = _pendingCatalogSearch;
    _pendingCatalogSearch = null;
    return q;
  }
}
