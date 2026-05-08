import 'package:flutter/foundation.dart';

/// True for native Android / iOS app — uses [MobileSpaTheme] and [MobileShell].
bool nuaspaUseMobileShell() {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}
