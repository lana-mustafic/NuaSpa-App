import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../auth/auth_storage_keys.dart';
import '../config/app_config.dart';

/// Rotates the refresh token without going through [AuthInterceptor].
class TokenRefreshService {
  TokenRefreshService._();

  static final TokenRefreshService instance = TokenRefreshService._();

  static const _storage = FlutterSecureStorage();

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  Completer<bool>? _inFlight;
  bool _refreshing = false;

  Future<bool> tryRefresh() async {
    if (_refreshing) {
      return _inFlight?.future ?? Future.value(false);
    }

    _refreshing = true;
    _inFlight = Completer<bool>();

    try {
      final refresh = await _storage.read(key: AuthStorageKeys.refreshToken);
      if (refresh == null || refresh.isEmpty) {
        _complete(false);
        return false;
      }

      final response = await _dio.post<dynamic>(
        'Account/refresh',
        data: {'refreshToken': refresh},
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        _complete(false);
        return false;
      }

      final access = data['token'] as String?;
      final nextRefresh = data['refreshToken'] as String?;
      if (access == null || access.isEmpty || nextRefresh == null || nextRefresh.isEmpty) {
        _complete(false);
        return false;
      }

      await _storage.write(key: AuthStorageKeys.accessToken, value: access);
      await _storage.write(key: AuthStorageKeys.refreshToken, value: nextRefresh);
      _complete(true);
      return true;
    } on DioException catch (e) {
      debugPrint('TokenRefreshService.tryRefresh failed: ${e.response?.statusCode}');
      _complete(false);
      return false;
    } catch (e) {
      debugPrint('TokenRefreshService.tryRefresh error: $e');
      _complete(false);
      return false;
    } finally {
      _refreshing = false;
      _inFlight = null;
    }
  }

  void _complete(bool value) {
    if (_inFlight != null && !_inFlight!.isCompleted) {
      _inFlight!.complete(value);
    }
  }
}
