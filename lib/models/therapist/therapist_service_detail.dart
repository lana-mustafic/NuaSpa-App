import '../usluga.dart';
import '../zaposlenik_status.dart';

class TherapistServiceDetail {
  const TherapistServiceDetail({
    required this.service,
    required this.isCertified,
    required this.isAuthorized,
    required this.employmentStatus,
    required this.completedBookingsCount,
    required this.myReviewCount,
    this.myAverageRating,
    this.scheduleWorkingHoursLabel,
    this.availableSlotCountToday = 0,
    this.isTherapistUnavailableToday = false,
    this.isSpaClosedToday = false,
  });

  final Usluga service;
  final bool isCertified;
  final bool isAuthorized;
  final ZaposlenikStatus employmentStatus;
  final int completedBookingsCount;
  final int myReviewCount;
  final double? myAverageRating;
  final String? scheduleWorkingHoursLabel;
  final int availableSlotCountToday;
  final bool isTherapistUnavailableToday;
  final bool isSpaClosedToday;

  bool get isEmployedActive => employmentStatus.isBookable;

  factory TherapistServiceDetail.fromJson(Map<String, dynamic> json) {
    final rawService = json['service'];
    return TherapistServiceDetail(
      service: rawService is Map<String, dynamic>
          ? Usluga.fromJson(rawService)
          : Usluga(
              id: 0,
              naziv: '',
              cijena: 0,
              trajanje: '',
              slikaUrl: '',
              kategorija: 'Unknown',
            ),
      isCertified: json['isCertified'] as bool? ?? false,
      isAuthorized: json['isAuthorized'] as bool? ?? false,
      employmentStatus: ZaposlenikStatus.fromApi(json['employmentStatus']),
      completedBookingsCount:
          (json['completedBookingsCount'] as num?)?.toInt() ?? 0,
      myReviewCount: (json['myReviewCount'] as num?)?.toInt() ?? 0,
      myAverageRating: (json['myAverageRating'] as num?)?.toDouble(),
      scheduleWorkingHoursLabel:
          json['scheduleWorkingHoursLabel'] as String?,
      availableSlotCountToday:
          (json['availableSlotCountToday'] as num?)?.toInt() ?? 0,
      isTherapistUnavailableToday:
          json['isTherapistUnavailableToday'] as bool? ?? false,
      isSpaClosedToday: json['isSpaClosedToday'] as bool? ?? false,
    );
  }
}

class TherapistServiceDetailResult {
  const TherapistServiceDetailResult({
    this.detail,
    this.error,
    this.notFound = false,
    this.forbidden = false,
    this.accountNotLinked = false,
  });

  final TherapistServiceDetail? detail;
  final String? error;
  final bool notFound;
  final bool forbidden;
  final bool accountNotLinked;
}
