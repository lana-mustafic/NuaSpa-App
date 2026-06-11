import '../config/app_config.dart';

/// Puni URL za slike s API-ja (relativne putanje, localhost zamjena za emulator).
String resolveMediaUrl(String? pathOrUrl) {
  if (pathOrUrl == null || pathOrUrl.trim().isEmpty) {
    return '';
  }

  var url = pathOrUrl.trim();
  final apiUri = Uri.parse(AppConfig.apiBaseUrl);
  final apiOrigin = Uri(
    scheme: apiUri.scheme,
    host: apiUri.host,
    port: apiUri.hasPort ? apiUri.port : null,
  );

  if (!url.startsWith('http')) {
    final base = apiOrigin.toString().replaceAll(RegExp(r'/+$'), '');
    url = url.startsWith('/') ? '$base$url' : '$base/$url';
  }

  final parsed = Uri.tryParse(url);
  if (parsed == null) {
    return url;
  }

  final isOurImage = parsed.path.contains('/api/files/usluge') ||
      parsed.path.contains('/api/files/terapeuti') ||
      parsed.path.contains('/uploads/usluge') ||
      parsed.path.contains('/uploads/terapeuti');
  if (isOurImage) {
    final imageHost = parsed.host;
    final apiHost = apiUri.host;
    final imageLoopback =
        imageHost == 'localhost' || imageHost == '127.0.0.1';
    final apiLoopback = apiHost == 'localhost' || apiHost == '127.0.0.1';
    if (imageLoopback && apiLoopback && imageHost != apiHost) {
      return parsed
          .replace(
            host: apiHost,
            port: apiUri.hasPort ? apiUri.port : parsed.port,
          )
          .toString();
    }
    if (imageLoopback && !apiLoopback) {
      return parsed
          .replace(
            host: apiHost,
            port: apiUri.hasPort ? apiUri.port : parsed.port,
          )
          .toString();
    }
  }

  return url;
}
