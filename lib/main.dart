import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Moramo uvesti provider
import 'screens/zaposlenici/zaposlenik_form.dart'; 
import 'providers/uloga_provider.dart'; // Importuj provider koji si napravila

void main() {
  runApp(
    // MultiProvider omogućava da dodaješ više providera kasnije (npr. za Auth, Usluge itd.)
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UlogaProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NuaSpa Desktop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
        // Dodajemo malo globalnog stila za gumbe
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
          ),
        ),
      ),
      // Tvoja forma je i dalje početni ekran
      home: const ZaposlenikForm(), 
    );
  }
}