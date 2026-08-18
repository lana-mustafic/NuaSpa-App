class AccountProfile {
  const AccountProfile({
    required this.userId,
    required this.userName,
    this.email,
    required this.firstName,
    required this.lastName,
    required this.roles,
    required this.isActive,
    required this.hasPassword,
    this.zaposlenikId,
    this.phone,
    this.cityName,
    this.memberSince,
    this.totalVisits,
    this.totalSpent,
    this.lastVisit,
    this.isVip,
  });

  final int userId;
  final String userName;
  final String? email;
  final String firstName;
  final String lastName;
  final List<String> roles;
  final bool isActive;
  final bool hasPassword;
  final int? zaposlenikId;
  final String? phone;
  final String? cityName;
  final DateTime? memberSince;
  final int? totalVisits;
  final double? totalSpent;
  final DateTime? lastVisit;
  final bool? isVip;

  String get fullName {
    final parts = [firstName, lastName]
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isNotEmpty) return parts.join(' ');
    return userName.trim();
  }

  String get initials {
    final name = fullName.trim();
    if (name.isEmpty) return '?';
    final parts = name.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    return name.length >= 2
        ? name.substring(0, 2).toUpperCase()
        : name.toUpperCase();
  }

  bool get isClient => roles.contains('Klijent');
  bool get isTherapist => roles.contains('Zaposlenik');
  bool get isAdmin => roles.contains('Admin');

  String get roleLabel {
    if (isAdmin) return 'Administrator';
    if (isTherapist) return 'Therapist';
    if (isClient) return 'Client';
    return 'Member';
  }

  factory AccountProfile.fromJson(Map<String, dynamic> json) {
    final rolesRaw = json['roles'];
    return AccountProfile(
      userId: (json['userId'] as num?)?.toInt() ?? 0,
      userName: json['userName'] as String? ?? '',
      email: json['email'] as String?,
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      roles: rolesRaw is List
          ? rolesRaw.map((e) => e.toString()).toList()
          : const [],
      isActive: json['isActive'] as bool? ?? true,
      hasPassword: json['hasPassword'] as bool? ?? true,
      zaposlenikId: (json['zaposlenikId'] as num?)?.toInt(),
      phone: json['phone'] as String?,
      cityName: json['cityName'] as String?,
      memberSince: json['memberSince'] == null
          ? null
          : DateTime.tryParse(json['memberSince'].toString()),
      totalVisits: (json['totalVisits'] as num?)?.toInt(),
      totalSpent: (json['totalSpent'] as num?)?.toDouble(),
      lastVisit: json['lastVisit'] == null
          ? null
          : DateTime.tryParse(json['lastVisit'].toString()),
      isVip: json['isVip'] as bool?,
    );
  }
}
