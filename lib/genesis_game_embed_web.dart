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
  int? rankingGame;
  Future<List<Map<String, dynamic>>>? rankingFuture;
  String? scoreNotice;
  bool saving = false;
  final Map<String, (int, int)> pendingScores = {};

  String get gameKey => game == 0 ? 'signal' : 'defender';

  @override
  void initState() {
    super.initState();
    if (!registered) {
      _register(signalView, 'genesis-game.html?embed=1', 'GENESIS SIGNAL');
      _register(defenderView, 'genesis-defender.html?embed=1', 'GENESIS DEFENDER');
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
        event.data is! String) {
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
      setState(() => scoreNotice = GenesisLanguage.copy(
        'Wynik jest na urządzeniu. Zaloguj się w KONTO, aby trafić do rankingu.',
        'Score saved locally. Sign in under ACCOUNT to join the leaderboard.'));
      return;
    }
    final key = decoded['game'] as String;
    final current = pendingScores[key];
    if (current == null || points > current.$1) {
      pendingScores[key] = (points, stage);
    }
    if (!saving) {
      await _savePendingScores();
    }
  }

  Future<void> _savePendingScores() async {
    if (saving || !mounted || pendingScores.isEmpty) return;
    setState(() {
      saving = true;
      scoreNotice = GenesisLanguage.copy(
        'Zapisuję wynik w rankingu…', 'Saving score to leaderboard…');
    });
    try {
      while (pendingScores.isNotEmpty && mounted) {
        final key = pendingScores.keys.first;
        final (points, stage) = pendingScores.remove(key)!;
        try {
          final updated = await AgcBackend.client.rpc(
            'agc_submit_game_score',
            params: {
              'p_game_key': key,
              'p_score': points,
              'p_level': stage,
            },
          );
          if (!mounted) return;
          setState(() => scoreNotice = updated == true
            ? GenesisLanguage.copy(
                '✓ Wynik zapisany! Sprawdź RANKING 🏆',
                '✓ Score saved! Check the LEADERBOARD 🏆')
            : GenesisLanguage.copy(
                'Wynik przyjęty. Rekord bez zmian.',
                'Score received. Personal best unchanged.'));
        } on PostgrestException catch (error) {
          if (!mounted) return;
          setState(() => scoreNotice = GenesisLanguage.copy(
            'Nie zapisano wyniku: ${error.message}',
            'Score not saved: ${error.message}'));
        } catch (_) {
          if (!mounted) return;
          setState(() => scoreNotice = GenesisLanguage.copy(
            'Nie udało się zapisać wyniku. Spróbuj ponownie.',
            'Could not save score. Please try again.'));
        }
      }
    } finally {
      if (mounted) setState(() => saving = false);
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
    setState(() {
      rankingGame = selectedGame;
      rankingFuture = _leaders(selectedGame == 0 ? 'signal' : 'defender');
    });
  }

  void _closeRanking() {
    setState(() {
      rankingGame = null;
      rankingFuture = null;
    });
  }

  Widget _rankingPage(int selectedGame) {
    final title = selectedGame == 0 ? 'GENESIS SIGNAL' : 'GENESIS DEFENDER';
    return SafeArea(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(children: [
            IconButton.filledTonal(
              onPressed: _closeRanking,
              tooltip: GenesisLanguage.copy('Zamknij ranking', 'Close leaderboard'),
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(GenesisLanguage.copy('RANKING GRACZY', 'PLAYER LEADERBOARD'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(title, style: const TextStyle(color: Color(0xFFD8B66A))),
              ],
            )),
            TextButton.icon(
              onPressed: _closeRanking,
              icon: const Icon(Icons.close),
              label: Text(GenesisLanguage.copy('ZAMKNIJ', 'CLOSE')),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Text(GenesisLanguage.copy(
            'Najlepszy wynik każdego gracza · niezależnie od GP',
            'Each player’s best score · separate from GP'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12)),
        ),
            Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(
              future: rankingFuture,
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
        const SizedBox(height: 8),
      ]),
    );
  }

  static const gold = Color(0xFFD8B66A);

  Widget _arcadeButton({
    required VoidCallback onPressed,
    required bool primary,
    required Color accent,
    required IconData icon,
    required String label,
  }) => Expanded(
    flex: primary ? 5 : 4,
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: primary
          ? LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: accent == const Color(0xFF39CBFF)
                ? [const Color(0xFF20D8FF), const Color(0xFF0079DB),
                   const Color(0xFF003A89)]
                : [const Color(0xFFFFDC79), const Color(0xFFFF9B29),
                   const Color(0xFFB44709)],
            )
          : const LinearGradient(colors: [
              Color(0xFF142B41), Color(0xFF071526),
            ]),
        border: Border.all(
          color: primary ? accent : const Color(0xFF4C7696),
          width: primary ? 1.6 : 1),
        boxShadow: primary ? [
          BoxShadow(
            color: accent.withValues(alpha: .45),
            blurRadius: 17, spreadRadius: 1),
          const BoxShadow(
            color: Color(0x66000000), blurRadius: 12, offset: Offset(0, 4)),
        ] : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(15),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 21,
                    color: primary ? Colors.white
                      : const Color(0xFF9DDCFF)),
                  const SizedBox(width: 6),
                  Flexible(child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: primary ? Colors.white
                        : const Color(0xFF9DDCFF),
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      letterSpacing: .35,
                    ))),
                  const SizedBox(width: 2),
                  Icon(Icons.chevron_right_rounded, size: 18,
                    color: primary ? Colors.white
                      : const Color(0xFF9DDCFF)),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _gameCard({
    required int index,
    required IconData icon,
    required String title,
    required String category,
    required String description,
  }) {
    final signal = index == 0;
    final accent = signal
      ? const Color(0xFF39CBFF) : const Color(0xFFFFB05A);
    final image = signal
      ? 'assets/genesis_signal_card.svg'
      : 'assets/genesis_defender_card.svg';
    final features = signal
      ? <(IconData, String)>[
          (Icons.extension_outlined,
            GenesisLanguage.copy('Kolejne poziomy', 'Progressive levels')),
          (Icons.leaderboard_outlined,
            GenesisLanguage.copy('Ranking graczy', 'Player leaderboard')),
          (Icons.lightbulb_outline,
            GenesisLanguage.copy('Wskazówki', 'Hints')),
          (Icons.emoji_events_outlined,
            GenesisLanguage.copy('Pobij swój rekord', 'Beat your high score')),
        ]
      : <(IconData, String)>[
          (Icons.rocket_launch_outlined,
            GenesisLanguage.copy(
              'Lot w czterech kierunkach', 'Full directional flight')),
          (Icons.my_location_outlined,
            GenesisLanguage.copy('Kolejne fale dronów', 'Enemy drone waves')),
          (Icons.leaderboard_outlined,
            GenesisLanguage.copy('Ranking graczy', 'Player leaderboard')),
          (Icons.shield_outlined,
            GenesisLanguage.copy('Tarcze i naprawy', 'Shields and repairs')),
        ];
    void openGame() => setState(() {
      game = index;
      scoreNotice = null;
    });
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF071525),
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: accent.withValues(alpha: .9), width: 1.3),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: .18),
            blurRadius: 20, spreadRadius: -2),
          const BoxShadow(
            color: Color(0x99000000), blurRadius: 24,
            offset: Offset(0, 10)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: openGame,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(children: [
                SizedBox(
                  height: 235, width: double.infinity,
                  child: SvgPicture.asset(image, fit: BoxFit.cover),
                ),
                Positioned.fill(child: IgnorePointer(
                  child: DecoratedBox(decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0, .44, 1],
                      colors: [
                        const Color(0xFF041020).withValues(alpha: .15),
                        const Color(0xFF041020).withValues(alpha: .10),
                        const Color(0xFF041020),
                      ],
                    ),
                  )),
                )),
                Positioned(
                  top: 18, left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF071525)
                        .withValues(alpha: .84),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: accent.withValues(alpha: .8)),
                    ),
                    child: Text(category, style: TextStyle(
                      color: accent, fontSize: 11,
                      fontWeight: FontWeight.w700, letterSpacing: 1.1)),
                  ),
                ),
                Positioned(
                  bottom: 10, left: 16, right: 16,
                  child: Text(title, textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white, fontSize: 25,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.8,
                      shadows: [Shadow(
                        blurRadius: 14, color: Colors.black)],
                    )),
                ),
              ]),
              Padding(
                padding: const EdgeInsets.fromLTRB(17, 5, 17, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (featureIcon, featureText) in features)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(children: [
                          Icon(featureIcon, color: accent, size: 20),
                          const SizedBox(width: 12),
                          Expanded(child: Text(featureText,
                            style: const TextStyle(
                              color: Color(0xFFD5E5F1), fontSize: 13))),
                        ]),
                      ),
                    const SizedBox(height: 8),
                    Row(children: [
                      _arcadeButton(
                        onPressed: openGame,
                        primary: true,
                        accent: accent,
                        icon: Icons.play_arrow_rounded,
                        label: GenesisLanguage.copy('ZAGRAJ', 'PLAY'),
                      ),
                      const SizedBox(width: 10),
                      _arcadeButton(
                        onPressed: () => _showRanking(index),
                        primary: false,
                        accent: accent,
                        icon: Icons.emoji_events_outlined,
                        label: GenesisLanguage.copy('RANKING', 'RANKING'),
                      ),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gameLibrary() => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1050),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        children: [
          const Center(child: Icon(
            Icons.sports_esports_outlined, size: 42, color: gold)),
          const SizedBox(height: 8),
          const Center(child: Text('GRA',
            style: TextStyle(
              fontSize: 25, color: gold,
              fontWeight: FontWeight.w700, letterSpacing: 1.5))),
          const SizedBox(height: 8),
          Text(GenesisLanguage.copy(
            'WYBIERZ GRĘ I ODKRYWAJ NOWE WYZWANIA',
            'CHOOSE A GAME AND DISCOVER NEW CHALLENGES'),
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
            if (constraints.maxWidth < 700) {
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
    if (rankingGame != null) {
      return _rankingPage(rankingGame!);
    }
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
      if (AgcBackend.user == null)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 5),
          child: Text(GenesisLanguage.copy(
            '⚠ Zaloguj się w KONTO, aby zapisywać punkty w rankingu.',
            '⚠ Sign in under ACCOUNT to save scores to the leaderboard.'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFFFC777), fontSize: 12)),
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
