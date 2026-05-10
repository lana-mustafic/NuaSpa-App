import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/service_provider.dart'; // DODANO
import 'screens/login_screen.dart';
import 'screens/catalog/service_details_screen.dart';
import 'core/api/services/api_service.dart';
import 'models/usluga.dart';
import 'models/rezervacija.dart';
import 'models/desktop_home_overview.dart';
import 'ui/layout/desktop_shell.dart';
import 'ui/theme/app_theme.dart';
import 'ui/theme/mobile_spa_theme.dart';
import 'ui/layout/mobile_shell.dart';
import 'providers/mobile_nav_provider.dart';
import 'ui/widgets/hover_card.dart';
import 'ui/widgets/overview_stat_card.dart';
import 'ui/widgets/hourly_occupancy_bars.dart';
import 'ui/behavior/app_scroll_behavior.dart';
import 'ui/navigation/desktop_nav.dart';
import 'bootstrap/desktop_window.dart';
import 'core/config/app_config.dart';
import 'core/platform/nua_spa_platform.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDesktopWindowIfNeeded();
  if (kDebugMode) {
    debugPrint('NuaSpa API base URL: ${AppConfig.apiBaseUrl}');
  }
  runApp(
    // MultiProvider omogućava da dodaješ više providera kasnije (npr. za Auth, Usluge itd.)
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..checkAuthState()),
        ChangeNotifierProvider(
          create: (_) => ServiceProvider(),
        ), // DODANO: Registracija kataloga
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final mobile = nuaspaUseMobileShell();
    if (kDebugMode) {
      debugPrint(
        'NuaSpa: Flutter client=${mobile ? "mobile (Android/iOS spa theme)" : "desktop/web (dark theme)"}',
      );
    }
    return MaterialApp(
      title: mobile ? 'NuaSpa' : 'NuaSpa Desktop',
      debugShowCheckedModeBanner: false,
      theme: mobile ? MobileSpaTheme.light() : AppTheme.dark(),
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
      if (nuaspaUseMobileShell()) {
        if (kDebugMode) {
          debugPrint('NuaSpa: showing MobileShell (premium bottom nav)');
        }
        return ChangeNotifierProvider(
          create: (_) => MobileNavProvider(),
          child: const MobileShell(),
        );
      }
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
  Future<({List<Rezervacija> bookings, DesktopHomeOverview? overview})>?
      _homeDayFuture;

  @override
  void initState() {
    super.initState();
    _loadPreporuke();
    final n = DateTime.now();
    final day = DateTime(n.year, n.month, n.day);
    _homeDayFuture = () async {
      final bookings = await _api.getRezervacijeFiltered(
        datum: day,
        includeOtkazane: false,
      );
      final overview = await _api.getDesktopHomeOverview(day: day);
      return (bookings: bookings, overview: overview);
    }();
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

  Widget _buildOverviewSection(BuildContext context) {
    return FutureBuilder<
        ({
          List<Rezervacija> bookings,
          DesktopHomeOverview? overview,
        })>(
      future: _homeDayFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pregled dana',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            ),
          );
        }
        final data = snap.data;
        final list = data?.bookings ?? const <Rezervacija>[];
        final overview = data?.overview;
        final active = list.where((r) => !r.isOtkazana).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.dashboard_customize_rounded,
                  size: 22,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 10),
                Text(
                  'Pregled dana — Overview',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, c) {
                final cols = c.maxWidth >= 1000
                    ? 3
                    : (c.maxWidth >= 620 ? 2 : 1);
                final gap = 16.0;
                final tileW = (c.maxWidth - gap * (cols - 1)) / cols;

                final novi = overview?.noviKlijentiZadnjih7Dana;
                final prihod = overview?.procijenjeniPrihodZaDan;
                final valuta = overview?.valuta ?? 'KM';
                final prihodTxt = prihod == null
                    ? '— $valuta'
                    : '${prihod.toStringAsFixed(2)} $valuta';

                final cards = <Widget>[
                  OverviewStatCard(
                    icon: Icons.event_available_rounded,
                    label: 'Današnje aktivne rezervacije',
                    value: '${active.length}',
                    subtitle: active.isEmpty
                        ? 'Za danas još nema aktivnih termina.'
                        : 'Ukupno u vašoj roli vidljivih termina.',
                    accent: Theme.of(context).colorScheme.primary,
                  ),
                  OverviewStatCard(
                    icon: Icons.person_add_alt_1_outlined,
                    label: 'Novi klijenti',
                    value: novi == null ? '—' : '$novi',
                    subtitle: novi == null
                        ? 'Broj novih registracija (7 dana) vidi samo administrator.'
                        : 'Nove registracije u zadnjih 7 dana (cijeli spa).',
                    accent: Theme.of(context).colorScheme.tertiary,
                  ),
                  OverviewStatCard(
                    icon: Icons.payments_outlined,
                    label: 'Očekivani prihod (procjena)',
                    value: overview == null ? '— $valuta' : prihodTxt,
                    subtitle:
                        'Suma cijena neotkanih termina za danas u okviru vaše uloge.',
                    accent: Theme.of(context).colorScheme.secondary,
                  ),
                ];

                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: cards
                      .map((w) => SizedBox(width: tileW, child: w))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 28),
            Material(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: HourlyOccupancyBars(rezervacije: active),
              ),
            ),
          ],
        );
      },
    );
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
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
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
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.08),
                                  child: Icon(
                                    Icons.spa_outlined,
                                    color: Theme.of(context).colorScheme.primary
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
    final nav = context.read<DesktopNav>();
    return Scrollbar(
      controller: _scrollController,
      child: SingleChildScrollView(
        controller: _scrollController,
        primary: false,
        padding: const EdgeInsets.fromLTRB(32, 28, 32, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dobrodošli', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Upravljajte katalogom, rezervacijama i rasporedom terapeuta.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.70)),
            ),
            const SizedBox(height: 28),
            _buildOverviewSection(context),
            const SizedBox(height: 36),
            _buildPreporukeStrip(context),
            const SizedBox(height: 28),
            LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;
                final cols = w >= 1100 ? 3 : (w >= 760 ? 2 : 1);
                final gap = 12.0;
                final tileW = (w - gap * (cols - 1)) / cols;

                final actions = <Widget>[
                  HoverCard(
                    tooltip: 'Otvori katalog usluga',
                    onTap: () => nav.goTo(DesktopRouteKey.catalog),
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
                      onTap: () => nav.goTo(DesktopRouteKey.reservations),
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
                      onTap: () => nav.goTo(DesktopRouteKey.favorites),
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
                      onTap: () => nav.goTo(DesktopRouteKey.schedule),
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
                      onTap: () => nav.goTo(DesktopRouteKey.admin),
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
          ],
        ),
      ),
    );
  }
}
