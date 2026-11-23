import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'agc_backend.dart';
import 'genesis_language.dart';

/// Global arcade leaderboard: sum of each player's personal best per game.
/// Uses the same database records as the individual game leaderboards.
class GenesisGlobalRanking extends StatefulWidget {
  static final scoreRevision = ValueNotifier<int>(0);
  final bool active;
  const GenesisGlobalRanking({super.key, this.active = true});

  @override
  State<GenesisGlobalRanking> createState() => _GenesisGlobalRankingState();
}

class _GenesisGlobalRankingState extends State<GenesisGlobalRanking> {
  late Future<List<_PlayerTotal>> future;
  String mode = 'all';
  String game = 'signal';
  DateTime day = DateTime.now();
  String get dayKey => '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
  static const games = ['signal','defender','wolf','blocks','snake','ski','maze','slingshot','crystals','solitaire','freecell','spider','hearts'];
  StreamSubscription<AuthState>? authSubscription;

  @override
  void initState() {
    super.initState();
    future = _load();
    GenesisGlobalRanking.scoreRevision.addListener(_scoreChanged);
    if (AgcBackend.configured) {
      authSubscription = AgcBackend.client.auth.onAuthStateChange.listen((_) {
        if (mounted) _refresh();
      });
    }
  }

  void _scoreChanged() {
    if (widget.active) _refresh();
  }

