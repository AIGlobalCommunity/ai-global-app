import 'package:flutter/material.dart';
import 'agc_backend.dart';
import 'agc_luxury_theme.dart';
import 'genesis_currency.dart';
import 'genesis_language.dart';

/// Read-only snapshot of points that have actually been awarded by Supabase.
class GenesisActualSnapshot {
  const GenesisActualSnapshot({
    required this.handle,
    required this.pointsByReason,
    required this.actualRank,
    required this.rankingScores,
  });

  final String handle;
  final Map<String, int> pointsByReason;
  final int? actualRank;
  final List<int> rankingScores;

  int get total => pointsByReason.values.fold(0, (sum, value) => sum + value);
  int pointsFor(String reason) => pointsByReason[reason] ?? 0;

  /// An estimate only: tie-breaking in the real ranking also uses signup date.
  int projectedRank(int hypotheticalPoints) =>
      1 + rankingScores.where((points) => points >= hypotheticalPoints).length;
}

Future<GenesisActualSnapshot> loadGenesisActualSnapshot() async {
  final member = AgcBackend.user;
  if (member == null) throw StateError('Sign in to load your real account data.');

  final results = await Future.wait<dynamic>([
    AgcBackend.client.from('agc_points')
        .select('reason,points').eq('member_id', member.id),
    AgcBackend.client.from('agc_leaderboard')
        .select('id,genesis_points,place').order('place').limit(10000),
    AgcBackend.myProfile(),
  ]);
  final pointRows = List<Map<String, dynamic>>.from(results[0] as List);
  final leaderboard = List<Map<String, dynamic>>.from(results[1] as List);
  final profile = results[2] as Map<String, dynamic>?;
  final byReason = <String, int>{};
  for (final row in pointRows) {
    final reason = row['reason'] as String? ?? 'other';
    byReason[reason] = (byReason[reason] ?? 0) +
        ((row['points'] as num?)?.toInt() ?? 0);
  }
  int? actualRank;
  final scores = <int>[];
  for (final row in leaderboard) {
    if (row['id'] == member.id) {
      actualRank = (row['place'] as num?)?.toInt();
    } else {
      scores.add((row['genesis_points'] as num?)?.toInt() ?? 0);
    }
  }
  return GenesisActualSnapshot(
    handle: profile?['handle'] as String? ?? member.email ?? 'Genesis',
    pointsByReason: byReason,
    actualRank: actualRank,
    rankingScores: scores,
  );
}

class GenesisRankSimulator extends StatefulWidget {
  const GenesisRankSimulator({super.key});

  @override
  State<GenesisRankSimulator> createState() => _GenesisRankSimulatorState();
}

class _GenesisRankSimulatorState extends State<GenesisRankSimulator> {
  late Future<GenesisActualSnapshot> snapshot;
  int extraReferrals = 0;
  int extraSupport = 0;

  @override
  void initState() {
    super.initState();
    snapshot = loadGenesisActualSnapshot();
  }

  void reset() => setState(() {
    extraReferrals = 0;
    extraSupport = 0;
  });

  void refresh() => setState(() {
    extraReferrals = 0;
    extraSupport = 0;
    snapshot = loadGenesisActualSnapshot();
  });

