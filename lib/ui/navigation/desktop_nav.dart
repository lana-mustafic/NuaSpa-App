import 'package:flutter/material.dart';

enum DesktopRouteKey {
  home,
  catalog,
  reservations,
  favorites,
  schedule,
  admin,
}

class DesktopNav extends ChangeNotifier {
  DesktopRouteKey _route = DesktopRouteKey.home;

  DesktopRouteKey get route => _route;

  void goTo(DesktopRouteKey r) {
    if (_route == r) return;
    _route = r;
    notifyListeners();
  }
}

