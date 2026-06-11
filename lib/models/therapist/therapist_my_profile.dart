import '../zaposlenik.dart';

class TherapistProfileNextAppointment {
  const TherapistProfileNextAppointment({
    required this.id,
    required this.datumRezervacije,
    this.uslugaNaziv,
    this.korisnikIme,
  });

  final int id;
  final DateTime datumRezervacije;
  final String? uslugaNaziv;
  final String? korisnikIme;

  factory TherapistProfileNextAppointment.fromJson(Map<String, dynamic> json) {
    return TherapistProfileNextAppointment(
      id: (json['id'] as num).toInt(),
      datumRezervacije: DateTime.parse(json['datumRezervacije'] as String),
      uslugaNaziv: json['uslugaNaziv'] as String?,
      korisnikIme: json['korisnikIme'] as String?,
    );
  }
}

class TherapistMyProfile {
  const TherapistMyProfile({
    required this.profile,
    this.loginEmail,
    this.accountLinkedAt,
    required this.eligibleServicesCount,
    required this.averageRating,
    required this.reviewCount,
    required this.allTimeCompletedSessions,
    required this.completedSessionsThisMonth,
    this.nextAppointment,
  });

  final Zaposlenik profile;
  final String? loginEmail;
  final DateTime? accountLinkedAt;
  final int eligibleServicesCount;
  final double averageRating;
  final int reviewCount;
  final int allTimeCompletedSessions;
  final int completedSessionsThisMonth;
  final TherapistProfileNextAppointment? nextAppointment;

  factory TherapistMyProfile.fromJson(Map<String, dynamic> json) {
    final rawProfile = json['profile'];
    TherapistProfileNextAppointment? next;
    final rawNext = json['nextAppointment'];
    if (rawNext is Map<String, dynamic>) {
      next = TherapistProfileNextAppointment.fromJson(rawNext);
    }

    final linkedAt = json['accountLinkedAt'];
    return TherapistMyProfile(
      profile: Zaposlenik.fromJson(rawProfile as Map<String, dynamic>),
      loginEmail: json['loginEmail'] as String?,
      accountLinkedAt: linkedAt == null
          ? null
          : DateTime.tryParse(linkedAt.toString()),
      eligibleServicesCount:
          (json['eligibleServicesCount'] as num?)?.toInt() ?? 0,
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      allTimeCompletedSessions:
          (json['allTimeCompletedSessions'] as num?)?.toInt() ?? 0,
      completedSessionsThisMonth:
          (json['completedSessionsThisMonth'] as num?)?.toInt() ?? 0,
      nextAppointment: next,
    );
  }
}

class TherapistMyProfileResult {
  const TherapistMyProfileResult({
    this.profile,
    this.error,
    this.accountNotLinked = false,
  });

  final TherapistMyProfile? profile;
  final String? error;
  final bool accountNotLinked;
}

class TherapistProfilePatchResult {
  const TherapistProfilePatchResult({this.profile, this.error});

  final Zaposlenik? profile;
  final String? error;
}
