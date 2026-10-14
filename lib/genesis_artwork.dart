import 'dart:math' as math;
import 'package:flutter/material.dart';

const agcGold = Color(0xFFE3C78C);
const agcNavy = Color(0xFF060C17);

/// Original vector artwork: an eye surrounded by nine orbiting circles.
/// Scales cleanly on Safari, Chrome, Android and iOS without external images.
class GenesisArtwork extends StatelessWidget {
  const GenesisArtwork({super.key, this.size = 270});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size, height: size,
    child: CustomPaint(painter: _GenesisPainter()),
  );
}

class _GenesisPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = w * .43;
    final glow = Paint()
      ..shader = RadialGradient(colors: [
        agcGold.withValues(alpha: .23),
        agcGold.withValues(alpha: .07),
        agcNavy.withValues(alpha: 0),
      ]).createShader(Rect.fromCircle(center: center, radius: w * .5));
    canvas.drawCircle(center, w * .5, glow);

    final rings = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = agcGold.withValues(alpha: .28);
    canvas.drawCircle(center, radius * 1.08, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .5
      ..color = agcGold.withValues(alpha: .17));
    canvas.drawCircle(center, radius * .85, rings);
    canvas.drawCircle(center, radius * .65, rings);
    canvas.drawCircle(center, radius * .44, rings);

    for (var i = 0; i < 9; i++) {
      final t = (i * 2 * math.pi / 9) - math.pi / 2;
      final point = Offset(center.dx + radius * math.cos(t),
        center.dy + radius * math.sin(t));
      canvas.drawCircle(point, w * .027,
        Paint()..color = agcGold.withValues(alpha: .85));
      canvas.drawCircle(point, w * .055,
        Paint()..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = agcGold.withValues(alpha: .25));
    }

    // Fine radial ornaments suggest a handcrafted celestial dial.
    for (var i = 0; i < 72; i++) {
      final angle = (i * 2 * math.pi / 72) - math.pi / 2;
      final inner = radius * (i % 6 == 0 ? .94 : .98);
      final outer = radius * 1.02;
      canvas.drawLine(
        Offset(center.dx + inner * math.cos(angle),
          center.dy + inner * math.sin(angle)),
        Offset(center.dx + outer * math.cos(angle),
          center.dy + outer * math.sin(angle)),
        Paint()..strokeWidth = i % 6 == 0 ? 1.2 : .55
          ..color = agcGold.withValues(alpha: i % 6 == 0 ? .48 : .18));
    }

    final eye = Path()
      ..moveTo(center.dx - w * .23, center.dy)
      ..quadraticBezierTo(center.dx, center.dy - w * .19,
        center.dx + w * .23, center.dy)
      ..quadraticBezierTo(center.dx, center.dy + w * .19,
        center.dx - w * .23, center.dy)
      ..close();
    canvas.drawPath(eye, Paint()..style = PaintingStyle.stroke
      ..strokeWidth = 2.5..color = agcGold);
    canvas.drawCircle(center, w * .085,
      Paint()..color = agcGold.withValues(alpha: .95));
    canvas.drawCircle(center, w * .037, Paint()..color = agcNavy);
    canvas.drawCircle(center.translate(-w * .025, -w * .025),
      w * .014, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
