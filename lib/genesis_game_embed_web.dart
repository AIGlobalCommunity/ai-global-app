// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'agc_backend.dart';
import 'genesis_language.dart';

/// HTML5 games send finished scores to their authenticated Flutter parent.
/// Only the signed-in user's personal best is stored in Supabase.
class GenesisGameTab extends StatefulWidget {
  const GenesisGameTab({super.key});

  @override
  State<GenesisGameTab> createState() => _GenesisGameTabState();
}

class _GenesisGameTabState extends State<GenesisGameTab> {
  static bool registered = false;
  static const signalView = 'genesis-signal-html5-iframe';
  static const defenderView = 'genesis-defender-html5-iframe';
  static final Map<String, html.IFrameElement> frames = {};
  StreamSubscription<html.MessageEvent>? messages;
  int? game;
  String? scoreNotice;
  bool saving = false;

  String get gameKey => game == 0 ? 'signal' : 'defender';

  @override
  void initState() {
    super.initState();
    if (!registered) {
      _register(signalView, 'genesis-game.html', 'GENESIS SIGNAL');
      _register(defenderView, 'genesis-defender.html', 'GENESIS DEFENDER');
      registered = true;
    }
    messages = html.window.onMessage.listen(_onMessage);
  }

  @override
  void dispose() {
    messages?.cancel();
    super.dispose();
  }

  static void _register(String type, String src, String title) {
    ui_web.platformViewRegistry.registerViewFactory(
      type,
      (int viewId) {
        final frame = html.IFrameElement()
          ..src = src
          ..title = title
          ..style.border = '0'
          ..style.width = '100%'
          ..style.height = '100%'
          ..setAttribute('loading', 'lazy');
        frames[type] = frame;
        return frame;
      },
    );
  }

