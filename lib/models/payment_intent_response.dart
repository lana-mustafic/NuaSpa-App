class PaymentIntentResponse {
  final String clientSecret;
  final String paymentIntentId;

  PaymentIntentResponse({
    required this.clientSecret,
    required this.paymentIntentId,
  });

  factory PaymentIntentResponse.fromJson(Map<String, dynamic> json) {
    return PaymentIntentResponse(
      clientSecret: json['clientSecret'] as String,
      paymentIntentId: (json['paymentIntentId'] as String?) ?? '',
    );
  }
}

class ConfirmPaymentResponse {
  final bool isPlacena;
  final bool isPaid;
  final bool alreadyCompleted;
  final double chargedAmount;

  ConfirmPaymentResponse({
    required this.isPlacena,
    required this.isPaid,
    required this.alreadyCompleted,
    required this.chargedAmount,
  });

  factory ConfirmPaymentResponse.fromJson(Map<String, dynamic> json) {
    final paid = (json['isPaid'] as bool?) ??
        (json['isPlacena'] as bool?) ??
        false;
    return ConfirmPaymentResponse(
      isPlacena: (json['isPlacena'] as bool?) ?? paid,
      isPaid: paid,
      alreadyCompleted: json['alreadyCompleted'] as bool? ?? false,
      chargedAmount: (json['chargedAmount'] as num?)?.toDouble() ?? 0,
    );
  }
}
