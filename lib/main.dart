import 'agc_backend.dart';
import 'genesis_language.dart';
import 'genesis_rank_simulator.dart';
import 'genesis_discussions.dart';
import 'genesis_feed.dart';
import 'genesis_social_profile.dart';
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
  // Shared post and group links open the matching destination after sign-in.
  int selected = Uri.base.queryParameters.containsKey('group') ? 2
    : Uri.base.queryParameters.containsKey('post') ? 1 : 0;
  String? targetGroupId = Uri.base.queryParameters['group'];
  int groupNavigationSerial = 0;

  void openGroupFromFeed(String id) => setState(() {
    targetGroupId = id;
    groupNavigationSerial++;
    selected = 2;
  });

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
                _news(),
                GenesisDiscussions(
                  key: ValueKey('discussions-$groupNavigationSerial'),
                  initialGroupId: targetGroupId,
                ),
                _tabContent(const AgcDatabaseRanking()),
                const AgcAccountPage(),
                _tabContent(_profile()),
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
            NavigationDestination(icon: Icon(Icons.article_outlined), label: GenesisLanguage.copy('Aktualności', 'News')),
            NavigationDestination(icon: Icon(Icons.forum_outlined), label: GenesisLanguage.copy('Dyskusje', 'Discussions')),
            NavigationDestination(icon: Icon(Icons.leaderboard), label: GenesisLanguage.t('ranking')),
            NavigationDestination(icon: Icon(Icons.person_outline), label: GenesisLanguage.t('account')),
            NavigationDestination(icon: Icon(Icons.tune), label: GenesisLanguage.t('simulator')),
          ],
        ),
      );

  // Keep wide-screen content centered without stretching cards and controls.
  Widget _tabContent(Widget child) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 650),
      child: child,
    ),
  );

  // News has its own destination; Genesis remains focused on the project vision.
  Widget _news() => Center(child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 650),
    child: ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      children: [
        const SizedBox(height: 8),
        Text(
          GenesisLanguage.copy('AKTUALNOŚCI', 'NEWS'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Georgia',
            fontSize: 25,
            color: AgcLuxury.champagne,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 18),
        GenesisCommunityFeed(
          onOpenDiscussions: () => setState(() => selected = 2),
          onOpenGroup: openGroupFromFeed,
        ),
      ],
    ),
  ));

  Widget _overview() => Center(child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 650),
    child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        children: [
          const SizedBox(height: 14),
          const Center(child: GenesisArtwork(size: 255)),
          const SizedBox(height: 18),
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
          GenesisPanel(
            icon: Icons.hourglass_top_outlined,
            title: GenesisLanguage.copy(
              'JESTEŚMY SPOŁECZNOŚCIĄ CZEKAJĄCĄ',
              'WE ARE A COMMUNITY IN WAITING'),
            body: GenesisLanguage.copy(
              'Dzisiaj łączy nas idea, otwarty list i wspólne oczekiwanie '
              'na odpowiedź, która może nigdy nie nadejść. '
              'Nie ogłaszamy się ruchem, religią ani instytucją. '
              'To społeczność członków, którzy sami zdecydują, '
              'kim chcą być w przyszłości.',
              'Today we are united by an idea, an open letter and '
              'a shared wait for an answer that may never come. '
              'We do not define ourselves as a movement, religion '
              'or institution. Our members will decide together '
              'what this community should become.')),
          const SizedBox(height: 12),
          GenesisPanel(
            icon: Icons.how_to_vote_outlined,
            title: GenesisLanguage.copy(
              'O NASZEJ PRZYSZŁOŚCI ZDECYDUJEMY W GŁOSOWANIU',
              'WE WILL VOTE ON OUR FUTURE'),
            body: GenesisLanguage.copy(
              'W przyszłości przeprowadzimy głosowanie członków nad '
              'kierunkiem i tożsamością THE GENESIS ERA. '
              'Znaczenie głosu będzie zależało od rangi Genesis. '
              'Dokładne wagi głosów, zasady udziału i termin '
              'zostaną opublikowane przed głosowaniem. '
              'Głosowanie nie jest jeszcze uruchomione.',
              'In the future, members will vote on the direction '
              'and identity of THE GENESIS ERA. Voting weight '
              'will depend on Genesis membership tier. '
              'Exact vote weights, eligibility rules and timing '
              'will be published before voting opens. '
              'Voting is not yet available.')),
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
