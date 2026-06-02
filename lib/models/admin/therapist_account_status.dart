class TherapistAccountStatus {
  const TherapistAccountStatus({
    required this.zaposlenikId,
    required this.hasLinkedAccount,
    required this.accountActive,
    required this.hasPassword,
    required this.invitePending,
    required this.canInvite,
    this.linkedEmail,
    this.linkedUserName,
    this.inviteExpiresAt,
    this.message,
  });

  final int zaposlenikId;
  final bool hasLinkedAccount;
  final String? linkedEmail;
  final String? linkedUserName;
  final bool accountActive;
  final bool hasPassword;
  final bool invitePending;
  final DateTime? inviteExpiresAt;
  final bool canInvite;
  final String? message;

  factory TherapistAccountStatus.fromJson(Map<String, dynamic> json) {
    return TherapistAccountStatus(
      zaposlenikId: (json['zaposlenikId'] as num?)?.toInt() ?? 0,
      hasLinkedAccount: json['hasLinkedAccount'] as bool? ?? false,
      linkedEmail: json['linkedEmail'] as String?,
      linkedUserName: json['linkedUserName'] as String?,
      accountActive: json['accountActive'] as bool? ?? false,
      hasPassword: json['hasPassword'] as bool? ?? false,
      invitePending: json['invitePending'] as bool? ?? false,
      inviteExpiresAt: json['inviteExpiresAt'] == null
          ? null
          : DateTime.tryParse(json['inviteExpiresAt'].toString()),
      canInvite: json['canInvite'] as bool? ?? false,
      message: json['message'] as String?,
    );
  }
}

class TherapistInviteResult {
  const TherapistInviteResult({
    required this.success,
    required this.message,
    this.inviteUrl,
    this.expiresAt,
    this.emailQueued = true,
  });

  final bool success;
  final String message;
  final String? inviteUrl;
  final DateTime? expiresAt;
  final bool emailQueued;

  factory TherapistInviteResult.fromJson(Map<String, dynamic> json) {
    return TherapistInviteResult(
      success: json['success'] as bool? ?? false,
      message: (json['message'] as String?) ?? '',
      inviteUrl: json['inviteUrl'] as String?,
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.tryParse(json['expiresAt'].toString()),
      emailQueued: json['emailQueued'] as bool? ?? true,
    );
  }
}

class InviteValidationResult {
  const InviteValidationResult({
    required this.valid,
    this.therapistName,
    this.email,
    this.expiresAt,
    this.message,
  });

  final bool valid;
  final String? therapistName;
  final String? email;
  final DateTime? expiresAt;
  final String? message;

  factory InviteValidationResult.fromJson(Map<String, dynamic> json) {
    return InviteValidationResult(
      valid: json['valid'] as bool? ?? false,
      therapistName: json['therapistName'] as String?,
      email: json['email'] as String?,
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.tryParse(json['expiresAt'].toString()),
      message: json['message'] as String?,
    );
  }
}
