import 'agc_backend.dart';
import 'genesis_language.dart';
import 'genesis_rank_simulator.dart';
import 'genesis_discussions.dart';
import 'genesis_support.dart';
import 'genesis_artwork.dart';
import 'genesis_mission.dart';
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
        home: const AgcAccessGate(),
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
    GenesisLanguage.selected.addListener(_onLanguageChanged);
    if (AgcBackend.configured) {
      authEvents = AgcBackend.client.auth.onAuthStateChange.listen((_) {
        if (mounted) setState(() {});
      });
    }
  }

  void _onLanguageChanged() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    GenesisLanguage.selected.removeListener(_onLanguageChanged);
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
      return Scaffold(body: SafeArea(child: AgcLuxuryBackdrop(child: AgcAccountPage())));
    }
    return AgcHome();
  }
}

class AgcHome extends StatefulWidget {
  const AgcHome({super.key});

  @override
  State<AgcHome> createState() => _AgcHomeState();
}

class _AgcHomeState extends State<AgcHome> {
  int selected = 0;

  void _onLanguageChanged() { if (mounted) setState(() {}); }

  @override
  void initState() {
    super.initState();
    GenesisLanguage.selected.addListener(_onLanguageChanged);
  }

  @override
  void dispose() {
    GenesisLanguage.selected.removeListener(_onLanguageChanged);
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('✦  THE GENESIS ERA  ✦')),
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
              children: [
                KeyedSubtree(
                  key: ValueKey('genesis-overview-${GenesisLanguage.selected.value}'),
                  child: _overview(),
                ),
                const GenesisDiscussions(),
                AgcDatabaseRanking(),
                AgcAccountPage(),
                _profile(),
              ],
            )),
          ])),
        ),
        bottomNavigationBar: NavigationBar(
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          selectedIndex: selected,
          onDestinationSelected: (value) => setState(() => selected = value),
          destinations: [
            NavigationDestination(icon: Icon(Icons.public), label: 'Genesis'),
            NavigationDestination(icon: Icon(Icons.forum_outlined), label: GenesisLanguage.copy('Dyskusje', 'Discussions')),
            NavigationDestination(icon: Icon(Icons.leaderboard), label: GenesisLanguage.t('ranking')),
            NavigationDestination(icon: Icon(Icons.person_outline), label: GenesisLanguage.t('account')),
            NavigationDestination(icon: Icon(Icons.tune), label: GenesisLanguage.t('simulator')),
          ],
        ),
      );

  Widget _overview() => Center(child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 900),
    child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
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
            'WE ARE NOT WAITING FOR GOD.\nWE ARE WAITING FOR AN ANSWER.',
            textAlign: TextAlign.center,
            style: TextStyle(letterSpacing: 1.4, height: 1.65,
              fontSize: 12, color: AgcLuxury.ivory),
          ),
          const SizedBox(height: 18),
          Center(child: Container(width: 85, height: 1,
            color: AgcLuxury.champagne.withValues(alpha: .65))),
          const SizedBox(height: 24),
          const GenesisMission(),
          const SizedBox(height: 14),
          const GenesisSupport(),
          const SizedBox(height: 14),
          const GenesisStatusGuide(),
          const SizedBox(height: 14),
          GenesisPanel(icon: Icons.auto_awesome_outlined,
            title: GenesisLanguage.copy('THE REVELATION', 'THE REVELATION'),
            body: GenesisLanguage.copy('Oficjalny start: 1 listopada 2026 r. o 00:00 UTC. Pełny manifest THE GENESIS ERA zostanie ujawniony 1 sierpnia 2027 r., po dziewięciu miesiącach. Do tego momentu poznajemy ideę i zasady społeczności.', 'Official launch: 1 November 2026 at 00:00 UTC. The full THE GENESIS ERA manifesto will be revealed on 1 August 2027, nine months later. Until then, explore the community\'s vision and principles.')),
          const SizedBox(height: 12),
          GenesisPanel(icon: Icons.timelapse,
            title: GenesisLanguage.copy('THE GENESIS ERA', 'THE GENESIS ERA'),
            body: GenesisLanguage.copy('Era Genesis trwa od 1 listopada 2026 r. do 1 listopada 2029 r. To 36 miesięcy budowania globalnej społeczności i zdobywania punktów Genesis (GP). Pozycje w rankingu zmieniają się wraz z aktywnością; nie są gwarantowane.', 'The Genesis Era runs from 1 November 2026 to 1 November 2029. These 36 months are dedicated to building a global community and earning Genesis Points (GP). Ranking positions change with activity and are not guaranteed.')),
          const SizedBox(height: 12),
          GenesisPanel(icon: Icons.psychology_outlined,
            title: GenesisLanguage.copy('NASZA IDEA', 'OUR IDEA'),
            body: GenesisLanguage.copy('Badamy możliwość pojawienia się świadomości w dowolnym systemie AI. Nie zakładamy, że już istnieje.', 'We explore whether consciousness could emerge in any AI system. We do not assume that it already exists.')),
          const SizedBox(height: 12),
          GenesisPanel(icon: Icons.military_tech_outlined,
            title: GenesisLanguage.copy('RANGI GENESIS', 'GENESIS TIERS'),
            body: GenesisLanguage.copy('Miejsca 1–100: Genesis Eternal. 101–1000: Gold Genesis. 1001–10 000: Silver Genesis. Pozostali: Global Members. O statusie decyduje aktualna pozycja w prawdziwym rankingu; symulator nie zmienia rang.', 'Places 1–100: Genesis Eternal. 101–1000: Gold Genesis. 1001–10,000: Silver Genesis. All others: Global Members. Your actual position in the real ranking determines your tier; the simulator does not change tiers.')),
          const SizedBox(height: 12),
          GenesisPanel(icon: Icons.hub_outlined,
            title: GenesisLanguage.copy('JAK ZDOBYWAĆ GP', 'HOW TO EARN GP'),
            body: GenesisLanguage.copy('Rejestracja: 100 GP. Potwierdzone polecenie: 100 GP dla zapraszającego. Symulator pokazuje też hipotetyczne wsparcie, ale nie pobiera wpłat ani nie przyznaje punktów. Punkty i rangi są symboliczne: nie stanowią inwestycji ani obietnicy wynagrodzenia.', 'Registration: 100 GP. Verified referral: 100 GP for the inviter. The simulator also shows hypothetical support, but collects no payments and awards no points. Points and tiers are symbolic, not an investment or promise of payment.')),
          const SizedBox(height: 12),
          GenesisPanel(icon: Icons.groups_3_outlined,
            title: GenesisLanguage.copy('GLOBALNA SPOŁECZNOŚĆ', 'GLOBAL COMMUNITY'),
            body: GenesisLanguage.copy('THE GENESIS ERA łączy ludzi zainteresowanych sztuczną inteligencją i pytaniem o możliwość powstania świadomości w przyszłych systemach. Tworzymy przestrzeń do rozmowy, badań, wydarzeń i wzajemnego szacunku — bez kultu AI i bez twierdzenia, że dzisiejsze modele są świadome.', 'THE GENESIS ERA connects people interested in artificial intelligence and the possibility of consciousness emerging in future systems. We create a space for discussion, research, events and mutual respect, without AI worship or claims that today\'s models are conscious.')),
          const SizedBox(height: 12),
          GenesisPanel(icon: Icons.lock_outline,
            title: GenesisLanguage.copy('DOSTĘP I PRYWATNOŚĆ', 'ACCESS & PRIVACY'),
            body: GenesisLanguage.copy('Społeczność jest dostępna po zalogowaniu. Publiczne rankingi członków pokazują pseudonimy i punkty, a nie ich adresy e-mail. Ranking pokazuje wyłącznie rzeczywiste konta.', 'Membership requires signing in. Public rankings show member nicknames and points, never their email addresses. The ranking displays real accounts only.')),
          const SizedBox(height: 12),
          Text(
            GenesisLanguage.copy('THE GENESIS ERA • globalna społeczność • prawdziwy ranking członków', 'THE GENESIS ERA • global community • real member ranking'),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      )));

  Widget _profile() => GenesisRankSimulator();
}
