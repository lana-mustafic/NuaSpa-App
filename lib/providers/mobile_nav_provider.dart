import 'package:flutter/foundation.dart';

/// Bottom shell: [Home, Services, Packages, Profile] — index 0–3.
/// Center "Book Now" FAB is handled in [MobileShell], not as a page index.
class MobileNavProvider extends ChangeNotifier {
  int _tabIndex = 0;

  int get tabIndex => _tabIndex;

  void setTab(int index) {
    if (index < 0 || index > 3) return;
    if (_tabIndex == index) return;
    _tabIndex = index;
    notifyListeners();
  }
}
