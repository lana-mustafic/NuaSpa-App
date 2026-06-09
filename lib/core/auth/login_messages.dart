import 'package:dio/dio.dart';

import '../api/api_error_messages.dart';

/// Maps known API messages to English copy for the sign-in UI.
abstract final class LoginMessages {
  static String en(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return 'Sign-in failed. Please try again.';
    }
    final t = raw.trim();
    const map = <String, String>{
      'Neispravno korisničko ime ili lozinka.': 'Invalid username or password.',
      'Invalid username or password.': 'Invalid username or password.',
      'Account is deactivated. Contact your spa administrator.':
          'Account is deactivated. Contact your spa administrator.',
      'Portal access is not activated yet. Open your invitation link to set a password.':
          'Portal access is not activated yet. Open your invitation link to set a password.',
      'Your therapist profile is not active. Contact your spa administrator.':
          'Your therapist profile is not active. Contact your spa administrator.',
      'Account is temporarily locked due to too many failed sign-in attempts. Try again later or contact your administrator.':
          'Account is temporarily locked due to too many failed sign-in attempts. Try again later or contact your administrator.',
      'Username or email is required.': 'Please enter your username or email.',
      'Password is required.': 'Please enter your password.',
      'Niste prijavljeni ili sesija je istekla.': 'Invalid username or password.',
      'Neispravan zahtjev. Provjerite unesene podatke.':
          'Invalid request. Check the information you entered.',
      'Mrežna greška. Pokušajte ponovo.': 'Network error. Please try again.',
    };
    return map[t] ?? t;
  }

  static String fromDio(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final detail = data['detail'] ?? data['message'];
      if (detail != null) {
        final parsed = detail.toString().trim();
        if (parsed.isNotEmpty) {
          return en(parsed);
        }
      }

      final errors = data['errors'];
      if (errors is Map) {
        final parts = <String>[];
        for (final entry in errors.entries) {
          final value = entry.value;
          if (value is List && value.isNotEmpty) {
            parts.add(en(value.first.toString()));
          } else if (value != null) {
            parts.add(en(value.toString()));
          }
        }
        if (parts.isNotEmpty) {
          return parts.join(' ');
        }
      }
    }

    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return 'Network error. Please check your connection and try again.';
    }

    final fallback = ApiErrorMessages.fromDio(error);
    if (error.response?.statusCode == 401 &&
        fallback == 'Niste prijavljeni ili sesija je istekla.') {
      return en('Invalid username or password.');
    }

    return en(fallback);
  }
}
