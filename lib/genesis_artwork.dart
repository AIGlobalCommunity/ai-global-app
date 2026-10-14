import 'package:flutter/material.dart';

const agcGold = Color(0xFFE3C78C);
const agcNavy = Color(0xFF060C17);

/// Resolution-independent celestial frame around the bundled AGC emblem.
/// The small PNG is deliberately displayed at a modest size to avoid blur;
/// the gold orbits and stars are painted crisply at any device pixel ratio.
class GenesisArtwork extends StatelessWidget {
  const GenesisArtwork({super.key, this.size = 270});
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'AI Global Community — złoty symbol Genesis i kosmiczne orbity',
    image: true,
    child: SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: const _GenesisOrbitPainter(),
        child: Center(
          child: Container(
            width: size * .64,
            height: size * .64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(
                color: agcGold.withValues(alpha: .12),
                blurRadius: 32,
                spreadRadius: 5,
              )],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/agc_genesis_luxury.png',
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                excludeFromSemantics: true,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _GenesisOrbitPainter extends CustomPainter {
  const _GenesisOrbitPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * .47;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .9
      ..color = agcGold.withValues(alpha: .55);
    for (final fraction in [.72, .84, 1.0]) {
      canvas.drawCircle(center, radius * fraction, ring);
    }
    for (var i = 0; i < 8; i++) {
      final angle = i * 3.141592653589793 / 4;
      final x = center.dx + radius * .92 * _cos(angle);
      final y = center.dy + radius * .92 * _sin(angle);
      canvas.drawCircle(Offset(x, y), size.width * .019,
        Paint()..color = agcGold.withValues(alpha: .9));
      canvas.drawCircle(Offset(x, y), size.width * .028,
        Paint()..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = agcGold.withValues(alpha: .45));
    }
    final star = Paint()
      ..color = agcGold.withValues(alpha: .7)
      ..strokeWidth = 1;
    for (final point in [
      Offset(center.dx, center.dy - radius * 1.04),
      Offset(center.dx, center.dy + radius * 1.04),
    ]) {
      canvas.drawLine(point.translate(-9, 0), point.translate(9, 0), star);
      canvas.drawLine(point.translate(0, -9), point.translate(0, 9), star);
    }
  }

  // Eight fixed compass points avoid trigonometric dependencies at runtime.
  double _cos(double a) {
    const values = [1.0, .70710678, 0.0, -.70710678,
      -1.0, -.70710678, 0.0, .70710678];
    return values[((a / (3.141592653589793 / 4)).round()) % 8];
  }

  double _sin(double a) {
    const values = [0.0, .70710678, 1.0, .70710678,
      0.0, -.70710678, -1.0, -.70710678];
    return values[((a / (3.141592653589793 / 4)).round()) % 8];
  }

  @override
  bool shouldRepaint(covariant _GenesisOrbitPainter oldDelegate) => false;
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
