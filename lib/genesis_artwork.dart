import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';

const agcGold = Color(0xFFE3C78C);
const agcNavy = Color(0xFF060C17);

/// Original vector artwork: an eye surrounded by nine orbiting circles.
/// Scales cleanly on Safari, Chrome, Android and iOS without external images.
class GenesisArtwork extends StatelessWidget {
  const GenesisArtwork({super.key, this.size = 270});
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Nowe logo AI Global Community: złote oko Genesis, dziewięć orbit i gwiazda',
    image: true,
    child: SvgPicture.asset(
      'assets/agc_genesis_luxury.svg',
      width: size,
      height: size,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
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
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [
        Color(0xFF203249), Color(0xFF101D30), Color(0xFF0B1424),
      ], begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: agcGold.withValues(alpha: .33), width: .8),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .18),
        blurRadius: 20, offset: const Offset(0, 9))],
    ),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: agcGold.withValues(alpha: .35)),
            color: agcGold.withValues(alpha: .07)),
          child: Icon(icon, color: agcGold),
        ),
        const SizedBox(width: 17),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: agcGold,
              letterSpacing: 1.5, fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 8),
            Text(body, style: const TextStyle(height: 1.6,
              color: Color(0xFFE3E5EA))),
          ])),
      ]),
    ),
  );
}
