import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'auth_interceptor.dart';
import '../config/app_config.dart';

/// Jedinstveni Dio za cijelu aplikaciju (JWT + isti baseUrl).
class ApiClient {
  ApiClient._() {
    dio = Dio(
      BaseOptions(
        // Zadano po platformi; override: --dart-define=NUASPA_API_BASE_URL=https://host/api/
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(AuthInterceptor());

    // Produkcija: koristi zadano potvrđivanje certifikata.
    // Development: dozvoli self-signed samo za lokalne hostove, da app može raditi dok se ne postavi valjan cert.
    if (!kReleaseMode) {
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.badCertificateCallback =
              (X509Certificate cert, String host, int port) {
            // Dev-only allowlist (ne prihvataj sve!).
            return host == '10.0.2.2' || host == 'localhost' || host == '127.0.0.1';
          };
          return client;
        },
      );
    }
  }

  static final ApiClient _instance = ApiClient._();

  factory ApiClient() => _instance;

  late final Dio dio;
}
