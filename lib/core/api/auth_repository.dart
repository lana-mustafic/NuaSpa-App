import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../auth/login_messages.dart';
import 'api_client.dart';
import 'auth_login_failure.dart';

class AuthRepository {
  final ApiClient _apiClient = ApiClient();

  String get baseUrlForDebug => _apiClient.dio.options.baseUrl;

  Future<Response> login(String username, String password) async {
    try {
      return await _apiClient.dio.post(
        'Account/login',
        data: {
          'Username': username,
          'Password': password,
        },
      );
    } on DioException catch (e) {
      debugPrint('AuthRepository.login DioException: ${e.response?.statusCode}');
      debugPrint('AuthRepository.login response: ${e.response?.data}');
      throw AuthLoginFailure(
        LoginMessages.fromDio(e),
        statusCode: e.response?.statusCode,
      );
    }
  }
}