/// Stripe publishable key ne dolazi s API-ja – postavi u .env ili dart-define:
/// `flutter run --dart-define-from-file=.env`
/// `flutter run --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_...`
const String kStripePublishableKey = String.fromEnvironment(
  'STRIPE_PUBLISHABLE_KEY',
  defaultValue: '',
);
