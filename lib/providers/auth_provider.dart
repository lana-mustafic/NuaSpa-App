import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async';
import '../core/api/auth_repository.dart';
import '../core/api/services/api_service.dart';
import '../core/jwt_roles.dart';
import '../core/auth/auth_events.dart';

enum AuthStatus {
  initializing,
  unauthenticated,
  authenticating,
  authenticated,
  error,
}

class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.initializing;
  final AuthRepository _repository = AuthRepository();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  List<String> _roles = [];
  int? _zaposlenikId;
  String? _loggedInUsername;
  StreamSubscription<AuthEvent>? _authEventsSub;
  String? _infoMessage;

  AuthStatus get status => _status;
  String? get infoMessage => _infoMessage;

  AuthProvider() {
    _authEventsSub = AuthEvents.instance.stream.listen((event) async {
      if (event is AuthEventForceLogout) {
        _infoMessage = event.message ?? 'Please sign in again.';
        await logout();
      }
    });
  }

  List<String> get roles => List.unmodifiable(_roles);

  bool get isAdmin => _roles.contains('Admin');

  bool get isZaposlenik => _roles.contains('Zaposlenik');

  /// Iz JWT claim-a `ZaposlenikId` (samo ako je korisnik vezan za zaposlenika).
  int? get zaposlenikId => _zaposlenikId;

  String? get displayName => _loggedInUsername;

  String? get userInitials {
    final u = _loggedInUsername?.trim();
    if (u == null || u.isEmpty) return null;
    final parts = u.split(RegExp(r'[\s._@]+')).where((e) => e.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    return u.length >= 2 ? u.substring(0, 2).toUpperCase() : u.toUpperCase();
  }

  String? get userAvatarUrl => null;

  Future<void> _refreshRolesFromToken() async {
    final token = await _storage.read(key: 'jwt_token');
    _roles = parseJwtRoles(token);
    _zaposlenikId = parseJwtIntClaim(token, 'ZaposlenikId');
    _loggedInUsername ??= parseJwtStringClaim(token, 'unique_name');
  }

  Future<bool> login(String username, String password) async {
    _status = AuthStatus.authenticating;
    notifyListeners();

    try {
      debugPrint(
        "Pokušaj logina za: $username na ${_repository.baseUrlForDebug}",
      );
      final response = await _repository.login(username, password);
      
      // Provjeravamo da li response sadrži token
      if (response.data != null && response.data['token'] != null) {
        final token = response.data['token'];
        await _storage.write(key: 'jwt_token', value: token);
        _loggedInUsername = username.trim();
        await _refreshRolesFromToken();
        _status = AuthStatus.authenticated;
        notifyListeners();
        return true;
      } else {
        debugPrint("Login uspio, ali token nije pronađen u odgovoru.");
        _roles = [];
        _zaposlenikId = null;
        _loggedInUsername = null;
        _status = AuthStatus.error;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint("Login Error: $e"); // Ovo će ti reći ako je Connection Refused
      _roles = [];
      _zaposlenikId = null;
      _loggedInUsername = null;
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<void> checkAuthState() async {
    _status = AuthStatus.initializing;
    notifyListeners();
    await _syncSessionFromStorage();
    notifyListeners();
  }

  /// Re-reads JWT claims without flipping the app into initializing state.
  Future<bool> reloadLocalSession() async {
    final previous = _status;
    await _syncSessionFromStorage();
    if (_status == AuthStatus.unauthenticated &&
        previous == AuthStatus.authenticated) {
      notifyListeners();
      return false;
    }
    if (_status != previous) {
      notifyListeners();
    }
    return _status == AuthStatus.authenticated;
  }

  Future<void> applySessionToken(String token, {String? username}) async {
    await _storage.write(key: 'jwt_token', value: token);
    if (username != null && username.trim().isNotEmpty) {
      _loggedInUsername = username.trim();
    }
    await _refreshRolesFromToken();
    _loggedInUsername ??= parseJwtStringClaim(token, 'unique_name');
    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<void> _syncSessionFromStorage() async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (isJwtSessionValid(token)) {
        await _refreshRolesFromToken();
        _loggedInUsername ??= parseJwtStringClaim(token, 'unique_name');
        _status = AuthStatus.authenticated;
      } else {
        if (token != null && token.isNotEmpty) {
          await _storage.delete(key: 'jwt_token');
        }
        _roles = [];
        _zaposlenikId = null;
        _loggedInUsername = null;
        _status = AuthStatus.unauthenticated;
      }
    } catch (e) {
      _roles = [];
      _zaposlenikId = null;
      _loggedInUsername = null;
      _status = AuthStatus.unauthenticated;
    }
  }

  /// Returns `true` when the server acknowledged logout.
  Future<bool> logout() async {
    var serverOk = false;
    try {
      final result = await ApiService().logout();
      serverOk = result.success;
    } catch (_) {
      serverOk = false;
    }
    await _storage.delete(key: 'jwt_token');
    _roles = [];
    _zaposlenikId = null;
    _loggedInUsername = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
    return serverOk;
  }

  void consumeInfoMessage() {
    _infoMessage = null;
  }

  @override
  void dispose() {
    _authEventsSub?.cancel();
    super.dispose();
  }
}