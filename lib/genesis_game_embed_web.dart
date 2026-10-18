// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

/// Trusted, bundled HTML5 game embedded as a responsive iframe on Flutter Web.
class GenesisGameTab extends StatefulWidget {
  const GenesisGameTab({super.key});

  @override
  State<GenesisGameTab> createState() => _GenesisGameTabState();
}

class _GenesisGameTabState extends State<GenesisGameTab> {
  static const viewType = 'genesis-signal-html5-iframe';
  static bool registered = false;

  @override
  void initState() {
    super.initState();
    if (!registered) {
      ui_web.platformViewRegistry.registerViewFactory(
        viewType,
        (int viewId) => html.IFrameElement()
          ..src = 'genesis-game.html'
          ..title = 'GENESIS SIGNAL — gra THE GENESIS ERA'
          ..style.border = '0'
          ..style.width = '100%'
          ..style.height = '100%'
          ..setAttribute('loading', 'lazy')
          ..setAttribute('allow', 'fullscreen'),
      );
      registered = true;
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand(
    child: HtmlElementView(viewType: viewType),
  );
}
