import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const agcGold = Color(0xFFE3C78C);
const agcNavy = Color(0xFF060C17);

/// True vector Genesis emblem with eight AI artifact medallions.
/// The SVG has a transparent background and stays sharp on Retina/4K screens.
class GenesisArtwork extends StatelessWidget {
  const GenesisArtwork({super.key, this.size = 270});
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Genesis — złote oko AI z ośmioma artefaktami: sztuczna inteligencja, wiedza, Ziemia, galaktyka, społeczność i rozwój',
    image: true,
    child: SizedBox.square(
      dimension: size,
      child: SvgPicture.asset(
        'assets/agc_genesis_ai_vector.svg',
        fit: BoxFit.contain,
        excludeFromSemantics: true,
        errorBuilder: (context, error, stackTrace) =>
            const Center(child: Icon(Icons.auto_awesome,
              color: agcGold, size: 64)),
      ),
    ),
  );
}

class GenesisPanel extends StatelessWidget {
  const GenesisPanel({super.key, required this.title, required this.body,
    required this.icon});
  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final narrow = constraints.maxWidth < 430;
      final iconBox = Container(
        padding: EdgeInsets.all(narrow ? 8 : 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: agcGold.withValues(alpha: .35)),
          color: agcGold.withValues(alpha: .07)),
        child: Icon(icon, color: agcGold, size: narrow ? 20 : 24),
      );
      final heading = Text(title, softWrap: true,
        style: TextStyle(color: agcGold,
          letterSpacing: narrow ? .5 : 1.1,
          fontWeight: FontWeight.w700, fontSize: narrow ? 12 : 13));
      final content = Text(body, softWrap: true,
        style: const TextStyle(height: 1.5,
          color: Color(0xFFE3E5EA)));
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [
            Color(0xFF203249), Color(0xFF101D30), Color(0xFF0B1424),
          ], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: agcGold.withValues(alpha: .33), width: .8),
        ),
        child: Padding(
          padding: EdgeInsets.all(narrow ? 14 : 20),
          child: narrow
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  iconBox,
                  const SizedBox(width: 10),
                  Expanded(child: heading),
                ]),
                const SizedBox(height: 12),
                content,
              ])
            : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                iconBox,
                const SizedBox(width: 16),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                    heading,
                    const SizedBox(height: 8),
                    content,
                  ])),
              ]),
        ),
      );
    },
  );
}
