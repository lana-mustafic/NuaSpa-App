import 'package:flutter/foundation.dart';

/// Bottom shell: [Home, Services, Reservations, Profile] — index 0–3.
/// Center "Book Now" FAB is handled in [MobileShell], not as a page index.
class MobileNavProvider extends ChangeNotifier {
  int _tabIndex = 0;
  int _bookingsEpoch = 0;

  int get tabIndex => _tabIndex;
  int get bookingsEpoch => _bookingsEpoch;

  void setTab(int index) {
    if (index < 0 || index > 3) return;
    if (_tabIndex == index) return;
    _tabIndex = index;
    notifyListeners();
  }

  /// After a successful client booking: show Bookings and force the list to reload.
  /// The reservations tab lives in an IndexedStack, so it would otherwise stay stale.
  void notifyBookingCreated() {
    _tabIndex = 2;
    _bookingsEpoch++;
    notifyListeners();
  }

  void reset() {
    if (_tabIndex == 0 && _bookingsEpoch == 0) return;
    _tabIndex = 0;
    _bookingsEpoch = 0;
    notifyListeners();
  }
}