  @override
  void didUpdateWidget(GenesisGlobalRanking oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) future = _load();
  }

  void _refresh() => setState(() => future = _load());

  @override
  void dispose() {
    GenesisGlobalRanking.scoreRevision.removeListener(_scoreChanged);
    authSubscription?.cancel();
    super.dispose();
  }

  Future<List<_PlayerTotal>> _load() async {
    if (!AgcBackend.configured) {
      throw StateError('Brak połączenia z bazą wyników.');
    }
    final selectedMode = mode, selectedGame = game, selectedDay = dayKey;
    final byPlayer = <String, Map<String, int>>{};
    // Fetch all visible records in pages, rather than silently ranking only
    // the first 100 or 1000 scores.
    const pageSize = 500;
    for (var offset = 0; ; offset += pageSize) {
      var query = AgcBackend.client.from(selectedMode == 'verified' ? 'agc_verified_daily_scores' : selectedMode == 'daily' ? 'agc_daily_scores' : 'agc_game_scores').select('member_id,game_key,best_score');
      if (selectedMode == 'daily' || selectedMode == 'verified') query = query.eq('score_day', selectedDay);
      if (selectedMode == 'game') query = query.eq('game_key', selectedGame);
      final raw = await query.order('member_id')
          .order('game_key')
          .range(offset, offset + pageSize - 1);
      final rows = List<Map<String, dynamic>>.from(raw);
      for (final row in rows) {
        final id = row['member_id']?.toString();
        final key = row['game_key']?.toString();
        final score = row['best_score'];
        if (id == null || key == null || score is! num || score < 0) continue;
        if (!const ['signal', 'defender', 'wolf', 'blocks', 'snake', 'ski', 'maze', 'slingshot', 'crystals', 'solitaire', 'freecell', 'spider', 'hearts'].contains(key)) continue;
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
        final members = await AgcBackend.client.rpc(
            'agc_game_ranking_names', params: {'p_ids': batch});
        for (final member in members) {
          final id = member['id']?.toString();
          if (id != null) {
            handles[id] = member['display_handle']?.toString() ?? '';
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
            : 'Gracz anonimowy',
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
    'wolf' => 'WILK I JAJKA',
    'blocks' => 'GENESIS BLOCKS',
    'snake' => 'GENESIS SNAKE',
    'ski' => 'SKOKI NARCIARSKIE',
    'maze' => 'GENESIS MAZE',
    'slingshot' => 'GENESIS SLINGSHOT',
    'crystals' => 'GENESIS CRYSTALS',
    'solitaire' => 'GENESIS SOLITAIRE',
    'freecell' => 'GENESIS FREECELL',
    'spider' => 'GENESIS SPIDER',
    'hearts' => 'GENESIS KIERKI',
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
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [
              for (final entry in {'all': GenesisLanguage.copy('Ogólny','Overall'), 'daily': GenesisLanguage.copy('Dzienny','Daily'), 'verified': GenesisLanguage.copy('Konkurs','Competition')}.entries)
                ChoiceChip(label: Text(entry.value), selected: mode == entry.key, onSelected: (_) => setState(() { mode = entry.key; future = _load(); })),
            ]),
            if (mode == 'game') DropdownButton<String>(value: game, isExpanded: true, items: [for (final key in games) DropdownMenuItem(value: key, child: Text(_gameName(key)))], onChanged: (value) { if (value != null) setState(() { game = value; future = _load(); }); }),
            if (mode == 'verified') Padding(padding: const EdgeInsets.all(8), child: Text(GenesisLanguage.copy('🏆 80 zł dziennie: 1. 50 zł • 2. 20 zł • 3. 10 zł • wyniki wymagają weryfikacji. Zwykłe gry także mogą się kwalifikować. Laureatów ogłasza organizator na Facebooku.','Daily prize pool: PLN 80 (1st: 50, 2nd: 20, 3rd: 10). Regular game scores may also qualify after verification. The organizer announces the winners on Facebook.'), textAlign: TextAlign.center)),
            if (mode == 'daily' || mode == 'verified') Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setState(() { day = DateTime(day.year,day.month,day.day-1); future = _load(); })),
              TextButton.icon(icon: const Icon(Icons.calendar_month), label: Text(dayKey), onPressed: () async { final picked = await showDatePicker(context: context, initialDate: day, firstDate: DateTime(2020), lastDate: DateTime.now()); if (picked != null && mounted) setState(() { day = picked; future = _load(); }); }),
              IconButton(icon: const Icon(Icons.chevron_right), onPressed: dayKey == DateTime.now().toIso8601String().substring(0,10) ? null : () => setState(() { day = DateTime(day.year,day.month,day.day+1); future = _load(); })),
              TextButton(onPressed: () => setState(() { day = DateTime.now(); future = _load(); }), child: Text(GenesisLanguage.copy('Dzisiaj','Today'))),
            ]),
            if (AgcBackend.user == null)
              Padding(padding: const EdgeInsets.only(top: 10), child: Text(
                GenesisLanguage.copy('⚠ Tryb gościa: możesz oglądać ranking, ale Twoje punkty nie są zapisywane. Zaloguj się w KONTO przed grą.', '⚠ Guest mode: you can view rankings, but your scores are not saved. Sign in before playing.'),
                textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFFFC777), fontSize: 12))),
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
                  const SizedBox(height: 8),
                  SelectableText('${snapshot.error}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Color(0xFFFFC777))),
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
                mode == 'daily' ? 'Brak wyników w wybranym dniu.' : 'Brak wyników widocznych w bazie.',
                mode == 'daily' ? 'No scores on the selected day.' : 'No scores are visible in the database.'),
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
                    isThreeLine: (mode == 'daily' || mode == 'verified') && index < 3,
                    title: Text(player.handle,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(GenesisLanguage.copy(
                          '${player.scores.length} gier · kliknij po szczegóły',
                          '${player.scores.length} games · tap for details')),
                        if (mode == 'daily' && index < 3)
                          Text(GenesisLanguage.copy(
                            '🏆 Potencjalna nagroda: ${[50, 20, 10][index]} zł, jeśli spełniasz wymagania konkursu i wynik zostanie zatwierdzony.',
                            '🏆 Potential prize: PLN ${[50, 20, 10][index]}, subject to contest eligibility and score verification.'),
                            style: const TextStyle(color: Color(0xFFD8B66A), fontSize: 11)),
                        if (mode == 'verified' && index < 3)
                          Text(GenesisLanguage.copy(
                            '🏆 Możesz wygrać ${[50, 20, 10][index]} zł, jeśli spełniasz wymagania konkursu i organizator zatwierdzi wynik.',
                            '🏆 You could win PLN ${[50, 20, 10][index]} if you meet contest requirements and your result is approved.'),
                            style: const TextStyle(color: Color(0xFFD8B66A), fontSize: 11)),
                      ],
                    ),
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
