import 'package:dio/dio.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter/foundation.dart';

import '../api/api_error_messages.dart';
import '../api/services/api_service.dart';
import '../stripe_publishable_key.dart';
import 'payment_result.dart';

class StripePaymentService {
  final ApiService _api = ApiService();

  /// Payment Sheet podržan je tipično na mobilnim platformama; desktop izbjegava crash.
  static bool get paymentSheetSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  static PaymentResult? preflight() {
    if (!paymentSheetSupported) {
      return PaymentResult.failure(
        'Online payment is available on Android and iOS only.',
      );
    }
    if (kStripePublishableKey.isEmpty) {
      return PaymentResult.failure(
        'Stripe is not configured in the app. Add STRIPE_PUBLISHABLE_KEY to .env and restart.',
      );
    }
    return null;
  }

  /// Vraća uspjeh tek nakon server-side potvrde (confirm API), ne nakon PaymentSheet-a.
  Future<PaymentResult> payForReservation(int rezervacijaId) async {
    final blocked = preflight();
    if (blocked != null) return blocked;

    try {
      final intent = await _api.createPaymentIntent(rezervacijaId);
      if (intent == null || intent.clientSecret.isEmpty) {
        return PaymentResult.failure('Could not start payment. Please try again.');
      }

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: intent.clientSecret,
          merchantDisplayName: 'NuaSpa',
          returnURL: 'nuaspa://redirect',
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      final paymentIntentId = intent.paymentIntentId;
      if (paymentIntentId.isEmpty) {
        return PaymentResult.failure(
          'Payment started but confirmation data is missing.',
        );
      }

      final confirmed = await _api.confirmPayment(paymentIntentId);
      if (confirmed?.isPaid ?? false) {
        return PaymentResult.success();
      }
      return PaymentResult.failure('Payment was not confirmed by the server.');
    } on DioException catch (e) {
      return PaymentResult.failure(
        ApiErrorMessages.fromObject(
          e,
          fallback: 'Could not start payment.',
        ),
      );
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        return PaymentResult.cancelled();
      }
      final message = e.error.localizedMessage ?? e.error.message;
      return PaymentResult.failure(
        message?.trim().isNotEmpty == true
            ? message!.trim()
            : 'Stripe payment failed.',
      );
    } catch (e) {
      debugPrint('Payment error: $e');
      return PaymentResult.failure('Payment failed: $e');
    }
  }
}
