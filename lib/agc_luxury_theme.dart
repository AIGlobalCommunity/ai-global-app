import 'package:flutter/material.dart';

/// AGC visual identity: midnight blue, satin surfaces and champagne gold.
/// All decoration is lightweight Flutter vector UI (no network assets).
abstract final class AgcLuxury {
  static const midnight = Color(0xFF060C17);
  static const navy = Color(0xFF0B1729);
  static const panel = Color(0xFF142238);
  static const champagne = Color(0xFFE3C78C);
  static const mutedGold = Color(0xFFB99757);
  static const ivory = Color(0xFFF5F1E7);
  static const mutedText = Color(0xFFAEB8C8);

  static final cardDecoration = BoxDecoration(
    borderRadius: BorderRadius.circular(22),
    border: Border.all(color: champagne.withValues(alpha: .28), width: .8),
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF203249), Color(0xFF111D31), Color(0xFF0B1526)],
      stops: [0, .55, 1],
    ),
    boxShadow: [
      BoxShadow(color: Colors.black.withValues(alpha: .2),
        blurRadius: 20, offset: const Offset(0, 10)),
    ],
  );

  static ThemeData theme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: champagne,
      brightness: Brightness.dark,
      surface: navy,
    ).copyWith(
      primary: champagne,
      onPrimary: midnight,
      secondary: mutedGold,
      onSurface: ivory,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: midnight,
      fontFamily: 'Georgia',
      textTheme: const TextTheme(
        headlineSmall: TextStyle(color: ivory, fontWeight: FontWeight.w600,
          letterSpacing: 1.4),
        titleLarge: TextStyle(color: champagne, fontWeight: FontWeight.w600),
        bodyMedium: TextStyle(color: ivory, height: 1.42),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: midnight,
        foregroundColor: champagne,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: champagne,
          fontFamily: 'Georgia', letterSpacing: 2, fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: panel,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: champagne.withValues(alpha: .22)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF152238),
        labelStyle: const TextStyle(color: mutedText),
        floatingLabelStyle: const TextStyle(color: champagne),
        prefixIconColor: champagne,
        suffixIconColor: champagne,
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 17),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: champagne.withValues(alpha: .26)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: champagne, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: champagne,
          foregroundColor: midnight,
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold, letterSpacing: .5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          foregroundColor: champagne,
          side: BorderSide(color: champagne.withValues(alpha: .48)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: navy,
        indicatorColor: champagne.withValues(alpha: .15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) =>
          TextStyle(fontSize: 11, letterSpacing: .3,
            color: states.contains(WidgetState.selected)
              ? champagne : mutedText)),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? champagne : mutedText,
        )),
      ),
      dividerTheme: DividerThemeData(
        color: champagne.withValues(alpha: .18)),
    );
  }
}

/// Celestial night sky inspired by the AGC luxury login artwork.
/// Painted locally in Flutter, so the background also works offline on iOS.
class AgcLuxuryBackdrop extends StatelessWidget {
  const AgcLuxuryBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox.expand(
    child: CustomPaint(
      painter: const _AgcCosmicPainter(),
      child: child,
    ),
  );
}

class _AgcCosmicPainter extends CustomPainter {
  const _AgcCosmicPainter();

  static const _gold = Color(0xFFE8C27C);
  static const _night = Color(0xFF040A14);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF030814), Color(0xFF0A1728), _night],
      stops: [0, .58, 1],
    ).createShader(rect));

    // The star positions are deterministic; no animations or layout shifts.
    for (var i = 0; i < 145; i++) {
      final x = ((i * 73 + 19) % 997) / 997 * w;
      final y = ((i * 173 + 41) % 991) / 991 * h;
      final r = i % 19 == 0 ? 1.45 : (i % 5 == 0 ? .85 : .43);
      final opacity = i % 7 == 0 ? .76 : .34;
      canvas.drawCircle(Offset(x, y), r, Paint()
        ..color = _gold.withValues(alpha: opacity));
      if (i % 31 == 0) {
        final star = Paint()..color = _gold.withValues(alpha: .35)
          ..strokeWidth = .65;
        canvas.drawLine(Offset(x - 7, y), Offset(x + 7, y), star);
        canvas.drawLine(Offset(x, y - 7), Offset(x, y + 7), star);
      }
    }

    // Very fine celestial rings frame the screen, like the reference artwork.
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .75
      ..color = _gold.withValues(alpha: .20);
    canvas.drawOval(Rect.fromCenter(
      center: Offset(w * .5, h * .39),
      width: w * 1.75, height: h * 1.42,
    ), arcPaint);
    canvas.drawOval(Rect.fromCenter(
      center: Offset(w * .5, h * .39),
      width: w * 1.62, height: h * 1.34,
    ), arcPaint..color = _gold.withValues(alpha: .10));

    // The illuminated Earth horizon sits behind the lower part of the UI.
    final planetTop = h * .79;
    final planetRect = Rect.fromLTWH(-w * .44, planetTop, w * 1.88, h * .72);
    canvas.drawOval(planetRect, Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF203A56), Color(0xFF0A1B31), Color(0xFF030914)],
      stops: [0, .38, 1],
    ).createShader(planetRect));
    canvas.drawOval(planetRect, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..shader = LinearGradient(
        colors: [
          _gold.withValues(alpha: .05),
          const Color(0xFFFFDE91).withValues(alpha: .82),
          _gold.withValues(alpha: .05),
        ],
      ).createShader(Rect.fromLTWH(0, planetTop, w, 10)));

    // Soft glow along the horizon, never obscuring form fields.
    canvas.drawOval(Rect.fromLTWH(-w * .3, planetTop - 14, w * 1.6, 38),
      Paint()..shader = RadialGradient(colors: [
        _gold.withValues(alpha: .19), Colors.transparent,
      ]).createShader(Rect.fromLTWH(-w * .3, planetTop - 14, w * 1.6, 38)));

    // Dark veil makes foreground copy and input controls readable.
    canvas.drawRect(rect, Paint()..shader = LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [
        Colors.transparent,
        _night.withValues(alpha: .10),
        _night.withValues(alpha: .34),
      ],
      stops: const [0, .52, 1],
    ).createShader(rect));
  }

  @override
  bool shouldRepaint(covariant _AgcCosmicPainter oldDelegate) => false;
}

/// Consistent fine gold line and an editorial section heading.
class AgcLuxuryHeading extends StatelessWidget {
  const AgcLuxuryHeading({super.key, required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(width: 58, height: 2, color: AgcLuxury.champagne),
      const SizedBox(height: 12),
      Text(title, style: const TextStyle(color: AgcLuxury.champagne,
        letterSpacing: 2, fontSize: 23, fontWeight: FontWeight.w700)),
      if (subtitle != null) ...[
        const SizedBox(height: 8),
        Text(subtitle!, style: const TextStyle(
          color: AgcLuxury.mutedText, height: 1.5)),
      ],
    ],
  );
}
