import '../rezervacija.dart';

class TherapistAppointmentRow {
  final int id;
  final DateTime datumRezervacije;
  final String status;
  final bool isPotvrdjena;
  final bool isPlacena;
  final bool isOtkazana;
  final String? razlogOtkaza;
  final DateTime? otkazanaAt;
  final bool isVip;
  final bool premiumKlijent;
  final int korisnikId;
  final String? korisnikIme;
  final String? korisnikTelefon;
  final String? korisnikEmail;
  final String? napomenaZaTerapeuta;
  final String? uslugaNaziv;
  final int uslugaId;
  final int uslugaTrajanjeMinuta;
  final double uslugaCijena;
  final String? prostorijaNaziv;

  const TherapistAppointmentRow({
    required this.id,
    required this.datumRezervacije,
    required this.status,
    required this.isPotvrdjena,
    required this.isPlacena,
    required this.isOtkazana,
    this.razlogOtkaza,
    this.otkazanaAt,
    this.isVip = false,
    this.premiumKlijent = false,
    this.korisnikId = 0,
    this.korisnikIme,
    this.korisnikTelefon,
    this.korisnikEmail,
    this.napomenaZaTerapeuta,
    this.uslugaNaziv,
    this.uslugaId = 0,
    this.uslugaTrajanjeMinuta = 0,
    this.uslugaCijena = 0,
    this.prostorijaNaziv,
  });

  factory TherapistAppointmentRow.fromJson(Map<String, dynamic> json) {
    return TherapistAppointmentRow(
      id: (json['id'] as num).toInt(),
      datumRezervacije: DateTime.parse(json['datumRezervacije'] as String),
      status: (json['status'] as String?) ?? 'Pending',
      isPotvrdjena: json['isPotvrdjena'] as bool? ?? false,
      isPlacena: (json['isPlacena'] as bool?) ??
          (json['isPaid'] as bool?) ??
          false,
      isOtkazana: json['isOtkazana'] as bool? ?? false,
      razlogOtkaza: json['razlogOtkaza'] as String?,
      otkazanaAt: (json['otkazanaAt'] as String?) == null
          ? null
          : DateTime.parse(json['otkazanaAt'] as String),
      isVip: json['isVip'] as bool? ?? false,
      premiumKlijent: json['premiumKlijent'] as bool? ?? false,
      korisnikId: (json['korisnikId'] as num?)?.toInt() ?? 0,
      korisnikIme: json['korisnikIme'] as String?,
      korisnikTelefon: json['korisnikTelefon'] as String?,
      korisnikEmail: json['korisnikEmail'] as String?,
      napomenaZaTerapeuta: json['napomenaZaTerapeuta'] as String?,
      uslugaNaziv: json['uslugaNaziv'] as String?,
      uslugaId: (json['uslugaId'] as num?)?.toInt() ?? 0,
      uslugaTrajanjeMinuta:
          (json['uslugaTrajanjeMinuta'] as num?)?.toInt() ?? 0,
      uslugaCijena: (json['uslugaCijena'] as num?)?.toDouble() ?? 0,
      prostorijaNaziv: json['prostorijaNaziv'] as String?,
    );
  }

  Rezervacija toRezervacija({required int zaposlenikId}) {
    return Rezervacija(
      id: id,
      datumRezervacije: datumRezervacije,
      status: status,
      isPotvrdjena: isPotvrdjena,
      isPlacena: isPlacena,
      isOtkazana: isOtkazana,
      razlogOtkaza: razlogOtkaza,
      otkazanaAt: otkazanaAt,
      korisnikId: korisnikId,
      korisnikIme: korisnikIme,
      korisnikTelefon: korisnikTelefon,
      korisnikEmail: korisnikEmail,
      napomenaZaTerapeuta: napomenaZaTerapeuta,
      uslugaNaziv: uslugaNaziv,
      uslugaId: uslugaId,
      uslugaTrajanjeMinuta: uslugaTrajanjeMinuta,
      uslugaCijena: uslugaCijena,
      zaposlenikId: zaposlenikId,
      prostorijaNaziv: prostorijaNaziv,
      premiumKlijent: premiumKlijent,
      isVip: isVip,
    );
  }
}

class TherapistAppointmentsList {
  final int upcomingCount;
  final int todayCount;
  final int completedCount;
  final int cancelledCount;
  final TherapistAppointmentRow? nextAppointment;
  final int ukupno;
  final int stranica;
  final int velicinaStranice;
  final List<TherapistAppointmentRow> items;

  const TherapistAppointmentsList({
    required this.upcomingCount,
    required this.todayCount,
    required this.completedCount,
    required this.cancelledCount,
    this.nextAppointment,
    required this.ukupno,
    required this.stranica,
    required this.velicinaStranice,
    this.items = const [],
  });

  factory TherapistAppointmentsList.fromJson(Map<String, dynamic> json) {
    TherapistAppointmentRow? next;
    final rawNext = json['nextAppointment'];
    if (rawNext is Map<String, dynamic>) {
      next = TherapistAppointmentRow.fromJson(rawNext);
    }

    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
            .map(
              (e) => TherapistAppointmentRow.fromJson(
                e as Map<String, dynamic>,
              ),
            )
            .toList()
        : <TherapistAppointmentRow>[];

    return TherapistAppointmentsList(
      upcomingCount: (json['upcomingCount'] as num?)?.toInt() ?? 0,
      todayCount: (json['todayCount'] as num?)?.toInt() ?? 0,
      completedCount: (json['completedCount'] as num?)?.toInt() ?? 0,
      cancelledCount: (json['cancelledCount'] as num?)?.toInt() ?? 0,
      nextAppointment: next,
      ukupno: (json['ukupno'] as num?)?.toInt() ?? items.length,
      stranica: (json['stranica'] as num?)?.toInt() ?? 1,
      velicinaStranice: (json['velicinaStranice'] as num?)?.toInt() ?? 50,
      items: items,
    );
  }
}
