import 'package:dio/dio.dart';
import '../models/referentni_podatak.dart';

class ApiService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: "http://localhost:8080/api",
    connectTimeout: const Duration(seconds: 5),
  ));

  Future<List<ReferentniPodatak>> getUloge() async {
    try {
      final response = await _dio.get('/uloge');

      if (response.statusCode == 200) {
        List data = response.data;
        return data.map((item) => ReferentniPodatak.fromJson(item)).toList();
      }
      throw Exception("Greška na serveru");
    } catch (e) {
      print("API Error (Vraćam testne podatke): $e");
      
      // MOCK PODACI: Dok ne središ Backend, koristi ovo za test
      await Future.delayed(const Duration(seconds: 1)); // Simulacija interneta
      return [
        ReferentniPodatak(id: 1, naziv: "Admin"),
        ReferentniPodatak(id: 2, naziv: "Maser"),
        ReferentniPodatak(id: 3, naziv: "Kozmetičar"),
        ReferentniPodatak(id: 4, naziv: "Recepcioner"),
      ];
    }
  }
}