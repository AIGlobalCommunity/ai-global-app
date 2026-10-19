import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Native fallback: both HTML5 games open in the device browser.
class GenesisGameTab extends StatelessWidget {
  const GenesisGameTab({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.sports_esports_outlined, size: 56),
        const SizedBox(height: 14),
        const Text('GENESIS GAMES',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        const Text('Wybierz grę HTML5. Otworzy się w przeglądarce.',
          textAlign: TextAlign.center),
        const SizedBox(height: 22),
        FilledButton.icon(
          icon: const Icon(Icons.hub_outlined),
          label: const Text('GENESIS SIGNAL · Łamigłówka'),
          onPressed: () => _open('genesis-game.html'),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          icon: const Icon(Icons.rocket_launch_outlined),
          label: const Text('GENESIS DEFENDER · Strzelanka'),
          onPressed: () => _open('genesis-defender.html'),
        ),
      ]),
    ),
  );

  Future<void> _open(String game) async {
    await launchUrl(
      Uri.parse('https://thegenesisera.com/$game'),
      mode: LaunchMode.externalApplication,
    );
  }
}
