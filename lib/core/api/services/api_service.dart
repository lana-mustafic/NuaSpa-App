import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../api_client.dart';
import '../paged_list_parser.dart';
import '../api_error_messages.dart';
import '../../../models/usluga.dart';
import '../../../models/preporucena_usluga.dart';
import '../../../models/kategorija_usluga.dart';
import '../../../models/zaposlenik.dart';
import '../../../models/rezervacija.dart';
import '../../../models/desktop_home_overview.dart';
import '../../../models/rezervacija_povijest_item.dart';
import '../../../models/recenzija.dart';
import '../../../models/payment_intent_response.dart';
import '../../../models/cancel_rezervacija_result.dart';
import '../../../models/sistemska_notifikacija.dart';
import '../../../models/obavijest.dart';
import '../../../models/admin/admin_client_row.dart';
import '../../../models/admin/admin_client_stats.dart';
import '../../../models/admin/admin_kpi.dart';
import '../../../models/admin/revenue_point.dart';
import '../../../models/admin/service_popularity.dart';
import '../../../models/admin/top_spender.dart';
import '../../../models/admin/rezervacija_calendar_item.dart';
import '../../../models/admin/therapist_kpi.dart';
import '../../../models/admin/therapist_admin_profile.dart';
import '../../../models/admin/therapist_account_status.dart';
import '../../../models/therapist/therapist_dashboard.dart';
import '../../../models/admin/spa_centar.dart';
import '../../../models/admin/admin_reviews_dashboard.dart';
import '../../../models/admin/admin_finance_dashboard.dart';
import '../../../models/admin/radno_vrijeme.dart';
import '../../../models/grad_lookup.dart';

class ApiService {
  final Dio _dio = ApiClient().dio;

