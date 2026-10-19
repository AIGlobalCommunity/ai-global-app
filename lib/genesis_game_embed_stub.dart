import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'agc_backend.dart';

/// Native fallback: game cards open the HTML5 games in the browser.
class GenesisGameTab extends StatelessWidget {
  const GenesisGameTab({super.key});

  static const gold = Color(0xFFD8B66A);

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
        children: [
          const Center(child: Icon(
            Icons.sports_esports_outlined, color: gold, size: 44)),
          const SizedBox(height: 10),
          const Center(child: Text('GRA',
            style: TextStyle(fontSize: 24, color: gold,
              fontWeight: FontWeight.bold))),
          const SizedBox(height: 10),
          const Center(child: Text(
            'WYBIERZ GRĘ I ODKRYWAJ NOWE WYZWANIA')),
          const SizedBox(height: 5),
          const Center(child: Text(
            'Gry otwierają się w przeglądarce.',
            style: TextStyle(fontSize: 11))),
          const SizedBox(height: 20),
          _card(
            context: context,
            icon: Icons.hub_outlined,
            title: 'GENESIS SIGNAL',
            description: 'Łamigłówka: połącz źródło sygnału z celem.',
            file: 'genesis-game.html',
            artwork: 'assets/genesis_signal_cinematic.jpg',
          ),
          const SizedBox(height: 12),
          _card(
            context: context,
            icon: Icons.rocket_launch_outlined,
            title: 'GENESIS DEFENDER',
            description: 'Strzelanka: broń stacji przed falami dronów.',
            file: 'genesis-defender.html',
            artwork: 'assets/genesis_defender_cinematic.jpg',
          ),
        ],
      ),
    ),
  );

  Widget _card({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required String file,
    required String artwork,
  }) {
    final signal = file == 'genesis-game.html';
    final accent = signal
      ? const Color(0xFF39CBFF) : const Color(0xFFFFB05A);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF071525),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent, width: 1.2),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: .22),
            blurRadius: 18),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => _open(file),
            child: SizedBox(
              width: double.infinity, height: 215,
              child: Image.asset(artwork, fit: BoxFit.cover,
                filterQuality: FilterQuality.high, semanticLabel: title),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Row(children: [
                Icon(icon, color: accent, size: 21),
                const SizedBox(width: 9),
                Expanded(child: Text(description,
                  style: const TextStyle(
                    color: Color(0xFFDFEAF2)))),
              ]),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: _button(
                  label: 'ZAGRAJ',
                  icon: Icons.play_arrow_rounded,
                  accent: accent,
                  primary: true,
                  onTap: () => _open(file),
                )),
                const SizedBox(width: 10),
                Expanded(child: _button(
                  label: 'RANKING',
                  icon: Icons.emoji_events_outlined,
                  accent: accent,
                  primary: false,
                  onTap: () => _showRanking(context, file),
                )),
              ]),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _button({
    required String label,
    required IconData icon,
    required Color accent,
    required bool primary,
    required VoidCallback onTap,
  }) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: primary
          ? (accent == const Color(0xFF39CBFF)
            ? [const Color(0xFF21D9FF), const Color(0xFF0076D8)]
            : [const Color(0xFFFFD677), const Color(0xFFDA6A10)])
          : [const Color(0xFF173047), const Color(0xFF071626)],
      ),
      border: Border.all(
        color: primary ? accent : const Color(0xFF547998)),
      boxShadow: primary
        ? [BoxShadow(color: accent.withValues(alpha: .38),
            blurRadius: 14)]
        : null,
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 55),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 5),
              Flexible(child: Text(label,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold))),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _showRanking(
    BuildContext context, String file,
  ) async {
    final key = file == 'genesis-game.html' ? 'signal' : 'defender';
    final title = key == 'signal' ? 'GENESIS SIGNAL' : 'GENESIS DEFENDER';
    Future<List<Map<String, dynamic>>> load() async {
      final raw = await AgcBackend.client
        .from('agc_game_scores')
        .select('member_id,best_score,best_level,updated_at')
        .eq('game_key', key)
        .order('best_score', ascending: false)
        .order('updated_at', ascending: true)
        .limit(50);
      final scores = List<Map<String, dynamic>>.from(raw);
      if (scores.isEmpty) {
        return scores;
      }
      final ids = scores.map((e) => e['member_id'] as String).toList();
      final members = await AgcBackend.client
        .from('agc_public_scores')
        .select('id,handle')
        .inFilter('id', ids);
      final names = <String, String>{
        for (final m in members)
          m['id'] as String: m['handle'] as String? ?? 'Genesis',
      };
      return scores.map((e) => {
        ...e,
        'handle': names[e['member_id']] ?? 'Genesis',
      }).toList();
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .7,
        child: Column(children: [
          const Icon(Icons.emoji_events_outlined, color: gold, size: 32),
          const SizedBox(height: 5),
          Text('RANKING · $title', style: const TextStyle(
            fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 12),
          Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(
            future: load(),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const Center(child: Text(
                  'Nie udało się pobrać rankingu.'));
              }
              final rows = snapshot.data ?? [];
              if (rows.isEmpty) {
                return const Center(child: Text(
                  'Brak wyników. Zostań pierwszym graczem!'));
              }
              return ListView.builder(
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final row = rows[index];
                  return ListTile(
                    leading: CircleAvatar(child: Text('${index + 1}')),
                    title: Text('${row['handle']}'),
                    subtitle: Text('Poziom / fala: ${row['best_level']}'),
                    trailing: Text('${row['best_score']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold, color: gold)),
                  );
                },
              );
            },
          )),
        ]),
      )),
    );
  }

  Future<void> _open(String file) async {
    await launchUrl(
      Uri.parse('https://thegenesisera.com/$file'),
      mode: LaunchMode.externalApplication,
    );
  }
}
