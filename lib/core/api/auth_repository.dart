import 'package:dio/dio.dart';
import 'api_client.dart';

class AuthRepository {
  final ApiClient _apiClient = ApiClient();

  Future<Response> login(String username, String password) async {
    return await _apiClient.dio.post(
      'Account/login',
      data: {
        'username': username,
        'password': password,
      },
    );
  }
}