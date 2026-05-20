import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../auth/auth_events.dart';

class AuthInterceptor extends Interceptor {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static bool _isLoginRequest(RequestOptions options) {
    final path = options.path.toLowerCase();
    return path.endsWith('account/login') || path.contains('account/login');
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    } catch (e) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: e,
          type: DioExceptionType.unknown,
        ),
      );
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode;
    if (status == 401 && !_isLoginRequest(err.requestOptions)) {
      // Token je istekao / nije validan: obriši ga i okini event da UI vrati korisnika na login.
      await _storage.delete(key: 'jwt_token');
      AuthEvents.instance.emit(
        const AuthEventForceLogout(
          message: 'Sesija je istekla. Prijavite se ponovo.',
        ),
      );
    }
    handler.next(err);
  }
}