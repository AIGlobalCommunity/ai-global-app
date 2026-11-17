import 'agc_backend.dart';
import 'genesis_language.dart';
import 'genesis_game_embed_stub.dart'
    if (dart.library.html) 'genesis_game_embed_web.dart';
import 'genesis_artwork.dart';
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
    debugPrint('Game portal backend unavailable: $error');
  }
  runApp(const AgcApp());
}

const gold = Color(0xFFD8B66A);
const background = Color(0xFF0A1425);

class AgcApp extends StatelessWidget {
  const AgcApp({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
    valueListenable: GenesisLanguage.selected,
    builder: (context, language, _) => MaterialApp(
      title: 'THE GENESIS ERA • GAMES',
      debugShowCheckedModeBanner: false,
      theme: AgcLuxury.theme(),
      home: const AgcHome(),
    ),
  );
}

/// Games remain accessible without login; signing in enables account features.
class AgcHome extends StatefulWidget {
  const AgcHome({super.key});
  @override
  State<AgcHome> createState() => _AgcHomeState();
}

class _AgcHomeState extends State<AgcHome> {
  int selected = 0;
  StreamSubscription<AuthState>? authEvents;

  @override
  void initState() {
    super.initState();
    GenesisLanguage.selected.addListener(_refresh);
    if (AgcBackend.configured) {
      authEvents = AgcBackend.client.auth.onAuthStateChange.listen((_) => _refresh());
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    GenesisLanguage.selected.removeListener(_refresh);
    authEvents?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const FittedBox(
        fit: BoxFit.scaleDown,
        child: Text('✦ THE GENESIS ERA • GAMES ✦'),
      ),
      centerTitle: true,
      backgroundColor: background,
      foregroundColor: gold,
      actions: const [GenesisLanguagePicker()],
    ),
    body: SafeArea(
      child: AgcLuxuryBackdrop(
        child: IndexedStack(
          index: selected,
          children: [
            _home(),
            const GenesisGameTab(),
            _offlineInfo(),
            const AgcAccountPage(),
          ],
        ),
      ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: selected,
      onDestinationSelected: (index) => setState(() => selected = index),
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.home_outlined),
          label: GenesisLanguage.copy('Start', 'Home')),
        NavigationDestination(
          icon: const Icon(Icons.sports_esports_outlined),
          label: GenesisLanguage.copy('Gry', 'Games')),
        NavigationDestination(
          icon: const Icon(Icons.offline_bolt_outlined),
          label: GenesisLanguage.copy('Offline', 'Offline')),
        NavigationDestination(
          icon: const Icon(Icons.person_outline),
          label: GenesisLanguage.copy('Konto', 'Account')),
      ],
    ),
  );

  Widget _home() => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 750),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 12),
          const Center(child: GenesisArtwork(size: 175)),
          const SizedBox(height: 20),
          Text(
            GenesisLanguage.copy('TWOJE CENTRUM GIER', 'YOUR GAMING HUB'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26, fontWeight: FontWeight.bold,
              color: gold, letterSpacing: 1.5),
          ),
          const SizedBox(height: 12),
          Text(
            GenesisLanguage.copy(
              'Graj w gry przeglądarkowe, bij rekordy i rywalizuj w rankingach. '
              'Wybierz grę i rozpocznij zabawę!',
              'Play browser games, beat high scores and compete on leaderboards. '
              'Pick a game and start playing!'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => setState(() => selected = 1),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(GenesisLanguage.copy('ZAGRAJ TERAZ', 'PLAY NOW')),
          ),
          const SizedBox(height: 14),
          Card(
            child: ListTile(
              leading: const Icon(Icons.emoji_events_outlined, color: gold),
              title: Text(GenesisLanguage.copy('Gry i rankingi', 'Games and leaderboards')),
              subtitle: Text(GenesisLanguage.copy(
                'Odkrywaj dostępne gry i sprawdzaj najlepsze wyniki.',
                'Explore available games and see the best scores.')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => setState(() => selected = 1),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.offline_bolt_outlined, color: gold),
              title: Text(GenesisLanguage.copy('Granie offline', 'Offline play')),
              subtitle: Text(GenesisLanguage.copy(
                'Informacje o graniu bez internetu i zapisie wyników.',
                'Learn about playing without internet and saving scores.')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => setState(() => selected = 2),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _offlineInfo() => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 650),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.offline_bolt_outlined, size: 72, color: gold),
          const SizedBox(height: 18),
          Text(
            GenesisLanguage.copy('GRAJ BEZ INTERNETU', 'PLAY WITHOUT INTERNET'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: gold),
          ),
          const SizedBox(height: 16),
          Text(
            GenesisLanguage.copy(
              'Przygotowujemy pełny tryb offline. Aktualnie gry wymagają '
              'wcześniejszego załadowania strony; dostępność bez połączenia '
              'zależy od pamięci przeglądarki. Rankingi online i synchronizacja '
              'wyników wymagają internetu.',
              'Full offline support is in development. Games currently need '
              'the site to be loaded first; availability without a connection '
              'depends on the browser cache. Online leaderboards and score '
              'synchronization require internet.'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),
          OutlinedButton.icon(
            onPressed: () => setState(() => selected = 1),
            icon: const Icon(Icons.sports_esports),
            label: Text(GenesisLanguage.copy('Przejdź do gier', 'Browse games')),
          ),
        ],
      ),
    ),
  );
}
