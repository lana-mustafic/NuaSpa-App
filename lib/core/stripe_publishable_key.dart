/// Stripe publishable key ne dolazi s API-ja – postavi pri buildu ili runu:
/// `flutter run --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_...`
const String kStripePublishableKey = String.fromEnvironment(
  'STRIPE_PUBLISHABLE_KEY',
  defaultValue: '',
);
