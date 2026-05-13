import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../api_client.dart';
import '../../../models/usluga.dart';
import '../../../models/kategorija_usluga.dart';
import '../../../models/zaposlenik.dart';
import '../../../models/rezervacija.dart';
import '../../../models/desktop_home_overview.dart';
import '../../../models/rezervacija_povijest_item.dart';
import '../../../models/recenzija.dart';
import '../../../models/payment_intent_response.dart';
import '../../../models/admin/admin_client_row.dart';
import '../../../models/admin/admin_kpi.dart';
import '../../../models/admin/revenue_point.dart';
import '../../../models/admin/service_popularity.dart';
import '../../../models/admin/top_spender.dart';
import '../../../models/admin/rezervacija_calendar_item.dart';
import '../../../models/admin/therapist_kpi.dart';
import '../../../models/admin/therapist_admin_profile.dart';
import '../../../models/admin/spa_centar.dart';
import '../../../models/admin/radno_vrijeme.dart';

class ApiService {
  final Dio _dio = ApiClient().dio;

  /// Opcionalni filteri mapiraju na [UslugaSearchObject] na backendu.
  Future<List<Usluga>> getUsluge({String? naziv, double? maxCijena}) async {
    try {
      final query = <String, dynamic>{};
      if (naziv != null && naziv.trim().isNotEmpty) {
        query['Naziv'] = naziv.trim();
      }
      if (maxCijena != null) {
        query['MaxCijena'] = maxCijena;
      }

      final response = await _dio.get<dynamic>(
        'Usluga',
        queryParameters: query.isEmpty ? null : query,
      );

      final data = response.data;
      if (data is! List) {
        debugPrint('Neočekivan odgovor za Usluga: $data');
        return [];
      }

      return data
          .map((e) => Usluga.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Greška u ApiService.getUsluge: $e');
      return [];
    }
  }

  /// Preporuke po kategorijama iz favorita i rezervacija (ili prvih N iz kataloga).
  Future<List<Usluga>> getPreporuke({int take = 10}) async {
    try {
      final response = await _dio.get<dynamic>(
        'Preporuka',
        queryParameters: {'take': take},
      );
      final data = response.data;
      if (data is! List) return [];
      return data
          .map((e) => Usluga.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Greška u ApiService.getPreporuke: $e');
      return [];
    }
  }

  Future<Usluga?> getUslugaById(int id) async {
    try {
      final response = await _dio.get<dynamic>('Usluga/$id');
      final data = response.data;
      if (data is! Map<String, dynamic>) return null;
      return Usluga.fromJson(data);
    } catch (e) {
      debugPrint('Greška u ApiService.getUslugaById: $e');
      return null;
    }
  }

  Future<List<Zaposlenik>> getZaposlenici() async {
    try {
      final response = await _dio.get<dynamic>('Zaposlenik');
      final data = response.data;
      if (data is! List) return [];
      return data
          .map((e) => Zaposlenik.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Greška u ApiService.getZaposlenici: $e');
      return [];
    }
  }

  Future<Zaposlenik?> createZaposlenik(Zaposlenik zaposlenik) async {
    try {
      final response = await _dio.post<dynamic>(
        'Zaposlenik',
        data: zaposlenik.toJson(includeId: false),
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) return null;
      return Zaposlenik.fromJson(data);
    } catch (e) {
      debugPrint('Greška u ApiService.createZaposlenik: $e');
      return null;
    }
  }

  Future<Zaposlenik?> updateZaposlenik(Zaposlenik zaposlenik) async {
    try {
      final response = await _dio.put<dynamic>(
        'Zaposlenik/${zaposlenik.id}',
        data: zaposlenik.toJson(),
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) return null;
      return Zaposlenik.fromJson(data);
    } catch (e) {
      debugPrint('Greška u ApiService.updateZaposlenik: $e');
      return null;
    }
  }

  Future<String?> deleteZaposlenik(int id) async {
    try {
      await _dio.delete<void>('Zaposlenik/$id');
      return null;
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
      debugPrint('Greška u ApiService.deleteZaposlenik: $e');
      return e.message;
    }
  }

  Future<TherapistKpi?> getTherapistKpis({
    required int zaposlenikId,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        'Zaposlenik/$zaposlenikId/kpi',
        queryParameters: {
          'from': from.toIso8601String(),
          'to': to.toIso8601String(),
        },
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) return null;
      return TherapistKpi.fromJson(data);
    } catch (e) {
      debugPrint('Greška u ApiService.getTherapistKpis: $e');
      return null;
    }
  }

  Future<TherapistAdminProfile?> getTherapistAdminProfile({
    required int zaposlenikId,
    int maxReviews = 20,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        'Zaposlenik/$zaposlenikId/admin-profile',
        queryParameters: {'maxReviews': maxReviews},
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) return null;
      return TherapistAdminProfile.fromJson(data);
    } catch (e) {
      debugPrint('Greška u ApiService.getTherapistAdminProfile: $e');
      return null;
    }
  }

  /// `true` — spremljeno; `false` — terapeut nema povezan korisnički nalog; `null` — mreža / greška.
  Future<bool?> patchTherapistInternaNapomena({
    required int zaposlenikId,
    String? napomena,
  }) async {
    try {
      await _dio.patch<dynamic>(
        'Zaposlenik/$zaposlenikId/interna-napomena',
        data: {'napomena': napomena},
      );
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) return false;
      debugPrint('Greška u ApiService.patchTherapistInternaNapomena: $e');
      return null;
    } catch (e) {
      debugPrint('Greška u ApiService.patchTherapistInternaNapomena: $e');
      return null;
    }
  }

