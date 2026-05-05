import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'; // Dodano za debugPrint
import 'api_client.dart';

class AuthRepository {
  final ApiClient _apiClient = ApiClient();

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
      // POPRAVLJENO: Korištenje debugPrint umjesto print
      debugPrint("DIO ERROR: ${e.response?.statusCode}");
      debugPrint("DATA IZ BACKENDA: ${e.response?.data}");
      
      throw Exception(e.response?.data?.toString() ?? "Server Error");
    }
  }
}