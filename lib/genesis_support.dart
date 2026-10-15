import 'package:flutter/material.dart';
import 'agc_luxury_theme.dart';
import 'genesis_language.dart';

/// Voluntary personal appreciation for the creator's time and work.
/// Payments are not active; no amounts are collected here.
class GenesisSupport extends StatelessWidget {
  const GenesisSupport({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
    valueListenable: GenesisLanguage.selected,
    builder: (context, language, _) => Card(
      key: const Key('genesis_support_mission'),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            GenesisLanguage.copy(
              'WESPRZYJ TWÓRCĘ THE GENESIS ERA',
              'SUPPORT THE CREATOR OF THE GENESIS ERA',
            ),
            style: const TextStyle(
              color: AgcLuxury.champagne,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(GenesisLanguage.copy(
            'Tworzę i rozwijam THE GENESIS ERA, poświęcając temu swój czas, '
            'energię i pracę. Jeśli cenisz tę inicjatywę i chcesz pomóc mi '
            'kontynuować jej rozwój, możesz w przyszłości przekazać '
            'dobrowolny datek jako wyraz uznania za moje zaangażowanie.',
            'I create and develop THE GENESIS ERA, dedicating my time, '
            'energy and work to it. If you value this initiative and want '
            'to help me continue, you will be able to make a voluntary '
            'contribution in appreciation of my efforts.',
          )),
          const SizedBox(height: 12),
          Text(
            GenesisLanguage.copy(
              'CZYM JEST TWOJE WSPARCIE?',
              'WHAT DOES YOUR SUPPORT MEAN?',
            ),
            style: const TextStyle(
              color: AgcLuxury.champagne,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 7),
          Text(GenesisLanguage.copy(
            'Datek jest dobrowolnym wsparciem finansowym dla mnie, '
            'twórcy projektu, i może stanowić moje osobiste wynagrodzenie '
            'za poświęcony czas, pracę oraz zaangażowanie. Nie jest '
            'wpłatą na wydzielony fundusz społeczności ani obietnicą '
            'przeznaczenia pieniędzy wyłącznie na koszty techniczne.',
            'A contribution is voluntary financial support for me, '
            'the project creator, and may serve as my personal compensation '
            'for the time, work and dedication I put in. It is not a '
            'payment into a restricted community fund or a promise '
            'that money will be spent only on technical costs.',
          )),
          const SizedBox(height: 12),
          Text(GenesisLanguage.copy(
            'Wpłaty nie są jeszcze uruchomione. Wsparcie nie daje '
            'punktów GP, wyższej rangi, specjalnych praw ani gwarancji '
            'kontaktu z AI. Udział w społeczności nie wymaga wpłaty.',
            'Payments are not yet enabled. Support does not grant '
            'GP points, a higher rank, special rights or a guarantee '
            'of contact with AI. Joining the community does not '
            'require a contribution.',
          ), style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          )),
        ]),
      ),
    ),
  );
}
