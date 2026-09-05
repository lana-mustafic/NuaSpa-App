/// Client-side mirror of server [RezervacijaStatus].
/// Legacy [isPotvrdjena] / [isOtkazana] flags are derived from this, not stored independently.
abstract final class RezervacijaStatusFlags {
  static String normalize(String? status) =>
      (status ?? 'Pending').trim().toLowerCase();

  static bool isCancelled(String? status) => normalize(status) == 'cancelled';

  static bool isConfirmedLike(String? status) {
    final s = normalize(status);
    return s == 'confirmed' || s == 'completed';
  }

  /// Mirrors backend [ValidateReservationPayable]: Confirmed, not paid, not cancelled.
  static bool isOnlinePayable(String? status, {required bool isPaid}) {
    if (isPaid) return false;
    return normalize(status) == 'confirmed';
  }
}
