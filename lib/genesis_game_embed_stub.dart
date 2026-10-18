import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Fallback for Android/iOS builds; the HTML5 game runs in the browser.
class GenesisGameTab extends StatelessWidget {
  const GenesisGameTab({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.extension_outlined, size: 56),
        const SizedBox(height: 14),
        const Text('GENESIS SIGNAL',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        const Text('Gra HTML5 jest dostępna w wersji przeglądarkowej.',
          textAlign: TextAlign.center),
        const SizedBox(height: 18),
        FilledButton.icon(
          icon: const Icon(Icons.open_in_browser),
          label: const Text('Otwórz grę w przeglądarce'),
          onPressed: () => launchUrl(
            Uri.parse('https://thegenesisera.com/genesis-game.html'),
            mode: LaunchMode.externalApplication),
        ),
      ]),
    ),
  );
}
