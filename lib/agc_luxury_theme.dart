import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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

/// HD cosmic wallpaper: only the artwork is baked into the asset.
/// Logo, manifesto and login controls stay native Flutter widgets.
class AgcLuxuryBackdrop extends StatelessWidget {
  const AgcLuxuryBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox.expand(
    child: Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AgcLuxury.midnight),
        SvgPicture.asset(
          'assets/agc_cosmic_background_hd.svg',
          fit: BoxFit.cover,
          alignment: Alignment.center,
          excludeFromSemantics: true,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x4D020713),
                Color(0x5E020713),
                Color(0xA6020713),
              ],
              stops: [0, .48, 1],
            ),
          ),
        ),
        child,
      ],
    ),
  );
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
