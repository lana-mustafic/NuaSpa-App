import '../admin/therapist_admin_profile.dart';

class TherapistMyReviewsSummary {
  const TherapistMyReviewsSummary({
    this.totalCount = 0,
    this.averageRating = 0,
    this.mostReviewedServiceName,
    this.latestReview,
  });

  final int totalCount;
  final double averageRating;
  final String? mostReviewedServiceName;
  final TherapistReviewRow? latestReview;

  factory TherapistMyReviewsSummary.fromJson(Map<String, dynamic> json) {
    final rawLatest = json['latestReview'];
    return TherapistMyReviewsSummary(
      totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0,
      mostReviewedServiceName: json['mostReviewedServiceName'] as String?,
      latestReview: rawLatest is Map<String, dynamic>
          ? TherapistReviewRow.fromJson(rawLatest)
          : null,
    );
  }
}

class TherapistReviewsPageResult {
  const TherapistReviewsPageResult({
    this.items = const [],
    this.total = 0,
    this.page = 1,
    this.pageSize = 20,
    this.error,
    this.accountNotLinked = false,
  });

  final List<TherapistReviewRow> items;
  final int total;
  final int page;
  final int pageSize;
  final String? error;
  final bool accountNotLinked;

  bool get hasMore => items.isNotEmpty && (page * pageSize) < total;
}

class TherapistMyReviewsSummaryResult {
  const TherapistMyReviewsSummaryResult({
    this.summary,
    this.error,
    this.accountNotLinked = false,
  });

  final TherapistMyReviewsSummary? summary;
  final String? error;
  final bool accountNotLinked;
}
