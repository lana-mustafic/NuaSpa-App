class PaymentIntentResponse {
  final String clientSecret;
  final String publishableKey;

  PaymentIntentResponse({
    required this.clientSecret,
    required this.publishableKey,
  });

  factory PaymentIntentResponse.fromJson(Map<String, dynamic> json) {
    return PaymentIntentResponse(
      clientSecret: json['clientSecret'] as String,
      publishableKey: (json['publishableKey'] as String?) ?? '',
    );
  }
}

