import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter/foundation.dart';
import '../api/services/api_service.dart';

class StripePaymentService {
  final ApiService _api = ApiService();

  Future<bool> payForReservation(int rezervacijaId) async {
    try {
      final intent = await _api.createPaymentIntent(rezervacijaId);
      if (intent == null) return false;

      // Init Stripe (runtime)
      if (intent.publishableKey.isEmpty) {
        debugPrint('Stripe publishable key nije postavljen.');
        return false;
      }
      Stripe.publishableKey = intent.publishableKey;

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: intent.clientSecret,
          merchantDisplayName: 'NuaSpa',
        ),
      );

      await Stripe.instance.presentPaymentSheet();
      return true;
    } on StripeException catch (e) {
      debugPrint('StripeException: $e');
      return false;
    } catch (e) {
      debugPrint('Payment error: $e');
      return false;
    }
  }
}

