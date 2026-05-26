import 'package:dio/dio.dart';

/// Parsira poruke validacije i poslovnih grešaka iz API odgovora.
abstract final class ApiErrorMessages {
  static String fromObject(Object error, {String? fallback}) {
    if (error is DioException) {
      final parsed = fromDio(error);
      if (parsed != null) return parsed;
    }
    return fallback ?? 'Došlo je do greške. Pokušajte ponovo.';
  }

  static String? fromDio(DioException error) {
    final data = error.response?.data;
    if (data is String && data.trim().isNotEmpty) {
      return _humanize(data.trim());
    }
    if (data is Map) {
      final detail = data['detail'] ?? data['message'] ?? data['title'];
      if (detail != null) {
        final d = detail.toString().trim();
        if (d.isNotEmpty && !_isGenericHttpTitle(d, error.response?.statusCode)) {
          return _humanize(d);
        }
      }
      final errors = data['errors'];
      if (errors is Map) {
        final parts = <String>[];
        for (final entry in errors.entries) {
          final v = entry.value;
          if (v is List) {
            parts.addAll(v.map((e) => e.toString()));
          } else if (v != null) {
            parts.add(v.toString());
          }
        }
        if (parts.isNotEmpty) return parts.join(' ');
      }
    }
    if (data is List && data.isNotEmpty) {
      return data.map((e) => e.toString()).join(' ');
    }
    final code = error.response?.statusCode;
    if (code == 409) {
      return 'Podaci su u konfliktu s postojećim zapisom (npr. e-mail je već registriran).';
    }
    if (code == 400) {
      return 'Neispravan zahtjev. Provjerite unesene podatke.';
    }
    if (code == 401) {
      return 'Niste prijavljeni ili sesija je istekla.';
    }
    if (code == 403) {
      return 'Nemate dozvolu za ovu radnju.';
    }
    return null;
  }

  static bool _isGenericHttpTitle(String title, int? statusCode) {
    if (statusCode == 400 && title == 'One or more validation errors occurred.') {
      return true;
    }
    return title == 'Bad Request' ||
        title == 'Success' ||
        title == 'Conflict' ||
        title == 'Unauthorized';
  }

  static String _humanize(String raw) {
    const replacements = <String, String>{
      'Email je već registriran.': 'E-mail adresa je već registrirana.',
      'Email is already registered.': 'E-mail adresa je već registrirana.',
      'Korisničko ime je zauzeto.': 'Korisničko ime je već zauzeto.',
    };
    return replacements[raw] ?? raw;
  }
}
