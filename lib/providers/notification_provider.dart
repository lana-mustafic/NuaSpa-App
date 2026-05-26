import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api/services/api_service.dart';
import '../models/obavijest.dart';
import '../models/sistemska_notifikacija.dart';

/// Auto-refresh notifikacija (polling svakih 15s) — bez ručnog refresha.
class NotificationProvider extends ChangeNotifier {
  static const _pollInterval = Duration(seconds: 15);

  final ApiService _api = ApiService();

  Timer? _pollTimer;
  bool _pollingActive = false;
  bool _loading = false;

  List<SistemskaNotifikacija> _notifikacije = [];
  List<Obavijest> _obavijesti = [];
  int _unreadCount = 0;

  List<SistemskaNotifikacija> get notifikacije => _notifikacije;
  List<Obavijest> get obavijesti => _obavijesti;
  int get unreadCount => _unreadCount;
  bool get loading => _loading;

  void setPollingActive(bool active) {
    if (_pollingActive == active) return;
    _pollingActive = active;
    if (active) {
      _startPolling();
    } else {
      _stopPolling();
      _notifikacije = [];
      _obavijesti = [];
      _unreadCount = 0;
      notifyListeners();
    }
  }

  void _startPolling() {
    _stopPolling();
    unawaited(_refresh());
    _pollTimer = Timer.periodic(_pollInterval, (_) => unawaited(_refresh()));
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _refresh() async {
    if (!_pollingActive || _loading) return;
    _loading = true;
    try {
      final results = await Future.wait([
        _api.getSistemskaNotifikacije(take: 50),
        _api.getSistemskaNotifikacijeUnreadCount(),
        _api.getObavijesti(),
      ]);
      _notifikacije = results[0] as List<SistemskaNotifikacija>;
      _unreadCount = results[1] as int;
      _obavijesti = results[2] as List<Obavijest>;
      notifyListeners();
    } catch (e) {
      debugPrint('NotificationProvider refresh: $e');
    } finally {
      _loading = false;
    }
  }

  Future<void> markRead(int id) async {
    final ok = await _api.markSistemskaNotifikacijaRead(id);
    if (!ok) return;
    _notifikacije = _notifikacije
        .map((n) => n.id == id
            ? SistemskaNotifikacija(
                id: n.id,
                tip: n.tip,
                naslov: n.naslov,
                tekst: n.tekst,
                procitana: true,
                datumVrijeme: n.datumVrijeme,
                rezervacijaId: n.rezervacijaId,
              )
            : n)
        .toList();
    if (_unreadCount > 0) _unreadCount--;
    notifyListeners();
  }

  Future<void> markAllRead() async {
    final ok = await _api.markAllSistemskaNotifikacijeRead();
    if (!ok) return;
    _notifikacije = _notifikacije
        .map((n) => SistemskaNotifikacija(
              id: n.id,
              tip: n.tip,
              naslov: n.naslov,
              tekst: n.tekst,
              procitana: true,
              datumVrijeme: n.datumVrijeme,
              rezervacijaId: n.rezervacijaId,
            ))
        .toList();
    _unreadCount = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }
}
