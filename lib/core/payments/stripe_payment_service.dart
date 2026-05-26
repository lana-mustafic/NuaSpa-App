import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter/foundation.dart';
import '../api/services/api_service.dart';
import '../stripe_publishable_key.dart';

class StripePaymentService {
  final ApiService _api = ApiService();

  /// Payment Sheet podržan je tipično na mobilnim platformama; desktop izbjegava crash.
  static bool get paymentSheetSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  /// Vraća true tek nakon server-side potvrde (confirm API), ne nakon PaymentSheet-a.
  Future<bool> payForReservation(int rezervacijaId) async {
    if (!paymentSheetSupported) {
      debugPrint(
        'Stripe: plaćanje putem Payment Sheet-a nije podržano na ovoj platformi (koristi Android/iOS).',
      );
      return false;
    }

    try {
      final intent = await _api.createPaymentIntent(rezervacijaId);
      if (intent == null || intent.clientSecret.isEmpty) return false;

      if (kStripePublishableKey.isEmpty) {
        debugPrint(
          'Stripe: postavi STRIPE_PUBLISHABLE_KEY (dart-define). Publishable key se ne šalje s API-ja.',
        );
        return false;
      }
      Stripe.publishableKey = kStripePublishableKey;

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: intent.clientSecret,
          merchantDisplayName: 'NuaSpa',
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      final paymentIntentId = intent.paymentIntentId;
      if (paymentIntentId.isEmpty) {
        debugPrint('Stripe: nedostaje paymentIntentId za server-side confirm.');
        return false;
      }

      final confirmed = await _api.confirmPayment(paymentIntentId);
      return confirmed?.isPaid ?? false;
    } on StripeException catch (e) {
      debugPrint('StripeException: $e');
      return false;
    } catch (e) {
      debugPrint('Payment error: $e');
      return false;
    }
  }
}
