import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async';
import '../core/api/auth_login_failure.dart';
import '../core/api/auth_repository.dart';
import '../core/api/services/api_service.dart';
import '../core/api/token_refresh_service.dart';
import '../core/auth/auth_events.dart';
import '../core/auth/auth_storage_keys.dart';
import '../core/auth/login_messages.dart';
import '../core/jwt_roles.dart';

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
    final token = await _storage.read(key: AuthStorageKeys.accessToken);
    _roles = parseJwtRoles(token);
    _zaposlenikId = parseJwtIntClaim(token, 'ZaposlenikId');
    _loggedInUsername ??= parseJwtStringClaim(token, 'unique_name');
  }

  Future<({bool success, String? errorMessage})> login(
    String username,
    String password,
  ) async {
    _status = AuthStatus.authenticating;
    notifyListeners();

    try {
      debugPrint(
        'AuthProvider.login attempt for $username at ${_repository.baseUrlForDebug}',
      );
      final response = await _repository.login(username, password);
      final data = response.data;
      final token = data is Map ? data['token'] as String? : null;
      final refresh = data is Map ? data['refreshToken'] as String? : null;

      if (token != null && token.isNotEmpty) {
        final apiUsername = data is Map ? data['username'] as String? : null;
        await _persistSession(
          accessToken: token,
          refreshToken: refresh,
          username: apiUsername?.trim().isNotEmpty == true
              ? apiUsername!.trim()
              : username.trim(),
        );
        _status = AuthStatus.authenticated;
        notifyListeners();
        return (success: true, errorMessage: null);
      }

      debugPrint('AuthProvider.login: response missing token.');
      await _clearSessionState();
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return (
        success: false,
        errorMessage: LoginMessages.en('Sign-in failed. Please try again.'),
      );
    } on AuthLoginFailure catch (e) {
      debugPrint('AuthProvider.login failed: ${e.message}');
      await _clearSessionState();
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return (success: false, errorMessage: e.message);
    } catch (e) {
      debugPrint('AuthProvider.login unexpected error: $e');
      await _clearSessionState();
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return (
        success: false,
        errorMessage: LoginMessages.en('Sign-in failed. Please try again.'),
      );
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

  Future<void> applySessionToken(
    String token, {
    String? username,
    String? refreshToken,
  }) async {
    await _persistSession(
      accessToken: token,
      refreshToken: refreshToken,
      username: username,
    );
    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<void> _syncSessionFromStorage() async {
    try {
      final token = await _storage.read(key: AuthStorageKeys.accessToken);
      if (isJwtSessionValid(token)) {
        await _refreshRolesFromToken();
        _loggedInUsername ??= parseJwtStringClaim(token, 'unique_name');
        _status = AuthStatus.authenticated;
        return;
      }

      if (token != null && token.isNotEmpty) {
        await _storage.delete(key: AuthStorageKeys.accessToken);
      }

      final refreshed = await TokenRefreshService.instance.tryRefresh();
      if (refreshed) {
        await _refreshRolesFromToken();
        final nextToken = await _storage.read(key: AuthStorageKeys.accessToken);
        _loggedInUsername ??= parseJwtStringClaim(nextToken, 'unique_name');
        _status = AuthStatus.authenticated;
        return;
      }

      await _clearSessionState();
      _status = AuthStatus.unauthenticated;
    } catch (e) {
      await _clearSessionState();
      _status = AuthStatus.unauthenticated;
    }
  }

  /// Returns `true` when the server acknowledged logout.
  Future<bool> logout() async {
    var serverOk = false;
    final refresh = await _storage.read(key: AuthStorageKeys.refreshToken);
    try {
      final result = await ApiService().logout(
        refreshToken: refresh,
      );
      serverOk = result.success;
    } catch (_) {
      serverOk = false;
    }
    await _storage.delete(key: AuthStorageKeys.accessToken);
    await _storage.delete(key: AuthStorageKeys.refreshToken);
    _roles = [];
    _zaposlenikId = null;
    _loggedInUsername = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
    return serverOk;
  }

  Future<void> _persistSession({
    required String accessToken,
    String? refreshToken,
    String? username,
  }) async {
    await _storage.write(key: AuthStorageKeys.accessToken, value: accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _storage.write(
        key: AuthStorageKeys.refreshToken,
        value: refreshToken,
      );
    }
    if (username != null && username.trim().isNotEmpty) {
      _loggedInUsername = username.trim();
    }
    await _refreshRolesFromToken();
    _loggedInUsername ??=
        parseJwtStringClaim(accessToken, 'unique_name');
  }

  Future<void> _clearSessionState() async {
    await _storage.delete(key: AuthStorageKeys.accessToken);
    await _storage.delete(key: AuthStorageKeys.refreshToken);
    _roles = [];
    _zaposlenikId = null;
    _loggedInUsername = null;
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
