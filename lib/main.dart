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
import 'ui/layout/desktop_shell.dart';
import 'ui/theme/app_theme.dart';
import 'ui/widgets/hover_card.dart';
import 'ui/widgets/primary_button.dart';
import 'ui/behavior/app_scroll_behavior.dart';
import 'ui/navigation/desktop_nav.dart';

void main() {
  runApp(
    // MultiProvider omogućava da dodaješ više providera kasnije (npr. za Auth, Usluge itd.)
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
      title: 'NuaSpa Desktop',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      scrollBehavior: const AppScrollBehavior(),
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
      return ChangeNotifierProvider(
        create: (_) => DesktopNav(),
        child: const DesktopShell(home: HomePage()),
      );
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
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadPreporuke();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
            Icon(
              Icons.auto_awesome_outlined,
              size: 20,
              color: Theme.of(context).colorScheme.secondary,
            ),
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
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            separatorBuilder: (context, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final u = list[index];
              return SizedBox(
                width: 180,
                child: HoverCard(
                  padding: EdgeInsets.zero,
                  tooltip: 'Otvori detalje: ${u.naziv}',
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
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                          child: Image.network(
                            u.slikaUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.08),
                              child: Icon(
                                Icons.spa_outlined,
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.55),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              u.naziv,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${u.cijena.toStringAsFixed(2)} KM',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.72),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
    final nav = context.read<DesktopNav?>();
    return Scrollbar(
      controller: _scrollController,
      child: SingleChildScrollView(
        controller: _scrollController,
        primary: false,
        padding: const EdgeInsets.fromLTRB(26, 22, 26, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dobrodošli', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Upravljajte katalogom, rezervacijama i rasporedom terapeuta.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.70)),
            ),
            const SizedBox(height: 18),
            _buildPreporukeStrip(context),
            const SizedBox(height: 22),
            LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;
                final cols = w >= 1100 ? 3 : (w >= 760 ? 2 : 1);
                final gap = 12.0;
                final tileW = (w - gap * (cols - 1)) / cols;

                final actions = <Widget>[
                  HoverCard(
                    tooltip: 'Otvori katalog usluga',
                    onTap: () {
                      if (nav != null) {
                        nav.goTo(DesktopRouteKey.catalog);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const ServiceCatalogScreen(),
                          ),
                        );
                      }
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.grid_view_rounded),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Katalog usluga',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!context.watch<AuthProvider>().isZaposlenik)
                    HoverCard(
                      onTap: () {
                        if (nav != null) {
                          nav.goTo(DesktopRouteKey.reservations);
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const ReservationListScreen(),
                            ),
                          );
                        }
                      },
                      child: Row(
                        children: [
                          const Icon(Icons.event_note_rounded),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Moje rezervacije',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (!context.watch<AuthProvider>().isZaposlenik)
                    HoverCard(
                      tooltip: 'Lista favorita',
                      onTap: () {
                        if (nav != null) {
                          nav.goTo(DesktopRouteKey.favorites);
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const FavoritesScreen(),
                            ),
                          );
                        }
                      },
                      child: Row(
                        children: [
                          const Icon(Icons.favorite_border),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Favoriti',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (context.watch<AuthProvider>().isZaposlenik)
                    HoverCard(
                      tooltip: 'Raspored terapeuta',
                      onTap: () {
                        if (nav != null) {
                          nav.goTo(DesktopRouteKey.schedule);
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const TherapistScheduleScreen(),
                            ),
                          );
                        }
                      },
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month_outlined),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Raspored terapeuta',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (context.watch<AuthProvider>().isAdmin)
                    HoverCard(
                      tooltip: 'Administracija',
                      onTap: () {
                        if (nav != null) {
                          nav.goTo(DesktopRouteKey.admin);
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const AdminDashboardScreen(),
                            ),
                          );
                        }
                      },
                      child: Row(
                        children: [
                          const Icon(Icons.admin_panel_settings_outlined),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Admin panel',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                ];

                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: actions
                      .map((w) => SizedBox(width: tileW, child: w))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 18),
            PrimaryButton(
              label: 'Odjavi se',
              icon: Icons.logout,
              tooltip: 'Odjava s računa',
              onPressed: () => context.read<AuthProvider>().logout(),
            ),
          ],
        ),
      ),
    );
  }
}