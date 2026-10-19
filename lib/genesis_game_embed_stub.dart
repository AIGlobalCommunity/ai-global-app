import 'package:flutter/material.dart';
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
          ),
          const SizedBox(height: 12),
          _card(
            icon: Icons.rocket_launch_outlined,
            title: 'GENESIS DEFENDER',
            description: 'Strzelanka: broń stacji przed falami dronów.',
            file: 'genesis-defender.html',
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
  }) => Card(
    color: const Color(0xFF10283C),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => _open(file),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 40, color: gold),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(
              fontSize: 21, fontWeight: FontWeight.bold, color: gold)),
            const SizedBox(height: 8),
            Text(description),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _open(file),
              icon: const Icon(Icons.play_arrow),
              label: const Text('ZAGRAJ'),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _open(String file) async {
    await launchUrl(
      Uri.parse('https://thegenesisera.com/$file'),
      mode: LaunchMode.externalApplication,
    );
  }
}
