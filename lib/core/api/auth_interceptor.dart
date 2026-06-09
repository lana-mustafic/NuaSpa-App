import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../auth/auth_events.dart';
import '../auth/auth_storage_keys.dart';
import 'api_client.dart';
import 'token_refresh_service.dart';

class AuthInterceptor extends QueuedInterceptor {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static bool _isAuthExempt(RequestOptions options) {
    final path = options.path.toLowerCase();
    return path.contains('account/login') ||
        path.contains('account/refresh') ||
        path.contains('account/forgot-password') ||
        path.contains('account/reset-password') ||
        path.contains('account/accept-invite') ||
        path.contains('account/validate-invite');
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final token = await _storage.read(key: AuthStorageKeys.accessToken);
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
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final status = err.response?.statusCode;
    final alreadyRetried = err.requestOptions.extra['retried'] == true;

    if (status == 401 &&
        !_isAuthExempt(err.requestOptions) &&
        !alreadyRetried) {
      final refreshed = await TokenRefreshService.instance.tryRefresh();
      if (refreshed) {
        try {
          final token = await _storage.read(key: AuthStorageKeys.accessToken);
          final requestOptions = err.requestOptions;
          requestOptions.extra['retried'] = true;
          if (token != null && token.isNotEmpty) {
            requestOptions.headers['Authorization'] = 'Bearer $token';
          }
          final response = await ApiClient().dio.fetch<dynamic>(requestOptions);
          handler.resolve(response);
          return;
        } catch (retryError) {
          if (retryError is DioException) {
            handler.next(retryError);
            return;
          }
        }
      }

      await _storage.delete(key: AuthStorageKeys.accessToken);
      await _storage.delete(key: AuthStorageKeys.refreshToken);
      AuthEvents.instance.emit(
        const AuthEventForceLogout(
          message: 'Your session has expired. Please sign in again.',
        ),
      );
    }

    handler.next(err);
  }
}
