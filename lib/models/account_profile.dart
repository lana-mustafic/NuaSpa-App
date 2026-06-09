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

  String get fullName {
    final parts = [firstName, lastName]
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return parts.join(' ');
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
    );
  }
}
