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

  final isLoopback =
      parsed.host == 'localhost' || parsed.host == '127.0.0.1';
  final apiIsLoopback =
      apiUri.host == 'localhost' || apiUri.host == '127.0.0.1';
  if (isLoopback && !apiIsLoopback) {
    return parsed
        .replace(
          host: apiUri.host,
          port: apiUri.hasPort ? apiUri.port : parsed.port,
        )
        .toString();
  }

  return url;
}
