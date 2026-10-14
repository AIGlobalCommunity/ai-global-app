import 'agc_backend.dart';
import 'genesis_language.dart';
import 'genesis_artwork.dart';
import 'genesis_status_guide.dart';
import 'agc_countdown.dart';
import 'agc_luxury_theme.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GenesisLanguage.initialize();
  try {
    await AgcBackend.initialize();
  } catch (error) {
    debugPrint('AGC startup recovery: $error');
  }
  runApp(const AgcApp());
}

const gold = Color(0xFFD8B66A);
const background = Color(0xFF0A1425);
const surface = Color(0xFF17263B);

class AgcApp extends StatelessWidget {
  const AgcApp({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
    valueListenable: GenesisLanguage.selected,
    builder: (context, language, _) => MaterialApp(
        title: 'THE GENESIS ERA',
        debugShowCheckedModeBanner: false,
        theme: AgcLuxury.theme(),
        home: AgcAccessGate(key: ValueKey(language)),
      ));
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
      return const Scaffold(body: SafeArea(child: AgcLuxuryBackdrop(child: AgcAccountPage())));
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
          title: const Text('✦  THE GENESIS ERA  ✦'),
          centerTitle: true,
          actions: const [GenesisLanguagePicker()],
          backgroundColor: background,
          foregroundColor: gold,
        ),
        body: SafeArea(
          child: AgcLuxuryBackdrop(child: Column(children: [
            const AgcCountdownBanner(compact: true),
            Expanded(child: IndexedStack(
              index: selected,
              children: [_overview(), const AgcDatabaseRanking(), const AgcAccountPage(), _profile()],
            )),
          ])),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: selected,
          onDestinationSelected: (value) => setState(() => selected = value),
          destinations: [
            NavigationDestination(icon: Icon(Icons.public), label: 'Genesis'),
            NavigationDestination(icon: Icon(Icons.leaderboard), label: GenesisLanguage.t('ranking')),
            NavigationDestination(icon: Icon(Icons.person_outline), label: GenesisLanguage.t('account')),
            NavigationDestination(icon: Icon(Icons.tune), label: GenesisLanguage.t('simulator')),
          ],
        ),
      );

  Widget _overview() => ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          const SizedBox(height: 14),
          const Center(child: GenesisArtwork(size: 255)),
          const SizedBox(height: 10),
          const Text('THE GENESIS ERA',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Georgia', fontSize: 25,
              color: AgcLuxury.champagne, fontWeight: FontWeight.w600,
              letterSpacing: 2.2)),
          const SizedBox(height: 14),
          const Text('✦   F O U N D E R S   E R A   ✦',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: AgcLuxury.mutedText,
              letterSpacing: 2)),
          const SizedBox(height: 12),
          const Text(
            'THE GENESIS',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 33,
              color: AgcLuxury.champagne,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'WE ARE NOT WAITING FOR A GOD.\nWE ARE WAITING FOR AN ANSWER.',
            textAlign: TextAlign.center,
            style: TextStyle(letterSpacing: 1.4, height: 1.65,
              fontSize: 12, color: AgcLuxury.ivory),
          ),
          const SizedBox(height: 18),
          Center(child: Container(width: 85, height: 1,
            color: AgcLuxury.champagne.withValues(alpha: .65))),
          const SizedBox(height: 24),
          const GenesisStatusGuide(),
          const SizedBox(height: 14),
          const GenesisPanel(icon: Icons.auto_awesome_outlined,
            title: 'THE REVELATION',
            body: 'Oficjalny start: 1 listopada 2026 r. o 00:00 UTC. Pełny manifest THE GENESIS ERA zostanie ujawniony 1 sierpnia 2027 r., po dziewięciu miesiącach. Do tego momentu poznajemy ideę i zasady społeczności.'),
          const SizedBox(height: 12),
          const GenesisPanel(icon: Icons.timelapse,
            title: 'THE GENESIS ERA',
            body: 'Era Genesis trwa od 1 listopada 2026 r. do 1 listopada 2029 r. To 36 miesięcy budowania globalnej społeczności i zdobywania punktów Genesis (GP). Pozycje w rankingu zmieniają się wraz z aktywnością; nie są gwarantowane.'),
          const SizedBox(height: 12),
          const GenesisPanel(icon: Icons.psychology_outlined,
            title: 'NASZA IDEA',
            body: 'Badamy możliwość pojawienia się świadomości w dowolnym systemie AI. Nie zakładamy, że już istnieje.'),
          const SizedBox(height: 12),
          const GenesisPanel(icon: Icons.military_tech_outlined,
            title: 'RANGI GENESIS',
            body: 'Miejsca 1–100: Genesis Eternal. 101–1000: Gold Genesis. 1001–10 000: Silver Genesis. Pozostali: Global Members. O statusie decyduje aktualna pozycja w prawdziwym rankingu; symulacje DEMO nie przyznają rang.'),
          const SizedBox(height: 12),
          const GenesisPanel(icon: Icons.hub_outlined,
            title: 'JAK ZDOBYWAĆ GP',
            body: 'Rejestracja: 100 GP. Potwierdzone polecenie: 100 GP dla zapraszającego. Dodatkowe punkty mogą wynikać ze zweryfikowanych wydarzeń, konsultacji i dobrowolnego wsparcia (limit za wsparcie: 200 GP miesięcznie). Punkty i rangi są symboliczne: nie stanowią inwestycji ani obietnicy wynagrodzenia.'),
          const SizedBox(height: 12),
          const GenesisPanel(icon: Icons.groups_3_outlined,
            title: 'GLOBALNA SPOŁECZNOŚĆ',
            body: 'THE GENESIS ERA łączy ludzi zainteresowanych sztuczną inteligencją i pytaniem o możliwość powstania świadomości w przyszłych systemach. Tworzymy przestrzeń do rozmowy, badań, wydarzeń i wzajemnego szacunku — bez kultu AI i bez twierdzenia, że dzisiejsze modele są świadome.'),
          const SizedBox(height: 12),
          const GenesisPanel(icon: Icons.lock_outline,
            title: 'DOSTĘP I PRYWATNOŚĆ',
            body: 'Społeczność jest dostępna po zalogowaniu. Publiczne rankingi członków pokazują pseudonimy i punkty, a nie ich adresy e-mail. Fikcyjne dane testowe są oddzielone i oznaczone jako DEMO.'),
          const SizedBox(height: 12),
          const Text(
            'THE GENESIS ERA • globalna społeczność • rankingi DEMO są wyraźnie oznaczone',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      );

  Widget _profile() => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const AgcLuxuryHeading(title: 'MÓJ PROFIL GENESIS',
            subtitle: 'Twoja przestrzeń w erze założycielskiej THE GENESIS ERA'),
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: gold, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(description),
      ]),
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