  Widget metric(String title, String value) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.white70)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(
          fontSize: 20, color: AgcLuxury.champagne, fontWeight: FontWeight.bold)),
      ]),
    ),
  );

  Widget counter(String title, int actualPoints, int additional,
      VoidCallback decrement, VoidCallback increment) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(GenesisLanguage.copy(
          'Już przyznane: $actualPoints GP · dodatkowe w symulacji: $additional',
          'Already awarded: $actualPoints GP · extra simulated actions: $additional'),
          style: const TextStyle(fontSize: 12, color: Colors.white70)),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          IconButton(onPressed: additional == 0 ? null : decrement,
            icon: const Icon(Icons.remove_circle_outline),
            tooltip: GenesisLanguage.copy('Odejmij symulację', 'Remove simulated action')),
          Text('$additional', style: const TextStyle(fontSize: 18)),
          IconButton(onPressed: increment,
            icon: const Icon(Icons.add_circle_outline),
            tooltip: GenesisLanguage.copy('Dodaj symulację', 'Add simulated action')),
        ]),
      ]),
    ),
  );

  String tier(int? rank) {
    if (rank == null) return '—';
    if (rank <= 100) return 'Genesis Eternal';
    if (rank <= 1000) return 'Gold Genesis';
    if (rank <= 10000) return 'Silver Genesis';
    return 'Global Member';
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<GenesisActualSnapshot>(
    future: snapshot,
    builder: (context, state) {
      if (state.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (state.hasError || state.data == null) {
        return ListView(padding: const EdgeInsets.all(20), children: [
          Text(GenesisLanguage.copy(
            'Nie udało się odczytać rzeczywistych danych konta. '
            'Symulator nie będzie podstawiał fikcyjnych wartości.',
            'Unable to load actual account data. The simulator will not '
            'substitute fictional values.')),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: refresh, icon: const Icon(Icons.refresh),
            label: Text(GenesisLanguage.copy('Spróbuj ponownie', 'Try again'))),
        ]);
      }
      final real = state.data!;
      final simulatedGain = extraReferrals * 100 +
          (extraSupport * 20).clamp(0, 200);
      final simulatedTotal = real.total + simulatedGain;
      final projected = real.rankingScores.isEmpty && real.actualRank == null
          ? null : real.projectedRank(simulatedTotal);
      return ListView(padding: const EdgeInsets.all(20), children: [
        AgcLuxuryHeading(
          title: GenesisLanguage.copy('SYMULATOR TWOJEJ RANGI', 'YOUR RANK SIMULATOR'),
          subtitle: GenesisLanguage.copy(
            'Startujemy od punktów zapisanych na Twoim koncie.',
            'Start from the points actually recorded in your account.')),
        const SizedBox(height: 12),
        Text(real.handle, style: const TextStyle(
          color: AgcLuxury.champagne, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        metric(GenesisLanguage.copy('Twoje prawdziwe punkty', 'Your real points'),
          '${real.total} GP'),
        metric(GenesisLanguage.copy('Twoje prawdziwe miejsce', 'Your real position'),
          real.actualRank?.toString() ?? '—'),
        metric(GenesisLanguage.copy('Twoja aktualna ranga', 'Your current tier'),
          tier(real.actualRank)),
        const SizedBox(height: 12),
        Text(GenesisLanguage.copy('ZDARZENIA JUŻ ZAPISANE NA KONCIE',
          'EVENTS ALREADY RECORDED ON YOUR ACCOUNT'),
          style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 7),
        Text(GenesisLanguage.copy(
          'Rejestracja: ${real.pointsFor('signup')} GP\n'
          'Potwierdzone polecenia: ${real.pointsFor('verified_referral')} GP\n'
          'Wsparcie: ${real.pointsFor('contribution')} GP',
          'Registration: ${real.pointsFor('signup')} GP\n'
          'Verified referrals: ${real.pointsFor('verified_referral')} GP\n'
          'Support: ${real.pointsFor('contribution')} GP')),
        const SizedBox(height: 18),
        Text(GenesisLanguage.copy('CO JEŚLI ZROBIĘ WIĘCEJ?',
          'WHAT IF I DO MORE?'),
          style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 7),
        counter(GenesisLanguage.copy('Nowe potwierdzone polecenia (+100 GP)',
          'New verified referrals (+100 GP)'),
          real.pointsFor('verified_referral'), extraReferrals,
          () => setState(() => extraReferrals--),
          () => setState(() => extraReferrals++)),
        const GenesisCurrencyPanel(),
        const SizedBox(height: 8),
        counter(
          '${GenesisLanguage.copy('Przykładowe wsparcie', 'Example support')} '
              '10 ${GenesisCurrency.currency} (+20 GP)',
          real.pointsFor('contribution'), extraSupport,
          () => setState(() => extraSupport--),
          () => setState(() => extraSupport++)),
        const SizedBox(height: 12),
        metric(GenesisLanguage.copy('Hipotetyczna suma', 'Hypothetical total'),
          '$simulatedTotal GP (+$simulatedGain GP)'),
        metric(GenesisLanguage.copy('Szacowane miejsce', 'Estimated position'),
          projected?.toString() ?? '—'),
        metric(GenesisLanguage.copy('Szacowana ranga', 'Estimated tier'),
          tier(projected)),
        const SizedBox(height: 9),
        Text(GenesisLanguage.copy(
          'Wszystkie dodane działania są tylko symulacją. Nie zmieniają '
          'konta, rankingu ani salda GP. Szacowane miejsce zależy od '
          'aktualnie odczytanych wyników innych członków i może się zmienić. '
          'Wpłaty nie są pobierane.',
          'All added actions are simulations only. They do not change your '
          'account, ranking or GP balance. The estimated position is based '
          'on currently retrieved scores and may change. No payments are taken.'),
          style: const TextStyle(fontSize: 12, color: Colors.white70)),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: reset, icon: const Icon(Icons.restart_alt),
          label: Text(GenesisLanguage.copy('Przywróć moje rzeczywiste dane',
            'Restore my actual data'))),
        OutlinedButton.icon(onPressed: refresh, icon: const Icon(Icons.refresh),
          label: Text(GenesisLanguage.copy('Odśwież z bazy', 'Refresh from database'))),
      ]);
    },
  );
}
