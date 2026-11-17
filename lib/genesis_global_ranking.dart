import 'package:flutter/material.dart';
import 'agc_backend.dart';
import 'genesis_language.dart';

/// Global arcade leaderboard: sum of each player's personal best per game.
/// Uses the same database records as the individual game leaderboards.
class GenesisGlobalRanking extends StatefulWidget {
  const GenesisGlobalRanking({super.key});

  @override
  State<GenesisGlobalRanking> createState() => _GenesisGlobalRankingState();
}

class _GenesisGlobalRankingState extends State<GenesisGlobalRanking> {
  late Future<List<_PlayerTotal>> future;

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  void _refresh() => setState(() => future = _load());

  Future<List<_PlayerTotal>> _load() async {
    if (!AgcBackend.configured) {
      throw StateError('Brak połączenia z bazą wyników.');
    }
    final byPlayer = <String, Map<String, int>>{};
    // Fetch all visible records in pages, rather than silently ranking only
    // the first 100 or 1000 scores.
    const pageSize = 500;
    for (var offset = 0; ; offset += pageSize) {
      final raw = await AgcBackend.client
          .from('agc_game_scores')
          .select('member_id,game_key,best_score')
          .order('member_id')
          .order('game_key')
          .range(offset, offset + pageSize - 1);
      final rows = List<Map<String, dynamic>>.from(raw);
      for (final row in rows) {
        final id = row['member_id']?.toString();
        final key = row['game_key']?.toString();
        final score = row['best_score'];
        if (id == null || key == null || score is! num || score < 0) continue;
        final games = byPlayer.putIfAbsent(id, () => <String, int>{});
        final points = score.toInt();
        if (points > (games[key] ?? -1)) games[key] = points;
      }
      if (rows.length < pageSize) break;
    }
    final handles = <String, String>{};
    final ids = byPlayer.keys.toList();
    for (var i = 0; i < ids.length; i += 100) {
      final batch = ids.skip(i).take(100).toList();
      try {
        final members = await AgcBackend.client
            .from('agc_public_scores')
            .select('id,handle')
            .inFilter('id', batch);
        for (final member in members) {
          final id = member['id']?.toString();
          if (id != null) {
            handles[id] = member['handle']?.toString() ?? '';
          }
        }
      } catch (_) {
        // A missing public profile should not hide a player's scores.
      }
    }
    final players = byPlayer.entries.map((entry) {
      final scores = Map<String, int>.unmodifiable(entry.value);
      return _PlayerTotal(
        id: entry.key,
        handle: (handles[entry.key]?.trim().isNotEmpty ?? false)
            ? handles[entry.key]!
            : 'Gracz ${entry.key.substring(0, entry.key.length < 6 ? entry.key.length : 6)}',
        scores: scores,
        total: scores.values.fold<int>(0, (sum, score) => sum + score),
      );
    }).toList();
    players.sort((a, b) {
      final order = b.total.compareTo(a.total);
      return order != 0 ? order : a.id.compareTo(b.id);
    });
    return players;
  }

  String _gameName(String key) => switch (key) {
    'signal' => 'GENESIS SIGNAL',
    'defender' => 'GENESIS DEFENDER',
    _ => key.replaceAll('_', ' ').toUpperCase(),
  };

  void _details(_PlayerTotal player, int place) {
    final games = player.scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(player.handle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('#$place  ·  ${player.total} pkt',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 19, color: Color(0xFFD8B66A),
                  fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text(GenesisLanguage.copy(
                'Najlepsze wyniki w grach', 'Personal bests by game'),
                textAlign: TextAlign.center),
              const SizedBox(height: 10),
              for (final entry in games)
                Card(child: ListTile(
                  leading: const Icon(Icons.sports_esports_outlined),
                  title: Text(_gameName(entry.key)),
                  trailing: Text('${entry.value} pkt',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                )),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(GenesisLanguage.copy('Zamknij', 'Close')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 800),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
          child: Column(children: [
            const Icon(Icons.emoji_events_outlined,
              size: 45, color: Color(0xFFD8B66A)),
            const SizedBox(height: 8),
            Text(GenesisLanguage.copy('RANKING GLOBALNY', 'GLOBAL LEADERBOARD'),
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(GenesisLanguage.copy(
              'Suma najlepszych zapisanych wyników ze wszystkich gier. '
              'Kliknij gracza, aby zobaczyć szczegóły.',
              'Sum of personal best scores across all games. '
              'Tap a player to see their game-by-game scores.'),
              textAlign: TextAlign.center),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: _refresh,
                tooltip: GenesisLanguage.copy('Odśwież', 'Refresh'),
                icon: const Icon(Icons.refresh)),
            ),
          ]),
        ),
        Expanded(child: FutureBuilder<List<_PlayerTotal>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(GenesisLanguage.copy(
                    'Nie udało się pobrać rankingu. Sprawdź połączenie i spróbuj ponownie.',
                    'Could not load leaderboard. Check connection and retry.'),
                    textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton.icon(onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                    label: Text(GenesisLanguage.copy('Ponów', 'Retry'))),
                ]),
              ));
            }
            final players = snapshot.data ?? [];
            if (players.isEmpty) {
              return Center(child: Text(GenesisLanguage.copy(
                'Brak zapisanych wyników. Zagraj i zdobądź pierwsze punkty!',
                'No scores yet. Play a game to get on the leaderboard!'),
                textAlign: TextAlign.center));
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
              itemCount: players.length,
              itemBuilder: (context, index) {
                final player = players[index];
                final mine = player.id == AgcBackend.user?.id;
                return Card(
                  color: mine ? const Color(0xFF253B48) : null,
                  child: ListTile(
                    onTap: () => _details(player, index + 1),
                    leading: CircleAvatar(
                      child: Text(index < 3
                        ? ['🥇', '🥈', '🥉'][index]
                        : '${index + 1}'),
                    ),
                    title: Text(player.handle,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(GenesisLanguage.copy(
                      '${player.scores.length} gier · kliknij po szczegóły',
                      '${player.scores.length} games · tap for details')),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${player.total}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 17,
                            color: Color(0xFFD8B66A))),
                        const Text('pkt', style: TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        )),
      ]),
    ),
  );
}

class _PlayerTotal {
  final String id;
  final String handle;
  final Map<String, int> scores;
  final int total;

  const _PlayerTotal({
    required this.id,
    required this.handle,
    required this.scores,
    required this.total,
  });
}
