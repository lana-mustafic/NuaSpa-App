import 'package:flutter/material.dart';
import 'screens/zaposlenici/zaposlenik_form.dart'; // Importuj formu

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NuaSpa Desktop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
      ),
      // OVDJE postavljamo tvoju formu kao početni ekran
      home: const ZaposlenikForm(), 
    );
  }
}