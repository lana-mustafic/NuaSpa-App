import 'package:flutter/material.dart';

import '../../screens/admin/admin_suite_route.dart';

enum DesktopRouteKey {
  commandCenter,
  therapists,
  revenueAnalytics,
  marketing,
  reviews,
  settings,
  home,
  catalog,
  reservations,
  adminCalendar,
  favorites,
  schedule,
  therapistDashboard,
  therapistAppointments,
  therapistServices,
  therapistReviews,
  therapistProfile,
  admin,
}

class DesktopNav extends ChangeNotifier {
  static DateTimeRange defaultHeaderDateRange() {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day);
    final start = end.subtract(const Duration(days: 29));
    return DateTimeRange(start: start, end: end);
  }

  DesktopRouteKey _route = DesktopRouteKey.home;
  DateTimeRange _headerDateRange = defaultHeaderDateRange();
  int _headerFiltersPulse = 0;
  AdminSuiteRoute _adminSuiteTarget = AdminSuiteRoute.overview;
  int _adminSuiteMount = 0;
  bool _adminLandingSeeded = false;
  bool _therapistLandingSeeded = false;

  /// Jednokratni upit za [ServiceCatalogScreen] nakon navigacije iz globalne tračice.
  String? _pendingCatalogSearch;
  String? _pendingClientSearch;
  String _clientSearchQuery = '';
  String _therapistSearchQuery = '';
  String _catalogSearchQuery = '';
  String _reviewsSearchQuery = '';
  bool _pendingCatalogFavoritesTab = false;
  String? _therapistPageSummary;
  String _appointmentSearchQuery = '';
  int _appointmentCreateRequest = 0;
  int _appointmentEditRequest = 0;
  int? _appointmentEditId;
  int? _appointmentPrefillZaposlenikId;
  int _therapistAddRequest = 0;
  int _serviceAddRequest = 0;
  int _clientAddRequest = 0;

  /// Shared with [LuxuryDesktopHeader] + [AdminCalendarScreen] (single search field).
  TextEditingController? _calendarSearchCtrl;

  TextEditingController get calendarSearchController =>
      _calendarSearchCtrl ??= TextEditingController();

  DesktopRouteKey get route => _route;

  DateTimeRange get headerDateRange => _headerDateRange;

  int get headerFiltersPulse => _headerFiltersPulse;

  void setHeaderDateRange(DateTimeRange range) {
    final start = DateTime(range.start.year, range.start.month, range.start.day);
    final end = DateTime(range.end.year, range.end.month, range.end.day);
    final normalized = DateTimeRange(
      start: start.isBefore(end) ? start : end,
      end: start.isBefore(end) ? end : start,
    );
    if (_headerDateRange.start == normalized.start &&
        _headerDateRange.end == normalized.end) {
      return;
    }
    _headerDateRange = normalized;
    notifyListeners();
  }

  void pulseHeaderFilters() {
    _headerFiltersPulse++;
    notifyListeners();
  }

  int get adminSuiteMount => _adminSuiteMount;

  AdminSuiteRoute get adminSuiteTarget => _adminSuiteTarget;

  String get therapistSearchQuery => _therapistSearchQuery;

  String get catalogSearchQuery => _catalogSearchQuery;

  String get reviewsSearchQuery => _reviewsSearchQuery;

  /// One-line roster stats shown under the Therapists page subtitle.
  String? get therapistPageSummary => _therapistPageSummary;

  void setTherapistPageSummary(String? summary) {
    if (_therapistPageSummary == summary) return;
    _therapistPageSummary = summary;
    notifyListeners();
  }

  String get clientSearchQuery => _clientSearchQuery;

  String get appointmentSearchQuery => _appointmentSearchQuery;

  int get appointmentCreateRequest => _appointmentCreateRequest;

  int get appointmentEditRequest => _appointmentEditRequest;

  int get therapistAddRequest => _therapistAddRequest;

  int get serviceAddRequest => _serviceAddRequest;

  int get clientAddRequest => _clientAddRequest;

  /// Postavi defaultnu landing stranicu za admina (Command Center).
  void seedAdminLandingIfNeeded(bool isAdmin) {
    if (!isAdmin || _adminLandingSeeded) return;
    _adminLandingSeeded = true;
    if (_route == DesktopRouteKey.home) {
      _route = DesktopRouteKey.commandCenter;
      notifyListeners();
    }
  }

  /// Default landing for therapist portal (My Dashboard).
  void seedTherapistLandingIfNeeded(bool isZaposlenik) {
    if (!isZaposlenik || _therapistLandingSeeded) return;
    _therapistLandingSeeded = true;
    if (_route == DesktopRouteKey.home) {
      _route = DesktopRouteKey.therapistDashboard;
      notifyListeners();
    }
  }

  void goTo(DesktopRouteKey r) {
    if (r == DesktopRouteKey.favorites) {
      goToCatalogFavorites();
      return;
    }
    if (_route == r) return;
    if (_route == DesktopRouteKey.adminCalendar &&
        r != DesktopRouteKey.adminCalendar) {
      _calendarSearchCtrl?.clear();
    }
    _route = r;
    notifyListeners();
  }

  void goToCatalogFavorites() {
    _pendingCatalogFavoritesTab = true;
    if (_route == DesktopRouteKey.adminCalendar) {
      _calendarSearchCtrl?.clear();
    }
    if (_route != DesktopRouteKey.catalog) {
      _route = DesktopRouteKey.catalog;
    }
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

  void setReviewsSearchQuery(String raw) {
    final value = raw.trim();
    if (_reviewsSearchQuery == value && _route == DesktopRouteKey.reviews) {
      return;
    }
    _reviewsSearchQuery = value;
    if (_route != DesktopRouteKey.reviews) {
      _route = DesktopRouteKey.reviews;
    }
    notifyListeners();
  }

  void setCatalogSearchQuery(String raw) {
    final value = raw.trim();
    if (_catalogSearchQuery == value && _route == DesktopRouteKey.catalog) {
      return;
    }
    _catalogSearchQuery = value;
    _pendingCatalogSearch = value.isEmpty ? null : value;
    if (_route != DesktopRouteKey.catalog) {
      _route = DesktopRouteKey.catalog;
    }
    notifyListeners();
  }

  void goToCatalogWithSearch(String raw) {
    setCatalogSearchQuery(raw);
  }

  void goToClientsWithSearch(String raw) {
    setClientSearchQuery(raw);
  }

  void setClientSearchQuery(String raw) {
    final value = raw.trim();
    _clientSearchQuery = value;
    _pendingClientSearch = value.isEmpty ? null : value;
    goToAdminSuite(AdminSuiteRoute.clients);
  }

  String? takePendingClientSearch() {
    final q = _pendingClientSearch;
    _pendingClientSearch = null;
    return q;
  }

  /// Dashboard global search — routes to the best admin screen for the query.
  void performAdminGlobalSearch(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return;

    if (t.contains('@')) {
      goToClientsWithSearch(t);
      return;
    }

    final lower = t.toLowerCase();
    const serviceHints = [
      'massage',
      'facial',
      'spa',
      'therapy',
      'treatment',
      'usluga',
      'service',
      'beauty',
      'brow',
      'lash',
      'makeup',
      'make-up',
      'wellness',
      'body',
    ];
    if (serviceHints.any((h) => lower.contains(h))) {
      goToCatalogWithSearch(t);
      return;
    }

    setAppointmentSearchQuery(t);
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

  void requestAppointmentEdit(int rezervacijaId) {
    if (_route == DesktopRouteKey.adminCalendar) {
      _calendarSearchCtrl?.clear();
    }
    _appointmentEditId = rezervacijaId;
    _appointmentEditRequest++;
    if (_route != DesktopRouteKey.reservations) {
      _route = DesktopRouteKey.reservations;
    }
    notifyListeners();
  }

  int? takeAppointmentEditId() {
    final v = _appointmentEditId;
    _appointmentEditId = null;
    return v;
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

  void requestServiceAdd() {
    _serviceAddRequest++;
    if (_route != DesktopRouteKey.catalog) {
      _route = DesktopRouteKey.catalog;
    }
    notifyListeners();
  }

  void requestClientAdd() {
    _clientAddRequest++;
    goToAdminSuite(AdminSuiteRoute.clients);
    notifyListeners();
  }

  String? takePendingCatalogSearch() {
    final q = _pendingCatalogSearch;
    _pendingCatalogSearch = null;
    return q;
  }

  bool takePendingCatalogFavoritesTab() {
    final pending = _pendingCatalogFavoritesTab;
    _pendingCatalogFavoritesTab = false;
    return pending;
  }
}
