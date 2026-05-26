import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:nuaspa_app/providers/auth_provider.dart';
import 'package:nuaspa_app/providers/notification_provider.dart';
import 'package:nuaspa_app/providers/service_provider.dart';

void main() {
  testWidgets('Provider tree builds (smoke)', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => NotificationProvider()),
          ChangeNotifierProvider(create: (_) => ServiceProvider()),
        ],
        child: const MaterialApp(home: SizedBox.shrink()),
      ),
    );
    await tester.pump();
    expect(find.byType(SizedBox), findsOneWidget);
  });
}
