class PaymentResult {
  const PaymentResult({required this.success, required this.message});

  final bool success;
  final String message;

  bool get cancelled =>
      !success && message == 'Payment cancelled.';

  factory PaymentResult.success() => const PaymentResult(
        success: true,
        message: 'Payment completed.',
      );

  factory PaymentResult.cancelled() => const PaymentResult(
        success: false,
        message: 'Payment cancelled.',
      );

  factory PaymentResult.failure(String message) => PaymentResult(
        success: false,
        message: message,
      );
}
