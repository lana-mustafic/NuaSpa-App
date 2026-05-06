class PaymentIntentResponse {
  final String clientSecret;

  PaymentIntentResponse({
    required this.clientSecret,
  });

  factory PaymentIntentResponse.fromJson(Map<String, dynamic> json) {
    return PaymentIntentResponse(
      clientSecret: json['clientSecret'] as String,
    );
  }
}