  Future<void> _onMessage(html.MessageEvent event) async {
    if (!mounted || game == null ||
        event.origin != html.window.location.origin ||
        event.data is! String || saving) {
      return;
    }
    final activeFrame = frames[game == 0 ? signalView : defenderView];
    if (activeFrame == null || event.source != activeFrame.contentWindow) {
      return;
    }
    dynamic decoded;
    try {
      decoded = jsonDecode(event.data as String);
    } catch (_) {
      return;
    }
    if (decoded is! Map<String, dynamic> ||
        decoded['type'] != 'genesis-game-score' ||
        decoded['game'] != gameKey ||
        decoded['score'] is! int ||
        decoded['level'] is! int) {
      return;
    }
    final points = decoded['score'] as int;
    final stage = decoded['level'] as int;
    if (points < 1 || points > 10000000 || stage < 1 || stage > 1000) {
      return;
    }
    if (AgcBackend.user == null) {
      return;
    }
    setState(() {
      saving = true;
      scoreNotice = GenesisLanguage.copy(
        'Zapisuję wynik w rankingu…', 'Saving your score…');
    });
    try {
      final updated = await AgcBackend.client.rpc(
        'agc_submit_game_score',
        params: {'p_game_key': gameKey, 'p_score': points, 'p_level': stage},
      );
      if (!mounted) {
        return;
      }
      setState(() => scoreNotice = updated == true
        ? GenesisLanguage.copy(
            'Nowy rekord zapisany w rankingu!', 'New personal best saved!')
        : GenesisLanguage.copy(
            'Wynik zapisany wcześniej lub bez poprawy rekordu.',
            'Your previous personal best still stands.'));
    } on PostgrestException catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => scoreNotice = GenesisLanguage.copy(
        'Nie udało się zapisać wyniku. Sprawdź połączenie.',
        'Could not save score. Check your connection.'));
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => scoreNotice = GenesisLanguage.copy(
        'Nie udało się zapisać wyniku.', 'Could not save score.'));
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  Future<List<Map<String, dynamic>>> _leaders(String key) async {
    final raw = await AgcBackend.client
      .from('agc_game_scores')
      .select('member_id,best_score,best_level,updated_at')
      .eq('game_key', key)
      .order('best_score', ascending: false)
      .order('updated_at', ascending: true)
      .limit(50);
    final rows = List<Map<String, dynamic>>.from(raw);
    if (rows.isEmpty) {
      return rows;
    }
    final ids = rows.map((r) => r['member_id'] as String).toList();
    final members = await AgcBackend.client
      .from('agc_public_scores')
      .select('id,handle')
      .inFilter('id', ids);
    final handles = <String, String>{
      for (final member in members)
        member['id'] as String: member['handle'] as String? ?? 'Genesis',
    };
    return rows.map((r) => {
      ...r,
      'handle': handles[r['member_id']] ?? 'Genesis',
    }).toList();
  }

  void _showRanking(int selectedGame) {
    final key = selectedGame == 0 ? 'signal' : 'defender';
    final title = selectedGame == 0 ? 'GENESIS SIGNAL' : 'GENESIS DEFENDER';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .76,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Column(children: [
                const Icon(Icons.emoji_events_outlined, size: 34,
                  color: Color(0xFFD8B66A)),
                Text(GenesisLanguage.copy(
                  'RANKING GRACZY', 'PLAYER LEADERBOARD'),
                  style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
                Text(title, style: const TextStyle(
                  color: Color(0xFFD8B66A))),
                const SizedBox(height: 6),
                Text(GenesisLanguage.copy(
                  'Najlepszy wynik każdego gracza · niezależnie od GP',
                  'Each player’s best score · separate from GP'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12)),
              ]),
            ),
            Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _leaders(key),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(GenesisLanguage.copy(
                      'Nie udało się pobrać rankingu. Spróbuj ponownie.',
                      'Could not load leaderboard. Please try again.'),
                      textAlign: TextAlign.center)));
                }
                final rows = snapshot.data ?? [];
                if (rows.isEmpty) {
                  return Center(child: Text(GenesisLanguage.copy(
                    'Brak wyników. Zostań pierwszym graczem!',
                    'No scores yet. Be the first player!')));
                }
                return ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    final mine = row['member_id'] == AgcBackend.user?.id;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: mine
                          ? const Color(0xFFD8B66A)
                          : const Color(0xFF19344A),
                        foregroundColor: mine ? Colors.black : Colors.white,
                        child: Text('${index + 1}')),
                      title: Text(
                        '${row['handle']}${mine ? ' ★' : ''}',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(GenesisLanguage.copy(
                        'Poziom / fala: ${row['best_level']}',
                        'Level / wave: ${row['best_level']}')),
                      trailing: Text('${row['best_score']}',
                        style: const TextStyle(
                          color: Color(0xFFD8B66A),
                          fontWeight: FontWeight.bold, fontSize: 17)),
                    );
                  },
                );
              },
            )),
            const SizedBox(height: 12),
          ]),
        ),
      ),
    );
  }

  static const gold = Color(0xFFD8B66A);
  static const navy = Color(0xFF10283C);

  Widget _gameCard({
    required int index,
    required IconData icon,
    required String title,
    required String category,
    required String description,
  }) {
    final accent = index == 0
      ? const Color(0xFF69DFFF) : const Color(0xFFFFB76C);
    final image = index == 0
      ? 'assets/genesis_signal_card.svg'
      : 'assets/genesis_defender_card.svg';
    void openGame() => setState(() {
      game = index;
      scoreNotice = null;
    });
    return Card(
      color: navy,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: accent.withValues(alpha: .55)),
      ),
      child: InkWell(
        onTap: openGame,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(children: [
              SizedBox(
                width: double.infinity,
                height: 188,
                child: SvgPicture.asset(image, fit: BoxFit.cover),
              ),
              Positioned.fill(child: IgnorePointer(
                child: DecoratedBox(decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF061322).withValues(alpha: .06),
                      const Color(0xFF061322).withValues(alpha: .15),
                      const Color(0xFF061322).withValues(alpha: .85),
                    ],
                  ),
                )),
              )),
              Positioned(
                top: 12, left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF071A2B).withValues(alpha: .86),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: accent.withValues(alpha: .6)),
                  ),
                  child: Text(category, style: TextStyle(
                    color: accent, fontSize: 10,
                    fontWeight: FontWeight.w700, letterSpacing: 1.3)),
                ),
              ),
              Positioned(
                top: 12, right: 12,
                child: Icon(icon, color: accent, size: 30),
              ),
              Positioned(
                bottom: 14, left: 16, right: 12,
                child: Text(title, style: const TextStyle(
                  color: Color(0xFFF6F0E5),
                  fontSize: 22, fontWeight: FontWeight.w800,
                  letterSpacing: 1.3,
                  shadows: [Shadow(
                    blurRadius: 12, color: Colors.black)],
                )),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 13, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(description, style: const TextStyle(
                    color: Color(0xFFCEDBE3), height: 1.45)),
                  const SizedBox(height: 15),
                  Row(children: [
                    Expanded(child: FilledButton.icon(
                      onPressed: openGame,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(GenesisLanguage.copy(
                        'ZAGRAJ', 'PLAY')),
                    )),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _showRanking(index),
                      icon: const Icon(
                        Icons.emoji_events_outlined, size: 18),
                      label: Text(GenesisLanguage.copy(
                        'Ranking', 'Leaderboard')),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gameLibrary() => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 840),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          const Center(child: Icon(
            Icons.sports_esports_outlined, size: 42, color: gold)),
          const SizedBox(height: 8),
          const Center(child: Text('GENESIS ARCADE',
            style: TextStyle(
              fontSize: 25, color: gold,
              fontWeight: FontWeight.w700, letterSpacing: 1.5))),
          const SizedBox(height: 8),
          Text(GenesisLanguage.copy(
            'Wybierz grę i rozpocznij misję. Każda gra ma osobny ranking.',
            'Choose a game and start your mission. Each game has its own leaderboard.'),
            textAlign: TextAlign.center),
          const SizedBox(height: 20),
          LayoutBuilder(builder: (context, constraints) {
            final cards = [
              _gameCard(
                index: 0,
                icon: Icons.hub_outlined,
                title: 'GENESIS SIGNAL',
                category: GenesisLanguage.copy(
                  'ŁAMIGŁÓWKA', 'PUZZLE'),
                description: GenesisLanguage.copy(
                  'Obracaj segmenty sieci, połącz sygnał i rozwiązuj coraz trudniejsze plansze.',
                  'Rotate network segments, connect the signal and solve harder puzzles.'),
              ),
              _gameCard(
                index: 1,
                icon: Icons.rocket_launch_outlined,
                title: 'GENESIS DEFENDER',
                category: GenesisLanguage.copy(
                  'STRZELANKA', 'SHOOTER'),
                description: GenesisLanguage.copy(
                  'Broń stacji Genesis przed dronami, przetrwaj fale i pobij rekord.',
                  'Defend the Genesis station, survive waves and beat the high score.'),
              ),
            ];
            if (constraints.maxWidth < 620) {
              return Column(children: [
                cards[0],
                const SizedBox(height: 12),
                cards[1],
              ]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 12),
                Expanded(child: cards[1]),
              ],
            );
          }),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (game == null) {
      return _gameLibrary();
    }
    final selectedGame = game!;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 7, 8, 5),
        child: Row(children: [
          IconButton.filledTonal(
            onPressed: () => setState(() {
              game = null;
              scoreNotice = null;
            }),
            tooltip: GenesisLanguage.copy(
              'Wróć do gier', 'Back to games'),
            icon: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(
            selectedGame == 0 ? 'GENESIS SIGNAL' : 'GENESIS DEFENDER',
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.bold, color: gold, fontSize: 16),
          )),
          IconButton.filledTonal(
            onPressed: () => _showRanking(selectedGame),
            tooltip: GenesisLanguage.copy(
              'Ranking tej gry', 'This game leaderboard'),
            icon: const Icon(Icons.emoji_events_outlined),
          ),
        ]),
      ),
      if (scoreNotice != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(scoreNotice!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: gold, fontSize: 11)),
        ),
      Expanded(child: HtmlElementView(
        key: ValueKey(selectedGame),
        viewType: selectedGame == 0 ? signalView : defenderView,
      )),
    ]);
  }
}
