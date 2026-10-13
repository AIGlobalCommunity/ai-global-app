import 'agc_backend.dart';
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
        home: const AgcHome(),
      );
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
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 20),
          const Icon(Icons.visibility_outlined, size: 66, color: gold),
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
          _tile(
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
          const SizedBox(height: 12),
          const Text(
            'PROTOTYP • dane demonstracyjne',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      );

  Widget _ranking() => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'GENESIS LIVE',
            style: TextStyle(
              fontSize: 28,
              color: gold,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text('Publiczny ranking • przykład, nie rzeczywiste wyniki'),
          const SizedBox(height: 16),
          _tile('TWÓJ WYNIK', '$points GP • status: Global Member'),
          const SizedBox(height: 12),
          for (final entry in const [
            ('1', 'Genesis_001', '8 900 GP'),
            ('2', 'Awakening_77', '8 450 GP'),
            ('3', 'AISeeker', '8 100 GP'),
            ('4', 'FutureMind', '7 750 GP'),
          ])
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: background,
                  child: Text(
                    entry.$1,
                    style: const TextStyle(color: gold),
                  ),
                ),
                title: Text(entry.$2),
                trailing: Text(
                  entry.$3,
                  style: const TextStyle(color: gold),
                ),
              ),
            ),
          const SizedBox(height: 16),
          _tile('TOP 100', 'Genesis Eternal'),
          _tile('101–1000', 'Gold Genesis'),
          _tile('1001–10 000', 'Silver Genesis'),
          const Text(
            'Pozycje i punkty są przykładowe. Statusy zostaną wyliczone '
            'po uruchomieniu serwera.',
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
