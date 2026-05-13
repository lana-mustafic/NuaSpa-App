import 'package:flutter/material.dart';

import '../../screens/admin/admin_suite_route.dart';

enum DesktopRouteKey {
  commandCenter,
  therapists,
  revenueAnalytics,
  marketing,
  packages,
  reviews,
  settings,
  home,
  catalog,
  reservations,
  adminCalendar,
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
  String _therapistSearchQuery = '';
  String _appointmentSearchQuery = '';
  int _appointmentCreateRequest = 0;
  int? _appointmentPrefillZaposlenikId;
  int _therapistAddRequest = 0;

  /// Shared with [LuxuryDesktopHeader] + [AdminCalendarScreen] (single search field).
  TextEditingController? _calendarSearchCtrl;

  TextEditingController get calendarSearchController =>
      _calendarSearchCtrl ??= TextEditingController();

  DesktopRouteKey get route => _route;

  int get adminSuiteMount => _adminSuiteMount;

  AdminSuiteRoute get adminSuiteTarget => _adminSuiteTarget;

  String get therapistSearchQuery => _therapistSearchQuery;

  String get appointmentSearchQuery => _appointmentSearchQuery;

  int get appointmentCreateRequest => _appointmentCreateRequest;

  int get therapistAddRequest => _therapistAddRequest;

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
    if (_route == DesktopRouteKey.adminCalendar &&
        r != DesktopRouteKey.adminCalendar) {
      _calendarSearchCtrl?.clear();
    }
    _route = r;
    notifyListeners();
  }

  void goToAdminSuite(AdminSuiteRoute target) {
    if (_route == DesktopRouteKey.adminCalendar) {
      _calendarSearchCtrl?.clear();
    }
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

  void setTherapistSearchQuery(String raw) {
    if (_route == DesktopRouteKey.adminCalendar) {
      _calendarSearchCtrl?.clear();
    }
    final value = raw.trim();
    if (_therapistSearchQuery == value) return;
    _therapistSearchQuery = value;
    if (_route != DesktopRouteKey.therapists) {
      _route = DesktopRouteKey.therapists;
    }
    notifyListeners();
  }

  void setAppointmentSearchQuery(String raw) {
    if (_route == DesktopRouteKey.adminCalendar) {
      _calendarSearchCtrl?.clear();
    }
    final value = raw.trim();
    if (_appointmentSearchQuery == value) return;
    _appointmentSearchQuery = value;
    if (_route != DesktopRouteKey.reservations) {
      _route = DesktopRouteKey.reservations;
    }
    notifyListeners();
  }

  void requestAppointmentCreate({int? zaposlenikId}) {
    if (_route == DesktopRouteKey.adminCalendar) {
      _calendarSearchCtrl?.clear();
    }
    _appointmentPrefillZaposlenikId = zaposlenikId;
    _appointmentCreateRequest++;
    if (_route != DesktopRouteKey.reservations) {
      _route = DesktopRouteKey.reservations;
    }
    notifyListeners();
  }

  /// Called when opening the admin "New appointment" dialog (consumes one-shot prefill).
  int? takeAppointmentPrefillZaposlenikId() {
    final v = _appointmentPrefillZaposlenikId;
    _appointmentPrefillZaposlenikId = null;
    return v;
  }

  void requestTherapistAdd() {
    if (_route == DesktopRouteKey.adminCalendar) {
      _calendarSearchCtrl?.clear();
    }
    _therapistAddRequest++;
    if (_route != DesktopRouteKey.therapists) {
      _route = DesktopRouteKey.therapists;
    }
    notifyListeners();
  }

  String? takePendingCatalogSearch() {
    final q = _pendingCatalogSearch;
    _pendingCatalogSearch = null;
    return q;
  }
}
