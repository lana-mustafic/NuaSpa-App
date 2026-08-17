/// Centralna konfiguracija Flutter klijenta.
///
/// Postavi URL pri runu/buildu (preporučeno):
/// `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5088/api/`
///
/// Ili učitaj iz `.env` datoteke:
/// `flutter run --dart-define-from-file=.env`
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

abstract final class AppConfig {
  static const String _primaryDefineKey = 'API_BASE_URL';
  static const String _legacyDefineKey = 'NUASPA_API_BASE_URL';

  static const String _fromPrimary = String.fromEnvironment(
    _primaryDefineKey,
    defaultValue: '',
  );

  static const String _fromLegacy = String.fromEnvironment(
    _legacyDefineKey,
    defaultValue: '',
  );

  /// Aktivni Dio base URL (mora uključivati path do API-ja, npr. …/api/).
  static String get apiBaseUrl {
    final override = _resolveBaseUrl();
    if (override.isEmpty) {
      if (kDebugMode && kIsWeb) {
        return 'http://localhost:5088/api/';
      }
      if (kDebugMode && !kIsWeb && Platform.isWindows) {
        return 'http://localhost:5088/api/';
      }
      throw StateError(
        'API_BASE_URL nije postavljen. Kopiraj .env.example u .env i pokreni:\n'
        '  flutter run --dart-define-from-file=.env\n'
        'ili:\n'
        '  flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5088/api/',
      );
    }
    return _ensureTrailingSlash(override);
  }

  static String _resolveBaseUrl() {
    final primary = _fromPrimary.trim();
    if (primary.isNotEmpty) {
      return primary;
    }
    return _fromLegacy.trim();
  }

  static String _ensureTrailingSlash(String url) {
    if (url.endsWith('/')) {
      return url;
    }
    return '$url/';
  }
}
