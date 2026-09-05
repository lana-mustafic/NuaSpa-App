import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api/services/api_service.dart';
import '../models/api_read_result.dart';
import '../models/sistemska_notifikacija.dart';

/// Auto-refresh notifikacija (polling svakih 15s) — bez ručnog refresha.
class NotificationProvider extends ChangeNotifier {
  static const _pollInterval = Duration(seconds: 15);

  final ApiService _api = ApiService();

  Timer? _pollTimer;
  bool _pollingActive = false;
  bool _loading = false;
  bool _hasLoadedOnce = false;
  String? _loadError;

  List<SistemskaNotifikacija> _notifikacije = [];
  int _unreadCount = 0;

  List<SistemskaNotifikacija> get notifikacije => _notifikacije;
  int get unreadCount => _unreadCount;
  bool get loading => _loading;
  bool get hasLoadedOnce => _hasLoadedOnce;
  String? get loadError => _loadError;

  void setPollingActive(bool active) {
    if (_pollingActive == active) return;
    _pollingActive = active;
    if (active) {
      _startPolling();
    } else {
      _stopPolling();
      _notifikacije = [];
      _unreadCount = 0;
      _hasLoadedOnce = false;
      _loadError = null;
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
    if (!_hasLoadedOnce) notifyListeners();
    try {
      final results = await Future.wait([
        _api.getSistemskaNotifikacije(take: 100),
        _api.getSistemskaNotifikacijeUnreadCount(),
      ]);
      final list = results[0] as ApiListResult<SistemskaNotifikacija>;
      final count = results[1] as ApiValueResult<int>;
      if (list.hasError || count.hasError) {
        _loadError = list.error ?? count.error;
        return;
      }
      _hasLoadedOnce = true;
      _loadError = null;
      _notifikacije = list.items;
      _unreadCount = count.value ?? 0;
    } catch (e) {
      debugPrint('NotificationProvider refresh: $e');
      _loadError = 'Could not load notifications. Check your connection.';
    } finally {
      _loading = false;
      notifyListeners();
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
