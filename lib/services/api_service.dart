import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../models/referentni_podatak.dart';

class ApiService {
  final Dio _dio = Dio(BaseOptions(
    // KORISTI: "http://10.0.2.2:8080/api" za Android Emulator
    // KORISTI: "http://localhost:8080/api" za Windows Desktop
    baseUrl: "http://10.0.2.2:8080/api", 
    connectTimeout: const Duration(seconds: 5),
  ));

  // Funkcija za povlačenje uloga
  Future<List<ReferentniPodatak>> getUloge() async {
    try {
      final response = await _dio.get('/uloge');
      if (response.statusCode == 200) {
        List data = response.data;
        return data.map((item) => ReferentniPodatak.fromJson(item)).toList();
      }
      throw Exception("Greška na serveru");
    } catch (e) {
      debugPrint("API Error (Vraćam testne podatke): $e");
      return [
        ReferentniPodatak(id: 1, naziv: "Admin"),
        ReferentniPodatak(id: 2, naziv: "Maser"),
        ReferentniPodatak(id: 3, naziv: "Kozmetičar"),
      ];
    }
  }

  // Funkcija za PDF Export - Putanja usklađena sa Swaggerom
  Future<void> downloadReport() async {
    try {
      // 1. Pronalaženje lokacije za spašavanje (Documents folder)
      final directory = await getApplicationDocumentsDirectory();
      final filePath = "${directory.path}/izvjestaj_top_usluge.pdf";

      debugPrint("Započinjem download u: $filePath");

      // 2. Download fajla sa tačnog endpointa
      await _dio.download(
        "/Izvjestaj/top-usluge", // Usklađeno sa tvojim Swaggerom
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            debugPrint("Napredak: ${(received / total * 100).toStringAsFixed(0)}%");
          }
        },
      );

      debugPrint("PDF uspješno spašen!");

      // 3. Otvaranje PDF-a odmah nakon preuzimanja
      final result = await OpenFile.open(filePath);
      debugPrint("Status otvaranja: ${result.message}");
      
    } catch (e) {
      debugPrint("Greška pri downloadu izvještaja: $e");
    }
  }
}