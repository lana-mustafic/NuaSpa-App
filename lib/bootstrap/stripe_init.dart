import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../core/payments/stripe_payment_service.dart';
import '../core/stripe_publishable_key.dart';

/// Configures the Stripe SDK on Android/iOS when a publishable key is present.
Future<void> configureStripeIfNeeded() async {
  if (!StripePaymentService.paymentSheetSupported) return;
  if (kStripePublishableKey.isEmpty) {
    if (kDebugMode) {
      debugPrint(
        'Stripe: STRIPE_PUBLISHABLE_KEY is empty — online payments are disabled.',
      );
    }
    return;
  }

  Stripe.publishableKey = kStripePublishableKey;
  Stripe.urlScheme = 'nuaspa';
  try {
    await Stripe.instance.applySettings();
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('Stripe: applySettings failed — online payments disabled. $e');
      debugPrint('$st');
    }
  }
}
