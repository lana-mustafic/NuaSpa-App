import 'package:flutter/foundation.dart';

/// Compile-time i zadani API endpointi za NuaSpa backend.
///
/// Override pri buildu ili runu:
/// `flutter run -d windows --dart-define=NUASPA_API_BASE_URL=http://192.168.1.5:5088/api/`
abstract final class AppConfig {
  static const String _defineKey = 'NUASPA_API_BASE_URL';

  /// Eksplicitni base URL (mora uključivati path do API-ja, npr. …/api/).
  static const String _fromEnvironment = String.fromEnvironment(
    _defineKey,
    defaultValue: '',
  );

  /// Aktivni Dio base URL (s završnim `/`).
  static String get apiBaseUrl {
    final override = _fromEnvironment.trim();
    if (override.isNotEmpty) {
      return _ensureTrailingSlash(override);
    }
    return _defaultBaseUrlForPlatform();
  }

  static String _defaultBaseUrlForPlatform() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'https://10.0.2.2:7155/api/';
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
        return 'http://127.0.0.1:5088/api/';
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return 'http://127.0.0.1:5088/api/';
    }
  }

  static String _ensureTrailingSlash(String url) {
    if (url.endsWith('/')) return url;
    return '$url/';
  }
}
