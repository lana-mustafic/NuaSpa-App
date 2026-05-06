import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Postavlja naslov, početnu veličinu i minimalnu veličinu prozora (Windows / Linux / macOS).
Future<void> configureDesktopWindowIfNeeded() async {
  if (kIsWeb) return;
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      return;
    case TargetPlatform.windows:
    case TargetPlatform.linux:
    case TargetPlatform.macOS:
      break;
  }

  await windowManager.ensureInitialized();

  const options = WindowOptions(
    size: Size(1280, 720),
    minimumSize: Size(1024, 640),
    center: true,
    title: 'NuaSpa Desktop',
    titleBarStyle: TitleBarStyle.normal,
  );

  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}
