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
    final c = Offset(w / 2, size.height / 2);
    final radius = w * .405;

    Offset at(double r, double theta) =>
      Offset(c.dx + r * math.cos(theta), c.dy + r * math.sin(theta));

    void ring(double r, double alpha, [double width = 1]) {
      canvas.drawCircle(c, r, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = agcGold.withValues(alpha: alpha));
    }

    final halo = Paint()..shader = RadialGradient(
      colors: [
        agcGold.withValues(alpha: .19),
        const Color(0xFF81683C).withValues(alpha: .085),
        agcNavy.withValues(alpha: 0),
      ], stops: const [0, .43, 1],
    ).createShader(Rect.fromCircle(center: c, radius: w * .49));
    canvas.drawCircle(c, w * .49, halo);

    ring(radius * 1.13, .27, .8);
    ring(radius * 1.045, .38, 1.2);
    ring(radius * .96, .23);
    ring(radius * .72, .26);
    ring(radius * .46, .22);

    // Fine watchmaking-inspired engravings.
    for (var i = 0; i < 120; i++) {
      final theta = 2 * math.pi * i / 120 - math.pi / 2;
      final major = i % 10 == 0;
      canvas.drawLine(
        at(radius * (major ? 1.055 : 1.083), theta),
        at(radius * 1.115, theta),
        Paint()..strokeWidth = major ? 1.05 : .45
          ..color = agcGold.withValues(alpha: major ? .7 : .24));
    }

    // Symmetric celestial cross, visually subordinate to the eye.
    for (var k = 0; k < 4; k++) {
      final theta = math.pi * k / 2;
      canvas.drawLine(at(radius * .8, theta), at(radius * 1.21, theta),
        Paint()..strokeWidth = .65
          ..color = agcGold.withValues(alpha: .43));
      final tip = at(radius * 1.215, theta);
      final diamond = Path()
        ..moveTo(tip.dx + math.cos(theta) * w * .031,
          tip.dy + math.sin(theta) * w * .031)
        ..lineTo(tip.dx - math.sin(theta) * w * .011,
          tip.dy + math.cos(theta) * w * .011)
        ..lineTo(tip.dx - math.cos(theta) * w * .031,
          tip.dy - math.sin(theta) * w * .031)
        ..lineTo(tip.dx + math.sin(theta) * w * .011,
          tip.dy - math.cos(theta) * w * .011)
        ..close();
      canvas.drawPath(diamond, Paint()
        ..color = agcGold.withValues(alpha: .76));
    }

    // Nine founder-orbit medallions, each with a polished gold core.
    for (var i = 0; i < 9; i++) {
      final theta = 2 * math.pi * i / 9 - math.pi / 2;
      final p = at(radius * .89, theta);
      final medallion = w * .047;
      canvas.drawCircle(p, medallion * 1.46, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8
        ..color = agcGold.withValues(alpha: .43));
      canvas.drawCircle(p, medallion * 1.15, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = agcGold.withValues(alpha: .72));
      canvas.drawCircle(p, medallion,
        Paint()..shader = RadialGradient(
          center: const Alignment(-.42, -.52),
          colors: [
            const Color(0xFFFFE8AE),
            agcGold,
            const Color(0xFF87602D),
          ],
        ).createShader(Rect.fromCircle(center: p, radius: medallion)));
      canvas.drawCircle(p.translate(medallion * -.25, medallion * -.24),
        medallion * .20, Paint()
          ..color = Colors.white.withValues(alpha: .64));
    }

    // Eye silhouette: layered metalwork rather than a flat icon.
    Path eye(double scale) => Path()
      ..moveTo(c.dx - w * .28 * scale, c.dy)
      ..cubicTo(c.dx - w * .115 * scale, c.dy - w * .172 * scale,
        c.dx + w * .115 * scale, c.dy - w * .172 * scale,
        c.dx + w * .28 * scale, c.dy)
      ..cubicTo(c.dx + w * .115 * scale, c.dy + w * .172 * scale,
        c.dx - w * .115 * scale, c.dy + w * .172 * scale,
        c.dx - w * .28 * scale, c.dy)
      ..close();

    canvas.drawPath(eye(1.035), Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * .032
      ..color = const Color(0xFF765226).withValues(alpha: .84));
    canvas.drawPath(eye(1), Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * .014
      ..color = agcGold);
    canvas.drawPath(eye(.98), Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = const Color(0xFFFFF0CA).withValues(alpha: .94));

    canvas.drawCircle(c, w * .10,
      Paint()..color = const Color(0xFF4C3518));
    canvas.drawCircle(c, w * .093, Paint()
      ..shader = RadialGradient(colors: [
        const Color(0xFFFFF1C7),
        agcGold,
        const Color(0xFF845521),
        const Color(0xFF0B1120),
      ], stops: const [0, .28, .7, 1])
        .createShader(Rect.fromCircle(center: c, radius: w * .093)));
    ring(w * .112, .74, 1);
    ring(w * .068, .75, 1);

    // Eight-pointed star is the luminous pupil of the emblem.
    final star = Path();
    for (var i = 0; i < 16; i++) {
      final theta = i * math.pi / 8 - math.pi / 2;
      final r = i.isEven ? w * .076 : w * .013;
      final point = at(r, theta);
      if (i == 0) {
        star.moveTo(point.dx, point.dy);
      } else {
        star.lineTo(point.dx, point.dy);
      }
    }
    star.close();
    canvas.drawPath(star, Paint()
      ..color = const Color(0xFFFFF3D1));
    canvas.drawCircle(c, w * .014, Paint()..color = Colors.white);
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
