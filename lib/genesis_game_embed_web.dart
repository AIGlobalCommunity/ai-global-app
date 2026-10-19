// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

/// Both self-contained HTML5 games are served from the same origin.
class GenesisGameTab extends StatefulWidget {
  const GenesisGameTab({super.key});

  @override
  State<GenesisGameTab> createState() => _GenesisGameTabState();
}

class _GenesisGameTabState extends State<GenesisGameTab> {
  static bool registered = false;
  static const signalView = 'genesis-signal-html5-iframe';
  static const defenderView = 'genesis-defender-html5-iframe';
  int game = 0;

  @override
  void initState() {
    super.initState();
    if (!registered) {
      _register(signalView, 'genesis-game.html', 'GENESIS SIGNAL');
      _register(defenderView, 'genesis-defender.html', 'GENESIS DEFENDER');
      registered = true;
    }
  }

  static void _register(String type, String src, String title) {
    ui_web.platformViewRegistry.registerViewFactory(
      type,
      (int viewId) => html.IFrameElement()
        ..src = src
        ..title = title
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..setAttribute('loading', 'lazy')
        ..setAttribute('allow', 'fullscreen'),
    );
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      child: Row(children: [
        Expanded(child: _choice(0, Icons.hub_outlined, 'SIGNAL')),
        const SizedBox(width: 8),
        Expanded(child: _choice(1, Icons.rocket_launch_outlined, 'DEFENDER')),
      ]),
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
          onPressed: () {},
          icon: Icon(icon, size: 18),
          label: Text(label),
        )
      : OutlinedButton.icon(
          onPressed: () => setState(() => game = index),
          icon: Icon(icon, size: 18),
          label: Text(label),
        );
  }
}
