import '../../providers/auth_provider.dart';

/// Central role and route guards — avoid scattering role checks in widgets.
enum AppRole { admin, therapist, client }

enum AppPermission {
  manageTherapists,
  viewAllClients,
  viewAllPayments,
  viewAllReports,
  manageAdminSettings,
  viewOwnTherapistData,
  updateOwnTherapistProfile,
  manageOwnAppointments,
  bookAppointments,
}

class AppPermissions {
  AppPermissions(this._auth);

  final AuthProvider _auth;

  static AppPermissions of(AuthProvider auth) => AppPermissions(auth);

  AppRole get primaryRole {
    if (_auth.isAdmin) return AppRole.admin;
    if (_auth.isZaposlenik) return AppRole.therapist;
    return AppRole.client;
  }

  bool has(AppPermission permission) {
    switch (permission) {
      case AppPermission.manageTherapists:
      case AppPermission.viewAllClients:
      case AppPermission.viewAllPayments:
      case AppPermission.viewAllReports:
      case AppPermission.manageAdminSettings:
        return _auth.isAdmin;
      case AppPermission.viewOwnTherapistData:
      case AppPermission.updateOwnTherapistProfile:
      case AppPermission.manageOwnAppointments:
        return _auth.isZaposlenik && _auth.zaposlenikId != null;
      case AppPermission.bookAppointments:
        return _auth.isAdmin || !_auth.isZaposlenik;
    }
  }

  /// Therapist may only access their own [zaposlenikId].
  bool canAccessTherapistRecord(int zaposlenikId) {
    if (_auth.isAdmin) return true;
    if (_auth.isZaposlenik) return _auth.zaposlenikId == zaposlenikId;
    return false;
  }
}
