import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart'; // Provjeri da li je putanja tačna

void main() {
  runApp(
    MultiProvider(
      providers: [
        // Inicijaliziramo AuthProvider i odmah pokrećemo provjeru tokena
        ChangeNotifierProvider(create: (_) => AuthProvider()..checkAuthState()),
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
      title: 'NuaSpa App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // AuthWrapper odlučuje šta prikazujemo: Login ili Home
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Slušamo promjene u AuthProvideru
    final authProvider = context.watch<AuthProvider>();

    if (authProvider.status == AuthStatus.authenticated) {
      return const HomePage();
    } else {
      return const LoginPage(); 
    }
  }
}

// PRIVREMENI LOGIN EKRAN (Samo da testiraš da li radi)
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Prijava")),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // Ovdje ćeš kasnije pozvati authProvider.login("lana", "Lana123!")
            context.read<AuthProvider>().login("lana", "Lana123!");
          },
          child: const Text("Prijavi se kao Lana"),
        ),
      ),
    );
  }
}

// PRIVREMENI HOME EKRAN
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("NuaSpa Home"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().logout(),
          )
        ],
      ),
      body: const Center(child: Text("Dobrodošli u NuaSpa!")),
    );
  }
}