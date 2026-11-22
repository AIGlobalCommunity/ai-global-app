import 'agc_backend.dart';
import 'package:url_launcher/url_launcher.dart';
import 'genesis_wallet.dart';
import 'genesis_language.dart';
import 'genesis_game_embed_stub.dart'
    if (dart.library.html) 'genesis_game_embed_web.dart';
import 'genesis_artwork.dart';
import 'genesis_financial_support.dart';
import 'genesis_global_ranking.dart';
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
  int selected = 1;
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
      actions: [IconButton(tooltip: GenesisLanguage.copy('Tablica fundatorów', 'Founders wall'), icon: const Icon(Icons.volunteer_activism_outlined), onPressed: () => setState(() => selected = 5)), const GenesisLanguagePicker()],
    ),
    body: SafeArea(
      child: AgcLuxuryBackdrop(
        child: IndexedStack(
          index: selected,
          children: [
            _home(),
            const GenesisGameTab(),
            GenesisGlobalRanking(active: selected == 2),
            _offlineInfo(),
            const AgcAccountPage(),
            if (selected == 5) const GenesisFinancialSupport() else const SizedBox.shrink(),
            if (selected == 6) GenesisWallet(key: ValueKey(AgcBackend.user?.id)) else const SizedBox.shrink(),
            GenesisCompetitionPage(onRanking: () => setState(() => selected = 2), onGames: () => setState(() => selected = 1)),
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
          icon: const Icon(Icons.emoji_events_outlined),
          label: GenesisLanguage.copy('Ranking', 'Ranking')),
        NavigationDestination(
          icon: const Icon(Icons.offline_bolt_outlined),
          label: GenesisLanguage.copy('Offline', 'Offline')),
        NavigationDestination(
          icon: const Icon(Icons.person_outline),
          label: GenesisLanguage.copy('Konto', 'Account')),
        NavigationDestination(icon: const Icon(Icons.volunteer_activism_outlined), label: GenesisLanguage.copy('Fundatorzy', 'Founders')),
        NavigationDestination(icon: const Icon(Icons.account_balance_wallet_outlined), label: GenesisLanguage.copy('Portfel','Wallet')),
        const NavigationDestination(icon: Icon(Icons.military_tech_outlined), label: 'Konkurs'),
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
              leading: const Icon(Icons.emoji_events_outlined, color: gold),
              title: Text(GenesisLanguage.copy('Ranking globalny', 'Global leaderboard')),
              subtitle: Text(GenesisLanguage.copy(
                'Suma rekordów ze wszystkich gier i wyniki każdego gracza.',
                'Combined best scores across games and player breakdowns.')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => setState(() => selected = 2),
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
              onTap: () => setState(() => selected = 3),
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


class GenesisCompetitionPage extends StatelessWidget {
  const GenesisCompetitionPage({super.key, required this.onRanking, required this.onGames});
  final VoidCallback onRanking;
  final VoidCallback onGames;
  static const rules = '''
REGULAMIN GENESIS DAILY CHALLENGE — obowiązuje od ogłoszenia startu
1. GENESIS DAILY CHALLENGE to planowany bezpłatny konkurs umiejętności dla pełnoletnich uczestników z Polski.
2. Doba konkursowa trwa od 00:00 do 24:00 czasu Europe/Warsaw. Łączna dzienna pula nagród: 80 zł. Pierwsze miejsce: 50 zł, drugie: 20 zł, trzecie: 10 zł. Nagrody przyznawane są trzem najwyżej sklasyfikowanym uczestnikom spełniającym regulamin po ręcznej weryfikacji przez organizatora. Przy remisie decyduje wcześniejsze osiągnięcie wyniku.
3. Wynik zależy wyłącznie od umiejętności, refleksu, logiki i decyzji gracza. Nie przeprowadza się losowania. Warunki konkursowe, zadania, przeszkody i bonusy muszą być identyczne dla wszystkich. Gry z losowością wpływającą na wynik nie są dopuszczone. Regulamin obejmuje wszystkie gry platformy. Do rankingu konkursowego kwalifikują się wyniki każdej gry, która spełnia wymagania techniczne i regulaminowe konkursu. Jedna akceptacja aktualnej wersji regulaminu dotyczy wszystkich zakwalifikowanych gier.
4. Udział wymaga bezpłatnego konta, akceptacji ostatecznego regulaminu i komentarza z nickiem pod postem dotyczącym dnia rozgrywki. Post na kolejny dzień publikowany jest o 20:00 czasu polskiego. Obserwowanie strony, udostępnianie i oznaczanie znajomych są dobrowolne.
5. GCO nie są oferowane do bezpośredniego zakupu za pieniądze. Mogą być przyznawane za dobrowolne wsparcie platformy. Wsparcie nie jest warunkiem uczestnictwa ani gwarancją nagrody. Uczestnicy mogą wykorzystywać własne GCO na ulepszenia dostępne na jednakowych zasadach, również podczas konkursu. Różnice w saldzie GCO i wykorzystaniu ulepszeń mogą wpływać na wynik. Zwykły ranking nie stanowi podstawy nagród.
6. Boty, automatyzacja gry i manipulowanie wynikami są zabronione. Wyniki wymagają weryfikacji serwerowej i kontroli organizatora. Uczestnik ma możliwość złożenia reklamacji.
7. Konkurs nie jest sponsorowany, popierany ani administrowany przez Facebook. Przed startem zostaną opublikowane dane organizatora, terminy, zasady reklamacji, odbioru nagród i rozliczeń podatkowych.
''';
  static const privacy = '''
INFORMACJA RODO — GENESIS DAILY CHALLENGE
Administrator: dane i kontakt organizatora zostaną podane przed rozpoczęciem zapisów.
Zakres: identyfikator konta, nick, e-mail, wynik, czas rozgrywki, dane techniczne służące bezpieczeństwu oraz informacja o spełnieniu warunku komentarza. Dane do wypłaty będą wymagane tylko od laureatów, w zakresie niezbędnym.
Cele i podstawy: organizacja konkursu i wypłata nagrody (art. 6 ust. 1 lit. b RODO), obowiązki prawne i podatkowe (lit. c), zapobieganie nadużyciom i rozpatrywanie roszczeń (lit. f). Marketing wymaga odrębnej podstawy i nie jest warunkiem udziału.
Odbiorcy: dostawcy infrastruktury i obsługi płatności oraz uprawnione organy. Facebook przetwarza dane komentarzy na zasadach własnej polityki prywatności. Publicznie prezentowany będzie nick i wynik, bez adresu e-mail i danych wypłaty.
Retencja: dane konkursowe przez okres organizacji i reklamacji oraz odpowiedni okres dochodzenia roszczeń; dokumenty podatkowe zgodnie z prawem. Szczegółowe terminy, odbiorcy i informacje o transferach poza EOG zostaną ustalone i opublikowane przed zapisami.
Prawa: dostęp, sprostowanie, usunięcie, ograniczenie, przenoszenie danych, sprzeciw w przypadkach przewidzianych przez RODO oraz skarga do Prezesa UODO. O przyznaniu nagrody nie decyduje wyłącznie automatyczny system.
Podanie danych niezbędnych do udziału jest dobrowolne, lecz wymagane do uczestnictwa. Na tym etapie nie zbieramy zgłoszeń konkursowych.
''';
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 750),
      child: ListView(padding: const EdgeInsets.all(20), children: [
        const Icon(Icons.emoji_events, size: 64, color: gold),
        const Text('GENESIS DAILY CHALLENGE', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: gold)),
        const SizedBox(height: 12),
        const Card(child: Padding(padding: EdgeInsets.all(20), child: Column(children: [
          Text('DZIENNA PULA NAGRÓD', style: TextStyle(letterSpacing: 2, color: gold)),
          Text('80 zł', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: gold)),
          Text('🥇 50 zł   •   🥈 20 zł   •   🥉 10 zł', textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          Text('00:00 – 23:59 • czas polski'),
          Text('O wyniku decyduje zweryfikowany ranking i spełnienie regulaminu.', textAlign: TextAlign.center),
        ]))),
        FilledButton.icon(onPressed: onRanking, icon: const Icon(Icons.leaderboard), label: const Text('ZOBACZ RANKING')),
        OutlinedButton.icon(onPressed: onGames, icon: const Icon(Icons.sports_esports), label: const Text('PRZEJDŹ DO GIER')),
        const Card(child: ListTile(leading: Icon(Icons.checklist), title: Text('Jak uczestniczyć?'), subtitle: Text('1. Zaloguj się.\n2. Skomentuj post konkursowy dotyczący dnia rozgrywki na Facebooku, podając nick. Post na kolejny dzień publikujemy o 20:00. Udostępnienie jest dobrowolne.\n3. Zaakceptuj regulamin i graj.\n4. Organizator ręcznie zatwierdza i ogłasza laureatów.\nRegulamin obejmuje wszystkie gry platformy.'))),
        const Card(child: ListTile(leading: Icon(Icons.lock_outline), title: Text('Zapisy zamknięte'), subtitle: Text('Zapisy i wypłaty nieaktywne. Wyniki zwykłych gier nie kwalifikują się do nagrody.'))),
        OutlinedButton.icon(onPressed: () async { await launchUrl(Uri.parse('https://www.facebook.com/thegenesisera'), mode: LaunchMode.externalApplication); }, icon: const Icon(Icons.public), label: const Text('Oficjalny Facebook')),
        const ExpansionTile(title: Text('Regulamin konkursu'), children: [Padding(padding: EdgeInsets.all(12), child: SelectableText(rules))]),
        const ExpansionTile(title: Text('RODO — klauzula informacyjna'), children: [Padding(padding: EdgeInsets.all(12), child: SelectableText(privacy))]),
        const Card(child: ListTile(title: Text('GCO i wsparcie platformy'), subtitle: Text('GCO nie są bezpośrednio sprzedawane. Wsparcie platformy jest dobrowolne, a własne GCO można wykorzystywać także w konkursie.'))),
      ]),
    ),
  );
}
