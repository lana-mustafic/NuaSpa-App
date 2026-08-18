import '../api/api_error_messages.dart';

/// Maps backend catalog admin errors into actionable English copy.
abstract final class CatalogAdminMessages {
  static String serviceDeleteError(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return 'The service could not be deleted. Please try again.';
    }

    final lower = raw.toLowerCase();
    if (lower.contains('rezervac') || lower.contains('booking')) {
      return 'This service has active bookings. Cancel or reassign them first, then try deleting again.';
    }
    if (lower.contains('favorit')) {
      return 'This service is saved in client favorites. Remove it from favorites first, then try again.';
    }
    if (lower.contains('recenzij') || lower.contains('review')) {
      return 'This service has client reviews and cannot be deleted yet.';
    }
    if (lower.contains('ne postoji') || lower.contains('not exist')) {
      return 'This service no longer exists. Refresh the catalog and try again.';
    }
    return ApiErrorMessages.humanize(raw);
  }

  static String categoryDeleteError(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return 'The category could not be deleted. Please try again.';
    }

    final lower = raw.toLowerCase();
    if (lower.contains('uslug') || lower.contains('service')) {
      return 'This category still has services assigned. Move or delete those services first.';
    }
    if (lower.contains('zaposlenik') || lower.contains('therapist')) {
      return 'This category is linked to therapists. Reassign them first, then try again.';
    }
    if (lower.contains('ne postoji') || lower.contains('not exist')) {
      return 'This category no longer exists. Refresh and try again.';
    }
    return ApiErrorMessages.humanize(raw);
  }
}
