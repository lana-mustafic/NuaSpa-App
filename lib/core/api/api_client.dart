import 'package:dio/dio.dart';
import 'auth_interceptor.dart';

class ApiClient {
  late Dio dio;

  ApiClient() {
    dio = Dio(
      BaseOptions(
        // 10.0.2.2 je adresa tvog računara za Android emulator
        baseUrl: 'http://10.0.2.2:5088/api/', 
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );

    // Dodajemo naš interceptor da automatski šalje token
    dio.interceptors.add(AuthInterceptor());
  }
}