  Future<List<Rezervacija>> getRezervacije() async {
    try {
      final response = await _dio.get<dynamic>('Rezervacija');
      final data = response.data;
      if (data is! List) return [];
      return data
          .map((e) => Rezervacija.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Greška u ApiService.getRezervacije: $e');
      return [];
    }
  }

  /// `Datum` / `IsPotvrdjena` mapiraju na [RezervacijaSearchObject]
  /// (za terapeuta backend i dalje vraća samo njegove rezervacije).
  Future<List<Rezervacija>> getRezervacijeFiltered({
    DateTime? datum,
    bool? isPotvrdjena,
    bool includeOtkazane = false,
    int? zaposlenikId,
  }) async {
    try {
      final query = <String, dynamic>{};
      if (datum != null) {
        final d = DateTime(datum.year, datum.month, datum.day);
        query['Datum'] =
            '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      }
      if (isPotvrdjena != null) {
        query['IsPotvrdjena'] = isPotvrdjena;
      }
      if (includeOtkazane) {
        query['IncludeOtkazane'] = true;
      }
      if (zaposlenikId != null) {
        query['ZaposlenikId'] = zaposlenikId;
      }

      final response = await _dio.get<dynamic>(
        'Rezervacija',
        queryParameters: query.isEmpty ? null : query,
      );
      final data = response.data;
      if (data is! List) return [];
      return data
          .map((e) => Rezervacija.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Greška u ApiService.getRezervacijeFiltered: $e');
      return [];
    }
  }

  Future<DesktopHomeOverview?> getDesktopHomeOverview({DateTime? day}) async {
    try {
      final query = <String, dynamic>{};
      if (day != null) {
        final d = DateTime(day.year, day.month, day.day);
        query['day'] =
            '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      }
      final response = await _dio.get<dynamic>(
        'Portal/desktop-home-overview',
        queryParameters: query.isEmpty ? null : query,
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) return null;
      return DesktopHomeOverview.fromJson(data);
    } catch (e) {
      debugPrint('Greška u ApiService.getDesktopHomeOverview: $e');
      return null;
    }
  }

  /// Povijest termina klijenta (admin / terapeut s vezu prema klijentu).
  Future<List<RezervacijaPovijestItem>> getRezervacijaPovijestZaKlijenta({
    required int korisnikId,
    int? excludeRezervacijaId,
    int take = 20,
  }) async {
    try {
      final query = <String, dynamic>{'korisnikId': korisnikId, 'take': take};
      if (excludeRezervacijaId != null) {
        query['excludeRezervacijaId'] = excludeRezervacijaId;
      }
      final response = await _dio.get<dynamic>(
        'Rezervacija/povijest-za-klijenta',
        queryParameters: query,
      );
      final data = response.data;
      if (data is! List) return [];
      return data
          .map(
            (e) => RezervacijaPovijestItem.fromJson(e as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      debugPrint('Greška u ApiService.getRezervacijaPovijestZaKlijenta: $e');
      return [];
    }
  }

  Future<bool> cancelRezervacija(int id, {String? razlogOtkaza}) async {
    try {
      await _dio.patch<void>(
        'Rezervacija/$id/cancel',
        data: {
          if (razlogOtkaza != null && razlogOtkaza.trim().isNotEmpty)
            'razlogOtkaza': razlogOtkaza.trim(),
        },
      );
      return true;
    } catch (e) {
      debugPrint('Greška u ApiService.cancelRezervacija: $e');
      return false;
    }
  }

  Future<List<DateTime>> getDostupniTermini({
    required int zaposlenikId,
    required DateTime datum,
  }) async {
    try {
      final d = DateTime(datum.year, datum.month, datum.day);
      final dateStr =
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final response = await _dio.get<dynamic>(
        'Rezervacija/dostupni-termini',
        queryParameters: {'zaposlenikId': zaposlenikId, 'datum': dateStr},
      );
      final data = response.data;
      if (data is! List) return [];
      final list = data.map((e) {
        if (e is String) return DateTime.parse(e);
        return DateTime.parse(e.toString());
      }).toList();
      list.sort();
      return list;
    } catch (e) {
      debugPrint('Greška u ApiService.getDostupniTermini: $e');
      return [];
    }
  }

  Future<Rezervacija?> createRezervacija({
    int? korisnikId,
    required DateTime datumRezervacije,
    required int uslugaId,
    required int zaposlenikId,
  }) async {
    try {
      final body = <String, dynamic>{
        'datumRezervacije': datumRezervacije.toIso8601String(),
        'uslugaId': uslugaId,
        'zaposlenikId': zaposlenikId,
      };
      if (korisnikId != null) {
        body['korisnikId'] = korisnikId;
      }
      final response = await _dio.post<dynamic>('Rezervacija', data: body);

      final data = response.data;
      if (data is! Map<String, dynamic>) return null;
      return Rezervacija.fromJson(data);
    } catch (e) {
      debugPrint('Greška u ApiService.createRezervacija: $e');
      return null;
    }
  }

  Future<Rezervacija?> editRezervacija({
    required int rezervacijaId,
    required DateTime datumRezervacije,
    required int uslugaId,
    required int zaposlenikId,
    bool isVip = false,
  }) async {
    try {
      final response = await _dio.put<dynamic>(
        'Rezervacija/$rezervacijaId',
        data: {
          'datumRezervacije': datumRezervacije.toIso8601String(),
          'uslugaId': uslugaId,
          'zaposlenikId': zaposlenikId,
          'isVip': isVip,
        },
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) return null;
      return Rezervacija.fromJson(data);
    } catch (e) {
      debugPrint('Greška u ApiService.editRezervacija: $e');
      return null;
    }
  }

  /// Admin: trajna VIP oznaka na rezervaciji.
  Future<bool> patchRezervacijaVip(int rezervacijaId, bool isVip) async {
    try {
      final response = await _dio.patch<dynamic>(
        'Rezervacija/$rezervacijaId/vip',
        data: {'isVip': isVip},
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Greška u ApiService.patchRezervacijaVip: $e');
      return false;
    }
  }

  Future<List<Recenzija>> getRecenzijeByUsluga(int uslugaId) async {
    try {
      final response = await _dio.get<dynamic>(
        'Recenzija',
        queryParameters: {'uslugaId': uslugaId},
      );
      final data = response.data;
      if (data is! List) return [];
      return data
          .map((e) => Recenzija.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Greška u ApiService.getRecenzijeByUsluga: $e');
      return [];
    }
  }

  Future<Recenzija?> createRecenzija({
    required int uslugaId,
    required int ocjena,
    required String komentar,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        'Recenzija',
        data: {'uslugaId': uslugaId, 'ocjena': ocjena, 'komentar': komentar},
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) return null;
      return Recenzija.fromJson(data);
    } catch (e) {
      debugPrint('Greška u ApiService.createRecenzija: $e');
      return null;
    }
  }

  Future<Set<int>> getMyFavoriteIds() async {
    try {
      final response = await _dio.get<dynamic>('Favorit/ids');
      final data = response.data;
      if (data is! List) return {};
      return data.map((e) => (e as num).toInt()).toSet();
    } catch (e) {
      debugPrint('Greška u ApiService.getMyFavoriteIds: $e');
      return {};
    }
  }

  Future<bool> addFavorite(int uslugaId) async {
    try {
      await _dio.post<dynamic>('Favorit', data: {'uslugaId': uslugaId});
      return true;
    } catch (e) {
      debugPrint('Greška u ApiService.addFavorite: $e');
      return false;
    }
  }

  Future<bool> removeFavorite(int uslugaId) async {
    try {
      await _dio.delete<dynamic>('Favorit/$uslugaId');
      return true;
    } catch (e) {
      debugPrint('Greška u ApiService.removeFavorite: $e');
      return false;
    }
  }

  Future<List<Usluga>> getMyFavorites() async {
    try {
      final response = await _dio.get<dynamic>('Favorit');
      final data = response.data;
      if (data is! List) return [];
      return data
          .map((e) => Usluga.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Greška u ApiService.getMyFavorites: $e');
      return [];
    }
  }

  Future<List<KategorijaUsluga>> getKategorijeUsluga() async {
    try {
      final response = await _dio.get<dynamic>('KategorijaUsluga');
      final data = response.data;
      if (data is! List) return [];
      return data
          .map((e) => KategorijaUsluga.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Greška u ApiService.getKategorijeUsluga: $e');
      return [];
    }
  }

  Future<KategorijaUsluga?> createKategorijaUsluga(String naziv) async {
    try {
      final response = await _dio.post<dynamic>(
        'KategorijaUsluga',
        data: {'id': 0, 'naziv': naziv},
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) return null;
      return KategorijaUsluga.fromJson(data);
    } catch (e) {
      debugPrint('Greška u ApiService.createKategorijaUsluga: $e');
      return null;
    }
  }

  Future<KategorijaUsluga?> updateKategorijaUsluga(KategorijaUsluga k) async {
    try {
      final response = await _dio.put<dynamic>(
        'KategorijaUsluga/${k.id}',
        data: k.toJson(),
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) return null;
      return KategorijaUsluga.fromJson(data);
    } catch (e) {
      debugPrint('Greška u ApiService.updateKategorijaUsluga: $e');
      return null;
    }
  }

  Future<String?> deleteKategorijaUsluga(int id) async {
    try {
      await _dio.delete<void>('KategorijaUsluga/$id');
      return null;
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
      debugPrint('Greška u ApiService.deleteKategorijaUsluga: $e');
      return e.message;
    }
  }

  Future<Usluga?> createUsluga(Usluga u) async {
    try {
      final response = await _dio.post<dynamic>(
        'Usluga',
        data: u.toAdminJson(includeId: false),
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) return null;
      return Usluga.fromJson(data);
    } catch (e) {
      debugPrint('Greška u ApiService.createUsluga: $e');
      return null;
    }
  }

  Future<Usluga?> updateUsluga(Usluga u) async {
    try {
      final response = await _dio.put<dynamic>(
        'Usluga/${u.id}',
        data: u.toAdminJson(includeId: true),
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) return null;
      return Usluga.fromJson(data);
    } catch (e) {
      debugPrint('Greška u ApiService.updateUsluga: $e');
      return null;
    }
  }

  Future<String?> deleteUsluga(int id) async {
    try {
      await _dio.delete<void>('Usluga/$id');
      return null;
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
      debugPrint('Greška u ApiService.deleteUsluga: $e');
      return e.message;
    }
  }

  Future<bool> updateRezervacijaPotvrdjena(int id, bool isPotvrdjena) async {
    try {
      await _dio.patch<void>(
        'Rezervacija/$id',
        data: {'isPotvrdjena': isPotvrdjena},
      );
      return true;
    } catch (e) {
      debugPrint('Greška u ApiService.updateRezervacijaPotvrdjena: $e');
      return false;
    }
  }

  Future<PaymentIntentResponse?> createPaymentIntent(int rezervacijaId) async {
    try {
      final response = await _dio.post<dynamic>(
        'Placanje/create-intent',
        data: {'rezervacijaId': rezervacijaId},
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) return null;
      return PaymentIntentResponse.fromJson(data);
    } catch (e) {
      debugPrint('Greška u ApiService.createPaymentIntent: $e');
      return null;
    }
  }

  Future<void> downloadReport() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/izvjestaj_top_usluge.pdf';
      await _dio.download('Izvjestaj/top-usluge', filePath);
      await OpenFile.open(filePath);
    } catch (e) {
      debugPrint('Greška pri downloadu: $e');
    }
  }

  Future<AdminKpi?> getAdminKpis({DateTime? date}) async {
    try {
      final response = await _dio.get<dynamic>(
        'Izvjestaj/kpi',
        queryParameters: {if (date != null) 'date': date.toIso8601String()},
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) return null;
      return AdminKpi.fromJson(data);
    } catch (e) {
      debugPrint('Greška u ApiService.getAdminKpis: $e');
      return null;
    }
  }

  Future<List<RevenuePoint>> getRevenueSeries({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        'Izvjestaj/revenue',
        queryParameters: {
          'from': from.toIso8601String(),
          'to': to.toIso8601String(),
        },
      );
      final data = response.data;
      if (data is! List) return [];
      return data
          .whereType<Map>()
          .map((e) => RevenuePoint.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('Greška u ApiService.getRevenueSeries: $e');
      return [];
    }
  }

  Future<List<ServicePopularity>> getServicePopularity({
    required DateTime from,
    required DateTime to,
    int take = 8,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        'Izvjestaj/service-popularity',
        queryParameters: {
          'from': from.toIso8601String(),
          'to': to.toIso8601String(),
          'take': take,
        },
      );
      final data = response.data;
      if (data is! List) return [];
      return data
          .whereType<Map>()
          .map((e) => ServicePopularity.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('Greška u ApiService.getServicePopularity: $e');
      return [];
    }
  }

  Future<List<TopSpender>> getTopSpenders({
    required DateTime from,
    required DateTime to,
    int take = 10,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        'Izvjestaj/top-spenders',
        queryParameters: {
          'from': from.toIso8601String(),
          'to': to.toIso8601String(),
          'take': take,
        },
      );
      final data = response.data;
      if (data is! List) return [];
      return data
          .whereType<Map>()
          .map((e) => TopSpender.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('Greška u ApiService.getTopSpenders: $e');
      return [];
    }
  }

  Future<List<AdminClientRow>> getAdminClients({
    String? q,
    int take = 200,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        'AdminKlijent',
        queryParameters: {
          if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
          'take': take,
        },
      );
      final data = response.data;
      if (data is! List) return [];
      return data
          .whereType<Map>()
          .map((e) => AdminClientRow.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('Greška u ApiService.getAdminClients: $e');
      return [];
    }
  }

  Future<List<RezervacijaCalendarItem>> getRezervacijeCalendar({
    required DateTime from,
    required DateTime to,
    int? zaposlenikId,
    int? uslugaId,
    String? q,
    bool includeOtkazane = false,
  }) async {
    try {
      final query = <String, dynamic>{
        'from': from.toIso8601String(),
        'to': to.toIso8601String(),
        if (zaposlenikId != null) 'zaposlenikId': zaposlenikId,
        if (uslugaId != null) 'uslugaId': uslugaId,
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        if (includeOtkazane) 'includeOtkazane': true,
      };

      final response = await _dio.get<dynamic>(
        'Rezervacija/calendar',
        queryParameters: query,
      );
      final data = response.data;
      if (data is! List) return [];
      return data
          .whereType<Map>()
          .map(
            (e) =>
                RezervacijaCalendarItem.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList();
    } catch (e) {
      debugPrint('Greška u ApiService.getRezervacijeCalendar: $e');
      return [];
    }
  }

  Future<SpaCentar?> getSpaCentar() async {
    try {
      final response = await _dio.get<dynamic>('Resursi/spa-centar');
      final data = response.data;
      if (data is! Map<String, dynamic>) return null;
      return SpaCentar.fromJson(data);
    } catch (e) {
      debugPrint('Greška u ApiService.getSpaCentar: $e');
      return null;
    }
  }

  Future<SpaCentar?> updateSpaCentar(SpaCentar dto) async {
    try {
      final response = await _dio.put<dynamic>(
        'Resursi/spa-centar',
        data: dto.toJson(),
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) return null;
      return SpaCentar.fromJson(data);
    } catch (e) {
      debugPrint('Greška u ApiService.updateSpaCentar: $e');
      return null;
    }
  }

  Future<List<RadnoVrijeme>> getRadnoVrijeme() async {
    try {
      final response = await _dio.get<dynamic>('Resursi/radno-vrijeme');
      final data = response.data;
      if (data is! List) return [];
      return data
          .whereType<Map>()
          .map((e) => RadnoVrijeme.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('Greška u ApiService.getRadnoVrijeme: $e');
      return [];
    }
  }

  Future<List<RadnoVrijeme>> updateRadnoVrijeme(
    List<RadnoVrijeme> items,
  ) async {
    try {
      final response = await _dio.put<dynamic>(
        'Resursi/radno-vrijeme',
        data: items.map((e) => e.toJson()).toList(),
      );
      final data = response.data;
      if (data is! List) return [];
      return data
          .whereType<Map>()
          .map((e) => RadnoVrijeme.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('Greška u ApiService.updateRadnoVrijeme: $e');
      return [];
    }
  }
}
