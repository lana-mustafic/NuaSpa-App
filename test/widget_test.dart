import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:nuaspa_app/main.dart';
import 'package:nuaspa_app/providers/auth_provider.dart';
import 'package:nuaspa_app/providers/service_provider.dart';

void main() {
  testWidgets('App builds with providers (smoke)', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => ServiceProvider()),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pump();
    // Root MaterialApp from MyApp
    expect(find.byType(MyApp), findsOneWidget);
  });
}
