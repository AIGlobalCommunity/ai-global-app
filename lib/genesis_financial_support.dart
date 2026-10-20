import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'genesis_language.dart';
import 'agc_backend.dart';
import 'genesis_founder_directory.dart';
import 'genesis_founder_account.dart';

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
  List<Map<String, dynamic>> founders = const [];

  @override
  void initState() {
    super.initState();
    _loadFounders();
  }

  Future<void> _loadFounders() async {
    if (!AgcBackend.configured) return;
    try {
      final result = await AgcBackend.client.rpc('agc_public_founder_top1000');
      if (!mounted) return;
      setState(() {
        founders = List<Map<String, dynamic>>.from(result as List);
      });
    } catch (error) {
      debugPrint('Founder wall data unavailable: $error');
    }
  }

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
    if (i < founders.length) {
      return math.max(1, ((founders[i]['total_grosz'] as num?)?.toDouble() ?? 100) / 100);
    }
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
          '${i < founders.length ? founders[i]['organization_name'] : 'Wolne miejsce'}. '
          'Sugerowany poziom wsparcia: ${amount(i).toInt()} zł. '
          'Wpłaty i rezerwacje nie są jeszcze dostępne.',
          '${i < founders.length ? founders[i]['organization_name'] : 'Available space'}. Suggested support tier: '
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
      final headerHeight = compact ? 114.0 : 145.0;
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
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.auto_awesome, size: 13, color: gold),
                  const SizedBox(width: 5),
                  Text('${founders.length} / 1000 TOP',
                    style: const TextStyle(fontSize: 11, color: gold)),
                  const SizedBox(width: 12),
                  Flexible(child: TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                      foregroundColor: gold),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) =>
                        const GenesisFounderDirectory())),
                    icon: const Icon(Icons.format_list_bulleted, size: 16),
                    label: Text(GenesisLanguage.copy(
                      'Wszystkie wpłaty i filtry →', 'All support & filters →'),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  )),
                ]),
                const SizedBox(height: 4),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Flexible(child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: gold, foregroundColor: const Color(0xFF101C2C),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => Scaffold(
                        appBar: AppBar(title: Text(GenesisLanguage.copy(
                          'Logowanie fundatora', 'Founder sign in'))),
                        body: const GenesisFounderAccount()))),
                    icon: const Icon(Icons.login_rounded, size: 16),
                    label: Text(GenesisLanguage.copy('Logowanie', 'Sign in'),
                      maxLines: 1, overflow: TextOverflow.ellipsis))),
                  const SizedBox(width: 8),
                  Flexible(child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: gold,
                      side: BorderSide(color: gold.withValues(alpha: .75)),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => Scaffold(
                        appBar: AppBar(title: Text(GenesisLanguage.copy(
                          'Rejestracja fundatora', 'Founder registration'))),
                        body: const GenesisFounderAccount(startRegistering: true)))),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                    label: Text(GenesisLanguage.copy('Rejestracja', 'Register'),
                      maxLines: 1, overflow: TextOverflow.ellipsis))),
                ]),
              ],
            )),
            const SizedBox(height: 6),
            Expanded(child: LayoutBuilder(builder: (context, mosaicBounds) {
              final size = Size(
                math.max(1, mosaicBounds.maxWidth),
                math.max(1, mosaicBounds.maxHeight));
              final tiles = layout(size);
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: gold.withValues(alpha: .65), width: 1.5),
                  boxShadow: [BoxShadow(color: gold.withValues(alpha: .10),
                    blurRadius: 18, spreadRadius: 1)],
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Color(0xFF162A42), Color(0xFF060E1C)])),
                padding: const EdgeInsets.all(4),
                child: ClipRRect(borderRadius: BorderRadius.circular(9),
                  child: GestureDetector(
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
                  painter: _FounderWallPainter(tiles, displayedIds, founders),
                ),
              )));
            })),
            const SizedBox(height: 5),
            Text(GenesisLanguage.copy(
              'Widoczne: 1000 najwyższych zweryfikowanych wpłat. Płatności jeszcze nieaktywne.',
              'Showing: top 1000 verified supporters. Payments not active yet.'),
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 9, color: Colors.white70)),
          ]),
        ),
      );
    },
  );
}

class _FounderWallPainter extends CustomPainter {
  _FounderWallPainter(this.tiles, this.displayedIds, this.founders);
  final List<Rect> tiles;
  final List<int> displayedIds;
  final List<Map<String, dynamic>> founders;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..style = PaintingStyle.fill;
    final border = Paint()
      ..color = const Color(0xFF8A7142)
      ..strokeWidth = .7
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < tiles.length; i++) {
      final r = tiles[i].deflate(.45);
      fill.color = i < 20
          ? const Color(0xFF6A512B)
          : i < 200
              ? const Color(0xFF254663)
              : const Color(0xFF172B40);
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(1.5)), fill);
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(1.5)), border);
      if (i < 20) {
        final shine = Paint()
          ..color = const Color(0xFFEDC984).withValues(alpha: .12)
          ..strokeWidth = 1;
        canvas.drawLine(r.topLeft, r.topRight, shine);
      }
      if (r.width >= 22 && r.height >= 11) {
        final label = TextPainter(
          text: TextSpan(
            text: displayedIds[i] < founders.length
              ? (founders[displayedIds[i]]['organization_name'] as String? ?? '')
              : '#${displayedIds[i] + 1}',
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
