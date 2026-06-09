import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

void configureDioHttpAdapter(Dio dio, {required bool releaseMode}) {
  if (releaseMode) {
    return;
  }

  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final client = HttpClient();
      client.badCertificateCallback =
          (X509Certificate cert, String host, int port) {
        return host == '10.0.2.2' || host == 'localhost' || host == '127.0.0.1';
      };
      return client;
    },
  );
}
