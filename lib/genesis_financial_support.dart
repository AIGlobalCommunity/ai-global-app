import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'genesis_language.dart';

/// A fixed, single-screen mosaic with exactly 1,000 visible demo places.
/// No payment, reservation or sponsor data is represented as real.
class GenesisFinancialSupport extends StatefulWidget {
  const GenesisFinancialSupport({super.key, this.preview = false});
  final bool preview;

  @override
  State<GenesisFinancialSupport> createState() => _GenesisFinancialSupportState();
}

class _GenesisFinancialSupportState extends State<GenesisFinancialSupport> {
  static const int capacity = 1000;
  static const Color gold = Color(0xFFD8B66A);

  // The first 100 IDs stay in fixed positions; the rest are shuffled
  // once per view, separately within their support tiers.
  late final List<int> displayedIds = _createDisplayOrder();

  List<int> _createDisplayOrder() {
    final ids = List<int>.generate(capacity, (i) => i);
    final random = math.Random();
    final partners = ids.sublist(100, 200)..shuffle(random);
    final friends = ids.sublist(200)..shuffle(random);
    ids.setRange(100, 200, partners);
    ids.setRange(200, capacity, friends);
    return ids;
  }

  // Illustrative support amounts. The first spaces are proportionally larger.
  double amount(int i) {
    if (i < 20) return 5000;
    if (i < 200) return 1000;
    return 200;
  }

  List<Rect> layout(Size size) {
    final result = List<Rect>.filled(capacity, Rect.zero);
    void partition(int first, int end, Rect rect) {
      if (end - first == 1) {
        result[first] = rect;
        return;
      }
      final total = _weight(first, end);
      final target = total / 2;
      var midpoint = first + 1;
      var subtotal = amount(first);
      while (midpoint < end - 1 &&
          subtotal + amount(midpoint) <= target) {
        subtotal += amount(midpoint);
        midpoint++;
      }
      final ratio = subtotal / total;
      if (rect.width >= rect.height) {
        final split = rect.left + rect.width * ratio;
        partition(first, midpoint,
          Rect.fromLTRB(rect.left, rect.top, split, rect.bottom));
        partition(midpoint, end,
          Rect.fromLTRB(split, rect.top, rect.right, rect.bottom));
      } else {
        final split = rect.top + rect.height * ratio;
        partition(first, midpoint,
          Rect.fromLTRB(rect.left, rect.top, rect.right, split));
        partition(midpoint, end,
          Rect.fromLTRB(rect.left, split, rect.right, rect.bottom));
      }
    }
    partition(0, capacity, Offset.zero & size);
    return result;
  }

  double _weight(int first, int end) {
    double sum = 0;
    for (var i = first; i < end; i++) {
      sum += amount(i);
    }
    return sum;
  }

  void showSpace(int i) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(GenesisLanguage.copy(
          'Miejsce #${i + 1}', 'Space #${i + 1}')),
        content: Text(GenesisLanguage.copy(
          'Przykładowe miejsce na ścianie fundatorów. '
          'Sugerowany poziom wsparcia: ${amount(i).toInt()} zł. '
          'Wpłaty i rezerwacje nie są jeszcze dostępne.',
          'Example founders wall space. Suggested support tier: '
          '${amount(i).toInt()} PLN. Payments and reservations '
          'are not yet available.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(GenesisLanguage.copy('Zamknij', 'Close')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final width = bounds.maxWidth.isFinite ? bounds.maxWidth : 700.0;
      final height = bounds.maxHeight.isFinite ? bounds.maxHeight : 700.0;
      final compact = height < 440;
      final headerHeight = compact ? 58.0 : 90.0;
      return SizedBox(
        width: width,
        height: height,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(children: [
            SizedBox(height: headerHeight, child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(fit: BoxFit.scaleDown, child: Text(
                  GenesisLanguage.copy('ŚCIANA FUNDATORÓW GENESIS',
                    'GENESIS FOUNDERS WALL'),
                  style: TextStyle(color: gold, fontWeight: FontWeight.bold,
                    fontSize: compact ? 17 : 22))),
                const SizedBox(height: 4),
                Text(GenesisLanguage.copy(
                  '1000 miejsc • TOP 100 na stałe • 900 losowo',
                  '1000 spaces • TOP 100 fixed • 900 shuffled'),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11)),
                if (!compact) const Text(
                  'DEMO • 0 / 1000', style: TextStyle(
                    color: Colors.white70, fontSize: 11)),
              ],
            )),
            const SizedBox(height: 6),
            Expanded(child: LayoutBuilder(builder: (context, mosaicBounds) {
              final size = Size(
                math.max(1, mosaicBounds.maxWidth),
                math.max(1, mosaicBounds.maxHeight));
              final tiles = layout(size);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) {
                  final position = details.localPosition;
                  for (var i = 0; i < tiles.length; i++) {
                    if (tiles[i].contains(position)) {
                      showSpace(displayedIds[i]);
                      break;
                    }
                  }
                },
                child: CustomPaint(
                  size: size,
                  painter: _FounderWallPainter(tiles, displayedIds),
                ),
              );
            })),
            const SizedBox(height: 5),
            Text(GenesisLanguage.copy(
              'Wizualizacja: wszystkie 1000 pól jest wolnych. '
              'Brak aktywnych wpłat i rezerwacji.',
              'Preview: all 1000 spaces are available. '
              'No payments or reservations are active.'),
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 9, color: Colors.white70)),
          ]),
        ),
      );
    },
  );
}

class _FounderWallPainter extends CustomPainter {
  _FounderWallPainter(this.tiles, this.displayedIds);
  final List<Rect> tiles;
  final List<int> displayedIds;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..style = PaintingStyle.fill;
    final border = Paint()
      ..color = const Color(0xFF8A7142)
      ..strokeWidth = .65
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < tiles.length; i++) {
      final r = tiles[i].deflate(.45);
      fill.color = i < 20
          ? const Color(0xFF6A512B)
          : i < 200
              ? const Color(0xFF254663)
              : const Color(0xFF172B40);
      canvas.drawRect(r, fill);
      canvas.drawRect(r, border);
      if (r.width >= 22 && r.height >= 11) {
        final label = TextPainter(
          text: TextSpan(
            text: '#${displayedIds[i] + 1}',
            style: TextStyle(
              color: i < 20
                  ? const Color(0xFFFFDF91)
                  : const Color(0xFFB8C8D6),
              fontSize: math.min(12, math.min(r.width / 4, r.height / 2)),
              fontWeight: FontWeight.w600)),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout(maxWidth: r.width - 3);
        label.paint(canvas, Offset(
          r.left + (r.width - label.width) / 2,
          r.top + (r.height - label.height) / 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FounderWallPainter oldDelegate) =>
      oldDelegate.tiles != tiles;
}
