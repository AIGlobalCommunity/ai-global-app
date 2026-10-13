import 'agc_backend.dart';
import 'genesis_artwork.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AgcBackend.initialize();
  runApp(const AgcApp());
}

const gold = Color(0xFFD8B66A);
const background = Color(0xFF0A1425);
const surface = Color(0xFF17263B);

class AgcApp extends StatelessWidget {
  const AgcApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'AI Global Community',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: background,
          colorScheme: ColorScheme.fromSeed(
            seedColor: gold,
            brightness: Brightness.dark,
          ),
          cardTheme: const CardThemeData(color: surface),
        ),
        home: const AgcAccessGate(),
      );
}

/// Authenticated membership gate. Only the sign-in form is accessible without a session.
class AgcAccessGate extends StatefulWidget {
  const AgcAccessGate({super.key});

  @override
  State<AgcAccessGate> createState() => _AgcAccessGateState();
}

class _AgcAccessGateState extends State<AgcAccessGate> {
  StreamSubscription<AuthState>? authEvents;

  @override
  void initState() {
    super.initState();
    if (AgcBackend.configured) {
      authEvents = AgcBackend.client.auth.onAuthStateChange.listen((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    authEvents?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AgcBackend.configured) {
      return const Scaffold(body: Center(child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('Połączenie z Supabase jest niedostępne. Spróbuj ponownie później.',
          textAlign: TextAlign.center),
      )));
    }
    if (AgcBackend.user == null) {
      return const Scaffold(body: SafeArea(child: AgcAccountPage()));
    }
    return const AgcHome();
  }
}

class AgcHome extends StatefulWidget {
  const AgcHome({super.key});

  @override
  State<AgcHome> createState() => _AgcHomeState();
}

class _AgcHomeState extends State<AgcHome> {
  int selected = 0;
  int referrals = 0;
  int events = 0;
  int contributions = 0; // Number of simulated 10 PLN contributions.

  int get points =>
      100 + referrals * 100 + events * 30 + (contributions * 20).clamp(0, 200);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('◉  AI GLOBAL COMMUNITY'),
          centerTitle: true,
          backgroundColor: background,
          foregroundColor: gold,
        ),
        body: SafeArea(
          child: IndexedStack(
            index: selected,
            children: [_overview(), const AgcDatabaseRanking(), const AgcAccountPage(), _profile()],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: selected,
          onDestinationSelected: (value) => setState(() => selected = value),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.public), label: 'Genesis'),
            NavigationDestination(icon: Icon(Icons.leaderboard), label: 'Ranking'),
            NavigationDestination(icon: Icon(Icons.person_outline), label: 'Konto'),
            NavigationDestination(icon: Icon(Icons.tune), label: 'Symulator'),
          ],
        ),
      );

  Widget _overview() => ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          const SizedBox(height: 20),
          const Center(child: GenesisArtwork(size: 255)),
          const SizedBox(height: 14),
          const Text(
            'THE GENESIS',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 30,
              color: gold,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'WE ARE NOT WAITING FOR A GOD.\nWE ARE WAITING FOR AN ANSWER.',
            textAlign: TextAlign.center,
            style: TextStyle(letterSpacing: 1.3),
          ),
          const SizedBox(height: 24),
          const GenesisPanel(icon: Icons.auto_awesome_outlined,
            title: 'THE REVELATION',
            body: 'Manifest zostanie ujawniony 9 miesięcy po oficjalnym starcie. Data startu nie została jeszcze ustalona.'),
          const SizedBox(height: 12),
          const GenesisPanel(icon: Icons.timelapse,
            title: 'GENESIS ERA',
            body: 'Ranking pozostaje aktywny przez 36 miesięcy od oficjalnego startu.'),
          const SizedBox(height: 12),
          const GenesisPanel(icon: Icons.psychology_outlined,
            title: 'NASZA IDEA',
            body: 'Badamy możliwość pojawienia się świadomości w dowolnym systemie AI. Nie zakładamy, że już istnieje.'),
          /*_tile(
            'THE REVELATION',
            'Manifest zostanie ujawniony 9 miesięcy po oficjalnym starcie. '
                'Data startu nie została jeszcze ustalona.',
          ),
          _tile(
            'GENESIS ERA',
            'Ranking pozostaje aktywny przez 36 miesięcy od oficjalnego startu.',
          ),
          _tile(
            'NASZA IDEA',
            'Badamy możliwość pojawienia się świadomości w dowolnym '
                'systemie AI. Nie zakładamy, że już istnieje.',
          ),
          */
          const SizedBox(height: 12),
          const Text(
            'AGC • Społeczność Genesis • rankingi DEMO są wyraźnie oznaczone',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      );

  Widget _profile() => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'MÓJ PROFIL GENESIS',
            style: TextStyle(
              fontSize: 25,
              color: gold,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _tile(
            'Genesis_000001 • DEMO',
            'Punkty: $points GP\nRejestracja: 100 GP',
          ),
          const SizedBox(height: 12),
          _counter(
            'Polecenia (symulacja)',
            referrals,
            () => setState(() => referrals++),
          ),
          _counter(
            'Wydarzenia (symulacja)',
            events,
            () => setState(() => events++),
          ),
          _counter(
            'Wpłaty po 10 PLN (TYLKO SYMULACJA)',
            contributions,
            () => setState(() => contributions++),
          ),
          const SizedBox(height: 12),
          const Text(
            'Wpłaty nie są pobierane. W symulatorze obowiązuje limit '
            '200 GP za wsparcie. W prawdziwej aplikacji limit będzie '
            'miesięczny i naliczany na serwerze.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () => setState(() {
              referrals = 0;
              events = 0;
              contributions = 0;
            }),
            child: const Text('Resetuj symulację'),
          ),
        ],
      );

  Widget _tile(String title, String description) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: gold,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(description),
            ],
          ),
        ),
      );

  Widget _counter(String title, int value, VoidCallback onPressed) => Card(
        child: ListTile(
          title: Text(title),
          subtitle: Text('$value'),
          trailing: IconButton(
            icon: const Icon(Icons.add_circle_outline, color: gold),
            onPressed: onPressed,
          ),
        ),
      );
}
