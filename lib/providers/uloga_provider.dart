import 'package:flutter/material.dart';
import '../models/referentni_podatak.dart';
import '../services/api_service.dart';

class UlogaProvider with ChangeNotifier {
  List<ReferentniPodatak> _uloge = [];
  bool _isLoading = false;

  List<ReferentniPodatak> get uloge => _uloge;
  bool get isLoading => _isLoading;

  // Funkcija za povlačenje podataka
  Future<void> fetchUloge() async {
    _isLoading = true;
    notifyListeners(); // Javi UI-u da vrti krug

    try {
      _uloge = await ApiService().getUloge();
    } catch (e) {
      // Izmijenjeno: debugPrint umjesto print
      debugPrint("Greška u provideru: $e");
    } finally {
      _isLoading = false;
      notifyListeners(); // Javi UI-u da su podaci stigli
    }
  }

  // Funkcija za simulaciju dodavanja u listu (State Syncing)
  void dodajUlogu(ReferentniPodatak novaUloga) {
    _uloge.add(novaUloga);
    notifyListeners(); // Ovo je magija koja osvježava listu na ekranu!
  }
}