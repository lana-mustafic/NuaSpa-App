import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'auth_interceptor.dart';

/// Jedinstveni Dio za cijelu aplikaciju (JWT + isti baseUrl).
class ApiClient {
  ApiClient._() {
    dio = Dio(
      BaseOptions(
        baseUrl: 'https://10.0.2.2:7155/api/',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(AuthInterceptor());

    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.badCertificateCallback =
            (X509Certificate cert, String host, int port) => true;
        return client;
      },
    );
  }

  static final ApiClient _instance = ApiClient._();

  factory ApiClient() => _instance;

  late final Dio dio;
}
