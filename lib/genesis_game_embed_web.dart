// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
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
  int game = 0;
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
    if (!mounted || event.origin != html.window.location.origin ||
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

  void _showRanking() {
    final key = gameKey;
    final title = game == 0 ? 'GENESIS SIGNAL' : 'GENESIS DEFENDER';
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

  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 5),
      child: Row(children: [
        Expanded(child: _choice(0, Icons.hub_outlined, 'SIGNAL')),
        const SizedBox(width: 6),
        Expanded(child: _choice(1, Icons.rocket_launch_outlined, 'DEFENDER')),
        const SizedBox(width: 6),
        IconButton.filledTonal(
          onPressed: _showRanking,
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
          style: const TextStyle(
            color: Color(0xFFD8B66A), fontSize: 11)),
      ),
    Expanded(child: HtmlElementView(
      key: ValueKey(game),
      viewType: game == 0 ? signalView : defenderView,
    )),
  ]);

  Widget _choice(int index, IconData icon, String label) {
    final active = game == index;
    return active
      ? FilledButton.icon(
          onPressed: null,
          icon: Icon(icon, size: 17),
          label: Text(label),
        )
      : OutlinedButton.icon(
          onPressed: () => setState(() {
            game = index;
            scoreNotice = null;
          }),
          icon: Icon(icon, size: 17),
          label: Text(label),
        );
  }
}
