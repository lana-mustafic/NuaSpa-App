import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/api/auth_repository.dart';

enum AuthStatus { unauthenticated, authenticating, authenticated, error }

class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.unauthenticated;
  final AuthRepository _repository = AuthRepository();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  AuthStatus get status => _status;

  // 1. LOGIN LOGIKA
  Future<bool> login(String username, String password) async {
    _status = AuthStatus.authenticating;
    notifyListeners();

    try {
      final response = await _repository.login(username, password);
      final token = response.data['token'];

      // Spremi token u "sef"
      await _storage.write(key: 'jwt_token', value: token);

      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  // 2. AUTO-LOGIN (Provjera pri pokretanju)
  Future<void> checkAuthState() async {
    String? token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      _status = AuthStatus.authenticated;
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  // 3. LOGOUT
  Future<void> logout() async {
    await _storage.delete(key: 'jwt_token');
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}