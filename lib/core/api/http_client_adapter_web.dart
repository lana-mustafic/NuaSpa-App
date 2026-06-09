import 'package:dio/dio.dart';

/// Flutter web uses the browser fetch adapter; CORS must be configured on the API.
void configureDioHttpAdapter(Dio dio, {required bool releaseMode}) {}
