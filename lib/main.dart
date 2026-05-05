import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/service_provider.dart'; // DODANO
import 'screens/login_screen.dart';
import 'screens/catalog/service_catalog_screen.dart'; // DODANO
import 'screens/catalog/service_details_screen.dart';
import 'screens/reservations/reservation_list_screen.dart';
import 'screens/favorites/favorites_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/therapist/therapist_schedule_screen.dart';
import 'core/api/services/api_service.dart';
import 'models/usluga.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..checkAuthState()),
        ChangeNotifierProvider(create: (_) => ServiceProvider()), // DODANO: Registracija kataloga
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
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authStatus = context.watch<AuthProvider>().status;

    if (authStatus == AuthStatus.authenticated) {
      return const HomePage();
    } else {
      return const LoginScreen();
    }
  }
}

// --- HOME PAGE (preporuke + brzi linkovi) ---
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ApiService _api = ApiService();
  List<Usluga>? _preporuke;
  bool _preporukeLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreporuke();
  }

  Future<void> _loadPreporuke() async {
    final list = await _api.getPreporuke(take: 12);
    if (!mounted) return;
    setState(() {
      _preporuke = list;
      _preporukeLoading = false;
    });
  }

  Widget _buildPreporukeStrip(BuildContext context) {
    if (_preporukeLoading) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final list = _preporuke ?? [];
    if (list.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome, size: 20, color: Colors.deepPurple.shade700),
            const SizedBox(width: 8),
            Text(
              'Preporučeno za vas',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 172,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            separatorBuilder: (context, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final u = list[index];
              return SizedBox(
                width: 144,
                child: Material(
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  color: Colors.grey.shade100,
                  elevation: 1,
                  shadowColor: Colors.black26,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (context) =>
                              ServiceDetailsScreen(serviceId: u.id),
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Image.network(
                            u.slikaUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: Colors.deepPurple.shade50,
                              child: Icon(Icons.spa_outlined,
                                  color: Colors.deepPurple.shade200),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                u.naziv,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${u.cijena.toStringAsFixed(2)} KM',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("NuaSpa Dashboard"),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            tooltip: "Odjavi se",
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<AuthProvider>().logout();
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.spa_outlined, size: 72, color: Colors.deepPurple),
            const SizedBox(height: 16),
            Text(
              "Dobrodošli u NuaSpa!",
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildPreporukeStrip(context),
            const SizedBox(height: 28),

            if (context.watch<AuthProvider>().isAdmin) ...[
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  foregroundColor: Colors.deepPurple,
                  side: const BorderSide(color: Colors.deepPurple),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (context) => const AdminDashboardScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.admin_panel_settings_outlined),
                label: const Text('Admin panel'),
              ),
              const SizedBox(height: 16),
            ],

            if (context.watch<AuthProvider>().isZaposlenik) ...[
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  foregroundColor: Colors.teal.shade800,
                  side: BorderSide(color: Colors.teal.shade700),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (context) => const TherapistScheduleScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.calendar_month_outlined),
                label: const Text('Terapeut · raspored'),
              ),
              const SizedBox(height: 16),
            ],

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => const ServiceCatalogScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.grid_view_rounded),
              label: const Text("Otvori Katalog Usluga"),
            ),

            const SizedBox(height: 16),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => const ReservationListScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.event_note_rounded),
              label: const Text("Moje rezervacije"),
            ),

            const SizedBox(height: 16),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => const FavoritesScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.favorite),
              label: const Text("Favoriti"),
            ),

            const SizedBox(height: 24),
            Text(
              "JWT token je validan. Možete pristupiti uslugama.",
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}