  static String _apiDateOnly(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  /// Opcionalni filteri mapiraju na [UslugaSearchObject] na backendu.
  Future<List<Usluga>> getUsluge({String? naziv, double? maxCijena}) async {
    try {
      final query = <String, dynamic>{
        'pageSize': 100,
      };
      if (naziv != null && naziv.trim().isNotEmpty) {
        query['Naziv'] = naziv.trim();
      }
      if (maxCijena != null) {
        query['MaxCijena'] = maxCijena;
      }

      final response = await _dio.get<dynamic>(
        'Usluga',
        queryParameters: query,
      );

      return parsePagedItems(
        response.data,
        (json) => Usluga.fromJson(json),
      );
    } catch (e) {
      debugPrint('Greška u ApiService.getUsluge: $e');
      return [];
    }
  }

  /// Content-based preporuke s objašnjenjem (razlogTekst).
  Future<List<PreporucenaUsluga>> getPreporuke({int take = 10}) async {
    try {
      final response = await _dio.get<dynamic>(
        'Preporuka',
        queryParameters: {'take': take},
      );
      final data = response.data;
      if (data is! List) return [];
      return data
          .map((e) => PreporucenaUsluga.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Greška u ApiService.getPreporuke: $e');
      return [];
    }
  }

  /// Zapis signala za recommender: tip 0 = pretraga, 1 = pregled usluge.
  Future<void> logPreporukaAktivnost({
    required int tip,
    int? uslugaId,
    int? kategorijaUslugaId,
    String? searchTerm,
  }) async {
    try {
      await _dio.post<void>(
        'Preporuka/aktivnost',
        data: {
          'tip': tip,
          if (uslugaId != null) 'uslugaId': uslugaId,
          if (kategorijaUslugaId != null) 'kategorijaUslugaId': kategorijaUslugaId,
          if (searchTerm != null && searchTerm.trim().isNotEmpty)
            'searchTerm': searchTerm.trim(),
        },
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        return;
      }
      debugPrint('Greška u ApiService.logPreporukaAktivnost: $e');
    } catch (e) {
      debugPrint('Greška u ApiService.logPreporukaAktivnost: $e');
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

  Future<List<Zaposlenik>> getZaposleniciForService(int uslugaId) async {
    try {
      final response = await _dio.get<dynamic>(
        'Zaposlenik/for-service/$uslugaId',
      );
      final data = response.data;
      if (data is! List) return [];
      return data
          .map((e) => Zaposlenik.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Greška u ApiService.getZaposleniciForService: $e');
      return [];
    }
  }

  /// Terapeuti vezani za kategoriju usluge (npr. recenzije na service details).
  Future<List<Zaposlenik>> getZaposleniciForCategory(
    int kategorijaUslugaId, {
    bool bookableOnly = true,
  }) async {
    if (kategorijaUslugaId <= 0) return [];
    try {
      final response = await _dio.get<dynamic>(
        'Zaposlenik/for-category/$kategorijaUslugaId',
        queryParameters: {'bookableOnly': bookableOnly},
      );
      final data = response.data;
      if (data is! List) return [];
      return data
          .map((e) => Zaposlenik.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Greška u ApiService.getZaposleniciForCategory: $e');
      return [];
    }
  }

  Future<Zaposlenik?> getTherapistMe() async {
    try {
      final response = await _dio.get<dynamic>('Zaposlenik/me');
      final data = response.data;
      if (data is! Map<String, dynamic>) return null;
      return Zaposlenik.fromJson(data);
    } catch (e) {
      debugPrint('Greška u ApiService.getTherapistMe: $e');
      return null;
    }
  }

  Future<Zaposlenik?> patchTherapistMe({
    String? telefon,
    String? jezici,
  }) async {
    try {
      final response = await _dio.patch<dynamic>(
        'Zaposlenik/me',
        data: {
          if (telefon != null) 'telefon': telefon,
          if (jezici != null) 'jezici': jezici,
        },
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) return null;
      return Zaposlenik.fromJson(data);
    } catch (e) {
      debugPrint('Greška u ApiService.patchTherapistMe: $e');
      return null;
    }
  }

  Future<TherapistDashboard?> getTherapistDashboard({DateTime? day}) async {
    try {
      final query = <String, dynamic>{};
      if (day != null) {
        final d = DateTime(day.year, day.month, day.day);
        query['day'] = d.toIso8601String();
      }
      final response = await _dio.get<dynamic>(
        'Zaposlenik/me/dashboard',
        queryParameters: query.isEmpty ? null : query,
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) return null;
      return TherapistDashboard.fromJson(data);
    } catch (e) {
      debugPrint('Greška u ApiService.getTherapistDashboard: $e');
      return null;
    }
  }

  Future<List<TherapistReviewRow>> getTherapistMyReviews({
    int maxReviews = 30,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        'Zaposlenik/me/reviews',
        queryParameters: {'maxReviews': maxReviews},
      );
      final data = response.data;
      if (data is! List) return <TherapistReviewRow>[];
      return data
          .map<TherapistReviewRow>(
            (e) => TherapistReviewRow.fromJson(e as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      debugPrint('Greška u ApiService.getTherapistMyReviews: $e');
      return <TherapistReviewRow>[];
    }
  }

  Future<List<Zaposlenik>> getZaposlenici() async {
    try {
      final response = await _dio.get<dynamic>(
        'Zaposlenik',
        queryParameters: {'pageSize': 100},
      );
      return parsePagedItems(
        response.data,
        (json) => Zaposlenik.fromJson(json),
      );
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
      final code = e.response?.statusCode;
      if (code == 409) {
        return 'Therapist cannot be deleted while linked reservations exist.';
      }
      debugPrint('Greška u ApiService.deleteZaposlenik: $e');
      return 'Failed to delete therapist. Please try again.';
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
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final query = <String, dynamic>{'maxReviews': maxReviews};
      if (from != null) {
        query['from'] = DateTime(from.year, from.month, from.day)
            .toIso8601String();
      }
      if (to != null) {
        query['to'] =
            DateTime(to.year, to.month, to.day).toIso8601String();
      }
      final response = await _dio.get<dynamic>(
        'Zaposlenik/$zaposlenikId/admin-profile',
        queryParameters: query,
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

  Future<TherapistAccountStatus?> getTherapistAccountStatus(int zaposlenikId) async {
    try {
      final response = await _dio.get<dynamic>(
        'admin/therapists/$zaposlenikId/account/status',
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) return null;
      return TherapistAccountStatus.fromJson(data);
    } catch (e) {
      debugPrint('Greška u ApiService.getTherapistAccountStatus: $e');
      return null;
    }
  }

  Future<TherapistInviteResult?> inviteTherapistAccount({
    required int zaposlenikId,
    String? email,
  }) async {
    if (zaposlenikId <= 0) {
      return const TherapistInviteResult(
        success: false,
        message: 'Therapist must be saved before sending an invitation.',
      );
    }

    final payload = <String, dynamic>{};
    final trimmedEmail = email?.trim();
    if (trimmedEmail != null && trimmedEmail.isNotEmpty) {
      payload['email'] = trimmedEmail;
    }

    try {
      final response = await _dio.post<dynamic>(
        'admin/therapists/$zaposlenikId/account/invite',
        data: payload,
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) return null;
      return TherapistInviteResult.fromJson(data);
    } on DioException catch (e) {
      final parsed = _parseTherapistInviteResult(e.response?.data);
      if (parsed != null) return parsed;

      final status = e.response?.statusCode;
      debugPrint(
        'Greška u ApiService.inviteTherapistAccount ($status): $e',
      );
      if (status == 404) {
        return const TherapistInviteResult(
          success: false,
          message:
              'Invite endpoint not found. Restart the API server to load therapist invite routes.',
        );
      }
      if (status == 401 || status == 403) {
        return const TherapistInviteResult(
          success: false,
          message: 'Not authorized to send therapist invitations.',
        );
      }
      return TherapistInviteResult(
        success: false,
        message: e.message ?? 'Invite request failed.',
      );
    } catch (e) {
      debugPrint('Greška u ApiService.inviteTherapistAccount: $e');
      return TherapistInviteResult(
        success: false,
        message: 'Invite request failed: $e',
      );
    }
  }

  TherapistInviteResult? _parseTherapistInviteResult(dynamic data) {
    if (data is Map<String, dynamic>) {
      return TherapistInviteResult.fromJson(data);
    }
    if (data is Map) {
      return TherapistInviteResult.fromJson(
        Map<String, dynamic>.from(data),
      );
    }
    if (data is String && data.trim().isNotEmpty) {
      return TherapistInviteResult(success: false, message: data.trim());
    }
    return null;
  }

  Future<InviteValidationResult?> validateInviteToken(String token) async {
    try {
      final response = await _dio.get<dynamic>(
        'Account/validate-invite',
        queryParameters: {'token': token},
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) return null;
      return InviteValidationResult.fromJson(data);
    } catch (e) {
      debugPrint('Greška u ApiService.validateInviteToken: $e');
      return null;
    }
  }

  /// Returns `(success, message)` — message is user-facing in both cases.
  Future<({bool success, String message})> acceptTherapistInvite({
    required String token,
    required String password,
    required String confirmPassword,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        'Account/accept-invite',
        data: {
          'token': token,
          'password': password,
          'confirmPassword': confirmPassword,
        },
      );
      final data = response.data;
      final msg = data is Map<String, dynamic>
          ? (data['message'] as String? ?? 'Account activated.')
          : 'Account activated.';
      return (success: true, message: msg);
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = data is Map && data['message'] != null
          ? data['message'].toString()
          : 'Could not activate account. Check your link and try again.';
      debugPrint('Greška u ApiService.acceptTherapistInvite: $e');
      return (success: false, message: msg);
    } catch (e) {
      debugPrint('Greška u ApiService.acceptTherapistInvite: $e');
      return (
        success: false,
        message: 'Network error. Please try again.',
      );
    }
  }

  /// Server-side odjava (opoziv JWT tokena).
  Future<({bool success, String message})> logout() async {
    try {
      final response = await _dio.post<dynamic>('Account/logout');
      final data = response.data;
      final msg = data is Map
          ? (data['message'] as String? ?? 'Uspješno ste se odjavili.')
          : 'Uspješno ste se odjavili.';
      return (success: true, message: msg);
    } on DioException catch (e) {
      return (
        success: false,
        message: ApiErrorMessages.fromDio(e) ??
            'Odjava nije uspjela. Lokalna sesija će biti obrisana.',
      );
    } catch (e) {
      debugPrint('Greška u ApiService.logout: $e');
      return (
        success: false,
        message: 'Odjava nije uspjela. Lokalna sesija će biti obrisana.',
      );
    }
  }

  /// Promjena vlastite lozinke (potrebna trenutna lozinka).
  Future<({bool success, String message})> changePassword({
    required String staraLozinka,
    required String novaLozinka,
    required String potvrdaNoveLozinke,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        'Account/change-password',
        data: {
          'staraLozinka': staraLozinka,
          'novaLozinka': novaLozinka,
          'potvrdaNoveLozinke': potvrdaNoveLozinke,
        },
      );
      final data = response.data;
      final msg = data is Map
          ? (data['message'] as String? ?? 'Lozinka je uspješno promijenjena.')
          : 'Lozinka je uspješno promijenjena.';
      return (success: true, message: msg);
    } on DioException catch (e) {
      return (
        success: false,
        message: ApiErrorMessages.fromDio(e) ??
            'Lozinka nije promijenjena. Provjerite unos.',
      );
    } catch (e) {
      debugPrint('Greška u ApiService.changePassword: $e');
      return (
        success: false,
        message: 'Mrežna greška. Pokušajte ponovo.',
      );
    }
  }

  Future<List<Rezervacija>> getRezervacije() async {
    try {
      final response = await _dio.get<dynamic>(
        'Rezervacija',
        queryParameters: {'pageSize': 100},
      );
      return parsePagedItems(
        response.data,
        (json) => Rezervacija.fromJson(json),
      );
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
      final query = <String, dynamic>{'pageSize': 500};
      if (datum != null) {
        query['Datum'] = _apiDateOnly(datum);
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
        queryParameters: query,
      );
      return parsePagedItems(
        response.data,
        (json) => Rezervacija.fromJson(json),
      );
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

  Future<CancelRezervacijaResult?> cancelRezervacija(
    int id, {
    String? razlogOtkaza,
  }) async {
    try {
      final response = await _dio.patch<dynamic>(
        'Rezervacija/$id/cancel',
        data: {
          if (razlogOtkaza != null && razlogOtkaza.trim().isNotEmpty)
            'razlogOtkaza': razlogOtkaza.trim(),
        },
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        return CancelRezervacijaResult(
          otkazana: true,
          refundIzvrsen: false,
        );
      }
      return CancelRezervacijaResult.fromJson(data);
    } catch (e) {
      debugPrint('Greška u ApiService.cancelRezervacija: $e');
      return null;
    }
  }

  /// Admin: trajno briše rezervaciju (plaćene blokira API).
  Future<String?> deleteRezervacijaAdmin(int id) async {
    try {
      await _dio.delete<void>('Rezervacija/$id');
      return null;
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
      debugPrint('Greška u ApiService.deleteRezervacijaAdmin: $e');
      return e.message;
    }
  }

  Future<List<DateTime>> getDostupniTermini({
    required int zaposlenikId,
    required DateTime datum,
    int? uslugaId,
  }) async {
    try {
      final d = DateTime(datum.year, datum.month, datum.day);
      final dateStr =
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final query = <String, dynamic>{
        'zaposlenikId': zaposlenikId,
        'datum': dateStr,
      };
      if (uslugaId != null) query['uslugaId'] = uslugaId;
      final response = await _dio.get<dynamic>(
        'Rezervacija/dostupni-termini',
        queryParameters: query,
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
    bool isVip = false,
  }) async {
    try {
      final body = <String, dynamic>{
        'datumRezervacije': datumRezervacije.toIso8601String(),
        'uslugaId': uslugaId,
        'zaposlenikId': zaposlenikId,
        'isVip': isVip,
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
        queryParameters: {'uslugaId': uslugaId, 'pageSize': 50},
      );
      return parsePagedItems(
        response.data,
        (json) => Recenzija.fromJson(json),
      );
    } catch (e) {
      debugPrint('Greška u ApiService.getRecenzijeByUsluga: $e');
      return [];
    }
  }

  Future<(Recenzija?, String?)> createRecenzija({
    required int uslugaId,
    required int zaposlenikId,
    required int ocjena,
    required String komentar,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        'Recenzija',
        data: {
          'uslugaId': uslugaId,
          'zaposlenikId': zaposlenikId,
          'ocjena': ocjena,
          'komentar': komentar,
        },
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        return (null, 'Neočekivan odgovor servera.');
      }
      return (Recenzija.fromJson(data), null);
    } on DioException catch (e) {
      final body = e.response?.data;
      if (body is Map && body['message'] != null) {
        return (null, body['message'].toString());
      }
      debugPrint('Greška u ApiService.createRecenzija: $e');
      return (null, 'Slanje recenzije nije uspjelo.');
    } catch (e) {
      debugPrint('Greška u ApiService.createRecenzija: $e');
      return (null, 'Slanje recenzije nije uspjelo.');
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
      final response = await _dio.get<dynamic>(
        'Favorit',
        queryParameters: {'pageSize': 100},
      );
      return parsePagedItems(
        response.data,
        (json) => Usluga.fromJson(json),
      );
    } catch (e) {
      debugPrint('Greška u ApiService.getMyFavorites: $e');
      return [];
    }
  }

  Future<List<KategorijaUsluga>> getKategorijeUsluga() async {
    try {
      final response = await _dio.get<dynamic>(
        'KategorijaUsluga',
        queryParameters: {'pageSize': 100},
      );
      return parsePagedItems(
        response.data,
        (json) => KategorijaUsluga.fromJson(json),
      );
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

  /// Admin: multipart upload slike usluge; vraća puni URL iz odgovora API-ja.
  Future<String?> uploadUslugaImage(String filePath) async {
    try {
      final normalized = filePath.replaceAll(r'\', '/');
      final fileName = normalized.contains('/')
          ? normalized.split('/').last
          : normalized;
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
      });
      final response = await _dio.post<dynamic>(
        'Usluga/upload-image',
        data: form,
      );
      final data = response.data;
      if (data is Map && data['url'] != null) {
        return data['url'].toString();
      }
      return null;
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        debugPrint('uploadUslugaImage: ${data['message']}');
      }
      debugPrint('Greška u ApiService.uploadUslugaImage: $e');
      return null;
    } catch (e) {
      debugPrint('Greška u ApiService.uploadUslugaImage: $e');
      return null;
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

  /// Server-side potvrda plaćanja (Stripe API verifikacija). Klijent ne smije sam evidentirati uspjeh.
  Future<ConfirmPaymentResponse?> confirmPayment(String paymentIntentId) async {
    try {
      final response = await _dio.post<dynamic>(
        'Placanje/confirm',
        data: {'paymentIntentId': paymentIntentId},
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) return null;
      return ConfirmPaymentResponse.fromJson(data);
    } catch (e) {
      debugPrint('Greška u ApiService.confirmPayment: $e');
      return null;
    }
  }

  Future<AdminReviewsDashboard?> getAdminReviewsDashboard({
    required DateTime from,
    required DateTime toInclusive,
    int page = 1,
    int pageSize = 10,
    String? search,
    int? minOcjena,
    int? maxOcjena,
    int? uslugaId,
    int? zaposlenikId,
  }) async {
    try {
      final query = <String, dynamic>{
        'from': _dateOnly(from),
        'to': _dateOnly(toInclusive),
        'page': page,
        'pageSize': pageSize,
      };
      if (search != null && search.trim().isNotEmpty) {
        query['search'] = search.trim();
      }
      if (minOcjena != null) query['minOcjena'] = minOcjena;
      if (maxOcjena != null) query['maxOcjena'] = maxOcjena;
      if (uslugaId != null) query['uslugaId'] = uslugaId;
      if (zaposlenikId != null) query['zaposlenikId'] = zaposlenikId;

      final response = await _dio.get<dynamic>(
        'Recenzija/admin-dashboard',
        queryParameters: query,
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) return null;
      return AdminReviewsDashboard.fromJson(data);
    } catch (e) {
      debugPrint('Greška u ApiService.getAdminReviewsDashboard: $e');
      return null;
    }
  }

  String _dateOnly(DateTime d) {
    final x = DateTime(d.year, d.month, d.day);
    return '${x.year.toString().padLeft(4, '0')}-'
        '${x.month.toString().padLeft(2, '0')}-'
        '${x.day.toString().padLeft(2, '0')}';
  }

  Future<bool> downloadAdminReviewsCsv({
    required DateTime from,
    required DateTime toInclusive,
    String? search,
    int? minOcjena,
    int? maxOcjena,
    int? uslugaId,
    int? zaposlenikId,
  }) async {
    try {
      final query = <String, dynamic>{
        'from': _dateOnly(from),
        'to': _dateOnly(toInclusive),
      };
      if (search != null && search.trim().isNotEmpty) {
        query['search'] = search.trim();
      }
      if (minOcjena != null) query['minOcjena'] = minOcjena;
      if (maxOcjena != null) query['maxOcjena'] = maxOcjena;
      if (uslugaId != null) query['uslugaId'] = uslugaId;
      if (zaposlenikId != null) query['zaposlenikId'] = zaposlenikId;

      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/recenzije_export.csv';
      await _dio.download(
        'Recenzija/admin-dashboard/csv',
        filePath,
        queryParameters: query,
      );
      await OpenFile.open(filePath);
      return true;
    } catch (e) {
      debugPrint('Greška u ApiService.downloadAdminReviewsCsv: $e');
      return false;
    }
  }

  Future<AdminFinanceDashboard?> getAdminFinanceDashboard({
    required DateTime from,
    required DateTime toInclusive,
    int page = 1,
    int pageSize = 10,
    String? search,
    String? status,
    String? methodCategory,
    int? uslugaId,
  }) async {
    try {
      final query = <String, dynamic>{
        'from': _dateOnly(from),
        'to': _dateOnly(toInclusive),
        'page': page,
        'pageSize': pageSize,
      };
      if (search != null && search.trim().isNotEmpty) {
        query['search'] = search.trim();
      }
      if (status != null && status.trim().isNotEmpty) {
        query['status'] = status.trim();
      }
      if (methodCategory != null && methodCategory.trim().isNotEmpty) {
        query['methodCategory'] = methodCategory.trim();
      }
      if (uslugaId != null) query['uslugaId'] = uslugaId;

      final response = await _dio.get<dynamic>(
        'AdminFinance/dashboard',
        queryParameters: query,
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) return null;
      return AdminFinanceDashboard.fromJson(data);
    } catch (e) {
      debugPrint('Greška u ApiService.getAdminFinanceDashboard: $e');
      return null;
    }
  }

  Future<bool> downloadAdminFinanceCsv({
    required DateTime from,
    required DateTime toInclusive,
    String? search,
    String? status,
    String? methodCategory,
    int? uslugaId,
  }) async {
    try {
      final query = <String, dynamic>{
        'from': _dateOnly(from),
        'to': _dateOnly(toInclusive),
      };
      if (search != null && search.trim().isNotEmpty) {
        query['search'] = search.trim();
      }
      if (status != null && status.trim().isNotEmpty) {
        query['status'] = status.trim();
      }
      if (methodCategory != null && methodCategory.trim().isNotEmpty) {
        query['methodCategory'] = methodCategory.trim();
      }
      if (uslugaId != null) query['uslugaId'] = uslugaId;

      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/placanja_export.csv';
      await _dio.download(
        'AdminFinance/dashboard/csv',
        filePath,
        queryParameters: query,
      );
      await OpenFile.open(filePath);
      return true;
    } catch (e) {
      debugPrint('Greška u ApiService.downloadAdminFinanceCsv: $e');
      return false;
    }
  }

  /// Admin: javni odgovor na recenziju. Prazan [tekst] briše odgovor.
  Future<bool> patchRecenzijaAdminOdgovor(int recenzijaId, String? tekst) async {
    try {
      await _dio.patch<dynamic>(
        'Recenzija/$recenzijaId/admin-odgovor',
        data: {'tekst': tekst},
      );
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return false;
      debugPrint('Greška u ApiService.patchRecenzijaAdminOdgovor: $e');
      return false;
    } catch (e) {
      debugPrint('Greška u ApiService.patchRecenzijaAdminOdgovor: $e');
      return false;
    }
  }

  Future<bool> downloadReport() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/izvjestaj_top_usluge.pdf';
      await _dio.download('Izvjestaj/top-usluge', filePath);
      await OpenFile.open(filePath);
      return true;
    } catch (e) {
      debugPrint('Greška pri downloadu: $e');
      return false;
    }
  }

  Future<AdminKpi?> getAdminKpis({DateTime? date}) async {
    try {
      final response = await _dio.get<dynamic>(
        'Izvjestaj/kpi',
        queryParameters: {
          if (date != null) 'date': _apiDateOnly(date),
        },
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
    int page = 1,
    int pageSize = 100,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        'AdminKlijent',
        queryParameters: {
          if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
          'page': page,
          'pageSize': pageSize,
        },
      );
      return parsePagedItems(
        response.data,
        (json) => AdminClientRow.fromJson(json),
      );
    } catch (e) {
      debugPrint('Greška u ApiService.getAdminClients: $e');
      return [];
    }
  }

  Future<AdminClientStats?> getAdminClientStats({String? q}) async {
    try {
      final response = await _dio.get<dynamic>(
        'AdminKlijent/stats',
        queryParameters: {
          if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        },
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) return null;
      return AdminClientStats.fromJson(data);
    } catch (e) {
      debugPrint('Greška u ApiService.getAdminClientStats: $e');
      return null;
    }
  }

  Future<List<GradLookup>> getGradovi({int? drzavaId, String? naziv}) async {
    try {
      final query = <String, dynamic>{'pageSize': 100};
      if (drzavaId != null) query['drzavaId'] = drzavaId;
      if (naziv != null && naziv.trim().isNotEmpty) {
        query['naziv'] = naziv.trim();
      }

      final response = await _dio.get<dynamic>(
        'Lookup/gradovi',
        queryParameters: query,
      );
      return parsePagedItems(
        response.data,
        (json) => GradLookup.fromJson(json),
      );
    } catch (e) {
      debugPrint('Greška u ApiService.getGradovi: $e');
      return [];
    }
  }

  Future<AdminClientRow?> createAdminClient({
    required String ime,
    required String prezime,
    required String email,
    required String userName,
    required String password,
    required int gradId,
    String? telefon,
    int? zaposlenikId,
    bool isVipKlijent = false,
  }) async {
    final response = await _dio.post<dynamic>(
      'AdminKlijent',
      data: {
        'ime': ime,
        'prezime': prezime,
        'email': email,
        'userName': userName,
        'password': password,
        'telefon': telefon,
        'gradId': gradId,
        'zaposlenikId': zaposlenikId,
        'isVipKlijent': isVipKlijent,
      },
    );
    final data = response.data;
    if (data is! Map) return null;
    return AdminClientRow.fromJson(Map<String, dynamic>.from(data));
  }

  Future<AdminClientRow?> patchAdminClient({
    required int id,
    String? ime,
    String? prezime,
    String? email,
    String? telefon,
    bool? status,
    bool? isVipKlijent,
    int? gradId,
    bool setZaposlenik = false,
    int? zaposlenikId,
    String? napomenaZaTerapeuta,
    String? novaLozinka,
    String? potvrdaNoveLozinke,
  }) async {
    final body = <String, dynamic>{};
    if (ime != null) body['ime'] = ime;
    if (prezime != null) body['prezime'] = prezime;
    if (email != null) body['email'] = email;
    if (telefon != null) body['telefon'] = telefon;
    if (status != null) body['status'] = status;
    if (isVipKlijent != null) body['isVipKlijent'] = isVipKlijent;
    if (gradId != null) body['gradId'] = gradId;
    if (setZaposlenik) body['zaposlenikId'] = zaposlenikId ?? 0;
    if (napomenaZaTerapeuta != null) {
      body['napomenaZaTerapeuta'] = napomenaZaTerapeuta;
    }
    if (novaLozinka != null && novaLozinka.isNotEmpty) {
      body['novaLozinka'] = novaLozinka;
      body['potvrdaNoveLozinke'] = potvrdaNoveLozinke ?? novaLozinka;
    }

    final response = await _dio.patch<dynamic>(
      'AdminKlijent/$id',
      data: body,
    );
    final data = response.data;
    if (data is! Map) return null;
    return AdminClientRow.fromJson(Map<String, dynamic>.from(data));
  }

  /// Human-readable message from admin client API errors.
  static String? adminClientPatchErrorMessage(Object error) {
    if (error is DioException) {
      return ApiErrorMessages.fromDio(error);
    }
    return null;
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

  Future<List<SistemskaNotifikacija>> getSistemskaNotifikacije({int take = 50}) async {
    try {
      final response = await _dio.get<dynamic>(
        'SistemskaNotifikacija',
        queryParameters: {'take': take},
      );
      final data = response.data;
      if (data is! List) return [];
      return data
          .whereType<Map>()
          .map((e) => SistemskaNotifikacija.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('Greška u ApiService.getSistemskaNotifikacije: $e');
      return [];
    }
  }

  Future<int> getSistemskaNotifikacijeUnreadCount() async {
    try {
      final response = await _dio.get<dynamic>('SistemskaNotifikacija/unread-count');
      final data = response.data;
      if (data is! Map<String, dynamic>) return 0;
      return (data['brojNeprocitanih'] as num?)?.toInt() ?? 0;
    } catch (e) {
      debugPrint('Greška u ApiService.getSistemskaNotifikacijeUnreadCount: $e');
      return 0;
    }
  }

  Future<bool> markSistemskaNotifikacijaRead(int id) async {
    try {
      await _dio.patch<void>('SistemskaNotifikacija/$id/procitana');
      return true;
    } catch (e) {
      debugPrint('Greška u ApiService.markSistemskaNotifikacijaRead: $e');
      return false;
    }
  }

  Future<bool> markAllSistemskaNotifikacijeRead() async {
    try {
      await _dio.patch<void>('SistemskaNotifikacija/procitaj-sve');
      return true;
    } catch (e) {
      debugPrint('Greška u ApiService.markAllSistemskaNotifikacijeRead: $e');
      return false;
    }
  }

  Future<List<Obavijest>> getObavijesti() async {
    try {
      final response = await _dio.get<dynamic>(
        'Obavijest',
        queryParameters: {'pageSize': 50},
      );
      return parsePagedItems(
        response.data,
        (json) => Obavijest.fromJson(json),
      );
    } catch (e) {
      debugPrint('Greška u ApiService.getObavijesti: $e');
      return [];
    }
  }
}
