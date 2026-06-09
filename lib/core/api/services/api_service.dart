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
import '../../../models/reviewable_visit.dart';
import '../../../models/service_load_result.dart';
import '../../../models/zaposlenici_load_result.dart';
import '../../../models/payment_intent_response.dart';
import '../../../models/cancel_rezervacija_result.dart';
import '../../../models/sistemska_notifikacija.dart';
import '../../../models/admin/admin_client_row.dart';
import '../../../models/admin/admin_client_stats.dart';
import '../../../models/admin/admin_kpi.dart';
import '../../../models/admin/revenue_point.dart';
import '../../../models/admin/activity_feed_item.dart';
import '../../../models/admin/service_popularity.dart';
import '../../../models/admin/top_spender.dart';
import '../../../models/admin/rezervacija_calendar_item.dart';
import '../../../models/admin/therapist_kpi.dart';
import '../../../models/admin/therapist_admin_profile.dart';
import '../../../models/admin/therapist_account_status.dart';
import '../../../models/admin/therapist_admin_roster.dart';
import '../../../models/admin/therapist_day_availability.dart';
import '../../../models/therapist/therapist_dashboard.dart';
import '../../../models/admin/spa_centar.dart';
import '../../../models/admin/admin_reviews_dashboard.dart';
import '../../../models/admin/admin_finance_dashboard.dart';
import '../../../models/admin/radno_vrijeme.dart';
import '../../../models/grad_lookup.dart';
import '../../../models/account_profile.dart';

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
      return await getUslugePage(
        page: 1,
        naziv: naziv,
        maxCijena: maxCijena,
      );
    } catch (e) {
      debugPrint('Greška u ApiService.getUsluge: $e');
      return [];
    }
  }

  Future<List<Usluga>> getUslugePage({
    required int page,
    int pageSize = 100,
    String? naziv,
    double? maxCijena,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'pageSize': pageSize,
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
  }

  /// Service catalog: all pages (backend max pageSize = 100).
  Future<List<Usluga>> getUslugeAll({
    String? naziv,
    double? maxCijena,
    int pageSize = 100,
    int maxPages = 50,
  }) async {
    final all = <Usluga>[];
    for (var page = 1; page <= maxPages; page++) {
      final items = await getUslugePage(
        page: page,
        pageSize: pageSize,
        naziv: naziv,
        maxCijena: maxCijena,
      );
      all.addAll(items);
      if (items.length < pageSize) break;
    }
    return all;
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

  Future<ServiceLoadResult> getUslugaById(int id) async {
    try {
      final response = await _dio.get<dynamic>('Usluga/$id');
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        return const ServiceLoadResult(notFound: true);
      }
      return ServiceLoadResult(service: Usluga.fromJson(data));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return const ServiceLoadResult(notFound: true);
      }
      debugPrint('Greška u ApiService.getUslugaById: $e');
      return ServiceLoadResult(
        error: ApiErrorMessages.fromDio(e) ??
            'Could not load service. Check your connection.',
      );
    } catch (e) {
      debugPrint('Greška u ApiService.getUslugaById: $e');
      return const ServiceLoadResult(
        error: 'Could not load service. Check your connection.',
      );
    }
  }

  Future<ZaposleniciLoadResult> getZaposleniciForService(int uslugaId) async {
    try {
      final response = await _dio.get<dynamic>(
        'Zaposlenik/for-service/$uslugaId',
      );
      final data = response.data;
      if (data is! List) {
        return const ZaposleniciLoadResult();
      }
      final items = data
          .map((e) => Zaposlenik.fromJson(e as Map<String, dynamic>))
          .toList();
      return ZaposleniciLoadResult(items: items);
    } on DioException catch (e) {
      debugPrint('Greška u ApiService.getZaposleniciForService: $e');
      return ZaposleniciLoadResult(
        error: ApiErrorMessages.fromDio(e) ??
            'Could not load therapists for this service.',
      );
    } catch (e) {
      debugPrint('Greška u ApiService.getZaposleniciForService: $e');
      return const ZaposleniciLoadResult(
        error: 'Could not load therapists for this service.',
      );
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

  Future<(List<TherapistReviewRow> items, String? error)> getTherapistMyReviews({
    int maxReviews = 30,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        'Zaposlenik/me/reviews',
        queryParameters: {'maxReviews': maxReviews},
      );
      final data = response.data;
      if (data is! List) {
        return (<TherapistReviewRow>[], 'Unexpected server response.');
      }
      final items = data
          .map<TherapistReviewRow>(
            (e) => TherapistReviewRow.fromJson(e as Map<String, dynamic>),
          )
          .toList();
      return (items, null);
    } catch (e) {
      debugPrint('Greška u ApiService.getTherapistMyReviews: $e');
      return (<TherapistReviewRow>[], 'Could not load reviews.');
    }
  }

  Future<List<Zaposlenik>> getZaposlenici() async {
    final result = await getZaposleniciResult();
    return result.therapists;
  }

  Future<({List<Zaposlenik> therapists, String? error})> getZaposleniciResult() async {
    try {
      final all = <Zaposlenik>[];
      var page = 1;
      const pageSize = 100;
      while (true) {
        final response = await _dio.get<dynamic>(
          'Zaposlenik',
          queryParameters: {'page': page, 'pageSize': pageSize},
        );
        final data = response.data;
        final items = parsePagedItems(
          data,
          (json) => Zaposlenik.fromJson(json),
        );
        all.addAll(items);
        final total = parsePagedTotal(data);
        if (total == null || all.length >= total || items.isEmpty) {
          break;
        }
        page++;
      }
      return (therapists: all, error: null);
    } catch (e) {
      debugPrint('Greška u ApiService.getZaposlenici: $e');
      final message = e is DioException
          ? ApiErrorMessages.fromDio(e)
          : null;
      return (
        therapists: <Zaposlenik>[],
        error: message ?? 'Unable to load therapists.',
      );
    }
  }

  Future<({TherapistAdminRoster? data, String? error})> getTherapistAdminRoster({
    DateTime? kpiFrom,
    DateTime? kpiTo,
    DateTime? weekStart,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        'Zaposlenik/admin-roster',
        queryParameters: {
          if (kpiFrom != null) 'kpiFrom': _apiDateOnly(kpiFrom),
          if (kpiTo != null) 'kpiTo': _apiDateOnly(kpiTo),
          if (weekStart != null) 'weekStart': _apiDateOnly(weekStart),
        },
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        return (data: null, error: 'Invalid therapist roster response.');
      }
      return (
        data: TherapistAdminRoster.fromJson(data),
        error: null,
      );
    } catch (e) {
      debugPrint('Greška u ApiService.getTherapistAdminRoster: $e');
      final message = e is DioException
          ? ApiErrorMessages.fromDio(e)
          : null;
      return (
        data: null,
        error: message ?? 'Unable to load therapist roster.',
      );
    }
  }

  Future<({Zaposlenik? therapist, String? error})> createZaposlenik(
    Zaposlenik zaposlenik,
  ) async {
    try {
      final response = await _dio.post<dynamic>(
        'Zaposlenik',
        data: zaposlenik.toJson(includeId: false),
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        return (therapist: null, error: 'Invalid response when creating therapist.');
      }
      return (therapist: Zaposlenik.fromJson(data), error: null);
    } catch (e) {
      debugPrint('Greška u ApiService.createZaposlenik: $e');
      final message = e is DioException
          ? ApiErrorMessages.fromDio(e)
          : null;
      return (
        therapist: null,
        error: message ?? 'Failed to save therapist.',
      );
    }
  }

  Future<({Zaposlenik? therapist, String? error})> updateZaposlenik(
    Zaposlenik zaposlenik,
  ) async {
    try {
      final response = await _dio.put<dynamic>(
        'Zaposlenik/${zaposlenik.id}',
        data: zaposlenik.toJson(),
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        return (therapist: null, error: 'Invalid response when updating therapist.');
      }
      return (therapist: Zaposlenik.fromJson(data), error: null);
    } catch (e) {
      debugPrint('Greška u ApiService.updateZaposlenik: $e');
      final message = e is DioException
          ? ApiErrorMessages.fromDio(e)
          : null;
      return (
        therapist: null,
        error: message ?? 'Failed to save therapist.',
      );
    }
  }

  Future<String?> deleteZaposlenik(int id) async {
    try {
      await _dio.delete<void>('Zaposlenik/$id');
      return null;
    } on DioException catch (e) {
      final message = ApiErrorMessages.fromDio(e);
      if (message != null) return message;
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
          'from': _apiDateOnly(from),
          'to': _apiDateOnly(to),
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

  Future<({TherapistAdminProfile? data, String? error})>
      getTherapistAdminProfile({
    required int zaposlenikId,
    int maxReviews = 20,
    DateTime? from,
    DateTime? to,
    DateTime? weekStart,
  }) async {
    try {
      final query = <String, dynamic>{'maxReviews': maxReviews};
      if (from != null) {
        query['from'] = _apiDateOnly(from);
      }
      if (to != null) {
        query['to'] = _apiDateOnly(to);
      }
      if (weekStart != null) {
        query['weekStart'] = _apiDateOnly(weekStart);
      }
      final response = await _dio.get<dynamic>(
        'Zaposlenik/$zaposlenikId/admin-profile',
        queryParameters: query,
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        return (data: null, error: 'Invalid therapist profile response.');
      }
      return (
        data: TherapistAdminProfile.fromJson(data),
        error: null,
      );
    } catch (e) {
      debugPrint('Greška u ApiService.getTherapistAdminProfile: $e');
      final message = e is DioException
          ? ApiErrorMessages.fromDio(e)
          : null;
      return (
        data: null,
        error: message ?? 'Unable to load therapist profile.',
      );
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

  Future<({TherapistAccountStatus? data, String? error})>
      getTherapistAccountStatus(int zaposlenikId) async {
    try {
      final response = await _dio.get<dynamic>(
        'admin/therapists/$zaposlenikId/account/status',
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        return (data: null, error: 'Invalid portal account status response.');
      }
      return (
        data: TherapistAccountStatus.fromJson(data),
        error: null,
      );
    } catch (e) {
      debugPrint('Greška u ApiService.getTherapistAccountStatus: $e');
      final message = e is DioException
          ? ApiErrorMessages.fromDio(e)
          : null;
      return (
        data: null,
        error: message ?? 'Unable to load portal account status.',
      );
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

  Future<AccountProfile?> getAccountProfile() async {
    try {
      final response = await _dio.get<dynamic>('Account/me');
      final data = response.data;
      if (data is! Map<String, dynamic>) return null;
      return AccountProfile.fromJson(data);
    } on DioException catch (e) {
      debugPrint('ApiService.getAccountProfile: ${ApiErrorMessages.fromDio(e)}');
      return null;
    } catch (e) {
      debugPrint('Greška u ApiService.getAccountProfile: $e');
      return null;
    }
  }

  /// Promjena vlastite lozinke (potrebna trenutna lozinka).
  Future<({bool success, String message, String? token})> changePassword({
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
      if (data is Map) {
        final msg = data['message'] as String? ?? 'Password changed successfully.';
        final token = data['token'] as String?;
        return (success: true, message: msg, token: token);
      }
      return (
        success: true,
        message: 'Password changed successfully.',
        token: null,
      );
    } on DioException catch (e) {
      return (
        success: false,
        message: ApiErrorMessages.fromDio(e) ??
            'Password was not changed. Check your input.',
        token: null,
      );
    } catch (e) {
      debugPrint('Greška u ApiService.changePassword: $e');
      return (
        success: false,
        message: 'Network error. Please try again.',
        token: null,
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
      // Note: backend clamps pageSize to MaxPageSize (currently 100).
      // This method returns only the first page (for backwards compatibility).
      final query = <String, dynamic>{'pageSize': 100, 'page': 1};
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

  /// Admin screens: fetch all pages of reservations (backend enforces max pageSize=100).
  Future<List<Rezervacija>> getRezervacijeFilteredAll({
    DateTime? datum,
    bool? isPotvrdjena,
    bool includeOtkazane = false,
    int? zaposlenikId,
    int pageSize = 100,
    int maxPages = 50,
  }) async {
    final result = await getRezervacijeFilteredAllResult(
      datum: datum,
      isPotvrdjena: isPotvrdjena,
      includeOtkazane: includeOtkazane,
      zaposlenikId: zaposlenikId,
      pageSize: pageSize,
      maxPages: maxPages,
    );
    return result.items;
  }

  Future<({List<Rezervacija> items, String? error})>
      getRezervacijeFilteredAllResult({
    DateTime? datum,
    bool? isPotvrdjena,
    bool includeOtkazane = false,
    int? zaposlenikId,
    int pageSize = 100,
    int maxPages = 50,
  }) async {
    try {
      final all = <Rezervacija>[];
      for (var page = 1; page <= maxPages; page++) {
        final pageItems = await _getRezervacijeFilteredPage(
          page: page,
          pageSize: pageSize,
          datum: datum,
          isPotvrdjena: isPotvrdjena,
          includeOtkazane: includeOtkazane,
          zaposlenikId: zaposlenikId,
        );
        all.addAll(pageItems);
        if (pageItems.length < pageSize) break;
      }
      return (items: all, error: null);
    } catch (e) {
      debugPrint('Greška u ApiService.getRezervacijeFilteredAllResult: $e');
      final message = e is DioException
          ? ApiErrorMessages.fromDio(e)
          : null;
      return (
        items: <Rezervacija>[],
        error: message ?? 'Unable to load appointments.',
      );
    }
  }

  Future<List<Rezervacija>> _getRezervacijeFilteredPage({
    required int page,
    required int pageSize,
    DateTime? datum,
    bool? isPotvrdjena,
    bool includeOtkazane = false,
    int? zaposlenikId,
  }) async {
    try {
      final query = <String, dynamic>{'pageSize': pageSize, 'page': page};
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
      debugPrint('Greška u ApiService._getRezervacijeFilteredPage: $e');
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

  Future<({TherapistDayAvailability? data, String? error})>
      getTherapistDayAvailability({
    required int zaposlenikId,
    required DateTime datum,
  }) async {
    try {
      final d = DateTime(datum.year, datum.month, datum.day);
      final response = await _dio.get<dynamic>(
        'Rezervacija/therapist-day-availability',
        queryParameters: {
          'zaposlenikId': zaposlenikId,
          'datum': _apiDateOnly(d),
        },
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        return (data: null, error: 'Invalid day availability response.');
      }
      return (
        data: TherapistDayAvailability.fromJson(data),
        error: null,
      );
    } catch (e) {
      debugPrint('Greška u ApiService.getTherapistDayAvailability: $e');
      final message =
          e is DioException ? ApiErrorMessages.fromDio(e) : null;
      return (
        data: null,
        error: message ?? 'Unable to load day availability.',
      );
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

  /// Admin create with API error text when the request fails.
  Future<({Rezervacija? data, String? error})> createRezervacijaWithMessage({
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
      if (data is! Map<String, dynamic>) {
        return (data: null, error: 'Unable to create appointment.');
      }
      return (data: Rezervacija.fromJson(data), error: null);
    } on DioException catch (e) {
      return (
        data: null,
        error: ApiErrorMessages.fromDio(e) ?? 'Unable to create appointment.',
      );
    } catch (e) {
      debugPrint('Greška u ApiService.createRezervacijaWithMessage: $e');
      return (data: null, error: 'Unable to create appointment.');
    }
  }

  /// Admin edit with API error text when the request fails.
  Future<({Rezervacija? data, String? error})> editRezervacijaWithMessage({
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
      if (data is! Map<String, dynamic>) {
        return (data: null, error: 'Unable to update appointment.');
      }
      return (data: Rezervacija.fromJson(data), error: null);
    } on DioException catch (e) {
      return (
        data: null,
        error: ApiErrorMessages.fromDio(e) ?? 'Unable to update appointment.',
      );
    } catch (e) {
      debugPrint('Greška u ApiService.editRezervacijaWithMessage: $e');
      return (data: null, error: 'Unable to update appointment.');
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

  Future<RecenzijeLoadResult> getRecenzijeByUsluga(int uslugaId) async {
    try {
      final all = <Recenzija>[];
      var page = 1;
      const pageSize = 50;
      const maxPages = 20;
      int? total;

      while (page <= maxPages) {
        final response = await _dio.get<dynamic>(
          'Recenzija',
          queryParameters: {
            'uslugaId': uslugaId,
            'page': page,
            'pageSize': pageSize,
          },
        );
        final batch = parsePagedItems(
          response.data,
          (json) => Recenzija.fromJson(json),
        );
        all.addAll(batch);
        total = parsePagedTotal(response.data);
        if (batch.isEmpty || total == null || all.length >= total) break;
        page++;
      }

      final truncated = total != null && all.length < total;
      return RecenzijeLoadResult(items: all, truncated: truncated);
    } catch (e) {
      debugPrint('Greška u ApiService.getRecenzijeByUsluga: $e');
      return const RecenzijeLoadResult(
        error: 'Could not load reviews. Check your connection.',
      );
    }
  }

  Future<ReviewableVisitsLoadResult> getReviewableVisits(int uslugaId) async {
    try {
      final response = await _dio.get<dynamic>(
        'Recenzija/reviewable-visits',
        queryParameters: {'uslugaId': uslugaId},
      );
      final data = response.data;
      if (data is! List) {
        return const ReviewableVisitsLoadResult(
          error: 'Could not load reviewable visits.',
        );
      }
      final items = data
          .whereType<Map<String, dynamic>>()
          .map(ReviewableVisit.fromJson)
          .toList();
      return ReviewableVisitsLoadResult(items: items);
    } on DioException catch (e) {
      debugPrint('Greška u ApiService.getReviewableVisits: $e');
      return ReviewableVisitsLoadResult(
        error: ApiErrorMessages.fromDio(e) ??
            'Could not load reviewable visits.',
      );
    } catch (e) {
      debugPrint('Greška u ApiService.getReviewableVisits: $e');
      return const ReviewableVisitsLoadResult(
        error: 'Could not load reviewable visits.',
      );
    }
  }

  Future<(Recenzija?, String?)> createRecenzija({
    required int rezervacijaId,
    required int uslugaId,
    required int zaposlenikId,
    required int ocjena,
    required String komentar,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        'Recenzija',
        data: {
          'rezervacijaId': rezervacijaId,
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
      debugPrint('Greška u ApiService.createRecenzija: $e');
      return (
        null,
        ApiErrorMessages.fromDio(e) ?? 'Could not submit your review.',
      );
    } catch (e) {
      debugPrint('Greška u ApiService.createRecenzija: $e');
      return (null, 'Could not submit your review.');
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
      return await getKategorijeUslugaPage(page: 1);
    } catch (e) {
      debugPrint('Greška u ApiService.getKategorijeUsluga: $e');
      return [];
    }
  }

  Future<List<KategorijaUsluga>> getKategorijeUslugaPage({
    required int page,
    int pageSize = 100,
  }) async {
    final response = await _dio.get<dynamic>(
      'KategorijaUsluga',
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    return parsePagedItems(
      response.data,
      (json) => KategorijaUsluga.fromJson(json),
    );
  }

  /// Service catalog: all category pages.
  Future<List<KategorijaUsluga>> getKategorijeUslugaAll({
    int pageSize = 100,
    int maxPages = 20,
  }) async {
    final all = <KategorijaUsluga>[];
    for (var page = 1; page <= maxPages; page++) {
      final items = await getKategorijeUslugaPage(page: page, pageSize: pageSize);
      all.addAll(items);
      if (items.length < pageSize) break;
    }
    return all;
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

  Future<String?> _parseUploadedImageUrl(Response<dynamic> response) async {
    final data = response.data;
    if (data is Map && data['url'] != null) {
      return data['url'].toString();
    }
    return null;
  }

  /// Admin: multipart upload slike usluge s diska; vraća URL iz odgovora API-ja.
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
      return _parseUploadedImageUrl(response);
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

  /// Admin: multipart upload from in-memory bytes (Flutter web and desktop).
  Future<String?> uploadUslugaImageBytes(
    List<int> bytes, {
    required String fileName,
  }) async {
    try {
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: fileName),
      });
      final response = await _dio.post<dynamic>(
        'Usluga/upload-image',
        data: form,
      );
      return _parseUploadedImageUrl(response);
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        debugPrint('uploadUslugaImageBytes: ${data['message']}');
      }
      debugPrint('Greška u ApiService.uploadUslugaImageBytes: $e');
      return null;
    } catch (e) {
      debugPrint('Greška u ApiService.uploadUslugaImageBytes: $e');
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

  Future<bool> completeRezervacija(int id) async {
    try {
      await _dio.patch<void>('Rezervacija/$id/complete');
      return true;
    } catch (e) {
      debugPrint('Greška u ApiService.completeRezervacija: $e');
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

  Future<({AdminReviewsDashboard? data, String? error})>
      getAdminReviewsDashboardResult({
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
      if (data is! Map<String, dynamic>) {
        return (data: null, error: 'Unexpected server response.');
      }
      return (data: AdminReviewsDashboard.fromJson(data), error: null);
    } on DioException catch (e) {
      debugPrint('Greška u ApiService.getAdminReviewsDashboard: $e');
      final status = e.response?.statusCode;
      if (status == 403) {
        return (data: null, error: 'Admin access required to view reviews.');
      }
      return (
        data: null,
        error: ApiErrorMessages.fromDio(e) ?? 'Could not load reviews dashboard.',
      );
    } catch (e) {
      debugPrint('Greška u ApiService.getAdminReviewsDashboard: $e');
      return (data: null, error: 'Could not load reviews dashboard.');
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
    final result = await getAdminReviewsDashboardResult(
      from: from,
      toInclusive: toInclusive,
      page: page,
      pageSize: pageSize,
      search: search,
      minOcjena: minOcjena,
      maxOcjena: maxOcjena,
      uslugaId: uslugaId,
      zaposlenikId: zaposlenikId,
    );
    return result.data;
  }

  String _dateOnly(DateTime d) {
    final x = DateTime(d.year, d.month, d.day);
    return '${x.year.toString().padLeft(4, '0')}-'
        '${x.month.toString().padLeft(2, '0')}-'
        '${x.day.toString().padLeft(2, '0')}';
  }

  Future<({bool ok, bool truncated})> downloadAdminReviewsCsvResult({
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
      final response = await _dio.download(
        'Recenzija/admin-dashboard/csv',
        filePath,
        queryParameters: query,
      );
      await OpenFile.open(filePath);
      final truncated =
          response.headers.value('x-export-truncated')?.toLowerCase() == 'true';
      return (ok: true, truncated: truncated);
    } catch (e) {
      debugPrint('Greška u ApiService.downloadAdminReviewsCsv: $e');
      return (ok: false, truncated: false);
    }
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
    final result = await downloadAdminReviewsCsvResult(
      from: from,
      toInclusive: toInclusive,
      search: search,
      minOcjena: minOcjena,
      maxOcjena: maxOcjena,
      uslugaId: uslugaId,
      zaposlenikId: zaposlenikId,
    );
    return result.ok;
  }

  Future<bool> deleteRecenzija(int recenzijaId) async {
    try {
      await _dio.delete<dynamic>('Recenzija/$recenzijaId');
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return false;
      debugPrint('Greška u ApiService.deleteRecenzija: $e');
      return false;
    } catch (e) {
      debugPrint('Greška u ApiService.deleteRecenzija: $e');
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
    } on DioException catch (e) {
      debugPrint('ApiService.getAdminFinanceDashboard failed: $e');
      return null;
    } catch (e) {
      debugPrint('ApiService.getAdminFinanceDashboard failed: $e');
      return null;
    }
  }

  Future<FinanceCsvExportResult> downloadAdminFinanceCsv({
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
      final fromLabel = _dateOnly(from);
      final toLabel = _dateOnly(toInclusive);
      final filePath = '${directory.path}/payments_${fromLabel}_$toLabel.csv';
      final response = await _dio.download(
        'AdminFinance/dashboard/csv',
        filePath,
        queryParameters: query,
      );
      final headers = response.headers;
      final truncated = headers.value('x-export-truncated') == 'true';
      final exported = int.tryParse(headers.value('x-export-rows') ?? '') ?? 0;
      final total = int.tryParse(headers.value('x-export-total') ?? '') ?? 0;
      final disposition = headers.value('content-disposition');
      String openPath = filePath;
      if (disposition != null && disposition.contains('filename=')) {
        final match = RegExp(r'filename="?([^";]+)"?').firstMatch(disposition);
        if (match != null) {
          openPath = '${directory.path}/${match.group(1)}';
        }
      }
      await OpenFile.open(openPath);
      return FinanceCsvExportResult(
        ok: true,
        truncated: truncated,
        exportedRows: exported,
        totalRows: total,
      );
    } on DioException catch (e) {
      final msg = e.response?.statusCode == 401
          ? 'Session expired. Sign in again.'
          : 'CSV export failed (${e.response?.statusCode ?? 'network'}).';
      debugPrint('ApiService.downloadAdminFinanceCsv failed: $e');
      return FinanceCsvExportResult(ok: false, errorMessage: msg);
    } catch (e) {
      debugPrint('ApiService.downloadAdminFinanceCsv failed: $e');
      return FinanceCsvExportResult(ok: false, errorMessage: 'CSV export failed.');
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

  Future<bool> downloadReport({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/izvjestaj_top_usluge.pdf';
      await _dio.download(
        'Izvjestaj/top-usluge',
        filePath,
        queryParameters: {
          'from': _apiDateOnly(from),
          'to': _apiDateOnly(to),
        },
      );
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
          'from': _apiDateOnly(from),
          'to': _apiDateOnly(to),
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

  Future<List<ActivityFeedItem>> getAdminActivityFeed({
    required DateTime day,
    int take = 12,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        'Izvjestaj/activity-feed',
        queryParameters: {
          'day': _apiDateOnly(day),
          'take': take,
        },
      );
      final data = response.data;
      if (data is! List) return [];
      return data
          .whereType<Map>()
          .map((e) => ActivityFeedItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('Greška u ApiService.getAdminActivityFeed: $e');
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
          'from': _apiDateOnly(from),
          'to': _apiDateOnly(to),
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

  Future<({
    AdminKpi? kpi,
    List<RevenuePoint> revenue,
    List<ServicePopularity> popularity,
    List<TopSpender> spenders,
    String? error,
    List<String> warnings,
  })> getAdminReportsDataResult({
    required DateTime from,
    required DateTime to,
    int popularityTake = 8,
    int spendersTake = 8,
  }) async {
    final warnings = <String>[];
    AdminKpi? kpi;
    List<RevenuePoint> revenue = const [];
    List<ServicePopularity> popularity = const [];
    List<TopSpender> spenders = const [];
    String? fatalError;

    try {
      final response = await _dio.get<dynamic>(
        'Izvjestaj/kpi',
        queryParameters: {'date': _apiDateOnly(DateTime.now())},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        kpi = AdminKpi.fromJson(data);
      } else {
        warnings.add('Today KPIs returned an unexpected response.');
      }
    } on DioException catch (e) {
      warnings.add(
        ApiErrorMessages.fromDio(e) ?? 'Today KPIs could not be loaded.',
      );
    } catch (_) {
      warnings.add('Today KPIs could not be loaded.');
    }

    try {
      final response = await _dio.get<dynamic>(
        'Izvjestaj/revenue',
        queryParameters: {
          'from': _apiDateOnly(from),
          'to': _apiDateOnly(to),
        },
      );
      final data = response.data;
      if (data is! List) {
        fatalError = 'Revenue data returned an unexpected response.';
      } else {
        revenue = data
            .whereType<Map>()
            .map((e) => RevenuePoint.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } on DioException catch (e) {
      fatalError = ApiErrorMessages.fromDio(e) ?? 'Could not load revenue data.';
    } catch (_) {
      fatalError = 'Could not load revenue data.';
    }

    if (fatalError == null) {
      try {
        final response = await _dio.get<dynamic>(
          'Izvjestaj/service-popularity',
          queryParameters: {
            'from': _apiDateOnly(from),
            'to': _apiDateOnly(to),
            'take': popularityTake,
          },
        );
        final data = response.data;
        if (data is List) {
          popularity = data
              .whereType<Map>()
              .map((e) =>
                  ServicePopularity.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        } else {
          warnings.add('Service popularity returned an unexpected response.');
        }
      } on DioException catch (e) {
        warnings.add(
          ApiErrorMessages.fromDio(e) ??
              'Service popularity could not be loaded.',
        );
      } catch (_) {
        warnings.add('Service popularity could not be loaded.');
      }

      try {
        final response = await _dio.get<dynamic>(
          'Izvjestaj/top-spenders',
          queryParameters: {
            'from': _apiDateOnly(from),
            'to': _apiDateOnly(to),
            'take': spendersTake,
          },
        );
        final data = response.data;
        if (data is List) {
          spenders = data
              .whereType<Map>()
              .map((e) => TopSpender.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        } else {
          warnings.add('Top clients returned an unexpected response.');
        }
      } on DioException catch (e) {
        warnings.add(
          ApiErrorMessages.fromDio(e) ?? 'Top clients could not be loaded.',
        );
      } catch (_) {
        warnings.add('Top clients could not be loaded.');
      }
    }

    return (
      kpi: kpi,
      revenue: revenue,
      popularity: popularity,
      spenders: spenders,
      error: fatalError,
      warnings: warnings,
    );
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
          'from': _apiDateOnly(from),
          'to': _apiDateOnly(to),
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
      rethrow;
    }
  }

  /// Admin screens: fetch all pages of clients (backend enforces max pageSize=100).
  Future<List<AdminClientRow>> getAdminClientsAll({
    String? q,
    int pageSize = 100,
    int maxPages = 50,
  }) async {
    final all = <AdminClientRow>[];
    for (var page = 1; page <= maxPages; page++) {
      final items = await getAdminClients(q: q, page: page, pageSize: pageSize);
      all.addAll(items);
      if (items.length < pageSize) break;
    }
    return all;
  }

  /// Returns all client pages plus server total when available.
  Future<({List<AdminClientRow> clients, int? serverTotal})>
      getAdminClientsAllWithTotal({
    String? q,
    int pageSize = 100,
    int maxPages = 50,
  }) async {
    final all = <AdminClientRow>[];
    int? serverTotal;
    for (var page = 1; page <= maxPages; page++) {
      final response = await _dio.get<dynamic>(
        'AdminKlijent',
        queryParameters: {
          if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
          'page': page,
          'pageSize': pageSize,
        },
      );
      serverTotal ??= parsePagedTotal(response.data);
      final pageItems = parsePagedItems(
        response.data,
        (json) => AdminClientRow.fromJson(json),
      );
      all.addAll(pageItems);
      if (pageItems.length < pageSize) break;
    }
    return (clients: all, serverTotal: serverTotal);
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
      rethrow;
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
    String? telefon,
    bool isVipKlijent = false,
    String? napomenaZaTerapeuta,
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
        'isVipKlijent': isVipKlijent,
        if (napomenaZaTerapeuta != null && napomenaZaTerapeuta.isNotEmpty)
          'napomenaZaTerapeuta': napomenaZaTerapeuta,
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

  Future<CalendarFetchResult> getRezervacijeCalendar({
    required DateTime from,
    required DateTime to,
    int? zaposlenikId,
    int? uslugaId,
    String? q,
    bool includeOtkazane = false,
  }) async {
    try {
      final query = <String, dynamic>{
        'from': _apiDateOnly(from),
        'to': _apiDateOnly(to),
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
      if (data is! List) {
        return const CalendarFetchResult(items: []);
      }
      final items = data
          .whereType<Map>()
          .map(
            (e) =>
                RezervacijaCalendarItem.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList();
      return CalendarFetchResult(items: items);
    } catch (e) {
      debugPrint('Greška u ApiService.getRezervacijeCalendar: $e');
      final message = e is DioException
          ? ApiErrorMessages.fromDio(e)
          : null;
      return CalendarFetchResult(
        items: const [],
        error: message ?? 'Unable to load calendar appointments.',
      );
    }
  }

  Future<Rezervacija?> getRezervacijaById(int id) async {
    try {
      final response = await _dio.get<dynamic>('Rezervacija/$id');
      final data = response.data;
      if (data is! Map<String, dynamic>) return null;
      return Rezervacija.fromJson(data);
    } catch (e) {
      debugPrint('Greška u ApiService.getRezervacijaById: $e');
      return null;
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
}
