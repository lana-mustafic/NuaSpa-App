import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/api/auth_repository.dart';
import '../core/jwt_roles.dart';

enum AuthStatus { unauthenticated, authenticating, authenticated, error }

class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.unauthenticated;
  final AuthRepository _repository = AuthRepository();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  List<String> _roles = [];
  int? _zaposlenikId;

  AuthStatus get status => _status;

  List<String> get roles => List.unmodifiable(_roles);

  bool get isAdmin => _roles.contains('Admin');

  bool get isZaposlenik => _roles.contains('Zaposlenik');

  /// Iz JWT claim-a `ZaposlenikId` (samo ako je korisnik vezan za zaposlenika).
  int? get zaposlenikId => _zaposlenikId;

  Future<void> _refreshRolesFromToken() async {
    final token = await _storage.read(key: 'jwt_token');
    _roles = parseJwtRoles(token);
    _zaposlenikId = parseJwtIntClaim(token, 'ZaposlenikId');
  }

  Future<bool> login(String username, String password) async {
    _status = AuthStatus.authenticating;
    notifyListeners();

    try {
      debugPrint("Pokušaj logina za: $username na http://10.0.2.2:7155/api");
      final response = await _repository.login(username, password);
      
      // Provjeravamo da li response sadrži token
      if (response.data != null && response.data['token'] != null) {
        final token = response.data['token'];
        await _storage.write(key: 'jwt_token', value: token);
        await _refreshRolesFromToken();

        _status = AuthStatus.authenticated;
        notifyListeners();
        return true;
      } else {
        debugPrint("Login uspio, ali token nije pronađen u odgovoru.");
        _roles = [];
        _zaposlenikId = null;
        _status = AuthStatus.error;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint("Login Error: $e"); // Ovo će ti reći ako je Connection Refused
      _roles = [];
      _zaposlenikId = null;
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<void> checkAuthState() async {
    try {
      String? token = await _storage.read(key: 'jwt_token');
      if (token != null) {
        await _refreshRolesFromToken();
        _status = AuthStatus.authenticated;
      } else {
        _roles = [];
        _zaposlenikId = null;
        _status = AuthStatus.unauthenticated;
      }
    } catch (e) {
      _roles = [];
      _zaposlenikId = null;
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<void> logout() async {
    await _storage.delete(key: 'jwt_token');
    _roles = [];
    _zaposlenikId = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}