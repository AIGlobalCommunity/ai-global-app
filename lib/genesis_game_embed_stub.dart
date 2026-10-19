import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

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
          const Center(child: Text('GENESIS ARCADE',
            style: TextStyle(fontSize: 24, color: gold,
              fontWeight: FontWeight.bold))),
          const SizedBox(height: 10),
          const Center(child: Text(
            'Wybierz grę. Otworzy się w przeglądarce.')),
          const SizedBox(height: 20),
          _card(
            icon: Icons.hub_outlined,
            title: 'GENESIS SIGNAL',
            description: 'Łamigłówka: połącz źródło sygnału z celem.',
            file: 'genesis-game.html',
            artwork: 'assets/genesis_signal_card.svg',
          ),
          const SizedBox(height: 12),
          _card(
            icon: Icons.rocket_launch_outlined,
            title: 'GENESIS DEFENDER',
            description: 'Strzelanka: broń stacji przed falami dronów.',
            file: 'genesis-defender.html',
            artwork: 'assets/genesis_defender_card.svg',
          ),
        ],
      ),
    ),
  );

  Widget _card({
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
            child: Stack(children: [
              SizedBox(
                width: double.infinity, height: 215,
                child: SvgPicture.asset(artwork, fit: BoxFit.cover),
              ),
              Positioned(
                bottom: 12, left: 12, right: 12,
                child: Text(title, textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 23, fontWeight: FontWeight.w900,
                    letterSpacing: 1.2, color: Colors.white,
                    shadows: [Shadow(
                      color: Colors.black, blurRadius: 15)])),
              ),
            ]),
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
                  onTap: () => _rankingUnavailable(),
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

  void _rankingUnavailable() {
    // Native games currently open externally; score submission is web-only.
  }

  Future<void> _open(String file) async {
    await launchUrl(
      Uri.parse('https://thegenesisera.com/$file'),
      mode: LaunchMode.externalApplication,
    );
  }
}
